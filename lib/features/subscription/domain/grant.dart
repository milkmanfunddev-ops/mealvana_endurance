/// A Grant: Pro given for a fixed time without a purchase, through
/// RevenueCat (CONTEXT.md). Pure Dart, no SDK types.
library;

/// Where a Grant came from, as far as the app can tell from RevenueCat's
/// customer info (mp-558).
///
/// Customer info carries no source: every grant the server makes
/// (`grant_entitlement` with an end time) reads as product
/// `rc_promo_pro_custom`, and subscriber attributes are not part of what the
/// SDK hands the app. What it does carry is the grant's start (the latest
/// purchase) and end, so the source is read from the grant's length: the
/// Legacy grace month is always [kLegacyGraceDays] days
/// (`supabase/functions/_shared/grace`), and a Code grants its own
/// `perk_days` (a giveaway 365).
enum GrantSource {
  /// The Legacy grace month: thirty days from the flip or the Grace claim.
  legacyGrace,

  /// A Code: a giveaway, or a coach's own Code.
  code;

  /// The source of a Grant that runs for [length]. A thirty-day Grant, give
  /// or take a day and a half for the grant call's own timing, is the Legacy
  /// grace month; anything else is a Code.
  static GrantSource fromLength(Duration length) {
    final off = (length - const Duration(days: kLegacyGraceDays)).abs();
    return off <= _graceTolerance ? legacyGrace : code;
  }

  static const _graceTolerance = Duration(hours: 36);
}

/// Days in the Legacy grace month (`GRACE_DAYS` in
/// `supabase/functions/_shared/grace/grace.ts`).
const int kLegacyGraceDays = 30;

/// The Grant an account holds now.
class Grant {
  const Grant({required this.source, this.endsAt});

  /// Where it came from.
  final GrantSource source;

  /// When it ends (UTC); null for a Grant with no end.
  final DateTime? endsAt;

  /// Read a Grant from its start and end as RevenueCat reports them. With
  /// either missing the length is unknown, and the Grant counts as a Code.
  factory Grant.fromDates({DateTime? startedAt, DateTime? endsAt}) {
    final source = startedAt == null || endsAt == null
        ? GrantSource.code
        : GrantSource.fromLength(endsAt.difference(startedAt));
    return Grant(source: source, endsAt: endsAt);
  }

  /// Calendar days from [now]'s day to the day the Grant ends, both in local
  /// time: 12 on 19 October for a Grant ending on 31 October, 0 on its last
  /// day. Null when it has no end; never negative.
  int? daysLeftAt(DateTime now) {
    final end = endsAt;
    if (end == null) return null;
    DateTime day(DateTime t) {
      final l = t.toLocal();
      return DateTime.utc(l.year, l.month, l.day);
    }

    final days = day(end).difference(day(now)).inDays;
    return days < 0 ? 0 : days;
  }

  @override
  bool operator ==(Object other) =>
      other is Grant && other.source == source && other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(source, endsAt);

  @override
  String toString() => 'Grant(source: ${source.name}, endsAt: $endsAt)';
}
