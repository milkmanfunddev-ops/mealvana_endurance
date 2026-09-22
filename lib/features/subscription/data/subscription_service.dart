import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../ai_credits/data/revenuecat_service.dart';
import '../domain/entitlement.dart';

part 'subscription_service.g.dart';

/// The RevenueCat offering that carries the normal prices (`$rc_monthly`,
/// `$rc_annual`). The paywall sells whatever offering is current (mp-453);
/// this one is the fallback when none is marked current and the source of
/// the struck-through price while another offering is current.
const String kProOfferingId = 'default';

/// The offering made current from 1 October to 30 November: the founding
/// prices, sold under the same package slots as [kProOfferingId] (mp-452,
/// mp-453). Switching to it and back is a dashboard change, never a release.
const String kFoundingOfferingId = 'founding';

/// Where a subscriber manages the subscription when RevenueCat has no
/// `managementURL` for them (no purchase on record yet, or the SDK is not
/// configured): the store's own subscriptions page.
const String kAppleSubscriptionsUrl =
    'https://apps.apple.com/account/subscriptions';
const String kGoogleSubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions';

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

/// Subscription-side wrapper over [Purchases] — CustomerInfo, the offering,
/// purchase/restore, management URL — layered on [RevenueCatService], which
/// owns configure/logIn and the store-error handling for purchases.
///
/// Same contract as [RevenueCatService]: every method is safe before the SDK
/// is configured (returns null / no-ops), never throws, and reports every
/// failure to Sentry with a breadcrumb trail so a "never unlocked" report
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

  /// The RevenueCat app user id the SDK's cache currently belongs to, or
  /// null when the SDK is unavailable. A local read — no network.
  Future<String?> currentAppUserId() async {
    if (!isAvailable) return null;
    try {
      return await Purchases.appUserID;
    } catch (e, st) {
      _report('appUserID failed', e, stackTrace: st);
      return null;
    }
  }

  /// Identify [userId] with RevenueCat (idempotent; a no-op before configure).
  Future<void> logIn(String userId) => _revenueCat.logIn(userId);

  /// The status RevenueCat currently holds for the identified customer.
  ///
  /// With a cache on disk the SDK answers from it at once, online or not
  /// (the cache is the answer whenever there is one, mp-284); with no cache
  /// it fetches, and an offline fetch fails. Null when the SDK is unavailable
  /// or the call fails — the caller treats that as locked.
  Future<SubscriptionStatus?> fetchStatus() async {
    if (!isAvailable) {
      _crumb('fetchStatus skipped: SDK not configured');
      return null;
    }
    try {
      final info = await Purchases.getCustomerInfo();
      final status = statusFromCustomerInfo(info);
      _crumb('customer info fetched', {
        'active': status.active,
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
  /// which is how the gate reacts to a refresh (mp-284).
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
        'active': status.active,
        'expires_at': status.expiresAt?.toIso8601String(),
      });
      onChange(status);
    }

    _sdkListener = listener;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Every offering RevenueCat serves this customer, including which one is
  /// current, or null when the SDK is unavailable / the fetch failed.
  Future<Offerings?> fetchOfferings() async {
    final offerings = await _revenueCat.getOfferings();
    if (offerings == null) return null;
    _crumb('offerings fetched', {
      'current': offerings.current?.identifier,
      'available': offerings.all.keys.join(','),
    });
    return offerings;
  }

  /// Product ids among [productIds] the store says are NOT eligible for
  /// their introductory offer (one free week per person per subscription
  /// group; a cancelled trial is not repeated, mp-279). Unknown eligibility
  /// is not in the set — the store sheet states the real terms at purchase.
  /// Empty when the SDK is unavailable or the check fails.
  Future<Set<String>> introIneligibleProductIds(List<String> productIds) async {
    if (!isAvailable || productIds.isEmpty) return const {};
    try {
      final result = await Purchases.checkTrialOrIntroductoryPriceEligibility(
        productIds,
      );
      return {
        for (final entry in result.entries)
          if (entry.value.status ==
              IntroEligibilityStatus.introEligibilityStatusIneligible)
            entry.key,
      };
    } catch (e, st) {
      _report('intro eligibility check failed', e, stackTrace: st);
      return const {};
    }
  }

  /// Purchase [pkg] through the store. True on success, false on cancel or
  /// error — [RevenueCatService.purchase] already reports the distinction.
  Future<bool> purchase(Package pkg) => _revenueCat.purchase(pkg);

  /// Restore purchases and return the resulting status (null when the SDK
  /// is unavailable or the store call fails).
  Future<SubscriptionStatus?> restore() async {
    if (!isAvailable) {
      _crumb('restore skipped: SDK not configured');
      return null;
    }
    try {
      final info = await Purchases.restorePurchases();
      final status = statusFromCustomerInfo(info);
      _crumb('restore completed', {'active': status.active});
      return status;
    } catch (e, st) {
      _report('restorePurchases failed', e, stackTrace: st);
      return null;
    }
  }

  /// Where this customer manages the subscription: RevenueCat's
  /// `managementURL` when it has one, else the platform store's
  /// subscriptions page. Never null on a phone; null on the web.
  Future<Uri?> managementUrl() async {
    if (isAvailable) {
      try {
        final info = await Purchases.getCustomerInfo();
        final url = info.managementURL;
        if (url != null && url.isNotEmpty) {
          final parsed = Uri.tryParse(url);
          if (parsed != null) return parsed;
        }
      } catch (e, st) {
        _report('managementURL read failed', e, stackTrace: st);
      }
    }
    return storeSubscriptionsUrl(defaultTargetPlatform);
  }

  /// The platform store's own subscriptions page; null off iOS / Android.
  @visibleForTesting
  static Uri? storeSubscriptionsUrl(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS => Uri.parse(kAppleSubscriptionsUrl),
      TargetPlatform.android => Uri.parse(kGoogleSubscriptionsUrl),
      _ => null,
    };
  }

  /// Map a [CustomerInfo] to the [SubscriptionStatus]. Only the ACTIVE
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
      willRenew: info.willRenew,
    );
  }

  /// The free introductory offer a store product carries, or null when it
  /// has none or the offer is a discount rather than free.
  static IntroOffer? introOfferOf(StoreProduct product) {
    final intro = product.introductoryPrice;
    if (intro == null || intro.price != 0) return null;
    final days = IntroOffer.daysFor(
      unit: intro.periodUnit.name,
      count: intro.periodNumberOfUnits * (intro.cycles < 1 ? 1 : intro.cycles),
    );
    return days == null ? null : IntroOffer(freeDays: days);
  }
}
