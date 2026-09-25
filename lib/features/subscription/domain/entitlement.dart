/// Domain model for the subscription entitlement.
///
/// Mirrors the RevenueCat entitlement identifier (`pro`). RevenueCat is the
/// only gate (mp-279): the client reads the SDK's cached entitlement and
/// nothing else, so there is one source here, not three. Pure Dart, no SDK
/// or Supabase types.
library;

import 'grant.dart';

/// Entitlements the app knows how to gate on. The [key] is the identifier in
/// RevenueCat; the server's own two-field cache (mp-285) keys on the user.
enum Entitlement {
  pro('pro');

  const Entitlement(this.key);

  /// RevenueCat entitlement identifier.
  final String key;
}

/// How long past its own [SubscriptionStatus.expiresAt] an active answer
/// still counts (mp-679): a saved copy on the phone keeps the Gate open this
/// long while the fetch for the renewal runs, then counts as closed until a
/// fresh answer arrives.
///
/// KEEP IN STEP with `RENEWAL_GRACE_MS` in
/// supabase/functions/_shared/vana/entitlement.ts, the server's grace for a
/// renewing account (15 minutes): the two must move together, or the phone
/// opens onto a server that refuses every AI call.
const Duration kRenewalGrace = Duration(minutes: 15);

/// Which source vouched for the active entitlement. [none] when inactive.
enum SubscriptionSource { none, revenuecat }

/// The gate's answer (mp-457): open or closed, nothing in between.
enum AppAccess {
  /// The entitlement is active, or the account is a team admin (mp-416).
  open,

  /// No live `pro`: never held, held once and expired, or an unknown answer
  /// (mp-284). The full-screen paywall and nothing else (mp-280, mp-611).
  closed;

  /// Whether AI actions may run: only an open gate.
  bool get allowsAi => this == open;
}

/// The resolved subscription status for the current user.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    this.expiresAt,
    this.source = SubscriptionSource.none,
    this.isTrial = false,
    this.productId,
    this.willRenew = true,
    this.hadPro = false,
    this.grant,
  });

  /// Nobody is subscribed (also the safe fallback whenever a lookup fails
  /// or times out: an unknown entitlement is locked, mp-284).
  static const none = SubscriptionStatus(active: false);

  /// Whether the app is unlocked for this user right now.
  final bool active;

  /// When the current period ends (UTC). Null for open-ended grants and for
  /// [none]. A past [expiresAt] with [active] true (RevenueCat's saved copy
  /// judges itself against the time it was fetched) counts only for
  /// [kRenewalGrace]: see [countedAt].
  final DateTime? expiresAt;

  /// Who said so. [SubscriptionSource.none] when [active] is false.
  final SubscriptionSource source;

  /// True while the entitlement is in a trial (or intro) period.
  final bool isTrial;

  /// The store SKU that granted the entitlement, when known.
  final String? productId;

  /// Whether the store will renew (or, in a trial, start charging) at
  /// [expiresAt]. False once the athlete has cancelled: the entitlement
  /// stays active to the end of the period, then lapses. The day-five
  /// reminder is cancelled on an active trial that will not renew (mp-456).
  final bool willRenew;

  /// Whether RevenueCat has ever recorded `pro` for this customer: true
  /// while it is active and after it has expired, false for a customer who
  /// never held it. The gate does not read it: lapsed and never are both
  /// closed (mp-457, mp-611). An unknown answer ([none]) is false.
  final bool hadPro;

  /// The Grant behind an active `pro`, when RevenueCat granted it rather
  /// than a store selling it (mp-558); null otherwise.
  final Grant? grant;

  /// Whether [expiresAt] has passed as of [now]. False when there is no expiry.
  bool isExpiredAt(DateTime now) {
    final e = expiresAt;
    return e != null && !e.isAfter(now);
  }

  /// The moment this answer stops counting (mp-679): its own [expiresAt],
  /// plus [kRenewalGrace] when it will renew. Like the server's isEntitled,
  /// only a renewing subscription gets the grace; a cancelled one ends at
  /// its expiry. Null for an inactive answer and for an open-ended one.
  DateTime? get stopsCountingAt {
    final e = expiresAt;
    if (!active || e == null) return null;
    return willRenew ? e.add(kRenewalGrace) : e;
  }

  /// This answer as it counts at [now] (mp-679). An active answer whose own
  /// [expiresAt] passed more than [kRenewalGrace] ago (at once, when it will
  /// not renew) is closed: held once,
  /// same expiry and product, nothing vouching for it. Every other answer
  /// counts as it is, so a fresh answer, which carries the new period's
  /// expiry, always wins.
  SubscriptionStatus countedAt(DateTime now) {
    final e = expiresAt;
    final end = stopsCountingAt;
    if (e == null || end == null || now.isBefore(end)) return this;
    return SubscriptionStatus(
      active: false,
      expiresAt: e,
      productId: productId,
      willRenew: false,
      hadPro: true,
    );
  }

  SubscriptionStatus copyWith({
    bool? active,
    DateTime? expiresAt,
    SubscriptionSource? source,
    bool? isTrial,
    String? productId,
    bool? willRenew,
    bool? hadPro,
    Grant? grant,
  }) {
    return SubscriptionStatus(
      active: active ?? this.active,
      expiresAt: expiresAt ?? this.expiresAt,
      source: source ?? this.source,
      isTrial: isTrial ?? this.isTrial,
      productId: productId ?? this.productId,
      willRenew: willRenew ?? this.willRenew,
      hadPro: hadPro ?? this.hadPro,
      grant: grant ?? this.grant,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SubscriptionStatus &&
      other.active == active &&
      other.expiresAt == expiresAt &&
      other.source == source &&
      other.isTrial == isTrial &&
      other.productId == productId &&
      other.willRenew == willRenew &&
      other.hadPro == hadPro &&
      other.grant == grant;

  @override
  int get hashCode => Object.hash(
    active,
    expiresAt,
    source,
    isTrial,
    productId,
    willRenew,
    hadPro,
    grant,
  );

  @override
  String toString() =>
      'SubscriptionStatus(active: $active, source: ${source.name}, '
      'expiresAt: $expiresAt, isTrial: $isTrial, productId: $productId, '
      'willRenew: $willRenew, hadPro: $hadPro, grant: $grant)';
}

/// A free introductory period the store attaches to a subscription product
/// (mp-279: seven days free on the monthly and annual plans). Only a free
/// offer is modelled — a discounted intro price is not one this app sells.
class IntroOffer {
  const IntroOffer({required this.freeDays});

  /// Length of the free period in days.
  final int freeDays;

  /// Days for a store period of [count] × [unit], where [unit] is the
  /// store's DAY / WEEK / MONTH / YEAR word (case-insensitive). Apple reports
  /// a seven-day trial as `WEEK × 1`; the copy says "7 days", so weeks are
  /// unrolled. Months and years use the 30 / 365 convention the stores use
  /// for their own copy. Unknown units yield null.
  static int? daysFor({required String unit, required int count}) {
    if (count <= 0) return null;
    return switch (unit.toUpperCase()) {
      'DAY' => count,
      'WEEK' => count * 7,
      'MONTH' => count * 30,
      'YEAR' => count * 365,
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is IntroOffer && other.freeDays == freeDays;

  @override
  int get hashCode => freeDays.hashCode;

  @override
  String toString() => 'IntroOffer(freeDays: $freeDays)';
}
