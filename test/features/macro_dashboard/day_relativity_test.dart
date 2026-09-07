import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// **The time-relativity axis, applied to the BREAKDOWN surface.**
///
/// `qa/docs/test-plan-dimensions.md` exists because of the mark-done teleport,
/// and its matrix carries a past/current/future column — but only for the card
/// GESTURES. The Today's Energy / Active Energy sheet was never added as a row,
/// so nothing checked what it says about a day that has not happened. It said
/// the day was over: `minutesSinceMidnight = isToday ? now : 1440` treated a
/// day a week away as fully elapsed, published a full day's resting + NEAT
/// under "so far" while workout and digestion stayed 0, and headlined a
/// −1,339 kcal deficit for a day that had not begun.
/// `ops/data/bug-reports/2026-08-22-breakdown-sheet-future-day-claims-day-is-over.md`
///
/// What these tests pin is the SPEC-DERIVABLE part only. intraday-display.md §1
/// defines every so-far quantity as a proration of ELAPSED time
/// (`neat_so_far = neat_kcal × (waking_minutes_elapsed / total_waking_minutes)`),
/// so elapsed minutes are a fact about the day: past = 1440, today = the clock,
/// future = 0. What a future day should DISPLAY — net-balance card or not, and
/// in which copy register — is unspecified and open as
/// `qa/intake/2026-08-20-future-day-net-balance-copy.md`. These tests must not
/// grow an opinion about that.
void main() {
  const assembler = MacroDashboardAssembler();
  final now = DateTime(2026, 8, 22, 15, 0);
  const weightKg = 47.6;

  Activity plannedRun(DateTime day) => Activity(
        id: 'w1',
        userId: 'u1',
        activityType: ActivityType.running,
        title: 'Run - Long Run',
        scheduledDateTime: DateTime(day.year, day.month, day.day, 7, 0),
        plannedTime: DateTime(day.year, day.month, day.day, 7, 0),
        status: ActivityStatus.planned,
        durationMinutes: 90,
        createdAt: day,
        updatedAt: day,
      );

  DailyMacroTargets targets(DateTime day) => DailyMacroTargets(
        id: 't1',
        userId: 'u1',
        targetDate: day,
        carbG: 447,
        protG: 85,
        fatG: 101,
        tdee: 3037,
        rmr: 1064,
        sessionKcal: 1290,
        neatKcal: 275,
        tefKcal: 304,
        mode: 'prospective',
        createdAt: day,
        updatedAt: day,
      );

  DashboardData assemble(DateTime day) => assembler.assemble(
        selectedDate: day,
        now: now,
        activities: [plannedRun(day)],
        meals: const [],
        targets: targets(day),
        consumed: const ConsumedTotals(),
        trackingOn: true,
        profileWeightKg: weightKg,
      );

  group('elapsed minutes are a fact about the selected day', () {
    test('a FUTURE day has not started: elapsed = 0', () {
      final b = assemble(DateTime(2026, 8, 29)).breakdown!;
      expect(b.minutesSinceMidnight, 0,
          reason: 'a day a week away has zero elapsed minutes');
    });

    test('a PAST day is over: elapsed = 1440', () {
      final b = assemble(DateTime(2026, 8, 15)).breakdown!;
      expect(b.minutesSinceMidnight, 1440);
    });

    test('TODAY runs as far as the clock says', () {
      final b = assemble(DateTime(2026, 8, 22)).breakdown!;
      expect(b.minutesSinceMidnight, 15 * 60);
    });
  });

  group('BUG_CHECK: the sheet never claims time that has not passed', () {
    test('a future day accrues NOTHING so far — every row, not just some', () {
      final b = assemble(DateTime(2026, 8, 29)).breakdown!;

      // The shipped bug showed resting 1,064 and movement 275 here (full-day
      // values) while workout and digestion sat at 0 — the columns disagreed
      // with each other about how much of the day had passed.
      expect(b.restingSoFar, 0, reason: 'resting has not been burned yet');
      expect(b.movementSoFar, 0, reason: 'no movement has happened yet');
      expect(b.workoutSoFar, 0);
      expect(b.digestionSoFar, 0);
    });

    test('a future day still PROJECTS the full day — the fix must not zero that',
        () {
      final b = assemble(DateTime(2026, 8, 29)).breakdown!;

      expect(b.restingByEnd, greaterThan(0),
          reason: 'by-day\'s-end is the engine\'s figure, unaffected by elapsed');
      expect(b.movementByEnd, greaterThan(0));
      expect(b.workoutByEnd, greaterThan(0),
          reason: 'the planned session is still projected');
    });

    test('a future day publishes no phantom deficit', () {
      final energy = assemble(DateTime(2026, 8, 29)).energy!;

      // Was −1,339 ("deficit — time to eat") for a day that had not begun.
      expect(energy.burnedKcal, 0,
          reason: 'nothing has been burned on a day that has not started');
      expect(energy.eatenKcal - energy.burnedKcal, 0);
    });

    test('a PAST day is internally consistent: so far == by day\'s end', () {
      final b = assemble(DateTime(2026, 8, 15)).breakdown!;

      // 100% elapsed must mean the two columns agree — the contradiction the
      // future-day case made visible ("100% of the day done" with so-far below
      // by-day's-end) is the same defect seen from the other side.
      expect(b.restingSoFar, closeTo(b.restingByEnd, 1.0));
      expect(b.movementSoFar, closeTo(b.movementByEnd, 1.0));
    });
  });
}
