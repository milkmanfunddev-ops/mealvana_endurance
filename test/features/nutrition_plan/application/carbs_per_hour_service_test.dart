import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/carbs_per_hour_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/carbs_per_hour_summary.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/fuel_log_data.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

const _service = CarbsPerHourService();

Activity _activity({
  ActivityType type = ActivityType.running,
  int? durationMinutes = 120,
  int? actualDurationMinutes,
  String? workoutSubtype,
  String? cyclingSessionGoal,
  Map<String, dynamic>? fuelLogData,
  String id = 'a1',
}) {
  return Activity(
    id: id,
    userId: 'u1',
    activityType: type,
    title: 'Session',
    scheduledDateTime: DateTime(2026, 3, 20, 7),
    durationMinutes: durationMinutes,
    actualDurationMinutes: actualDurationMinutes,
    workoutSubtype: workoutSubtype,
    cyclingSessionGoal: cyclingSessionGoal,
    fuelLogData: fuelLogData,
    createdAt: DateTime(2026, 3, 19),
    updatedAt: DateTime(2026, 3, 20),
  );
}

/// A fuel log with [duringCarbs]g in the during section and [otherCarbs]g
/// split across before/after (which must NOT count toward carbs/hr).
FuelLogData _fuelLog({required int duringCarbs, int otherCarbs = 0}) {
  return FuelLogData(
    items: [
      FuelLogItem(
        foodId: 'gel',
        sectionId: 'during_run',
        plannedQuantity: 1,
        actualQuantity: 1,
        name: 'Gel',
        nutritionalInfo: NutritionalInfo(carbs: duringCarbs),
      ),
      if (otherCarbs > 0)
        FuelLogItem(
          foodId: 'banana',
          sectionId: 'after_run',
          plannedQuantity: 1,
          actualQuantity: 1,
          name: 'Banana',
          nutritionalInfo: NutritionalInfo(carbs: otherCarbs),
        ),
    ],
  );
}

void main() {
  group('duringCarbsG', () {
    test('sums only during-section carbs, ignoring before/after', () {
      final log = _fuelLog(duringCarbs: 90, otherCarbs: 27);
      expect(_service.duringCarbsG(log), 90);
    });

    test('scales by actual ÷ planned quantity', () {
      final log = FuelLogData(
        items: [
          FuelLogItem(
            foodId: 'gel',
            sectionId: 'during_run',
            plannedQuantity: 4,
            actualQuantity: 2, // half consumed
            name: 'Gel',
            nutritionalInfo: NutritionalInfo(carbs: 80),
          ),
        ],
      );
      expect(_service.duringCarbsG(log), 40);
    });

    // Regression: workout fuel-log "reverts on Save / resets on reopen"
    // (Bug Reports 391e3fdb…f591 + …9647). Both fixes rely on the saved
    // fuel log round-tripping through JSON so an edited actualQuantity is
    // restored — not reset to the planned amount — when the screen reloads
    // it from `activity.fuelLogData`.
    test('edited actualQuantity survives a toJson→fromJson round-trip', () {
      final edited = FuelLogData(
        items: [
          FuelLogItem(
            foodId: 'gel',
            sectionId: 'during_run',
            plannedQuantity: 3,
            actualQuantity: 4, // user logged one extra gel
            name: 'Energy Gel',
            nutritionalInfo: NutritionalInfo(carbs: 30),
          ),
        ],
      );
      // Live (in-memory) value the dashboard shows: 30 × 4/3 = 40.
      expect(_service.duringCarbsG(edited), 40);

      // What gets persisted to activity.fuelLogData and reloaded on
      // re-entry / after Save must preserve the edit (40), not revert to the
      // planned 30.
      final reloaded = FuelLogData.fromJson(edited.toJson());
      expect(reloaded.items.single.actualQuantity, 4);
      expect(reloaded.items.single.plannedQuantity, 3);
      expect(_service.duringCarbsG(reloaded), 40);
    });
  });

  group('sessionCarbRate', () {
    test('divides during carbs by effective duration in hours', () {
      final rate = _service.sessionCarbRate(
        _activity(durationMinutes: 120),
        _fuelLog(duringCarbs: 100),
      );
      expect(rate, closeTo(50.0, 0.001));
    });

    test('prefers actual duration over planned', () {
      final rate = _service.sessionCarbRate(
        _activity(durationMinutes: 120, actualDurationMinutes: 100),
        _fuelLog(duringCarbs: 90),
      );
      expect(rate, closeTo(54.0, 0.001));
    });
  });

  group('exclusionReason', () {
    test('none for an eligible long run', () {
      expect(
        _service.exclusionReason(_activity(durationMinutes: 120)),
        CarbsHrExclusionReason.none,
      );
    });

    test('swim for swimming', () {
      expect(
        _service.exclusionReason(_activity(type: ActivityType.swimming)),
        CarbsHrExclusionReason.swim,
      );
    });

    test('tooShort under the 90-minute threshold', () {
      expect(
        _service.exclusionReason(_activity(durationMinutes: 80)),
        CarbsHrExclusionReason.tooShort,
      );
    });

    test('speedWork from workout subtype', () {
      expect(
        _service.exclusionReason(
          _activity(durationMinutes: 120, workoutSubtype: 'interval'),
        ),
        CarbsHrExclusionReason.speedWork,
      );
    });

    test('speedWork from cycling intervals goal', () {
      expect(
        _service.exclusionReason(
          _activity(
            type: ActivityType.cycling,
            durationMinutes: 120,
            cyclingSessionGoal: 'intervals',
          ),
        ),
        CarbsHrExclusionReason.speedWork,
      );
    });
  });

  group('buildSummary', () {
    test('excluded state for speed work', () {
      final summary = _service.buildSummary(
        activity: _activity(durationMinutes: 120, workoutSubtype: 'tempo'),
        fuelLog: _fuelLog(duringCarbs: 100),
        baseline: CarbsPerHourBaseline.empty,
      );
      expect(summary.state, CarbsHrState.excluded);
      expect(summary.exclusionReason, CarbsHrExclusionReason.speedWork);
      expect(summary.totalDuringCarbsG, 100);
      expect(summary.trend, isEmpty);
    });

    test('buildingBaseline when fewer than the unlock threshold', () {
      final summary = _service.buildSummary(
        activity: _activity(durationMinutes: 120),
        fuelLog: _fuelLog(duringCarbs: 100),
        baseline: const CarbsPerHourBaseline(history: [50, 55], count: 2),
      );
      expect(summary.state, CarbsHrState.buildingBaseline);
      expect(summary.trend, isEmpty);
      expect(summary.baselineCount, 2);
    });

    test('inBaseline with trend, delta, and highest-yet flag', () {
      final summary = _service.buildSummary(
        activity: _activity(durationMinutes: 120, actualDurationMinutes: 100),
        fuelLog: _fuelLog(duringCarbs: 90), // 54 g/hr
        baseline: const CarbsPerHourBaseline(
          history: [40, 44, 39, 47, 49],
          count: 5,
        ),
        targetGPerH: 60,
      );
      expect(summary.state, CarbsHrState.inBaseline);
      expect(summary.carbsPerHour, closeTo(54.0, 0.001));
      // trend = history + today
      expect(summary.trend, [40, 44, 39, 47, 49, closeTo(54, 0.001)]);
      expect(summary.baselineAverage, closeTo(43.8, 0.001));
      expect(summary.deltaVsAverage, closeTo(10.2, 0.001));
      expect(summary.isHighestYet, isTrue);
      expect(summary.targetGPerH, 60);
    });

    test('inBaseline below average is not highest yet', () {
      final summary = _service.buildSummary(
        activity: _activity(durationMinutes: 120),
        fuelLog: _fuelLog(duringCarbs: 60), // 30 g/hr
        baseline: const CarbsPerHourBaseline(
          history: [40, 44, 39, 47, 49],
          count: 5,
        ),
      );
      expect(summary.isHighestYet, isFalse);
      expect(summary.deltaVsAverage, lessThan(0));
    });
  });

  group('baselineFromHistory', () {
    test('reduces recent efforts to qualifying rates, oldest→newest', () {
      // recent-first input
      final recent = [
        _activity(
          id: 'r1',
          durationMinutes: 100,
          fuelLogData: _fuelLog(duringCarbs: 90).toJson(), // 54
        ),
        _activity(
          id: 'r2',
          durationMinutes: 120,
          fuelLogData: _fuelLog(duringCarbs: 100).toJson(), // 50
        ),
        _activity(
          id: 'swim',
          type: ActivityType.swimming,
          durationMinutes: 120,
          fuelLogData: _fuelLog(duringCarbs: 100).toJson(), // excluded
        ),
        _activity(
          id: 'r3',
          durationMinutes: 120,
          fuelLogData: _fuelLog(duringCarbs: 80).toJson(), // 40
        ),
        _activity(id: 'noFuel', durationMinutes: 120), // skipped (no fuel)
      ];

      final baseline = _service.baselineFromHistory(recent);
      expect(baseline.count, 3);
      expect(baseline.history.length, 3);
      // oldest → newest
      expect(baseline.history[0], closeTo(40, 0.001));
      expect(baseline.history[1], closeTo(50, 0.001));
      expect(baseline.history[2], closeTo(54, 0.001));
    });

    test('windows priors to (trendWindow - 1) points but counts all', () {
      final recent = List.generate(
        9,
        (i) => _activity(
          id: 'r$i',
          durationMinutes: 120,
          fuelLogData: _fuelLog(duringCarbs: 100).toJson(),
        ),
      );
      final baseline = _service.baselineFromHistory(recent);
      expect(baseline.count, 9);
      expect(baseline.history.length, 5); // trendWindow(6) - 1
    });
  });
}
