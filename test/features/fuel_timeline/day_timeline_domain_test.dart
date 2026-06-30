import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/day_energy_summary.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/fuel_timeline_filter.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/timeline_node.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  final now = DateTime(2026, 6, 17, 12);

  MealNode mealNode() => MealNode(MealLog(
        id: 'm',
        userId: 'u',
        logDate: '2026-06-17',
        slot: MealSlot.lunch,
        name: 'M',
        source: MealLogSource.manual,
        components: const [],
        createdAt: now,
        updatedAt: now,
      ));

  WorkoutNode workoutNode() => WorkoutNode(Activity(
        id: 'w',
        userId: 'u',
        activityType: ActivityType.cycling,
        title: 'Ride',
        scheduledDateTime: DateTime(2026, 6, 17, 16),
        createdAt: now,
        updatedAt: now,
      ));

  DailyMacroTargets targets({
    double rmr = 1000,
    double? neat = 400,
    double session = 500,
    double carb = 300,
    double prot = 140,
    double fat = 75,
  }) =>
      DailyMacroTargets(
        id: 't',
        userId: 'u',
        targetDate: DateTime(2026, 6, 17),
        carbG: carb,
        protG: prot,
        fatG: fat,
        tdee: rmr + (neat ?? 0) + session,
        rmr: rmr,
        sessionKcal: session,
        neatKcal: neat,
        mode: 'prospective',
        createdAt: now,
        updatedAt: now,
      );

  group('FuelTimelineFilter', () {
    test('matches gates meal vs workout nodes', () {
      expect(FuelTimelineFilter.all.matches(mealNode()), isTrue);
      expect(FuelTimelineFilter.all.matches(workoutNode()), isTrue);
      expect(FuelTimelineFilter.meals.matches(mealNode()), isTrue);
      expect(FuelTimelineFilter.meals.matches(workoutNode()), isFalse);
      expect(FuelTimelineFilter.workout.matches(workoutNode()), isTrue);
      expect(FuelTimelineFilter.workout.matches(mealNode()), isFalse);
    });

    test('Add-button gating', () {
      expect(FuelTimelineFilter.all.showsAddFood, isTrue);
      expect(FuelTimelineFilter.all.showsAddActivity, isTrue);
      expect(FuelTimelineFilter.meals.showsAddFood, isTrue);
      expect(FuelTimelineFilter.meals.showsAddActivity, isFalse);
      expect(FuelTimelineFilter.workout.showsAddFood, isFalse);
      expect(FuelTimelineFilter.workout.showsAddActivity, isTrue);
    });
  });

  group('DayKind.of', () {
    test('classifies by calendar day, ignoring time of day', () {
      final n = DateTime(2026, 6, 17, 23, 59);
      expect(DayKind.of(DateTime(2026, 6, 16, 0, 1), n), DayKind.past);
      expect(DayKind.of(DateTime(2026, 6, 17, 0, 0), n), DayKind.today);
      expect(DayKind.of(DateTime(2026, 6, 18, 0, 1), n), DayKind.future);
    });
  });

  group('DayEnergySummary.compute', () {
    DayEnergySummary compute(
      DateTime selected, {
      DateTime? at,
      DailyMacroTargets? t,
      ConsumedTotals consumed = const ConsumedTotals(),
      double workoutBurned = 0,
    }) =>
        DayEnergySummary.compute(
          selectedDate: selected,
          now: at ?? now,
          targets: t ?? targets(),
          consumed: consumed,
          workoutBurnedKcal: workoutBurned,
        );

    test('today prorates resting+daily by elapsed fraction', () {
      final at6 = compute(DateTime(2026, 6, 17),
          at: DateTime(2026, 6, 17, 6)); // 360/1440 = 0.25
      expect(at6.restingKcal, closeTo(250, 1e-6));
      expect(at6.dailyActivityKcal, closeTo(100, 1e-6));

      final at18 = compute(DateTime(2026, 6, 17),
          at: DateTime(2026, 6, 17, 18)); // 0.75
      expect(at18.restingKcal, closeTo(750, 1e-6));
      expect(at18.dailyActivityKcal, closeTo(300, 1e-6));
    });

    test('midnight today → zero prorated base', () {
      final m = compute(DateTime(2026, 6, 17), at: DateTime(2026, 6, 17, 0, 0));
      expect(m.restingKcal, 0);
      expect(m.dailyActivityKcal, 0);
    });

    test('past day uses full resting + daily', () {
      final p = compute(DateTime(2026, 6, 16), workoutBurned: 500);
      expect(p.dayKind, DayKind.past);
      expect(p.restingKcal, 1000);
      expect(p.dailyActivityKcal, 400);
      expect(p.workoutKcal, 500);
      expect(p.hasBurnData, isTrue);
    });

    test('future day → no burn, net equals eaten', () {
      final f = compute(DateTime(2026, 6, 18),
          consumed: const ConsumedTotals(calories: 800), workoutBurned: 500);
      expect(f.dayKind, DayKind.future);
      expect(f.hasBurnData, isFalse);
      expect(f.burnedCalories, 0);
      expect(f.netCalories, 800);
    });

    test('net intake = eaten - burned (today)', () {
      final s = compute(DateTime(2026, 6, 17),
          at: DateTime(2026, 6, 17, 12), // 0.5 → resting 500, daily 200
          consumed: const ConsumedTotals(calories: 1000),
          workoutBurned: 300);
      expect(s.burnedCalories, 1000); // 500 + 200 + 300
      expect(s.netCalories, 0);
    });

    test('plannedWorkoutKcal mirrors sessionKcal; null targets → zeros', () {
      expect(compute(DateTime(2026, 6, 17)).plannedWorkoutKcal, 500);
      final none = DayEnergySummary.compute(
        selectedDate: DateTime(2026, 6, 17),
        now: now,
        targets: null,
        consumed: const ConsumedTotals(calories: 400),
        workoutBurnedKcal: 0,
      );
      expect(none.targetCalories, 0);
      expect(none.plannedWorkoutKcal, 0);
      expect(none.caloriesPct, 0);
    });

    test('macro + calorie pct clamp to 0..1', () {
      final over = compute(DateTime(2026, 6, 17),
          t: targets(carb: 100, prot: 50, fat: 20),
          consumed: const ConsumedTotals(
              calories: 99999, carbsG: 999, proteinG: 999, fatG: 999));
      expect(over.caloriesPct, 1.0);
      expect(over.carbsPct, 1.0);
      expect(over.proteinPct, 1.0);
      expect(over.fatPct, 1.0);

      final half = compute(DateTime(2026, 6, 17),
          consumed: const ConsumedTotals(carbsG: 150)); // target 300
      expect(half.carbsPct, closeTo(0.5, 1e-9));
    });
  });
}
