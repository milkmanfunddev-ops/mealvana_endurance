/// Date helpers shared by the meal-planning repositories and controllers —
/// ports of `today` / `addDays` / `weekStartFor` in the edge functions'
/// `_shared/vana/env.ts` so the client and server agree on which week a
/// plan belongs to.
///
/// All values are `YYYY-MM-DD` strings in the athlete's local calendar;
/// the server persists `meal_plans.week_start` as a DATE.
library;

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

/// **Sunday-start** week containing [iso] (cook day Sunday, matching the
/// design's "Aug 23 – 29" and the server's `weekStartFor`). Defaults to
/// this week.
String weekStartFor([String? iso]) {
  final day = iso ?? todayIso();
  final d = DateTime.parse(day);
  // DateTime.weekday: Monday = 1 … Sunday = 7; JS getUTCDay: Sunday = 0.
  final offset = d.weekday % 7;
  return addDays(day, -offset);
}
