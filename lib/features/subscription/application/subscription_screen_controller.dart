import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/grant_source_repository.dart';
import '../data/subscription_service.dart';
import '../domain/entitlement.dart';
import '../domain/grant.dart';
import 'subscription_status_provider.dart';

part 'subscription_screen_controller.g.dart';

/// The clock a Grant's days left are counted against. A provider so tests
/// can pin it; the app never overrides it.
@riverpod
DateTime Function() subscriptionScreenClock(Ref ref) => DateTime.now;

/// Which plan state the Subscription screen shows (mp-495 §2, mp-558).
///
/// There is no ended state: a lapsed athlete stays on the full-screen
/// paywall (mp-457) and never reaches this screen (87-008).
enum PlanStatus {
  /// In the free week; [SubscriptionScreenState.date] is the day it ends.
  trial,

  /// Subscribed at the normal price; the date is the renewal (or, once
  /// cancelled, the day it ends).
  active,

  /// Subscribed on a founding product (mp-452); dated as [active].
  founding,

  /// Pro from a Grant (mp-558): where it came from
  /// ([SubscriptionScreenState.grantSource]) and its days left
  /// ([SubscriptionScreenState.daysLeft]).
  grant,
}

/// The plan bought, as the paywall sells it (mp-628: the athlete "sees the
/// plan they bought").
enum PlanTerm { monthly, annual }

/// What the Subscription screen shows.
class SubscriptionScreenState {
  const SubscriptionScreenState({
    required this.plan,
    this.date,
    this.willRenew = false,
    this.canManage = false,
    this.grantSource,
    this.daysLeft,
    this.term,
  });

  /// Null when no plan is running. Only an Admin (open without Pro,
  /// mp-457) reaches the screen so; a lapsed athlete is on the paywall.
  final PlanStatus? plan;

  /// Trial end, renewal or end date (UTC), per [plan]. Null when RevenueCat
  /// has none (an open-ended grant, or no plan running).
  final DateTime? date;

  /// Whether the store renews (or, in a trial, starts charging) at [date].
  final bool willRenew;

  /// Manage subscription is offered only with a store subscription on
  /// record, running or ended (mp-495 §3, as the paywall's ⋯ menu, mp-494).
  final bool canManage;

  /// Where the Grant came from, when [plan] is [PlanStatus.grant].
  final GrantSource? grantSource;

  /// Days until the Grant ends, when [plan] is [PlanStatus.grant] and it has
  /// an end.
  final int? daysLeft;

  /// Monthly or Annual, for a running store plan (trial, active, founding)
  /// whose SKU says which. Null for a Grant, no plan running, or a SKU that
  /// names neither.
  final PlanTerm? term;

  /// Pure: the screen's state for [status] on [now]. A founding member is
  /// one whose running plan is a founding product (`me_pro_*_founding`,
  /// mp-452); the free week outranks it, since its end date is the one that
  /// matters. A running Grant shows as itself, with its days left (mp-558),
  /// and where it came from as the server recorded it ([grantRecords],
  /// mp-615); with no matching record, as its length suggests.
  static SubscriptionScreenState from(
    SubscriptionStatus status, {
    required bool hasStoreSubscription,
    required DateTime now,
    List<GrantRecord> grantRecords = const [],
  }) {
    final held = status.active ? status.grant : null;
    final grant = held?.withSource(
      GrantRecord.sourceFor(grantRecords, held.endsAt),
    );
    final PlanStatus? plan;
    if (!status.active) {
      plan = null;
    } else if (grant != null) {
      plan = PlanStatus.grant;
    } else if (status.isTrial) {
      plan = PlanStatus.trial;
    } else if (isFoundingProduct(status.productId)) {
      plan = PlanStatus.founding;
    } else {
      plan = PlanStatus.active;
    }
    return SubscriptionScreenState(
      plan: plan,
      date: plan == null ? null : status.expiresAt,
      willRenew: status.active && status.willRenew,
      canManage: hasStoreSubscription,
      grantSource: grant?.source,
      daysLeft: grant?.daysLeftAt(now),
      term: plan == null || plan == PlanStatus.grant
          ? null
          : termOf(status.productId),
    );
  }

  /// Pure: the term a store SKU sells. Every SKU the offerings sell names it
  /// (`me_pro_monthly`, `me_pro_annual_founding`, `mealvana_pro_monthly`,
  /// Play's `product:base-plan`); anything else names no plan.
  static PlanTerm? termOf(String? productId) {
    final id = productId?.toLowerCase();
    if (id == null) return null;
    if (id.contains('annual') || id.contains('yearly')) return PlanTerm.annual;
    if (id.contains('monthly')) return PlanTerm.monthly;
    return null;
  }

  /// Whether [productId] is one of the founding products the `founding`
  /// offering sells (dev and `_prod` SKUs alike).
  static bool isFoundingProduct(String? productId) =>
      productId != null && productId.contains('_$kFoundingOfferingId');
}

/// Whether this account has a store subscription that is running and will
/// renew, so deleting the account leaves it billing: both Delete account
/// confirms (Settings, the paywall's menu) say so and offer Manage
/// subscription only then (finding 02-004). Asked afresh on each open.
@riverpod
Future<bool> renewingStoreSubscription(Ref ref) =>
    ref.read(subscriptionServiceProvider).hasRenewingStoreSubscription();

/// Asks RevenueCat itself, past the SDK's saved copy, once per opening of
/// the Subscription screen (ticket 105, Finding 87-006): a plan in its last
/// period reads "Ends on {date}. It won't renew." (mp-558), never "Renews
/// on". Its own provider so the ask runs once per open, not on every status
/// change the screen rebuilds for; it goes with the screen. Bounded by the
/// status controller's wait; no answer keeps the saved copy.
@riverpod
Future<void> subscriptionFreshOnOpen(Ref ref) =>
    ref.read(subscriptionStatusProvider.notifier).fetchFresh();

/// The Subscription screen in Settings (mp-495): the plan's status from the
/// status provider (RevenueCat, mp-279), where a Grant came from (the
/// server's `pro_grants`, mp-615), whether there is a store subscription to
/// manage, and where Manage subscription goes.
///
/// Rebuilds whenever the status does, so a Code redeemed on the screen
/// shows at once.
@riverpod
class SubscriptionScreenController extends _$SubscriptionScreenController {
  @override
  Future<SubscriptionScreenState> build() async {
    await ref.watch(subscriptionFreshOnOpenProvider.future);
    final status = await ref.watch(subscriptionStatusProvider.future);
    final hasStoreSubscription = await ref
        .read(subscriptionServiceProvider)
        .hasStoreSubscriptionOnRecord();
    // Where a running Grant came from is the server's record (mp-615); asked
    // only when there is a Grant to label.
    final grantRecords = status.active && status.grant != null
        ? await ref.read(grantSourceRepositoryProvider).recentGrants()
        : const <GrantRecord>[];
    return SubscriptionScreenState.from(
      status,
      hasStoreSubscription: hasStoreSubscription,
      now: ref.read(subscriptionScreenClockProvider)(),
      grantRecords: grantRecords,
    );
  }

  /// Where Manage subscription goes: the same as the paywall's ⋯ menu entry
  /// (RevenueCat's management URL, else the store's own subscriptions page).
  /// Null when there is no page to open: a Test Store subscription, which
  /// RevenueCat gives no management URL (finding 09-001).
  Future<Uri?> managementUrl() =>
      ref.read(subscriptionServiceProvider).managementUrl();
}
