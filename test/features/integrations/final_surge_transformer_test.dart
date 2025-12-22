import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/domain/final_surge_defaults.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../fixtures/final_surge_fixtures.dart';

void main() {
  late FinalSurgeTransformer transformer;
  const testUserId = 'test-user-id-123';

  setUp(() {
    transformer = const FinalSurgeTransformer();
  });

  group('FinalSurgeTransformer', () {
    // =========================================================================
    // TIME CONVERSION TESTS
    // =========================================================================
    group('Time conversion', () {
      test('converts PlannedTime seconds to minutes', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        // 4800 seconds = 80 minutes
        expect(result!.activity.durationMinutes, equals(80));
      });

      test('handles null PlannedTime with running default', () {
        final result = transformer.transform(
          FinalSurgeFixtures.workoutMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.durationMinutes,
          equals(FinalSurgeDefaults.runningDurationMinutes),
        );
      });

      test('handles null PlannedTime with cycling default', () {
        final result = transformer.transform(
          FinalSurgeFixtures.cyclingMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.durationMinutes,
          equals(FinalSurgeDefaults.cyclingDurationMinutes),
        );
      });

      test('handles null PlannedTime with swimming default', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.durationMinutes,
          equals(FinalSurgeDefaults.swimmingDurationMinutes),
        );
      });
    });

    // =========================================================================
    // PACE PARSING TESTS
    // =========================================================================
    group('Pace parsing', () {
      test('parses single pace value from description "@ 8:00"', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.paceTargetMinutesPerMile, equals(8.0));
        expect(result.paceMinMinutesPerMile, isNull);
        expect(result.paceMaxMinutesPerMile, isNull);
      });

      test('parses pace RANGE "@ 9:12 - 10:01" correctly', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutPaceRange,
          testUserId,
        );

        expect(result, isNotNull);

        // 9:12 = 9 + 12/60 = 9.2
        expect(
          result!.paceMinMinutesPerMile,
          closeTo(9.2, 0.01),
        );

        // 10:01 = 10 + 1/60 ≈ 10.0167
        expect(
          result.paceMaxMinutesPerMile,
          closeTo(10.0167, 0.01),
        );

        // Midpoint
        final expectedMidpoint = (9.2 + 10.0167) / 2;
        expect(
          result.activity.paceTargetMinutesPerMile,
          closeTo(expectedMidpoint, 0.01),
        );
      });

      test('parses pace RANGE without spaces "@ 8:30-9:30"', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutPaceRangeNoSpace,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.paceMinMinutesPerMile, closeTo(8.5, 0.01));
        expect(result.paceMaxMinutesPerMile, closeTo(9.5, 0.01));
        expect(result.activity.paceTargetMinutesPerMile, closeTo(9.0, 0.01));
      });

      test('handles null description with running default pace', () {
        final result = transformer.transform(
          FinalSurgeFixtures.workoutNullFields,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.paceTargetMinutesPerMile,
          equals(FinalSurgeDefaults.runningPaceMinPerMile),
        );
      });

      test('handles empty description with running default pace', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutDescription'] = '';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(
          result!.activity.paceTargetMinutesPerMile,
          equals(FinalSurgeDefaults.runningPaceMinPerMile),
        );
      });
    });

    // =========================================================================
    // SPORT TYPE MAPPING TESTS
    // =========================================================================
    group('Sport type mapping', () {
      test('maps Run to ActivityType.running', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.running));
      });

      test('maps Walk to ActivityType.running with easy intensity', () {
        final result = transformer.transform(
          FinalSurgeFixtures.walkWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.running));
        expect(result.activity.intensityLevel, equals(IntensityLevel.easy));
        expect(result.workoutSubtype, equals('Walk'));
      });

      test('maps Swim to ActivityType.swimming', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.swimming));
      });

      test('maps Bike to ActivityType.cycling', () {
        final result = transformer.transform(
          FinalSurgeFixtures.cyclingWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.cycling));
      });

      test('filters out Rest Day workouts', () {
        final result = transformer.transform(
          FinalSurgeFixtures.restDayWorkout,
          testUserId,
        );

        expect(result, isNull);
      });

      test('filters out Recovery/Rehab workouts', () {
        final result = transformer.transform(
          FinalSurgeFixtures.recoveryWorkout,
          testUserId,
        );

        expect(result, isNull);
      });
    });

    // =========================================================================
    // DISTANCE CONVERSION TESTS
    // =========================================================================
    group('Distance conversion', () {
      test('keeps miles as-is for running', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.distanceMiles, equals(10.0));
      });

      test('converts km to miles for cycling', () {
        final result = transformer.transform(
          FinalSurgeFixtures.cyclingWorkoutKm,
          testUserId,
        );

        expect(result, isNotNull);
        // 40 km * 0.621371 = 24.85484 miles
        expect(result!.activity.distanceMiles, closeTo(24.85, 0.1));
      });

      test('stores swimming distance in meters', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.distanceMeters, equals(2000.0));
        expect(result.activity.distanceMiles, isNull); // Swimming uses meters
      });

      test('converts swimming yards to meters', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingWorkoutYards,
          testUserId,
        );

        expect(result, isNotNull);
        // 1650 yards * 0.9144 = 1508.76 meters
        expect(result!.distanceMeters, closeTo(1508.76, 0.1));
      });

      test('applies running default distance when missing', () {
        final result = transformer.transform(
          FinalSurgeFixtures.workoutMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.distanceMiles,
          equals(FinalSurgeDefaults.runningDistanceMiles),
        );
      });

      test('applies cycling default distance when missing', () {
        final result = transformer.transform(
          FinalSurgeFixtures.cyclingMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.distanceMiles,
          equals(FinalSurgeDefaults.cyclingDistanceMiles),
        );
      });

      test('applies swimming default distance when missing', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.distanceMeters,
          equals(FinalSurgeDefaults.swimmingDistanceMeters),
        );
      });
    });

    // =========================================================================
    // SENSIBLE DEFAULTS TESTS
    // =========================================================================
    group('Sensible defaults', () {
      test('applies all running defaults for missing data', () {
        final result = transformer.transform(
          FinalSurgeFixtures.workoutMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.distanceMiles,
          equals(FinalSurgeDefaults.runningDistanceMiles),
        );
        expect(
          result.activity.durationMinutes,
          equals(FinalSurgeDefaults.runningDurationMinutes),
        );
        expect(
          result.activity.paceTargetMinutesPerMile,
          equals(FinalSurgeDefaults.runningPaceMinPerMile),
        );
      });

      test('applies all cycling defaults for missing data', () {
        final result = transformer.transform(
          FinalSurgeFixtures.cyclingMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.activity.distanceMiles,
          equals(FinalSurgeDefaults.cyclingDistanceMiles),
        );
        expect(
          result.activity.durationMinutes,
          equals(FinalSurgeDefaults.cyclingDurationMinutes),
        );
      });

      test('applies all swimming defaults for missing data', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingMissingData,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.distanceMeters,
          equals(FinalSurgeDefaults.swimmingDistanceMeters),
        );
        expect(
          result.activity.durationMinutes,
          equals(FinalSurgeDefaults.swimmingDurationMinutes),
        );
      });
    });

    // =========================================================================
    // WORKOUT ID EXTRACTION TESTS
    // =========================================================================
    group('Workout ID extraction', () {
      test('extracts WorkoutKey as primary ID', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.providerWorkoutId, equals('79f28709-f623-4cb5-b99a-4c3161e6d20f'));
      });

      test('stores provider URL', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(
          result!.providerWorkoutUrl,
          contains('log.finalsurge.com/WorkoutDetails'),
        );
      });

      test('sets syncedFromProvider to final_surge', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.syncedFromProvider, equals('final_surge'));
      });
    });

    // =========================================================================
    // INTENSITY INFERENCE TESTS
    // =========================================================================
    group('Intensity inference', () {
      test('infers easy intensity for recovery subtype', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutSubTypeName'] = 'Easy Recovery';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.intensityLevel, equals(IntensityLevel.easy));
      });

      test('infers hard intensity for tempo subtype', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutSubTypeName'] = 'Tempo';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.intensityLevel, equals(IntensityLevel.hard));
      });

      test('infers hard intensity for intervals subtype', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutSubTypeName'] = 'Speed Intervals';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.intensityLevel, equals(IntensityLevel.hard));
      });

      test('infers race intensity when WorkoutRace is true', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutRace'] = true;

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.intensityLevel, equals(IntensityLevel.race));
      });

      test('infers moderate intensity for long run subtype', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutSubTypeName'] = 'Long Run';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.intensityLevel, equals(IntensityLevel.moderate));
      });

      test('defaults to moderate intensity when no hints', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutSubTypeName'] = null
          ..['WorkoutRace'] = false;

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.intensityLevel, equals(IntensityLevel.moderate));
      });
    });

    // =========================================================================
    // TITLE HANDLING TESTS
    // =========================================================================
    group('Title handling', () {
      test('uses WorkoutTitle when available', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.title, equals('Marathon Tempo'));
      });

      test('falls back to WorkoutTypeName when title is null and no subtype', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutTitle'] = null
          ..['WorkoutSubTypeName'] = null;

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.title, equals('Run'));
      });

      test('combines type and subtype when title is empty', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutTitle'] = ''
          ..['WorkoutSubTypeName'] = 'Tempo';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.title, equals('Run - Tempo'));
      });
    });

    // =========================================================================
    // SWIMMING PACE CALCULATION TESTS
    // =========================================================================
    group('Swimming pace calculation', () {
      test('calculates swimming pace in seconds per 100m', () {
        final result = transformer.transform(
          FinalSurgeFixtures.swimmingWorkout,
          testUserId,
        );

        expect(result, isNotNull);

        // 2000m in 40 minutes = 2400 seconds
        // 2000m / 100 = 20 hundreds
        // 2400 / 20 = 120 seconds per 100m
        expect(result!.activity.swimmingPacePer100mSeconds, equals(120));
      });
    });

    // =========================================================================
    // DESCRIPTION CLEANING TESTS
    // =========================================================================
    group('Description cleaning', () {
      test('removes pace prefix from description', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.notes, equals('Easy warmup, then marathon pace'));
        expect(result.activity.notes, isNot(contains('@ 8:00')));
      });

      test('returns null for empty description after cleaning', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutPaceRange)
          ..['WorkoutDescription'] = '@ 9:12 - 10:01';

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.activity.notes, isNull);
      });
    });

    // =========================================================================
    // DATE PARSING TESTS
    // =========================================================================
    group('Date parsing', () {
      test('parses ISO date string correctly', () {
        final result = transformer.transform(
          FinalSurgeFixtures.runningWorkoutComplete,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.scheduledDateTime.year, equals(2025));
        expect(result.activity.scheduledDateTime.month, equals(12));
        expect(result.activity.scheduledDateTime.day, equals(23));
      });

      test('handles null date with fallback to now', () {
        final workout = Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
          ..['WorkoutDate'] = null;

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        // Should be today (within reasonable margin)
        final now = DateTime.now();
        expect(result!.activity.scheduledDateTime.year, equals(now.year));
        expect(result.activity.scheduledDateTime.month, equals(now.month));
        expect(result.activity.scheduledDateTime.day, equals(now.day));
      });
    });
  });
}
