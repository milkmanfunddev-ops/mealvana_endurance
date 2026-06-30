import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_config.dart';

part 'revenuecat_service.g.dart';

@riverpod
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
  bool _configured = false;

  bool get _canUse => _config.aiCreditsEnabled && _config.revenueCatApiKey.isNotEmpty;

  /// Configure the RevenueCat SDK.
  ///
  /// No-op when [AppConfig.aiCreditsEnabled] is false or the platform API key
  /// is absent. Safe to call multiple times; subsequent calls after the first
  /// successful configuration are skipped.
  Future<void> configureIfPossible() async {
    if (!_canUse) return;
    if (_configured) return;

    try {
      await Purchases.configure(
        PurchasesConfiguration(_config.revenueCatApiKey),
      );
      _configured = true;
      if (kDebugMode) {
        debugPrint('[RevenueCatService] configured (key suffix: '
            '...${_config.revenueCatApiKey.substring(
          (_config.revenueCatApiKey.length - 4).clamp(0, _config.revenueCatApiKey.length),
          _config.revenueCatApiKey.length,
        )})');
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
      return await Purchases.getOfferings();
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
