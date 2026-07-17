import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart' show CarbLoadingDay;
import 'package:mealvana_endurance/features/fuel_timeline/application/day_timeline_assembler.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/day_energy_summary.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/fuel_timeline_filter.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/timeline_node.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  const assembler = DayTimelineAssembler();

  // ── fixture builders ────────────────────────────────────────────────────────
  MealLog meal(
    String id, {
    required DateTime eatenAt,
    int calories = 0,
    bool isDeleted = false,
  }) {
    return MealLog(
      id: id,
      userId: 'u1',
      logDate: '2026-06-17',
      slot: MealSlot.lunch,
      name: 'Meal $id',
      source: MealLogSource.manual,
      components: const [],
      calories: calories,
      eatenAt: eatenAt,
      createdAt: eatenAt,
      updatedAt: eatenAt,
      isDeleted: isDeleted,
    );
  }

  Activity workout(
    String id, {
    required DateTime scheduledAt,
    DateTime? deletedAt,
  }) {
    return Activity(
      id: id,
      userId: 'u1',
      activityType: ActivityType.cycling,
      title: 'Ride $id',
      scheduledDateTime: scheduledAt,
      createdAt: scheduledAt,
      updatedAt: scheduledAt,
      deletedAt: deletedAt,
    );
  }

  DailyMacroTargets targets({
    double carbG = 300,
    double protG = 140,
    double fatG = 75,
    double rmr = 1000,
    double? neatKcal = 400,
    double sessionKcal = 500,
  }) {
    return DailyMacroTargets(
      id: 'm1',
      userId: 'u1',
      targetDate: DateTime(2026, 6, 17),
      carbG: carbG,
      protG: protG,
      fatG: fatG,
      tdee: rmr + (neatKcal ?? 0) + sessionKcal,
      rmr: rmr,
      sessionKcal: sessionKcal,
      neatKcal: neatKcal,
      mode: 'prospective',
      createdAt: DateTime(2026, 6, 17),
      updatedAt: DateTime(2026, 6, 17),
    );
  }

  final date = DateTime(2026, 6, 17);

  group('ordering + interleave', () {
    test('meals and workouts interleave in chronological order', () {
      final result = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: [
          meal('bf', eatenAt: DateTime(2026, 6, 17, 7, 30)),
          meal('dn', eatenAt: DateTime(2026, 6, 17, 19, 0)),
        ],
        activities: [workout('ride', scheduledAt: DateTime(2026, 6, 17, 16, 15))],
        targets: targets(),
        consumed: const ConsumedTotals(),
      );

      expect(result.nodes.map((n) => n.id).toList(), ['bf', 'ride', 'dn']);
      expect(result.nodes[0], isA<MealNode>());
      expect(result.nodes[1], isA<WorkoutNode>());
    });

    test('events and carb-loading days appear on the timeline', () {
      final event = Event(
        id: 'race1',
        userId: 'u1',
        eventType: ActivityType.running,
        eventName: 'City Marathon',
        eventDate: date,
        startTime: '2026-06-17T09:00:00',
        createdAt: date,
        updatedAt: date,
      );
      final carbDay = CarbLoadingDay(
        id: 'cd1',
        carbLoadingPlanId: 'plan1',
        planDate: date,
        dayNumber: 2,
        carbTargetGrams: 610,
        carbProtocolGPerKg: 8.0,
        mealCount: 4,
        breakfastPercent: 0.25,
        morningSnackPercent: 0.1,
        lunchPercent: 0.25,
        afternoonSnackPercent: 0.1,
        dinnerPercent: 0.2,
        eveningSnackPercent: 0.1,
        loggedCarbsGrams: 0,
        loggedCalories: 0,
        completed: false,
        needsUpload: false,
        localUpdatedAt: date,
      );

      final result = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: [meal('lunch', eatenAt: DateTime(2026, 6, 17, 12, 0))],
        activities: const [],
        targets: targets(),
        consumed: const ConsumedTotals(),
        events: [event],
        carbLoadingDays: [carbDay],
        planTotalDaysById: const {'plan1': 3},
      );

      // Carb day sorts to midnight (all-day), event to 09:00, lunch to noon.
      expect(result.nodes.map((n) => n.runtimeType.toString()).toList(),
          ['CarbLoadingNode', 'EventNode', 'MealNode']);

      final carb = result.nodes.whereType<CarbLoadingNode>().single;
      expect(carb.day.carbTargetGrams, 610);
      expect(carb.totalDays, 3);

      final ev = result.nodes.whereType<EventNode>().single;
      expect(ev.event.eventName, 'City Marathon');
      expect(ev.time, DateTime(2026, 6, 17, 9, 0));
    });

    test('event with no date/startTime is dropped', () {
      final result = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: const [],
        activities: const [],
        targets: targets(),
        consumed: const ConsumedTotals(),
        events: [
          Event(
            id: 'nodate',
            userId: 'u1',
            eventType: ActivityType.running,
            eventName: 'Undated',
            createdAt: date,
            updatedAt: date,
          ),
        ],
      );
      expect(result.nodes.whereType<EventNode>(), isEmpty);
    });

    test('meal with no eatenAt falls back to createdAt for ordering', () {
      final m = MealLog(
        id: 'noeat',
        userId: 'u1',
        logDate: '2026-06-17',
        slot: MealSlot.snack,
        name: 'No eat time',
        source: MealLogSource.manual,
        components: const [],
        createdAt: DateTime(2026, 6, 17, 6, 0),
        updatedAt: DateTime(2026, 6, 17, 6, 0),
      );
      final result = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: [meal('later', eatenAt: DateTime(2026, 6, 17, 9, 0)), m],
        activities: const [],
        targets: targets(),
        consumed: const ConsumedTotals(),
      );
      expect(result.nodes.first.id, 'noeat');
    });

    test('deleted meals and activities are excluded', () {
      final result = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: [
          meal('keep', eatenAt: DateTime(2026, 6, 17, 8)),
          meal('gone', eatenAt: DateTime(2026, 6, 17, 9), isDeleted: true),
        ],
        activities: [
          workout('keepW', scheduledAt: DateTime(2026, 6, 17, 10)),
          workout(
            'goneW',
            scheduledAt: DateTime(2026, 6, 17, 11),
            deletedAt: DateTime(2026, 6, 17, 11),
          ),
        ],
        targets: targets(),
        consumed: const ConsumedTotals(),
      );
      expect(result.nodes.map((n) => n.id).toList(), ['keep', 'keepW']);
    });

    test('empty inputs yield no nodes and a zeroed target summary', () {
      final result = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 12),
        meals: const [],
        activities: const [],
        targets: null,
        consumed: const ConsumedTotals(),
      );
      expect(result.nodes, isEmpty);
      expect(result.summary.targetCalories, 0);
      expect(result.summary.burnedCalories, 0);
      expect(result.summary.caloriesPct, 0);
    });
  });

  group('filter gating', () {
    final meals = [meal('m', eatenAt: DateTime(2026, 6, 17, 8))];
    final acts = [workout('w', scheduledAt: DateTime(2026, 6, 17, 16))];

    test('all shows both', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: meals,
        activities: acts,
        targets: targets(),
        consumed: const ConsumedTotals(),
        filter: FuelTimelineFilter.all,
      );
      expect(r.nodes.length, 2);
    });

    test('workout shows only workouts', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: meals,
        activities: acts,
        targets: targets(),
        consumed: const ConsumedTotals(),
        filter: FuelTimelineFilter.workout,
      );
      expect(r.nodes.map((n) => n.id).toList(), ['w']);
    });

    test('meals shows only meals', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: meals,
        activities: acts,
        targets: targets(),
        consumed: const ConsumedTotals(),
        filter: FuelTimelineFilter.meals,
      );
      expect(r.nodes.map((n) => n.id).toList(), ['m']);
    });

    test('summary is unaffected by the filter', () {
      final base = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 20),
        meals: meals,
        activities: acts,
        targets: targets(),
        consumed: const ConsumedTotals(calories: 500),
        burnByActivityId: const {'w': 500},
        filter: FuelTimelineFilter.meals,
      );
      // Workout burn still counts even though the workout node is filtered out.
      expect(base.summary.workoutKcal, 500);
    });
  });

  group('burn proration by day kind', () {
    test('past day uses full resting + daily + workout', () {
      final r = assembler.assemble(
        selectedDate: DateTime(2026, 6, 16),
        now: DateTime(2026, 6, 17, 12),
        meals: const [],
        activities: [workout('w', scheduledAt: DateTime(2026, 6, 16, 9))],
        targets: targets(rmr: 1000, neatKcal: 400),
        consumed: const ConsumedTotals(calories: 1000),
        burnByActivityId: const {'w': 500},
      );
      expect(r.summary.dayKind, DayKind.past);
      expect(r.summary.restingKcal, 1000);
      expect(r.summary.dailyActivityKcal, 400);
      expect(r.summary.workoutKcal, 500);
      // Planned workout energy comes from targets.sessionKcal regardless of
      // done-state, and drives the Workout dashboard headline.
      expect(r.summary.plannedWorkoutKcal, 500);
      expect(r.summary.burnedCalories, 1900);
      expect(r.summary.netCalories, 1000 - 1900);
      expect(r.summary.hasBurnData, isTrue);
    });

    test('today prorates resting/daily by elapsed fraction (noon = 0.5)', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 12), // 720/1440 = 0.5
        meals: const [],
        activities: [workout('w', scheduledAt: DateTime(2026, 6, 17, 9))],
        targets: targets(rmr: 1000, neatKcal: 400),
        consumed: const ConsumedTotals(calories: 1000),
        burnByActivityId: const {'w': 500},
      );
      expect(r.summary.dayKind, DayKind.today);
      expect(r.summary.restingKcal, 500);
      expect(r.summary.dailyActivityKcal, 200);
      expect(r.summary.workoutKcal, 500); // 09:00 <= now
      expect(r.summary.burnedCalories, 1200);
      expect(r.summary.netCalories, 1000 - 1200);
    });

    test('today does not count a workout scheduled after now', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 12),
        meals: const [],
        activities: [workout('w', scheduledAt: DateTime(2026, 6, 17, 16, 15))],
        targets: targets(rmr: 1000, neatKcal: 400),
        consumed: const ConsumedTotals(calories: 1000),
        burnByActivityId: const {'w': 500},
      );
      expect(r.summary.workoutKcal, 0);
      expect(r.summary.burnedCalories, 700); // 500 resting + 200 daily, no workout
    });

    test('future day shows targets only — no burn, net equals eaten', () {
      final r = assembler.assemble(
        selectedDate: DateTime(2026, 6, 18),
        now: DateTime(2026, 6, 17, 12),
        meals: const [],
        activities: [workout('w', scheduledAt: DateTime(2026, 6, 18, 9))],
        targets: targets(rmr: 1000, neatKcal: 400),
        consumed: const ConsumedTotals(calories: 800),
        burnByActivityId: const {'w': 500},
      );
      expect(r.summary.dayKind, DayKind.future);
      expect(r.summary.hasBurnData, isFalse);
      expect(r.summary.burnedCalories, 0);
      expect(r.summary.workoutKcal, 0);
      expect(r.summary.netCalories, 800);
    });
  });

  group('intake summary', () {
    test('macros + target + clamped pct flow through from targets/consumed', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 12),
        meals: const [],
        activities: const [],
        targets: targets(carbG: 300, protG: 140, fatG: 75),
        consumed: const ConsumedTotals(
          calories: 1000,
          carbsG: 150,
          proteinG: 70,
          fatG: 30,
        ),
      );
      // target calories = 300*4 + 140*4 + 75*9 = 2435
      expect(r.summary.targetCalories, 2435);
      expect(r.summary.carbsEaten, 150);
      expect(r.summary.carbsTarget, 300);
      expect(r.summary.carbsPct, closeTo(0.5, 1e-9));
      expect(r.summary.caloriesPct, closeTo(1000 / 2435, 1e-9));
    });

    test('caloriesPct clamps to 1.0 when over target', () {
      final r = assembler.assemble(
        selectedDate: date,
        now: DateTime(2026, 6, 17, 12),
        meals: const [],
        activities: const [],
        targets: targets(carbG: 100, protG: 50, fatG: 20),
        consumed: const ConsumedTotals(calories: 5000),
      );
      expect(r.summary.caloriesPct, 1.0);
    });
  });
}
