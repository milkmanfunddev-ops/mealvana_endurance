import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../ai_credits/data/revenuecat_service.dart';
import '../domain/entitlement.dart';

part 'subscription_service.g.dart';

/// The RevenueCat offering that carries the Pro packages (`$rc_monthly`,
/// `$rc_annual`). Falls back to `Offerings.current` when the id is renamed.
const String kProOfferingId = 'default';

/// Kept alive for the same reason as [revenueCatServiceProvider]: it wraps
/// the process-wide [Purchases] singleton and owns the one CustomerInfo
/// listener slot; an autoDispose instance would drop that listener with the
/// last watcher.
@Riverpod(keepAlive: true)
SubscriptionService subscriptionService(Ref ref) {
  return SubscriptionService(
    revenueCat: ref.watch(revenueCatServiceProvider),
    sentry: ref.watch(sentryReporterProvider),
  );
}

/// Subscription-side wrapper over [Purchases] — CustomerInfo, the Pro
/// offering, purchase/restore — layered on [RevenueCatService], which owns
/// configure/logIn and the store-error handling for purchases.
///
/// Same contract as [RevenueCatService]: every method is safe before the SDK
/// is configured (returns null / no-ops), never throws, and reports every
/// failure to Sentry with a breadcrumb trail so a "Pro never unlocked" report
/// arrives with the fetch/listener sequence attached.
class SubscriptionService {
  SubscriptionService({
    required RevenueCatService revenueCat,
    required SentryReporter sentry,
  }) : _revenueCat = revenueCat,
       _sentry = sentry;

  final RevenueCatService _revenueCat;
  final SentryReporter _sentry;

  /// The single app-level CustomerInfo listener, as registered with the SDK.
  /// One slot (not a list) so a provider rebuild can replace it without
  /// leaking the previous registration.
  CustomerInfoUpdateListener? _sdkListener;

  /// Whether the SDK is configured — the precondition for every store call.
  bool get isAvailable => RevenueCatService.isConfigured;

  void _crumb(String message, [Map<String, dynamic>? data]) {
    debugPrint('[SubscriptionService] $message${data == null ? '' : ' $data'}');
    _sentry.addBreadcrumb(
      message: message,
      category: 'subscription',
      data: data,
    );
  }

  void _report(String message, Object error, {StackTrace? stackTrace}) {
    debugPrint('[SubscriptionService] $message: $error');
    _sentry.reportCriticalError(
      error,
      stackTrace: stackTrace,
      context: 'subscription',
      tags: {'rc_operation': message},
    );
  }

  /// The Pro status RevenueCat currently holds for the identified customer.
  ///
  /// Null when the SDK is unavailable or the call fails — the caller decides
  /// whether a server row or cache should stand in.
  Future<SubscriptionStatus?> fetchStatus() async {
    if (!isAvailable) {
      _crumb('fetchStatus skipped: SDK not configured');
      return null;
    }
    try {
      final info = await Purchases.getCustomerInfo();
      final status = statusFromCustomerInfo(info);
      _crumb('customer info fetched', {
        'pro_active': status.active,
        'expires_at': status.expiresAt?.toIso8601String(),
        'is_trial': status.isTrial,
      });
      return status;
    } catch (e, st) {
      _report('getCustomerInfo failed', e, stackTrace: st);
      return null;
    }
  }

  /// Register (or replace) the app-level status listener. RevenueCat calls
  /// it whenever CustomerInfo changes — purchase, renewal, expiry, restore —
  /// and immediately with the last-known info if it already has one.
  ///
  /// Pass null to detach. Safe before configure: the SDK only stores the
  /// callback, so a listener attached early simply starts firing once
  /// configure + logIn have run.
  void setStatusListener(void Function(SubscriptionStatus status)? onChange) {
    final previous = _sdkListener;
    if (previous != null) {
      Purchases.removeCustomerInfoUpdateListener(previous);
      _sdkListener = null;
    }
    if (onChange == null) return;

    void listener(CustomerInfo info) {
      final status = statusFromCustomerInfo(info);
      _crumb('customer info updated', {
        'pro_active': status.active,
        'expires_at': status.expiresAt?.toIso8601String(),
      });
      onChange(status);
    }

    _sdkListener = listener;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// The offering that carries the Pro packages, or null when the SDK is
  /// unavailable / the store served nothing.
  Future<Offering?> fetchProOffering() async {
    final offerings = await _revenueCat.getOfferings();
    if (offerings == null) return null;
    final offering = offerings.getOffering(kProOfferingId) ?? offerings.current;
    if (offering == null) {
      _crumb('pro offering missing', {
        'available': offerings.all.keys.join(','),
      });
    }
    return offering;
  }

  /// Purchase [pkg] through the store. True on success, false on cancel or
  /// error — [RevenueCatService.purchase] already reports the distinction.
  Future<bool> purchase(Package pkg) => _revenueCat.purchase(pkg);

  /// Restore purchases and return the resulting Pro status (null when the SDK
  /// is unavailable or the store call fails).
  Future<SubscriptionStatus?> restore() async {
    if (!isAvailable) {
      _crumb('restore skipped: SDK not configured');
      return null;
    }
    try {
      final info = await Purchases.restorePurchases();
      final status = statusFromCustomerInfo(info);
      _crumb('restore completed', {'pro_active': status.active});
      return status;
    } catch (e, st) {
      _report('restorePurchases failed', e, stackTrace: st);
      return null;
    }
  }

  /// Map a [CustomerInfo] to the Pro [SubscriptionStatus]. Only the ACTIVE
  /// entitlement map counts — an expired entitlement still appears in `all`.
  static SubscriptionStatus statusFromCustomerInfo(CustomerInfo info) =>
      statusFromEntitlement(info.entitlements.active[Entitlement.pro.key]);

  /// Pure mapping from an (active) [EntitlementInfo] to a status; null → none.
  @visibleForTesting
  static SubscriptionStatus statusFromEntitlement(EntitlementInfo? info) {
    if (info == null || !info.isActive) return SubscriptionStatus.none;
    final raw = info.expirationDate;
    final expiresAt = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    return SubscriptionStatus(
      active: true,
      expiresAt: expiresAt,
      source: SubscriptionSource.revenuecat,
      isTrial:
          info.periodType == PeriodType.trial ||
          info.periodType == PeriodType.intro,
      productId: info.productIdentifier,
    );
  }
}
