import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_config.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../ai_credits/data/revenuecat_service.dart';
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
  /// Store confirmed and the status provider now reports Pro.
  activated,

  /// Store confirmed but the status had not flipped yet — RevenueCat's push
  /// or the webhook is late. The money is real; the CustomerInfo listener
  /// will flip the tab when it lands.
  purchasedPending,

  /// User dismissed the store sheet. Not an error.
  cancelled,

  /// Nobody is signed in — refused before the store was contacted.
  notSignedIn,

  /// Anonymous session — refused; the UI routes to account creation (the
  /// link-in-place upgrade keeps the auth id the webhook will map).
  requiresAccount,

  /// `PRO_PURCHASE_ENABLED` is off for this build; the UI should not have
  /// offered the button.
  disabled,

  /// Store rejected the purchase or the SDK is unconfigured.
  failed,
}

/// The offering that carries `$rc_monthly` / `$rc_annual`. Null when the SDK
/// is unconfigured or the store served nothing — the screen renders its
/// "plans unavailable" state.
@riverpod
Future<Offering?> proOffering(Ref ref) {
  return ref.read(subscriptionServiceProvider).fetchProOffering();
}

/// Drives purchase and restore for the Pro subscription.
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

  /// Purchase [pkg]. Refuses (before touching the store) when purchasing is
  /// disabled for the build, nobody is signed in, or the session is
  /// anonymous; re-asserts the RevenueCat identity; then buys and refreshes
  /// the status provider.
  Future<ProPurchaseOutcome> buy(Package pkg) async {
    final sku = pkg.storeProduct.identifier;
    final sentry = ref.read(sentryReporterProvider);

    if (!ref.read(appConfigProvider).proPurchaseEnabled) {
      sentry.addBreadcrumb(
        message: 'pro purchase blocked: PRO_PURCHASE_ENABLED off',
        category: 'subscription',
        data: {'sku': sku},
      );
      return ProPurchaseOutcome.disabled;
    }

    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) {
      await sentry.reportCriticalError(
        StateError('Pro purchase attempted with no signed-in user (sku: $sku)'),
        context: 'subscription',
        tags: {'rc_operation': 'buy_unauthenticated', 'sku': sku},
      );
      return ProPurchaseOutcome.notSignedIn;
    }
    if (_repo.isAnonymousUser) {
      sentry.addBreadcrumb(
        message: 'pro purchase blocked: anonymous session',
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
      await ref.read(revenueCatServiceProvider).logIn(userId);

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
          message: 'pro purchase completed but status not yet active',
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
  /// Returns whether Pro is active afterwards.
  Future<bool> restore() async {
    state = const AsyncLoading();
    var active = false;
    state = await AsyncValue.guard(() async {
      await _service.restore();
      active = (await _refreshStatus()).active;
    });
    return active;
  }

  Future<SubscriptionStatus> _refreshStatus() async {
    await ref.read(subscriptionStatusProvider.notifier).refresh();
    return ref.read(subscriptionStatusProvider.future);
  }
}
