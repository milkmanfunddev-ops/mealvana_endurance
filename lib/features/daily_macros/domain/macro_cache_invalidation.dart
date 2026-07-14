/// Which cached macro days an activity change actually invalidates.
///
/// Cached `daily_macro_targets` rows are keyed by day. A day is only stale if
/// one of the *inputs* to its calculation moved. Per `DailyMacroService`, day D
/// is computed from exactly three activity-derived inputs:
///
///   1. activities **on D**                        (`_loadSessionsForDate`)
///   2. activities on **D-1** and **D+1**          (`_loadDayContext` — yesterday's
///      TSS / hours-since, tomorrow's load)
///   3. total training hours across **D's Mon–Sun week** (`_calculateWeeklyHours`)
///
/// Inverting that: an activity on day X can only affect a day D when
///
///   * D == X                              (input 1)
///   * D == X-1 or D == X+1                (input 2 — those days read X)
///   * D is in the same Mon–Sun week as X  (input 3 — their weekly sum includes X)
///
/// which is the union computed by [daysAffectedByActivityOn]: X's Monday-week,
/// plus X±1. Seven days when X falls mid-week; eight when X is a Monday or a
/// Sunday, because one neighbour spills into the adjacent week.
///
/// This replaces a blanket `DELETE FROM daily_macro_targets WHERE user_id = ?`,
/// which discarded every cached day the user had — months of history — on any
/// single workout edit, forcing an edge-function round trip for every date they
/// subsequently opened (and leaving them with no macros at all while offline).
///
/// IF YOU ADD A NEW ACTIVITY-DERIVED INPUT to the macro calculation — a 14-day
/// rolling load, a next-race lookahead, anything reading activities outside the
/// window above — you MUST widen this function to match, or cached rows will go
/// silently stale. `macro_cache_invalidation_test.dart` pins the current rule.
library;

import '../../activities/domain/activity.dart';

/// Normalizes to midnight, dropping any time component.
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Monday that starts [d]'s week — matching `_calculateWeeklyHours`, which
/// sums Monday..Sunday. (Note the *display* week in the fuel timeline is
/// Sunday-start; that's a presentation choice and irrelevant here. What governs
/// staleness is the window the calculation actually reads.)
DateTime _startOfWeek(DateTime d) {
  final day = _day(d);
  return _day(day.subtract(Duration(days: day.weekday - 1)));
}

/// Every day whose cached macros an activity scheduled on [date] can affect.
///
/// Every element is normalized to midnight. That matters: `Duration(days: 1)` is
/// exactly 24 hours, so adding it across a DST boundary lands on 01:00 (or
/// 23:00) of the neighbouring day rather than midnight. Cached rows are keyed by
/// midnight, so an un-normalized day would silently fail to match and the row
/// would survive as stale. Re-normalize after every shift.
Set<DateTime> daysAffectedByActivityOn(DateTime date) {
  final day = _day(date);
  final monday = _startOfWeek(day);
  return {
    for (var i = 0; i < 7; i++) _day(monday.add(Duration(days: i))),
    _day(day.subtract(const Duration(days: 1))),
    _day(day.add(const Duration(days: 1))),
  };
}

/// The days on which activities were added, removed, or modified between
/// [before] and [after].
///
/// Matched by `id`, compared by value (`Activity` implements `==`):
///   * present only in [before]  → removed  → its day changed
///   * present only in [after]   → added    → its day changed
///   * in both but not equal     → modified → BOTH days change, since the edit
///     may have been a reschedule (Tue → Fri leaves Tuesday stale too)
///
/// Reordering the list changes nothing, so it yields an empty set — macros don't
/// depend on list order.
Set<DateTime> changedActivityDates(List<Activity> before, List<Activity> after) {
  final beforeById = {for (final a in before) a.id: a};
  final afterById = {for (final a in after) a.id: a};

  final dates = <DateTime>{};

  for (final entry in beforeById.entries) {
    final now = afterById[entry.key];
    if (now == null) {
      dates.add(_day(entry.value.scheduledDateTime)); // removed
    } else if (now != entry.value) {
      dates.add(_day(entry.value.scheduledDateTime)); // modified: old slot
      dates.add(_day(now.scheduledDateTime)); //          and new slot
    }
  }

  for (final entry in afterById.entries) {
    if (!beforeById.containsKey(entry.key)) {
      dates.add(_day(entry.value.scheduledDateTime)); // added
    }
  }

  return dates;
}

/// The cached macro days to invalidate when the activity list goes from
/// [before] to [after]. Empty when nothing meaningful changed.
Set<DateTime> macroDatesToInvalidate(
  List<Activity> before,
  List<Activity> after,
) {
  return {
    for (final date in changedActivityDates(before, after))
      ...daysAffectedByActivityOn(date),
  };
}
