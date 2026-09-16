/// Date helpers shared by the meal-planning repositories and controllers —
/// ports of `today` / `addDays` / `weekStartFor` in the edge functions'
/// `_shared/vana/env.ts` and `sessionOffsets` in `plan-math.ts`, so the
/// client and server agree on which week a plan belongs to and which day
/// each cooking session falls on.
///
/// All values are `YYYY-MM-DD` strings in the athlete's local calendar;
/// the server persists `meal_plans.week_start` as a DATE.
library;

import 'cooking_session.dart';

/// `YYYY-MM-DD` for [date] (local calendar day).
String isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Today's `YYYY-MM-DD` in local time.
String todayIso([DateTime? now]) => isoDate(now ?? DateTime.now());

/// [iso] shifted by [days] calendar days.
String addDays(String iso, int days) {
  final d = DateTime.parse(iso);
  return isoDate(DateTime(d.year, d.month, d.day + days));
}

/// The plan week containing [iso]: the latest [startWeekday]
/// (`DateTime.monday` … `DateTime.sunday`) on or before it. Sunday by
/// default, matching the design's "Aug 23 – 29" and the server's
/// `weekStartFor`. Defaults to this week.
String weekStartFor([String? iso, int startWeekday = DateTime.sunday]) {
  final day = iso ?? todayIso();
  final d = DateTime.parse(day);
  final offset = (d.weekday - startWeekday + 7) % 7;
  return addDays(day, -offset);
}

/// Days after the period start each cooking session falls on (mp-269):
/// cook = the first day, top-up = 3/7 of the way in, fresh = 5/7, each kept
/// inside the period. Seven days gives +0 / +3 / +5; ten gives +0 / +4 / +7.
/// Port of `sessionOffsets` in `plan-math.ts` — keep in lockstep.
Map<CookingSession, int> sessionOffsets([int periodDays = 7]) {
  int inside(int n) => n < 0 ? 0 : (n > periodDays - 1 ? periodDays - 1 : n);
  // `Math.round` (halves toward +∞); the values here are positive.
  int jsRound(double v) => (v + 0.5).floor();
  return {
    CookingSession.cookSun: 0,
    CookingSession.topupWed: inside(jsRound(periodDays * 3 / 7)),
    CookingSession.freshFri: inside(jsRound(periodDays * 5 / 7)),
  };
}

/// The date [session] falls on in the period starting [weekStart].
String sessionDate(String weekStart, CookingSession session, int periodDays) =>
    addDays(weekStart, sessionOffsets(periodDays)[session]!);

/// The athlete's plan period (mp-269): the day a plan week starts and how
/// many days it runs. Both are keyed Vana settings (`week_start`,
/// `period_days`); Sunday and seven days are the defaults.
class PlanPeriod {
  const PlanPeriod({
    this.startWeekday = DateTime.sunday,
    this.days = defaultDays,
  });

  static const int defaultDays = 7;

  /// The range `period_days` accepts — the server's `PERIOD_DAYS_MIN/MAX`
  /// in `memory.ts`.
  static const int minDays = 3;
  static const int maxDays = 14;

  /// `DateTime.monday` … `DateTime.sunday`.
  final int startWeekday;
  final int days;

  /// The `week_start` wire values, in JS `getUTCDay` order (Sunday first).
  static const List<String> weekdayWires = [
    'sun',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
  ];

  /// `DateTime.weekday` for a `week_start` value, or null when unknown.
  static int? weekdayFromWire(Object? wire) {
    final i = weekdayWires.indexOf('$wire');
    if (wire is! String || i < 0) return null;
    return i == 0 ? DateTime.sunday : i;
  }

  static String weekdayToWire(int weekday) => weekdayWires[weekday % 7];

  static bool isValidDays(Object? value) =>
      value is int && value >= minDays && value <= maxDays;

  /// From the stored setting values; anything never set or outside the
  /// contract falls back to its default (the server's `getPlanPeriod`).
  factory PlanPeriod.fromSettings({Object? weekStart, Object? periodDays}) {
    final days = periodDays is num && periodDays == periodDays.roundToDouble()
        ? periodDays.toInt()
        : null;
    return PlanPeriod(
      startWeekday: weekdayFromWire(weekStart) ?? DateTime.sunday,
      days: isValidDays(days) ? days! : defaultDays,
    );
  }

  String get startWire => weekdayToWire(startWeekday);

  /// The week start (`YYYY-MM-DD`) of the period containing [iso] (today
  /// when omitted).
  String startFor([String? iso]) => weekStartFor(iso, startWeekday);

  @override
  bool operator ==(Object other) =>
      other is PlanPeriod &&
      other.startWeekday == startWeekday &&
      other.days == days;

  @override
  int get hashCode => Object.hash(startWeekday, days);

  @override
  String toString() => 'PlanPeriod($startWire, $days days)';
}
