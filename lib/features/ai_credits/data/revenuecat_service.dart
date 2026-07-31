import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_config.dart';

part 'revenuecat_service.g.dart';

/// Kept alive because this wraps a process-wide native singleton. Under
/// autoDispose the instance that startup configured was thrown away, and every
/// later read built a fresh, unconfigured one.
@Riverpod(keepAlive: true)
RevenueCatService revenueCatService(Ref ref) {
  return RevenueCatService(config: ref.watch(appConfigProvider));
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
class RevenueCatService {
  RevenueCatService({required AppConfig config}) : _config = config;

  final AppConfig _config;

  /// Static because [Purchases] is a process-wide native singleton: once it has
  /// been configured, it is configured for every instance of this wrapper.
  ///
  /// This was an instance field, which silently broke the whole paywall — app
  /// startup configured one instance, and any later instance reported
  /// `_configured == false`, so [getOfferings] returned null at its guard and
  /// the UI rendered "packs unavailable" forever.
  static bool _configured = false;

  bool get _canUse =>
      _config.aiCreditsEnabled && _config.revenueCatApiKey.isNotEmpty;

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
    if (!_canUse) return;
    if (_configured) return;

    // Guard against a wrong-platform / malformed key reaching the native SDK,
    // which would crash the app rather than throw a catchable Dart error.
    if (!_isKeyValidForPlatform(_config.revenueCatApiKey)) {
      if (kDebugMode) {
        debugPrint(
          '[RevenueCatService] skipping configure: API key does not '
          'match required prefix "$_requiredKeyPrefix" for this platform. '
          'RevenueCat is disabled for this session.',
        );
      }
      return;
    }

    try {
      await Purchases.configure(
        PurchasesConfiguration(_config.revenueCatApiKey),
      );
      _configured = true;
      if (kDebugMode) {
        debugPrint(
          '[RevenueCatService] configured (key suffix: '
          '...${_config.revenueCatApiKey.substring((_config.revenueCatApiKey.length - 4).clamp(0, _config.revenueCatApiKey.length), _config.revenueCatApiKey.length)})',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatService] configure error (non-fatal): $e');
      }
    }
  }

  /// Identify the signed-in user with RevenueCat.
  ///
  /// No-op when the SDK is not configured.
  Future<void> logIn(String userId) async {
    if (!_configured) return;

    try {
      await Purchases.logIn(userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatService] logIn error (non-fatal): $e');
      }
    }
  }

  /// Fetch the current RevenueCat offering catalogue.
  ///
  /// Returns null when the SDK is not configured or on any error.
  Future<Offerings?> getOfferings() async {
    if (!_configured) return null;

    try {
      final offerings = await Purchases.getOfferings();
      if (kDebugMode) {
        // An empty package list is the single most common reason the paywall
        // renders "unavailable", and it is indistinguishable from a network
        // failure without this. Log what the store actually served.
        final summary = offerings.all.entries
            .map((e) => '${e.key}(${e.value.availablePackages.length})')
            .join(', ');
        debugPrint(
          '[RevenueCatService] offerings: '
          '${summary.isEmpty ? '<none>' : summary} '
          '| current=${offerings.current?.identifier ?? '<none>'}',
        );
      }
      return offerings;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatService] getOfferings error: $e');
      }
      return null;
    }
  }

  /// Purchase [pkg] through the native store.
  ///
  /// Returns true on success, false on cancellation or any error.
  /// Never throws so the controller can safely use the return value.
  Future<bool> purchase(Package pkg) async {
    if (!_configured) return false;

    try {
      await Purchases.purchase(PurchaseParams.package(pkg));
      return true;
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        if (kDebugMode) debugPrint('[RevenueCatService] purchase cancelled');
        return false;
      }
      if (kDebugMode) {
        debugPrint('[RevenueCatService] purchase error (${e.code}): $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCatService] purchase unexpected: $e');
      return false;
    }
  }

  /// Restore previous purchases.
  ///
  /// No-op (and safe) when the SDK is not configured.
  Future<void> restore() async {
    if (!_configured) return;

    try {
      await Purchases.restorePurchases();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatService] restore error (non-fatal): $e');
      }
    }
  }
}
