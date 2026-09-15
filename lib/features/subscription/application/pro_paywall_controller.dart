import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/sentry/sentry_reporter.dart';
import '../data/subscription_service.dart';
import '../data/user_entitlements_repository.dart';
import '../domain/entitlement.dart';
import 'subscription_status_provider.dart';

part 'pro_paywall_controller.g.dart';

/// What actually happened during [ProPaywallController.buy] — each outcome
/// carries its own honest message on the screen (same lesson as
/// [PurchaseOutcome] for credit packs: never tell a charged user nothing
/// happened).
enum ProPurchaseOutcome {
  /// Store confirmed and the status provider now reports active.
  activated,

  /// Store confirmed but the status had not flipped yet — RevenueCat's push
  /// is late. The money is real; the CustomerInfo listener will open the
  /// app when it lands.
  purchasedPending,

  /// User dismissed the store sheet. Not an error.
  cancelled,

  /// Nobody is signed in — refused before the store was contacted.
  notSignedIn,

  /// Anonymous session — refused; the UI routes to account creation (the
  /// link-in-place upgrade keeps the auth id the webhook will map).
  requiresAccount,

  /// Store rejected the purchase or the SDK is unconfigured.
  failed,
}

/// The two plans the paywall offers, with the store's word on who still
/// qualifies for the free week. Either package may be missing when the store
/// served nothing; the screen renders its "plans unavailable" state then.
class PaywallPlans {
  const PaywallPlans({
    this.monthly,
    this.annual,
    this.introIneligible = const {},
  });

  final Package? monthly;
  final Package? annual;

  /// Product ids whose introductory offer this customer may not use again.
  final Set<String> introIneligible;

  bool get isEmpty => monthly == null && annual == null;

  /// The free introductory offer to show for [pkg], or null when the product
  /// carries none or this customer is no longer eligible.
  IntroOffer? introOfferFor(Package pkg) {
    if (introIneligible.contains(pkg.storeProduct.identifier)) return null;
    return SubscriptionService.introOfferOf(pkg.storeProduct);
  }
}

/// The `default` offering's monthly and annual packages plus intro
/// eligibility, read once per paywall visit.
@riverpod
Future<PaywallPlans> paywallPlans(Ref ref) async {
  final service = ref.read(subscriptionServiceProvider);
  final offering = await service.fetchProOffering();
  if (offering == null) return const PaywallPlans();
  final monthly = offering.monthly ?? offering.getPackage(r'$rc_monthly');
  final annual = offering.annual ?? offering.getPackage(r'$rc_annual');
  final ids = [
    if (monthly != null) monthly.storeProduct.identifier,
    if (annual != null) annual.storeProduct.identifier,
  ];
  final ineligible = await service.introIneligibleProductIds(ids);
  return PaywallPlans(
    monthly: monthly,
    annual: annual,
    introIneligible: ineligible,
  );
}

/// Drives purchase, restore and "manage subscription" for the paywall.
///
/// State is `AsyncValue<void>`: loading while a store call is in flight,
/// data when idle, error when the last operation failed unexpectedly.
///
/// keepAlive for the same reason as [PurchaseController]: the screen only
/// `ref.read`s the notifier to call [buy], so under autoDispose the notifier
/// could be torn down at the first await and every later `ref` use would
/// throw — a purchase in flight must outlive the widget that started it.
@Riverpod(keepAlive: true)
class ProPaywallController extends _$ProPaywallController {
  SubscriptionService get _service => ref.read(subscriptionServiceProvider);
  UserEntitlementsRepository get _repo =>
      ref.read(userEntitlementsRepositoryProvider);

  @override
  FutureOr<void> build() => null;

  /// Purchase [pkg]. Refuses (before touching the store) when nobody is
  /// signed in or the session is anonymous; re-asserts the RevenueCat
  /// identity; then buys and refreshes the status provider.
  Future<ProPurchaseOutcome> buy(Package pkg) async {
    final sku = pkg.storeProduct.identifier;
    final sentry = ref.read(sentryReporterProvider);

    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) {
      await sentry.reportCriticalError(
        StateError('Purchase attempted with no signed-in user (sku: $sku)'),
        context: 'subscription',
        tags: {'rc_operation': 'buy_unauthenticated', 'sku': sku},
      );
      return ProPurchaseOutcome.notSignedIn;
    }
    if (_repo.isAnonymousUser) {
      sentry.addBreadcrumb(
        message: 'purchase blocked: anonymous session',
        category: 'subscription',
        data: {'sku': sku},
      );
      return ProPurchaseOutcome.requiresAccount;
    }

    state = const AsyncLoading();
    var outcome = ProPurchaseOutcome.failed;
    state = await AsyncValue.guard(() async {
      // Same idempotent re-login as the credit path: anyone who signed in
      // after launch still carries the anonymous RevenueCat id otherwise.
      await _service.logIn(userId);

      final success = await _service.purchase(pkg);
      if (!success) {
        // Cancel vs. store error was already reported by the service.
        outcome = ProPurchaseOutcome.cancelled;
        return;
      }

      final status = await _refreshStatus();
      outcome = status.active
          ? ProPurchaseOutcome.activated
          : ProPurchaseOutcome.purchasedPending;
      if (!status.active) {
        sentry.addBreadcrumb(
          message: 'purchase completed but status not yet active',
          category: 'subscription',
          data: {'sku': sku},
        );
      }
    });

    if (state is AsyncError) {
      final err = state as AsyncError;
      outcome = ProPurchaseOutcome.failed;
      await sentry.reportCriticalError(
        err.error,
        stackTrace: err.stackTrace,
        context: 'subscription',
        tags: {'rc_operation': 'buy', 'sku': sku},
      );
    }
    return outcome;
  }

  /// Restore purchases through the store and refresh the status provider.
  /// Returns whether the app is unlocked afterwards.
  Future<bool> restore() async {
    state = const AsyncLoading();
    var active = false;
    state = await AsyncValue.guard(() async {
      final userId = _repo.currentUserId;
      if (userId != null && userId.isNotEmpty) await _service.logIn(userId);
      await _service.restore();
      active = (await _refreshStatus()).active;
    });
    return active;
  }

  /// Where "Manage subscription" goes: RevenueCat's management URL for this
  /// customer, else the platform store's subscriptions page. Null only on a
  /// platform with no store (web).
  Future<Uri?> managementUrl() => _service.managementUrl();

  Future<SubscriptionStatus> _refreshStatus() async {
    await ref.read(subscriptionStatusProvider.notifier).refresh();
    return ref.read(subscriptionStatusProvider.future);
  }
}
