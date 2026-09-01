/// Domain model for the Pro subscription entitlement.
///
/// Mirrors the RevenueCat entitlement identifier (`pro`) and the server row in
/// `public.user_entitlements` (docs/implement_mealplanning/04-entitlement.md).
/// Pure Dart — no SDK or Supabase types — so the application layer can unify
/// the three sources (RevenueCat, server row, internal tester flag) into one
/// [SubscriptionStatus] without the presentation layer knowing which won.
library;

/// Entitlements the app knows how to gate on. The [key] is the identifier in
/// RevenueCat AND the `entitlement` column server-side; they must stay equal.
enum Entitlement {
  pro('pro');

  const Entitlement(this.key);

  /// RevenueCat entitlement identifier / `user_entitlements.entitlement`.
  final String key;
}

/// Which source vouched for the active entitlement.
///
/// Order matters for [SubscriptionStatus.merge]: RevenueCat is authoritative
/// (it sees the store directly), the server row is the paywall the edge
/// functions enforce, and the internal tester flag is a client-only override
/// for QA that never reaches the server.
enum SubscriptionSource { none, revenuecat, server, internal }

/// The resolved Pro status for the current user.
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    this.expiresAt,
    this.source = SubscriptionSource.none,
    this.isTrial = false,
    this.productId,
  });

  /// Nobody is subscribed (also the safe fallback whenever a lookup fails).
  static const none = SubscriptionStatus(active: false);

  /// Whether Pro features are unlocked for this user right now.
  final bool active;

  /// When the current period ends (UTC). Null for open-ended grants and for
  /// [none]. A past [expiresAt] with [active] true is still honoured — the
  /// producer decided — but [isExpiredAt] lets callers double-check.
  final DateTime? expiresAt;

  /// Who said so. [SubscriptionSource.none] when [active] is false.
  final SubscriptionSource source;

  /// True while the entitlement is in a trial (or intro) period.
  final bool isTrial;

  /// The store SKU that granted the entitlement, when known.
  final String? productId;

  /// Whether [expiresAt] has passed as of [now]. False when there is no expiry.
  bool isExpiredAt(DateTime now) {
    final e = expiresAt;
    return e != null && !e.isAfter(now);
  }

  /// Pick the status to show when several sources report. The first ACTIVE
  /// status in [candidates] wins (so pass them in priority order); when none
  /// is active, [none] is returned rather than an inactive row from a
  /// lower-priority source, keeping `source` meaningful.
  static SubscriptionStatus merge(Iterable<SubscriptionStatus?> candidates) {
    for (final c in candidates) {
      if (c != null && c.active) return c;
    }
    return none;
  }

  SubscriptionStatus copyWith({
    bool? active,
    DateTime? expiresAt,
    SubscriptionSource? source,
    bool? isTrial,
    String? productId,
  }) {
    return SubscriptionStatus(
      active: active ?? this.active,
      expiresAt: expiresAt ?? this.expiresAt,
      source: source ?? this.source,
      isTrial: isTrial ?? this.isTrial,
      productId: productId ?? this.productId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SubscriptionStatus &&
      other.active == active &&
      other.expiresAt == expiresAt &&
      other.source == source &&
      other.isTrial == isTrial &&
      other.productId == productId;

  @override
  int get hashCode => Object.hash(active, expiresAt, source, isTrial, productId);

  @override
  String toString() =>
      'SubscriptionStatus(active: $active, source: ${source.name}, '
      'expiresAt: $expiresAt, isTrial: $isTrial, productId: $productId)';
}
