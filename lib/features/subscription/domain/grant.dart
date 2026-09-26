/// A Grant: Pro given for a fixed time without a purchase, through
/// RevenueCat (CONTEXT.md). Pure Dart, no SDK types.
library;

/// Where a Grant came from (mp-558, mp-615).
///
/// The server records it: every grant it makes writes a `pro_grants` row
/// with its source (`grace`, `code` or `coach`; migration
/// 20260926070000_pro_grants_source.sql), and [GrantRecord.sourceFor] picks
/// the row that made the running Grant.
///
/// RevenueCat's customer info carries no source: every grant the server
/// makes (`grant_entitlement` with an end time) reads as product
/// `rc_promo_pro_custom`, and subscriber attributes are not part of what the
/// SDK hands the app. So with no row to read (a Grant made before the table,
/// a failed write, or no network) the source is still read from the Grant's
/// length, [fromLength]: the Legacy grace month is always [kLegacyGraceDays]
/// days (`supabase/functions/_shared/grace`), anything else a Code. That
/// guess cannot tell a coach's own 30-day Code from the grace month.
enum GrantSource {
  /// The Legacy grace month: thirty days from the flip or the Grace claim.
  legacyGrace,

  /// A Code: a giveaway (or, when only the length is known, any Code).
  code,

  /// A coach's own Code, entered by that coach (mp-458): "Coach access".
  coach;

  /// The source of a Grant that runs for [length], when the server has no
  /// record of it. A thirty-day Grant, give or take a day and a half for the
  /// grant call's own timing, is the Legacy grace month; anything else is a
  /// Code.
  static GrantSource fromLength(Duration length) {
    final off = (length - const Duration(days: kLegacyGraceDays)).abs();
    return off <= _graceTolerance ? legacyGrace : code;
  }

  /// The source as `pro_grants.source` names it; null for a name this build
  /// does not know.
  static GrantSource? fromServer(String? name) => switch (name) {
    'grace' => legacyGrace,
    'code' => code,
    'coach' => coach,
    _ => null,
  };

  static const _graceTolerance = Duration(hours: 36);
}

/// Days in the Legacy grace month (`GRACE_DAYS` in
/// `supabase/functions/_shared/grace/grace.ts`).
const int kLegacyGraceDays = 30;

/// One `pro_grants` row: a Grant the server made, and where it came from.
class GrantRecord {
  const GrantRecord({
    required this.source,
    required this.grantedAt,
    required this.proDays,
  });

  /// Null when the server names a source this build does not know.
  final GrantSource? source;

  /// When the grant was made (UTC).
  final DateTime grantedAt;

  /// Days of `pro` it gave.
  final int proDays;

  /// When the Grant it made ends: RevenueCat's grant runs [proDays] days
  /// from the moment it is made.
  DateTime get endsAt => grantedAt.add(Duration(days: proDays));

  /// A row as PostgREST returns it; null when a field is missing or
  /// unreadable.
  static GrantRecord? fromRow(Map<String, dynamic> row) {
    final grantedAt = DateTime.tryParse('${row['granted_at']}')?.toUtc();
    final days = row['pro_days'];
    if (grantedAt == null || days is! num) return null;
    return GrantRecord(
      source: GrantSource.fromServer(row['source'] as String?),
      grantedAt: grantedAt,
      proDays: days.toInt(),
    );
  }

  /// The recorded source of the running Grant ending at [endsAt]: the newest
  /// of [records] whose own end is within a day and a half of it (the grant
  /// call and the row's write are a moment apart). An older row ending
  /// elsewhere belongs to another Grant and says nothing about this one.
  /// With no end to match, the newest row. Null when none matches.
  static GrantSource? sourceFor(List<GrantRecord> records, DateTime? endsAt) {
    final newestFirst = [...records]
      ..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
    for (final r in newestFirst) {
      if (r.source == null) continue;
      if (endsAt == null) return r.source;
      if (r.endsAt.difference(endsAt).abs() <= _matchTolerance) {
        return r.source;
      }
    }
    return null;
  }

  static const _matchTolerance = Duration(hours: 36);
}

/// The Grant an account holds now.
class Grant {
  const Grant({required this.source, this.endsAt});

  /// Where it came from.
  final GrantSource source;

  /// When it ends (UTC); null for a Grant with no end.
  final DateTime? endsAt;

  /// Read a Grant from its start and end as RevenueCat reports them, its
  /// source guessed from its length until the server's record says
  /// otherwise ([withSource]). With either date missing the length is
  /// unknown, and the Grant counts as a Code.
  factory Grant.fromDates({DateTime? startedAt, DateTime? endsAt}) {
    final source = startedAt == null || endsAt == null
        ? GrantSource.code
        : GrantSource.fromLength(endsAt.difference(startedAt));
    return Grant(source: source, endsAt: endsAt);
  }

  /// This Grant with the source the server recorded for it; unchanged when
  /// there is no record.
  Grant withSource(GrantSource? recorded) =>
      recorded == null ? this : Grant(source: recorded, endsAt: endsAt);

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
