import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_config.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';

part 'revenuecat_service.g.dart';

/// Kept alive because this wraps a process-wide native singleton. Under
/// autoDispose the instance that startup configured was thrown away, and every
/// later read built a fresh, unconfigured one.
@Riverpod(keepAlive: true)
RevenueCatService revenueCatService(Ref ref) {
  return RevenueCatService(
    config: ref.watch(appConfigProvider),
    sentry: ref.watch(sentryReporterProvider),
  );
}

/// Thin wrapper over [Purchases] (purchases_flutter).
///
/// All public methods are safe to call even when:
/// - [AppConfig.aiCreditsEnabled] is false.
/// - [AppConfig.revenueCatApiKey] is empty.
/// - The RevenueCat SDK has not been configured yet.
///
/// In those cases the methods are no-ops or return null/false rather than
/// throwing, so the feature flag can be flipped without crashing the app.
///
/// **Every failure path reports to Sentry.** This class swallows errors by
/// design so a store outage can never crash a purchase screen — which
/// previously meant a failed purchase produced *no signal anywhere*: the
/// diagnostics were all behind `kDebugMode`, which is false in the release-mode
/// dev builds testers actually run. Breadcrumbs record the happy path too, so a
/// Sentry event arrives with the configure/offerings/purchase sequence attached.
class RevenueCatService {
  RevenueCatService({
    required AppConfig config,
    required SentryReporter sentry,
    RevenueCatSdk sdk = const PurchasesFlutterSdk(),
    Duration configureWait = const Duration(seconds: 10),
  }) : _config = config,
       _sentry = sentry,
       _sdk = sdk,
       _configureWait = configureWait;

  final AppConfig _config;
  final SentryReporter _sentry;
  final RevenueCatSdk _sdk;

  /// How long a [logIn] asked before any configure attempt waits for one.
  /// The startup flow always makes the attempt on its critical path, so in
  /// the app the wait ends when that attempt settles; the bound is for a
  /// startup that never reaches it (a force-upgrade or resync return).
  final Duration _configureWait;

  /// Static because [Purchases] is a process-wide native singleton: once it has
  /// been configured, it is configured for every instance of this wrapper.
  ///
  /// This was an instance field, which silently broke the whole paywall — app
  /// startup configured one instance, and any later instance reported
  /// `_configured == false`, so [getOfferings] returned null at its guard and
  /// the UI rendered "packs unavailable" forever.
  static bool _configured = false;

  /// The configure attempt in flight, shared by every caller that asks while
  /// it runs, so the native SDK is configured once.
  static Future<void>? _configureAttempt;

  /// Settles when the first configure attempt has finished, configured or
  /// not. A [logIn] asked before that (the router's gate reads the
  /// subscription status the moment the router exists, ahead of the startup
  /// flow) waits on it instead of being dropped (Finding 09-013).
  static Completer<void>? _configureSettled;

  /// The `logIn` in flight and the account it is for: a second ask for the
  /// same account while it runs joins it rather than logging in again.
  static Future<void>? _logInInFlight;
  static String? _logInInFlightUserId;

  /// Whether the SDK completed [configureIfPossible]. Exposed so callers can
  /// tell "the store said no" apart from "we never reached the store", which
  /// are indistinguishable from a null/false return.
  static bool get isConfigured => _configured;

  /// Forget the process-wide state between tests. The app never calls this.
  @visibleForTesting
  static void debugResetForTesting() {
    _configured = false;
    _configureAttempt = null;
    _configureSettled = null;
    _logInInFlight = null;
    _logInInFlightUserId = null;
  }

  static Completer<void> get _settled =>
      _configureSettled ??= Completer<void>();

  bool get _canUse =>
      _config.aiCreditsEnabled && _config.revenueCatApiKey.isNotEmpty;

  /// True when the current session is talking to the RevenueCat **Test Store**
  /// rather than a real one. Purchases complete instantly and free, and the
  /// native SDK shows its own non-brandable confirmation dialog.
  bool get isTestStore => _config.revenueCatApiKey.startsWith('test_');

  /// Log both to the console and to Sentry.
  ///
  /// `debugPrint` is deliberately *not* wrapped in `kDebugMode` — release-mode
  /// dev builds are exactly the ones testers run, and silencing them there is
  /// what left a failed purchase with no trace at all.
  void _report(
    String message,
    Object error, {
    StackTrace? stackTrace,
    Map<String, String> tags = const {},
  }) {
    debugPrint('[RevenueCatService] $message: $error');
    _sentry.reportCriticalError(
      error,
      stackTrace: stackTrace,
      context: 'revenuecat',
      tags: {
        'rc_operation': message,
        'rc_store': isTestStore ? 'test_store' : 'native_store',
        ...tags,
      },
    );
  }

  void _crumb(String message, [Map<String, dynamic>? data]) {
    debugPrint('[RevenueCatService] $message${data == null ? '' : ' $data'}');
    _sentry.addBreadcrumb(message: message, category: 'revenuecat', data: data);
  }

  /// The API-key prefix the native RevenueCat SDK requires for the current
  /// platform. Passing a key with any other prefix (e.g. a Google `goog_` or a
  /// Test Store `test_` key on iOS) makes the native SDK raise a *fatal*
  /// "invalid API key" error that bypasses Dart error handling and crashes the
  /// app. We validate the prefix here so such a key is never handed to
  /// [Purchases.configure].
  String? get _requiredKeyPrefix {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'appl_';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'goog_';
    }
    return null; // Unsupported platform (web/etc.) — caller already no-ops.
  }

  /// Whether [key] is a well-formed public SDK key for the current platform.
  ///
  /// RevenueCat **Test Store** keys (`test_…`) are deliberately accepted on
  /// every platform: the Test Store is not a native store, so it has no
  /// platform-specific key and the SDK handles it directly. Rejecting them here
  /// is what previously made simulator purchase testing impossible — the guard
  /// exists to stop a *wrong-platform native* key (e.g. a `goog_` key on iOS)
  /// reaching `Purchases.configure`, where it raises a fatal error that bypasses
  /// Dart error handling.
  bool _isKeyValidForPlatform(String key) {
    // Test Store keys are platform-agnostic and legitimate — but ONLY in a
    // debug build. RevenueCat's SDK refuses them in a release binary: it puts
    // up a native "wrong API key … update your RevenueCat settings to use a
    // production key" alert at launch and kills the app when it is dismissed,
    // from native code that no Dart error handling can intercept. Accepting a
    // `test_` key purely because the *flavor* was dev is what shipped that
    // crash to TestFlight.
    if (key.startsWith('test_')) return kDebugMode;
    final prefix = _requiredKeyPrefix;
    return prefix != null && key.startsWith(prefix);
  }

  /// Configure the RevenueCat SDK.
  ///
  /// No-op when [AppConfig.aiCreditsEnabled] is false, the platform API key is
  /// absent, or the key does not match the platform's required prefix. Safe to
  /// call multiple times: a call while an attempt is in flight joins it, and
  /// calls after the first successful configuration are skipped.
  Future<void> configureIfPossible() {
    if (_configured) return Future.value();
    final inFlight = _configureAttempt;
    if (inFlight != null) return inFlight;
    final attempt = _configure().whenComplete(() {
      _configureAttempt = null;
      final settled = _settled;
      if (!settled.isCompleted) settled.complete();
    });
    _configureAttempt = attempt;
    return attempt;
  }

  Future<void> _configure() async {
    if (!_canUse) {
      // Not an error — the flag is off or no key is provisioned. But it is the
      // most common reason the whole feature looks broken, so leave a trail.
      _crumb('configure skipped: feature unavailable', {
        'ai_credits_enabled': _config.aiCreditsEnabled,
        'has_api_key': _config.revenueCatApiKey.isNotEmpty,
      });
      return;
    }

    // Guard against a wrong-platform / malformed key reaching the native SDK,
    // which would crash the app rather than throw a catchable Dart error.
    if (!_isKeyValidForPlatform(_config.revenueCatApiKey)) {
      _report(
        'configure skipped: wrong-platform API key',
        StateError(
          'RevenueCat API key does not match required prefix '
          '"$_requiredKeyPrefix" for this platform; RevenueCat is disabled '
          'for this session',
        ),
      );
      return;
    }

    // A dev build on a real store key cannot complete a purchase: the credit
    // SKUs are not provisioned in App Store Connect / Play, so the store serves
    // an empty offering and the sheet says "packs aren't available" with no
    // stated cause. That happens whenever `REVENUECAT_API_KEY_TEST` is missing
    // from the build's environment — notably CI dev builds, whose
    // `.env.dev.local` comes from the `DOTENV_DEV_LOCAL` secret rather than a
    // developer's local file. Name it rather than letting it look like an
    // outage.
    if (_config.isDevelopment && !isTestStore) {
      _crumb(
        'dev build on a REAL store key — expected in a release build, where '
        'RevenueCat forbids Test Store keys. Purchases cannot complete until '
        'the SKUs exist in the live store; use a debug build for Test Store '
        'purchases.',
      );
    }

    try {
      await _sdk.configure(PurchasesConfiguration(_config.revenueCatApiKey));
      _configured = true;
      _crumb('configured', {'store': isTestStore ? 'test_store' : 'native'});
    } catch (e, st) {
      _report('configure failed', e, stackTrace: st);
    }
  }

  /// Identify the signed-in user with RevenueCat.
  ///
  /// The RevenueCat App User ID **must** be the Supabase auth user id — the
  /// `revenuecat-webhook` edge function maps `app_user_id` straight onto our
  /// user, so a missed login means a real purchase credits nobody's wallet.
  ///
  /// Runs once per identity change, and only after configure (ticket 85,
  /// Finding 09-013): asked before the first configure attempt has settled,
  /// it waits for that attempt (bounded) instead of being dropped; asked
  /// while the same account's `logIn` is in flight, it joins it; asked for
  /// the identity the SDK already holds, it does nothing. No-op when the
  /// feature is off or the SDK could not be configured.
  Future<void> logIn(String userId) async {
    if (!_configured) {
      if (!_canUse) {
        _crumb('logIn skipped: feature unavailable');
        return;
      }
      final settled = _settled;
      if (!settled.isCompleted) {
        _crumb('logIn waiting for configure');
        await settled.future.timeout(_configureWait, onTimeout: () {});
      }
      if (!_configured) {
        _crumb('logIn skipped: SDK not configured');
        return;
      }
    }

    final inFlight = _logInInFlight;
    if (inFlight != null && _logInInFlightUserId == userId) return inFlight;

    final attempt = _logIn(userId);
    _logInInFlight = attempt;
    _logInInFlightUserId = userId;
    try {
      await attempt;
    } finally {
      if (identical(_logInInFlight, attempt)) {
        _logInInFlight = null;
        _logInInFlightUserId = null;
      }
    }
  }

  Future<void> _logIn(String userId) async {
    try {
      if (await _sdk.appUserID == userId) {
        _crumb('logIn skipped: already identified');
        return;
      }
      await _sdk.logIn(userId);
      _crumb('logged in');
    } catch (e, st) {
      _report('logIn failed', e, stackTrace: st);
    }
  }

  /// Forget the signed-in user: the SDK returns to a fresh anonymous customer
  /// with an empty CustomerInfo cache.
  ///
  /// Without this, sign-out left the SDK identified as the last account, so a
  /// signed-out phone kept fetching that customer's entitlement and the next
  /// person's first status read could be the previous person's subscription
  /// (Findings 03-002, 32-002). No-op before configure and when the SDK is
  /// already anonymous (`Purchases.logOut` throws for an anonymous user).
  Future<void> logOut() async {
    if (!_configured) {
      _crumb('logOut skipped: SDK not configured');
      return;
    }

    try {
      if (await _sdk.isAnonymous) {
        _crumb('logOut skipped: already anonymous');
        return;
      }
      await _sdk.logOut();
      _crumb('logged out');
    } catch (e, st) {
      _report('logOut failed', e, stackTrace: st);
    }
  }

  /// Fetch the current RevenueCat offering catalogue.
  ///
  /// Returns null when the SDK is not configured or on any error.
  Future<Offerings?> getOfferings() async {
    if (!_configured) {
      _crumb('getOfferings skipped: SDK not configured');
      return null;
    }

    try {
      final offerings = await _sdk.getOfferings();
      // An empty package list is the single most common reason the paywall
      // renders "unavailable", and it is indistinguishable from a network
      // failure without this. Record what the store actually served.
      final summary = offerings.all.entries
          .map((e) => '${e.key}(${e.value.availablePackages.length})')
          .join(', ');
      _crumb('offerings served', {
        'offerings': summary.isEmpty ? '<none>' : summary,
        'current': offerings.current?.identifier ?? '<none>',
      });
      return offerings;
    } catch (e, st) {
      _report('getOfferings failed', e, stackTrace: st);
      return null;
    }
  }

  /// Purchase [pkg] through the native store.
  ///
  /// Returns true on success, false on cancellation or any error.
  /// Never throws so the controller can safely use the return value.
  ///
  /// A user cancelling is reported as a breadcrumb, not an error — it is a
  /// normal outcome and would otherwise drown the real failures in Sentry.
  Future<bool> purchase(Package pkg) async {
    final sku = pkg.storeProduct.identifier;

    if (!_configured) {
      _report(
        'purchase attempted before configure',
        StateError('RevenueCat SDK not configured'),
        tags: {'sku': sku},
      );
      return false;
    }

    _crumb('purchase started', {'sku': sku});
    try {
      await _sdk.purchase(PurchaseParams.package(pkg));
      _crumb('purchase succeeded', {'sku': sku});
      return true;
    } on PurchasesError catch (e, st) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        _crumb('purchase cancelled by user', {'sku': sku});
        return false;
      }
      _report(
        'purchase failed',
        e,
        stackTrace: st,
        tags: {'sku': sku, 'rc_error_code': e.code.name},
      );
      return false;
    } catch (e, st) {
      // A user tapping Cancel does not always arrive as a typed
      // `PurchasesError`. purchases_flutter also surfaces it raw, as a
      // PlatformException out of `_invokeReturningMap` carrying
      // `readable_error_code: PURCHASE_CANCELLED` / `userCancelled: true`.
      // That shape misses the branch above and used to be reported as
      // "purchase failed (unexpected)" — Sentry MEALVANA-ENDURANCE-DEV-6E,
      // 14 events from 2 users, none of them a fault. Someone declining a
      // purchase is the system working.
      if (e is PlatformException && _isUserCancellation(e)) {
        _crumb('purchase cancelled by user (platform channel)', {'sku': sku});
        return false;
      }
      _report(
        'purchase failed (unexpected)',
        e,
        stackTrace: st,
        tags: {'sku': sku},
      );
      return false;
    }
  }

  /// Whether a raw [PlatformException] from purchases_flutter represents the
  /// user cancelling, rather than a failure.
  ///
  /// Checks the structured `details` map first and falls back to the error
  /// code, because the two platforms disagree: iOS populates `userCancelled`,
  /// Android leads with `readable_error_code`. Anything unrecognised returns
  /// false, so a genuine failure is still reported.
  @visibleForTesting
  static bool debugIsUserCancellation(PlatformException e) =>
      _isUserCancellation(e);

  static bool _isUserCancellation(PlatformException e) {
    final details = e.details;
    if (details is Map) {
      if (details['userCancelled'] == true) return true;
      if (details['readable_error_code'] == 'PURCHASE_CANCELLED') return true;
      if (details['readableErrorCode'] == 'PURCHASE_CANCELLED') return true;
    }
    // RevenueCat's numeric code 1 is PURCHASE_CANCELLED on both platforms.
    return e.code == '1' || e.code == 'PURCHASE_CANCELLED';
  }

  /// Restore previous purchases.
  ///
  /// No-op (and safe) when the SDK is not configured.
  Future<void> restore() async {
    if (!_configured) {
      _crumb('restore skipped: SDK not configured');
      return;
    }

    try {
      await _sdk.restorePurchases();
      _crumb('restore completed');
    } catch (e, st) {
      _report('restore failed', e, stackTrace: st);
    }
  }
}

/// The purchases_flutter calls [RevenueCatService] makes, behind one seam so
/// a test can stand in for the native SDK (it lives on platform channels
/// that dart:test cannot reach). Results the service never reads are
/// dropped, so a fake returns nothing.
abstract interface class RevenueCatSdk {
  Future<void> configure(PurchasesConfiguration configuration);
  Future<String> get appUserID;
  Future<void> logIn(String appUserID);
  Future<bool> get isAnonymous;
  Future<void> logOut();
  Future<Offerings> getOfferings();
  Future<void> purchase(PurchaseParams params);
  Future<void> restorePurchases();
}

/// The real SDK: the [Purchases] statics, one to one.
class PurchasesFlutterSdk implements RevenueCatSdk {
  const PurchasesFlutterSdk();

  @override
  Future<void> configure(PurchasesConfiguration configuration) =>
      Purchases.configure(configuration);

  @override
  Future<String> get appUserID => Purchases.appUserID;

  @override
  Future<void> logIn(String appUserID) => Purchases.logIn(appUserID);

  @override
  Future<bool> get isAnonymous => Purchases.isAnonymous;

  @override
  Future<void> logOut() => Purchases.logOut();

  @override
  Future<Offerings> getOfferings() => Purchases.getOfferings();

  @override
  Future<void> purchase(PurchaseParams params) => Purchases.purchase(params);

  @override
  Future<void> restorePurchases() => Purchases.restorePurchases();
}
