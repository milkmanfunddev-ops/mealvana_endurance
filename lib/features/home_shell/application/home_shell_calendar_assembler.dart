/// The calendar sheet's per-day channel fold — `home-shell@v1`.
///
/// Contract: docs/ssot/spec/design/components/calendar-sheet.md (RATIFIED v1
/// Xuan 2026-09-06) Q1 (dot ← workout state) + Q2 (tint ← logged fueling,
/// binary v1), via the handoff's producer/consumer inventory:
///
///  * Day-key for the dot slot is the DISPLAY rule — [Activity.displayTime]
///    (`actual_time ?? planned_time ?? scheduled_date_time`), the ONE
///    resolver the dashboard uses. Never `scheduled_date_time` directly
///    (the engine's divergent bucketing is an OPEN ruling,
///    intake/2026-08-20 — the calendar follows the display rule).
///  * The per-activity state comes from [resolveWorkoutCardState] — the
///    extracted dashboard derivation (two-time model, G6 sync-beats-skip,
///    derived passive SKIPPED), never a copy.
///  * Multi-workout/brick day: ONE dot, best state wins — any completed →
///    filled; else any planned → hollow. SKIPPED (active or passive alike)
///    and rest days contribute no dot.
///  * Tint: presence of the day's `log_date` in [loggedDates] — ≥ 1 athlete
///    meal-log row, any [MealLogSource] (every source is the athlete's; the
///    engine writes no meal_log rows — verified 2026-09-06, the one
///    server-side writer is the athlete-described `jade_baseline` chat
///    tool). Day boundary is `log_date` itself, the app's daily-macros day
///    definition.
library;

import '../../activities/domain/activity.dart';
import '../../macro_dashboard/domain/dashboard_models.dart';
import '../../macro_dashboard/domain/workout_state_resolver.dart';
import '../../../shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';

/// `'yyyy-MM-dd'` — the meal-log day key (matches `meal_logs.log_date`).
String logDateKey(DateTime day) {
  final mm = day.month.toString().padLeft(2, '0');
  final dd = day.day.toString().padLeft(2, '0');
  return '${day.year}-$mm-$dd';
}

/// Fold [activities] and [loggedDates] into the month's day-cell channel
/// data. [month] is the first day of the month; [now] is the wall clock
/// (passive-skip derivation needs it).
Map<int, KyleCalendarDayData> assembleCalendarMonth({
  required DateTime month,
  required DateTime now,
  required List<Activity> activities,
  required Set<String> loggedDates,
}) {
  // §4b tombstones never render — the same live filter the dashboard
  // assembler applies.
  final byDay = <int, List<Activity>>{};
  for (final a in activities) {
    if (a.status == ActivityStatus.deleted || a.deletedAt != null) continue;
    final t = a.displayTime;
    if (t.year != month.year || t.month != month.month) continue;
    byDay.putIfAbsent(t.day, () => []).add(a);
  }

  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final result = <int, KyleCalendarDayData>{};
  for (var day = 1; day <= daysInMonth; day++) {
    final date = DateTime(month.year, month.month, day);
    final dayActivities = byDay[day] ?? const <Activity>[];

    var anyDone = false;
    var anyPlanned = false;
    for (final a in dayActivities) {
      switch (resolveWorkoutCardState(a, day: date, now: now)) {
        case WorkoutCardState.doneConfirmed:
        case WorkoutCardState.doneVerified:
          anyDone = true;
        case WorkoutCardState.planned:
          anyPlanned = true;
        case WorkoutCardState.skipped:
          break; // no dot — the calendar stays neutral about skips
      }
    }
    final dot = anyDone
        ? CalendarDotState.done
        : anyPlanned
        ? CalendarDotState.planned
        : CalendarDotState.none;

    final tinted = loggedDates.contains(logDateKey(date));
    if (dot != CalendarDotState.none || tinted) {
      result[day] = KyleCalendarDayData(dot: dot, tinted: tinted);
    }
  }
  return result;
}
