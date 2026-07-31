/// Energy-balance maths behind the Fuel Timeline dashboard.
///
/// [DayEnergySummary] decides what the dashboard's intake/burn/net figures say,
/// and its rules are day-kind dependent:
///   • past   → resting + NEAT counted for the whole day
///   • today  → resting + NEAT prorated by minutes elapsed
///   • future → no burn at all
///
/// The proration is easy to get subtly wrong (off-by-one on the clamp, burn
/// leaking into a future day, a breakdown that does not add up to its own
/// total), and every one of those errors reads as a plausible number on screen
/// rather than as a crash. These tests pin the arithmetic exactly.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/day_energy_summary.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';

void main() {
  DailyMacroTargets targets({
    double carbG = 300,
    double protG = 150,
    double fatG = 80,
    double rmr = 1680,
    double? neatKcal = 480,
    double sessionKcal = 600,
  }) => DailyMacroTargets(
    id: 'dmt-1',
    userId: 'u1',
    targetDate: DateTime(2026, 7, 31),
    carbG: carbG,
    protG: protG,
    fatG: fatG,
    tdee: 2800,
    rmr: rmr,
    sessionKcal: sessionKcal,
    neatKcal: neatKcal,
    mode: 'performance',
    createdAt: DateTime(2026, 7, 31),
    updatedAt: DateTime(2026, 7, 31),
  );

  const consumed = ConsumedTotals(
    calories: 1800,
    carbsG: 200,
    proteinG: 90,
    fatG: 60,
  );

  group('DayKind.of', () {
    final now = DateTime(2026, 7, 31, 13, 30);

    test('classifies by calendar day, ignoring time of day', () {
      // 23:59 on the same date is still "today", not "future".
      expect(DayKind.of(DateTime(2026, 7, 31, 23, 59), now), DayKind.today);
      expect(DayKind.of(DateTime(2026, 7, 31, 0, 0), now), DayKind.today);
    });

    test('yesterday is past and tomorrow is future', () {
      expect(DayKind.of(DateTime(2026, 7, 30, 23, 59), now), DayKind.past);
      expect(DayKind.of(DateTime(2026, 8, 1, 0, 0), now), DayKind.future);
    });

    test('handles month and year boundaries', () {
      final newYear = DateTime(2027, 1, 1, 0, 5);
      expect(DayKind.of(DateTime(2026, 12, 31, 23, 55), newYear), DayKind.past);
      expect(DayKind.of(DateTime(2027, 1, 1, 23, 55), newYear), DayKind.today);
    });
  });

  group('past days count the full resting + NEAT burn', () {
    final summary = DayEnergySummary.compute(
      selectedDate: DateTime(2026, 7, 30),
      now: DateTime(2026, 7, 31, 9, 0),
      targets: targets(),
      consumed: consumed,
      workoutBurnedKcal: 500,
    );

    test('applies no proration', () {
      expect(summary.restingKcal, 1680);
      expect(summary.dailyActivityKcal, 480);
    });

    test('burned is the sum of the three components', () {
      expect(summary.burnedCalories, 1680 + 480 + 500);
    });

    test('net is eaten minus burned', () {
      expect(summary.netCalories, 1800 - (1680 + 480 + 500));
    });

    test('reports burn data', () {
      expect(summary.hasBurnData, isTrue);
      expect(summary.dayKind, DayKind.past);
    });
  });

  group('today prorates resting + NEAT by elapsed minutes', () {
    // 06:00 is 360/1440 = 25% of the day.
    final summary = DayEnergySummary.compute(
      selectedDate: DateTime(2026, 7, 31),
      now: DateTime(2026, 7, 31, 6, 0),
      targets: targets(),
      consumed: consumed,
      workoutBurnedKcal: 500,
    );

    test('resting and NEAT are scaled to the quarter-day', () {
      expect(summary.restingKcal, closeTo(1680 * 0.25, 0.001));
      expect(summary.dailyActivityKcal, closeTo(480 * 0.25, 0.001));
    });

    test('workout energy is NOT prorated — it counts in full once done', () {
      expect(summary.workoutKcal, 500);
    });

    test('midnight yields essentially no resting burn', () {
      final atMidnight = DayEnergySummary.compute(
        selectedDate: DateTime(2026, 7, 31),
        now: DateTime(2026, 7, 31, 0, 0),
        targets: targets(),
        consumed: consumed,
        workoutBurnedKcal: 0,
      );
      expect(atMidnight.restingKcal, 0);
      expect(atMidnight.burnedCalories, 0);
    });

    test('23:59 is very nearly a whole day but never exceeds one', () {
      final lateNight = DayEnergySummary.compute(
        selectedDate: DateTime(2026, 7, 31),
        now: DateTime(2026, 7, 31, 23, 59),
        targets: targets(),
        consumed: consumed,
        workoutBurnedKcal: 0,
      );
      expect(lateNight.restingKcal, lessThanOrEqualTo(1680));
      expect(lateNight.restingKcal, greaterThan(1680 * 0.99));
    });
  });

  group('future days show targets only', () {
    final summary = DayEnergySummary.compute(
      selectedDate: DateTime(2026, 8, 5),
      now: DateTime(2026, 7, 31, 13, 0),
      targets: targets(),
      consumed: consumed,
      workoutBurnedKcal: 0,
    );

    test('no burn data', () {
      expect(summary.hasBurnData, isFalse);
      expect(summary.burnedCalories, 0);
    });

    test('net equals eaten, not a negative burn figure', () {
      expect(summary.netCalories, 1800);
    });

    test('targets still come through', () {
      expect(summary.targetCalories, targets().totalCalories);
      expect(summary.plannedWorkoutKcal, 600);
    });
  });

  group('the burn breakdown always adds up to the reported total', () {
    // The dashboard renders resting / daily / workout as a breakdown *and*
    // renders burnedCalories as the headline. If a future day zeroes the total
    // but leaves a workout figure in the breakdown, the two disagree on screen.
    for (final (label, date, now) in [
      ('past', DateTime(2026, 7, 30), DateTime(2026, 7, 31, 9, 0)),
      ('today', DateTime(2026, 7, 31), DateTime(2026, 7, 31, 18, 0)),
      ('future', DateTime(2026, 8, 3), DateTime(2026, 7, 31, 9, 0)),
    ]) {
      test('$label day', () {
        final summary = DayEnergySummary.compute(
          selectedDate: date,
          now: now,
          targets: targets(),
          consumed: consumed,
          // Deliberately non-zero even for the future day: compute() is a
          // public factory and must not depend on its caller pre-zeroing.
          workoutBurnedKcal: 500,
        );

        expect(
          summary.restingKcal + summary.dailyActivityKcal + summary.workoutKcal,
          closeTo(summary.burnedCalories, 0.001),
          reason:
              'On a $label day the breakdown '
              '(${summary.restingKcal} + ${summary.dailyActivityKcal} + '
              '${summary.workoutKcal}) must equal the headline '
              '${summary.burnedCalories}.',
        );
      });
    }
  });

  group('missing targets degrade gracefully', () {
    final summary = DayEnergySummary.compute(
      selectedDate: DateTime(2026, 7, 31),
      now: DateTime(2026, 7, 31, 12, 0),
      targets: null,
      consumed: consumed,
      workoutBurnedKcal: 250,
    );

    test('zeroes every target rather than throwing', () {
      expect(summary.targetCalories, 0);
      expect(summary.carbsTarget, 0);
      expect(summary.proteinTarget, 0);
      expect(summary.fatTarget, 0);
      expect(summary.plannedWorkoutKcal, 0);
    });

    test('still counts the workout burn', () {
      expect(summary.workoutKcal, 250);
      expect(summary.burnedCalories, 250);
    });

    test('percentages are zero, not NaN or infinity', () {
      for (final pct in [
        summary.caloriesPct,
        summary.carbsPct,
        summary.proteinPct,
        summary.fatPct,
      ]) {
        expect(pct, 0);
        expect(pct.isFinite, isTrue);
      }
    });
  });

  group('progress percentages', () {
    test('clamp to 1.0 when the athlete eats over target', () {
      final over = DayEnergySummary.compute(
        selectedDate: DateTime(2026, 7, 31),
        now: DateTime(2026, 7, 31, 20, 0),
        targets: targets(carbG: 100, protG: 0, fatG: 0),
        consumed: const ConsumedTotals(calories: 99999, carbsG: 500),
        workoutBurnedKcal: 0,
      );

      expect(over.caloriesPct, 1.0);
      expect(over.carbsPct, 1.0);
    });

    test('are proportional in the ordinary case', () {
      final half = DayEnergySummary.compute(
        selectedDate: DateTime(2026, 7, 31),
        now: DateTime(2026, 7, 31, 12, 0),
        targets: targets(carbG: 100, protG: 100, fatG: 0),
        consumed: const ConsumedTotals(carbsG: 50, proteinG: 25),
        workoutBurnedKcal: 0,
      );

      expect(half.carbsPct, 0.5);
      expect(half.proteinPct, 0.25);
    });

    test('a null NEAT is treated as zero, not as a crash', () {
      final noNeat = DayEnergySummary.compute(
        selectedDate: DateTime(2026, 7, 30),
        now: DateTime(2026, 7, 31, 9, 0),
        targets: targets(neatKcal: null),
        consumed: consumed,
        workoutBurnedKcal: 0,
      );

      expect(noNeat.dailyActivityKcal, 0);
      expect(noNeat.burnedCalories, 1680);
    });
  });
}
