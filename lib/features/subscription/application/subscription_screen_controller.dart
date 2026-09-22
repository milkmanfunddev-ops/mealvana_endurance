import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/subscription_service.dart';
import '../domain/entitlement.dart';
import 'subscription_status_provider.dart';

part 'subscription_screen_controller.g.dart';

/// Which of the four plan states the Subscription screen shows (mp-495 §2).
enum PlanStatus {
  /// In the free week; [SubscriptionScreenState.date] is the day it ends.
  trial,

  /// Subscribed at the normal price; the date is the renewal (or, once
  /// cancelled, the day it ends).
  active,

  /// Subscribed on a founding product (mp-452); dated as [active].
  founding,

  /// No plan running now; the date is the day it ended, when known.
  ended,
}

/// What the Subscription screen shows.
class SubscriptionScreenState {
  const SubscriptionScreenState({
    required this.plan,
    this.date,
    this.willRenew = false,
    this.canManage = false,
  });

  final PlanStatus plan;

  /// Trial end, renewal or end date (UTC), per [plan]. Null when RevenueCat
  /// has none (an open-ended grant, or no plan on record).
  final DateTime? date;

  /// Whether the store renews (or, in a trial, starts charging) at [date].
  final bool willRenew;

  /// Manage subscription is offered only with a store subscription on
  /// record, running or ended (mp-495 §3, as the paywall's ⋯ menu, mp-494).
  final bool canManage;

  /// Upgrade (opens the paywall) is offered only once the plan has ended
  /// (mp-495 §3).
  bool get canUpgrade => plan == PlanStatus.ended;

  /// Pure: the screen's state for [status]. A founding member is one whose
  /// running plan is a founding product (`me_pro_*_founding`, mp-452); the
  /// free week outranks it, since its end date is the one that matters.
  static SubscriptionScreenState from(
    SubscriptionStatus status, {
    required bool hasStoreSubscription,
  }) {
    final PlanStatus plan;
    if (!status.active) {
      plan = PlanStatus.ended;
    } else if (status.isTrial) {
      plan = PlanStatus.trial;
    } else if (isFoundingProduct(status.productId)) {
      plan = PlanStatus.founding;
    } else {
      plan = PlanStatus.active;
    }
    return SubscriptionScreenState(
      plan: plan,
      date: status.expiresAt,
      willRenew: status.active && status.willRenew,
      canManage: hasStoreSubscription,
    );
  }

  /// Whether [productId] is one of the founding products the `founding`
  /// offering sells (dev and `_prod` SKUs alike).
  static bool isFoundingProduct(String? productId) =>
      productId != null && productId.contains('_$kFoundingOfferingId');
}

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), whether there is a store
/// subscription to manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a purchase made through Upgrade
/// turns "ended" into the running plan while the screen is open.
@riverpod
class SubscriptionScreenController extends _$SubscriptionScreenController {
  @override
  Future<SubscriptionScreenState> build() async {
    final status = await ref.watch(subscriptionStatusProvider.future);
    final hasStoreSubscription = await ref
        .read(subscriptionServiceProvider)
        .hasStoreSubscriptionOnRecord();
    return SubscriptionScreenState.from(
      status,
      hasStoreSubscription: hasStoreSubscription,
    );
  }

  /// Where Manage subscription goes: the same as the paywall's ⋯ menu entry
  /// (RevenueCat's management URL, else the store's own subscriptions page).
  Future<Uri?> managementUrl() =>
      ref.read(subscriptionServiceProvider).managementUrl();
}
