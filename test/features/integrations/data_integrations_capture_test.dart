/// data-integrations@v1 Stage A — capture onto the Activity row (Q-INT26).
///
/// The transformers computed TSS/IF/calories/subtype/pace and then discarded
/// them on the TransformResult (Q-INT13); Stage A persists them on the
/// Activity itself. DI-13 null-tolerance: fixtures are producer-shaped (TP/FS
/// wire field names); a provider omitting a field must yield null on the row
/// — never an error, never a fabricated value (null != 0, the basic-athlete
/// shape).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';

import '../../fixtures/final_surge_fixtures.dart';
import '../../fixtures/training_peaks_fixtures.dart';

void main() {
  const userId = 'capture-test-user';

  group('TrainingPeaks capture (Q-INT26 items 1/2/6/9)', () {
    const transformer = TrainingPeaksTransformer();

    test('planned load metrics + planned calories land on the Activity', () {
      final workout = {
        'Id': 111222333,
        'WorkoutDay': '2026-09-12T00:00:00',
        'WorkoutType': 'Bike',
        'Title': 'Sweet Spot Intervals',
        'TotalTimePlanned': 1.5,
        'DistancePlanned': 40000.0,
        // TP wire fields, wire-shaped values
        'TSSPlanned': 85.2,
        'IFPlanned': 0.84,
        'CaloriesPlanned': 950,
      };

      final activity = transformer.transform(workout, userId)!.activity;

      expect(activity.tssPlanned, 85.2);
      expect(activity.ifPlanned, 0.84);
      expect(activity.tpCaloriesPlanned, 950.0);
      expect(activity.workoutSubtype, 'Sweet Spot Intervals');
      // Completed-side fields absent on a planned workout: null, not 0.
      expect(activity.tssActual, isNull);
      expect(activity.ifActual, isNull);
      expect(activity.tpCalories, isNull);
    });

    test('completed workout actuals land on the Activity', () {
      final workout = {
        'Id': 111222334,
        'WorkoutDay': '2026-09-11T00:00:00',
        'WorkoutType': 'Run',
        'Title': 'Threshold Run',
        'TotalTime': 1.02, // completed decimal hours
        'Distance': 14200.0,
        'TSSPlanned': 70.0,
        'IFPlanned': 0.88,
        // completed-side wire fields (premium athletes only)
        'TssActual': 74.6,
        'IF': 0.91,
        'Calories': 812,
      };

      final activity = transformer.transform(workout, userId)!.activity;

      expect(activity.tssActual, 74.6);
      expect(activity.ifActual, 0.91);
      expect(activity.tpCalories, 812.0);
      expect(activity.tssPlanned, 70.0);
      expect(activity.ifPlanned, 0.88);
    });

    test('basic-athlete payload (all nulls) captures nothing and never '
        'throws', () {
      // Real basic-athlete shape: keys present, values null (per 1.2 caveat).
      final workout = {
        'Id': 111222335,
        'WorkoutDay': '2026-09-13T00:00:00',
        'WorkoutType': 'Run',
        'Title': 'Easy Run',
        'TotalTimePlanned': 0.75,
        'TSSPlanned': null,
        'IFPlanned': null,
        'TssActual': null,
        'IF': null,
        'Calories': null,
        'CaloriesPlanned': null,
      };

      final activity = transformer.transform(workout, userId)!.activity;

      expect(activity.tssPlanned, isNull);
      expect(activity.tssActual, isNull);
      expect(activity.ifPlanned, isNull);
      expect(activity.ifActual, isNull);
      expect(activity.tpCalories, isNull);
      expect(activity.tpCaloriesPlanned, isNull);
    });

    test('minimal payload (keys absent entirely) never throws', () {
      final workout = {
        'Id': 111222336,
        'WorkoutDay': '2026-09-13T00:00:00',
        'WorkoutType': 'Run',
        'Title': 'Bare Minimum',
      };

      final activity = transformer.transform(workout, userId)!.activity;
      expect(activity.tssPlanned, isNull);
      expect(activity.workoutSubtype, 'Bare Minimum');
    });

    test('Walk subtype lands as Walk on the row', () {
      final activity = transformer
          .transform(TrainingPeaksFixtures.walkWorkout, userId)!
          .activity;
      expect(activity.workoutSubtype, 'Walk');
    });
  });

  group('Final Surge capture (Q-INT26 item 6)', () {
    final transformer = FinalSurgeTransformer();

    test('subtype and pace range land on the Activity', () {
      final activity = transformer
          .transform(FinalSurgeFixtures.runningWorkoutComplete, userId)!
          .activity;
      expect(activity.workoutSubtype, 'Tempo');

      final ranged = transformer
          .transform(FinalSurgeFixtures.runningWorkoutPaceRange, userId)!
          .activity;
      // "@ 9:12 - 10:01" — wire rounding of the parsed range
      expect(ranged.paceMinMinutesPerMile, closeTo(9.2, 0.01));
      expect(ranged.paceMaxMinutesPerMile, closeTo(10.0167, 0.01));
    });

    test('Walk subtype lands as Walk on the row', () {
      final activity = transformer
          .transform(FinalSurgeFixtures.walkWorkout, userId)!
          .activity;
      expect(activity.workoutSubtype, 'Walk');
    });

    test('payload without subtype or pace captures nulls, never throws', () {
      final workout = {
        'WorkoutKey': 'fs-minimal-1',
        'WorkoutDate': '2026-09-12T00:00:00',
        'WorkoutTitle': 'Just Run',
        'WorkoutTypeName': 'Run',
      };
      final activity = transformer.transform(workout, userId)!.activity;
      expect(activity.workoutSubtype, isNull);
      expect(activity.paceMinMinutesPerMile, isNull);
      expect(activity.paceMaxMinutesPerMile, isNull);
    });
  });
}
