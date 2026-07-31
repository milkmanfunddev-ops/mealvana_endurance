import 'package:flutter/foundation.dart';
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
  RevenueCatService({required AppConfig config, required SentryReporter sentry})
    : _config = config,
      _sentry = sentry;

  final AppConfig _config;
  final SentryReporter _sentry;

  /// Static because [Purchases] is a process-wide native singleton: once it has
  /// been configured, it is configured for every instance of this wrapper.
  ///
  /// This was an instance field, which silently broke the whole paywall — app
  /// startup configured one instance, and any later instance reported
  /// `_configured == false`, so [getOfferings] returned null at its guard and
  /// the UI rendered "packs unavailable" forever.
  static bool _configured = false;

  /// Whether the SDK completed [configureIfPossible]. Exposed so callers can
  /// tell "the store said no" apart from "we never reached the store", which
  /// are indistinguishable from a null/false return.
  static bool get isConfigured => _configured;

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
    if (key.startsWith('test_')) return true;
    final prefix = _requiredKeyPrefix;
    return prefix != null && key.startsWith(prefix);
  }

  /// Configure the RevenueCat SDK.
  ///
  /// No-op when [AppConfig.aiCreditsEnabled] is false, the platform API key is
  /// absent, or the key does not match the platform's required prefix. Safe to
  /// call multiple times; subsequent calls after the first successful
  /// configuration are skipped.
  Future<void> configureIfPossible() async {
    if (!_canUse) {
      // Not an error — the flag is off or no key is provisioned. But it is the
      // most common reason the whole feature looks broken, so leave a trail.
      _crumb('configure skipped: feature unavailable', {
        'ai_credits_enabled': _config.aiCreditsEnabled,
        'has_api_key': _config.revenueCatApiKey.isNotEmpty,
      });
      return;
    }
    if (_configured) return;

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
        'dev build using a REAL store key — REVENUECAT_API_KEY_TEST is not set, '
        'so purchases cannot complete until the SKUs exist in the live store',
      );
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(_config.revenueCatApiKey),
      );
      _configured = true;
      _crumb('configured', {'store': isTestStore ? 'test_store' : 'native'});
    } catch (e, st) {
      _report('configure failed', e, stackTrace: st);
    }
  }

  /// Identify the signed-in user with RevenueCat.
  ///
  /// No-op when the SDK is not configured. The RevenueCat App User ID **must**
  /// be the Supabase auth user id — the `revenuecat-webhook` edge function maps
  /// `app_user_id` straight onto our user, so a missed login means a real
  /// purchase credits nobody's wallet.
  Future<void> logIn(String userId) async {
    if (!_configured) {
      _crumb('logIn skipped: SDK not configured');
      return;
    }

    try {
      await Purchases.logIn(userId);
      _crumb('logged in');
    } catch (e, st) {
      _report('logIn failed', e, stackTrace: st);
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
      final offerings = await Purchases.getOfferings();
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
      await Purchases.purchase(PurchaseParams.package(pkg));
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
      _report(
        'purchase failed (unexpected)',
        e,
        stackTrace: st,
        tags: {'sku': sku},
      );
      return false;
    }
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
      await Purchases.restorePurchases();
      _crumb('restore completed');
    } catch (e, st) {
      _report('restore failed', e, stackTrace: st);
    }
  }
}
