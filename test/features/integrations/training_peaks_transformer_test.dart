import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/domain/intensity_distribution_mapper.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/intensity_distribution.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../fixtures/training_peaks_fixtures.dart';

void main() {
  late TrainingPeaksTransformer transformer;
  const testUserId = 'test-user-id-123';

  setUp(() {
    transformer = const TrainingPeaksTransformer();
  });

  group('TrainingPeaksTransformer', () {
    // =========================================================================
    // BASIC TRANSFORMATION TESTS
    // =========================================================================
    group('Basic transformation', () {
      test('transforms running workout correctly', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.easyRunWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.running));
        expect(result.syncedFromProvider, equals('training_peaks'));
      });

      test('transforms cycling workout correctly', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.cyclingEndurance,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.cycling));
      });

      test('maps Walk to running with easy intensity', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.walkWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.running));
        expect(result.workoutSubtype, equals('Walk'));
      });

      test('imports unsupported workout types as ActivityType.other', () {
        final unsupportedWorkout = {
          'Id': 999999,
          'WorkoutDay': '2026-02-01T00:00:00',
          'WorkoutType': 'Strength',
          'Title': 'Gym Session',
        };

        final result = transformer.transform(unsupportedWorkout, testUserId);
        expect(result, isNotNull);
        expect(result!.activity.activityType, equals(ActivityType.other));
        expect(result.activity.title, equals('Gym Session'));
      });

      test('returns null when WorkoutType is missing', () {
        final noTypeWorkout = {
          'Id': 999998,
          'WorkoutDay': '2026-02-01T00:00:00',
          'Title': 'Mystery Session',
        };

        final result = transformer.transform(noTypeWorkout, testUserId);
        expect(result, isNull);
      });
    });

    // =========================================================================
    // INTENSITY DISTRIBUTION - STRUCTURED WORKOUT PARSING
    // =========================================================================
    group('Intensity Distribution - Structured Workout Parsing', () {
      test('parses structured workout with FTP-based intervals', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.structuredWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        // Expected: warmup (10 min conv) + 4x(3 min all-out + 2 min conv) + cooldown (10 min conv)
        // = 28 min conversational, 0 tempo, 12 min all-out
        // = 70% conv, 0% tempo, 30% all-out
        expect(dist.conversationalPct, equals(70));
        expect(dist.tempoPct, equals(0));
        expect(dist.allOutPct, equals(30));
      });

      test('parses structured workout with seconds duration', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.structuredWorkoutSeconds,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        // Warmup: 600s @ 65% → conv
        // 6x (90s @ 110% → all-out + 90s @ 50% → conv)
        // Cooldown: 600s @ 60% → conv
        // Total: 600 + 6*(90+90) + 600 = 2280s = 38 min
        // Conv: 600 + 6*90 + 600 = 1740s
        // All-out: 6*90 = 540s
        // Expected: ~76% conv, 0% tempo, ~24% all-out
        expect(dist.conversationalPct, greaterThan(70));
        expect(dist.allOutPct, greaterThan(20));
      });

      test('parses structured workout with HR zones', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.structuredWorkoutHrZones,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        // 20 min @ 70% MaxHR → conv, 20 min @ 88% MaxHR → tempo, 20 min @ 70% → conv
        // = 67% conv, 33% tempo, 0% all-out
        expect(dist.conversationalPct, equals(67));
        expect(dist.tempoPct, equals(33));
        expect(dist.allOutPct, equals(0));
      });

      test('handles malformed structure JSON gracefully', () {
        final workoutWithBadJson = Map<String, dynamic>.from(
          TrainingPeaksFixtures.structuredWorkout,
        )..['Structure'] = 'not valid json {{{';

        final result = transformer.transform(workoutWithBadJson, testUserId);

        expect(result, isNotNull);
        // Should fall back to IF-based inference since structure parsing failed
        // This workout has IF=0.95, which maps to intervals pattern
        expect(result!.intensityDistribution, isNotNull);
      });

      test('handles empty structure array', () {
        final workoutWithEmptyStructure = Map<String, dynamic>.from(
          TrainingPeaksFixtures.structuredWorkout,
        )..['Structure'] = '[]';

        final result = transformer.transform(workoutWithEmptyStructure, testUserId);

        expect(result, isNotNull);
        // Should fall back to IF-based inference
        expect(result!.intensityDistribution, isNotNull);
      });
    });

    // =========================================================================
    // INTENSITY DISTRIBUTION - IF-BASED INFERENCE
    // =========================================================================
    group('Intensity Distribution - IF-based Inference', () {
      test('maps low IF (0.65) to easy pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutWithLowIF,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternEasyRecovery));
      });

      test('maps moderate IF (0.82) to moderate pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutWithIF,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternModerate));
      });

      test('maps high IF (0.92) to tempo pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutWithHighIF,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternTempo));
      });

      test('maps very high IF (0.98) to intervals pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutWithVeryHighIF,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternIntervals));
      });

      test('maps IF > 1.0 to race pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutWithRaceIF,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternRace));
      });
    });

    // =========================================================================
    // INTENSITY DISTRIBUTION - KEYWORD INFERENCE
    // =========================================================================
    group('Intensity Distribution - Keyword Inference', () {
      test('maps "Easy Recovery Run" to easy pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.easyRunWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternEasyRecovery));
      });

      test('maps "Tempo Run" to tempo pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.tempoRunWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternTempo));
      });

      test('maps "Lactate Threshold" to tempo pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.thresholdWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternTempo));
      });

      test('maps "5K Race" to race pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.raceWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternRace));
      });

      test('maps "Track Speed Intervals" to intervals pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.intervalWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternIntervals));
      });

      test('maps "Long Endurance Run" to long run pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.longRunWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternLongRun));
      });

      test('maps "VO2max Session" to intervals pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.vo2maxWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternIntervals));
      });

      test('maps "Sweet Spot" to tempo pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.cyclingSweetSpot,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        // IF=0.88 should also map to tempo
        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternTempo));
      });

      test('maps "Endurance Ride" to long run pattern', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.cyclingEndurance,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternLongRun));
      });
    });

    // =========================================================================
    // INTENSITY DISTRIBUTION - FALLBACK BEHAVIOR
    // =========================================================================
    group('Intensity Distribution - Fallback Behavior', () {
      test('returns null when no intensity hints available', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutNoHints,
          testUserId,
        );

        expect(result, isNotNull);
        // "Run" title is too generic - should return null
        expect(result!.intensityDistribution, isNull);
      });

      test('returns null for workout with empty fields', () {
        final result = transformer.transform(
          TrainingPeaksFixtures.workoutEmptyFields,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNull);
      });

      test('prefers structured workout over IF when both available', () {
        // structuredWorkout has both Structure and IF=0.95
        // Structure should take precedence
        final result = transformer.transform(
          TrainingPeaksFixtures.structuredWorkout,
          testUserId,
        );

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        // If IF were used, it would be intervals pattern (40/30/30)
        // Structure gives us 70/0/30
        final dist = result.intensityDistribution!;
        expect(dist.conversationalPct, equals(70));
        expect(dist.tempoPct, equals(0));
        expect(dist.allOutPct, equals(30));
      });

      test('prefers IF over keywords when both available', () {
        // Create workout with IF and keywords that would map differently
        final workout = <String, dynamic>{
          'Id': 999888777,
          'WorkoutDay': '2026-02-05T00:00:00',
          'WorkoutType': 'Run',
          'Title': 'Easy Run', // Would map to easy pattern
          'TotalTimePlanned': 0.5,
          'IFPlanned': 0.92, // Should map to tempo pattern (higher priority)
          'Structure': null,
        };

        final result = transformer.transform(workout, testUserId);

        expect(result, isNotNull);
        expect(result!.intensityDistribution, isNotNull);

        // IF (0.92) → tempo pattern should win over "Easy" keyword
        final dist = result.intensityDistribution!;
        expect(dist, equals(IntensityDistributionMapper.patternTempo));
      });
    });
  });

  // ===========================================================================
  // INTENSITY DISTRIBUTION MAPPER UNIT TESTS
  // ===========================================================================
  group('IntensityDistributionMapper', () {
    group('ftpToZone', () {
      test('maps 0-75% FTP to conversational', () {
        expect(
          IntensityDistributionMapper.ftpToZone(0.50),
          equals(IntensityZone.conversational),
        );
        expect(
          IntensityDistributionMapper.ftpToZone(0.75),
          equals(IntensityZone.conversational),
        );
      });

      test('maps 76-100% FTP to tempo', () {
        expect(
          IntensityDistributionMapper.ftpToZone(0.76),
          equals(IntensityZone.tempo),
        );
        expect(
          IntensityDistributionMapper.ftpToZone(1.00),
          equals(IntensityZone.tempo),
        );
      });

      test('maps >100% FTP to all-out', () {
        expect(
          IntensityDistributionMapper.ftpToZone(1.01),
          equals(IntensityZone.allOut),
        );
        expect(
          IntensityDistributionMapper.ftpToZone(1.20),
          equals(IntensityZone.allOut),
        );
      });
    });

    group('maxHrToZone', () {
      test('maps 0-80% MaxHR to conversational', () {
        expect(
          IntensityDistributionMapper.maxHrToZone(0.70),
          equals(IntensityZone.conversational),
        );
        expect(
          IntensityDistributionMapper.maxHrToZone(0.80),
          equals(IntensityZone.conversational),
        );
      });

      test('maps 81-95% MaxHR to tempo', () {
        expect(
          IntensityDistributionMapper.maxHrToZone(0.81),
          equals(IntensityZone.tempo),
        );
        expect(
          IntensityDistributionMapper.maxHrToZone(0.95),
          equals(IntensityZone.tempo),
        );
      });

      test('maps >95% MaxHR to all-out', () {
        expect(
          IntensityDistributionMapper.maxHrToZone(0.96),
          equals(IntensityZone.allOut),
        );
      });
    });

    group('rpeToZone', () {
      test('maps RPE 1-4 to conversational', () {
        expect(
          IntensityDistributionMapper.rpeToZone(1),
          equals(IntensityZone.conversational),
        );
        expect(
          IntensityDistributionMapper.rpeToZone(4),
          equals(IntensityZone.conversational),
        );
      });

      test('maps RPE 5-7 to tempo', () {
        expect(
          IntensityDistributionMapper.rpeToZone(5),
          equals(IntensityZone.tempo),
        );
        expect(
          IntensityDistributionMapper.rpeToZone(7),
          equals(IntensityZone.tempo),
        );
      });

      test('maps RPE 8-10 to all-out', () {
        expect(
          IntensityDistributionMapper.rpeToZone(8),
          equals(IntensityZone.allOut),
        );
        expect(
          IntensityDistributionMapper.rpeToZone(10),
          equals(IntensityZone.allOut),
        );
      });
    });

    group('fromSegments', () {
      test('calculates time-weighted distribution correctly', () {
        final segments = [
          const WorkoutSegment(
            durationSeconds: 600, // 10 min
            zone: IntensityZone.conversational,
          ),
          const WorkoutSegment(
            durationSeconds: 300, // 5 min
            zone: IntensityZone.tempo,
          ),
          const WorkoutSegment(
            durationSeconds: 100, // 1.67 min
            zone: IntensityZone.allOut,
          ),
        ];

        final result = IntensityDistributionMapper.fromSegments(segments);

        expect(result, isNotNull);
        // Total: 1000s
        // Conv: 600/1000 = 60%
        // Tempo: 300/1000 = 30%
        // AllOut: 100/1000 = 10%
        expect(result!.conversationalPct, equals(60));
        expect(result.tempoPct, equals(30));
        expect(result.allOutPct, equals(10));
      });

      test('returns null for empty segments', () {
        final result = IntensityDistributionMapper.fromSegments([]);
        expect(result, isNull);
      });

      test('handles rounding to ensure sum equals 100', () {
        // Create segments that would result in non-integer percentages
        final segments = [
          const WorkoutSegment(
            durationSeconds: 333,
            zone: IntensityZone.conversational,
          ),
          const WorkoutSegment(
            durationSeconds: 333,
            zone: IntensityZone.tempo,
          ),
          const WorkoutSegment(
            durationSeconds: 334,
            zone: IntensityZone.allOut,
          ),
        ];

        final result = IntensityDistributionMapper.fromSegments(segments);

        expect(result, isNotNull);
        expect(
          result!.conversationalPct + result.tempoPct + result.allOutPct,
          equals(100),
        );
      });
    });

    group('fromWorkoutType', () {
      test('returns null for empty input', () {
        expect(IntensityDistributionMapper.fromWorkoutType(null), isNull);
        expect(IntensityDistributionMapper.fromWorkoutType(''), isNull);
      });

      test('matches easy/recovery keywords', () {
        expect(
          IntensityDistributionMapper.fromWorkoutType('Easy Run'),
          equals(IntensityDistributionMapper.patternEasyRecovery),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Recovery'),
          equals(IntensityDistributionMapper.patternEasyRecovery),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Warmup'),
          equals(IntensityDistributionMapper.patternEasyRecovery),
        );
      });

      test('matches tempo/threshold keywords', () {
        expect(
          IntensityDistributionMapper.fromWorkoutType('Tempo Run'),
          equals(IntensityDistributionMapper.patternTempo),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Threshold'),
          equals(IntensityDistributionMapper.patternTempo),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Cruise Control'),
          equals(IntensityDistributionMapper.patternTempo),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Sweet Spot'),
          equals(IntensityDistributionMapper.patternTempo),
        );
      });

      test('matches intervals/speed keywords', () {
        expect(
          IntensityDistributionMapper.fromWorkoutType('Interval Session'),
          equals(IntensityDistributionMapper.patternIntervals),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Speed Work'),
          equals(IntensityDistributionMapper.patternIntervals),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Track'),
          equals(IntensityDistributionMapper.patternIntervals),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('VO2max'),
          equals(IntensityDistributionMapper.patternIntervals),
        );
      });

      test('matches race keywords', () {
        expect(
          IntensityDistributionMapper.fromWorkoutType('Race'),
          equals(IntensityDistributionMapper.patternRace),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Competition'),
          equals(IntensityDistributionMapper.patternRace),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Time Trial'),
          equals(IntensityDistributionMapper.patternRace),
        );
      });

      test('matches long run/endurance keywords', () {
        expect(
          IntensityDistributionMapper.fromWorkoutType('Long Run'),
          equals(IntensityDistributionMapper.patternLongRun),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('Endurance'),
          equals(IntensityDistributionMapper.patternLongRun),
        );
      });

      test('returns null for unmatched keywords', () {
        expect(IntensityDistributionMapper.fromWorkoutType('Run'), isNull);
        expect(IntensityDistributionMapper.fromWorkoutType('Bike'), isNull);
        expect(IntensityDistributionMapper.fromWorkoutType('Workout'), isNull);
      });

      test('is case insensitive', () {
        expect(
          IntensityDistributionMapper.fromWorkoutType('EASY RUN'),
          equals(IntensityDistributionMapper.patternEasyRecovery),
        );
        expect(
          IntensityDistributionMapper.fromWorkoutType('tempo RUN'),
          equals(IntensityDistributionMapper.patternTempo),
        );
      });
    });

    group('fromIntensityFactor', () {
      test('returns null for null or invalid IF', () {
        expect(IntensityDistributionMapper.fromIntensityFactor(null), isNull);
        expect(IntensityDistributionMapper.fromIntensityFactor(0), isNull);
        expect(IntensityDistributionMapper.fromIntensityFactor(-0.5), isNull);
      });

      test('maps IF < 0.75 to easy pattern', () {
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.60),
          equals(IntensityDistributionMapper.patternEasyRecovery),
        );
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.74),
          equals(IntensityDistributionMapper.patternEasyRecovery),
        );
      });

      test('maps IF 0.75-0.85 to moderate pattern', () {
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.75),
          equals(IntensityDistributionMapper.patternModerate),
        );
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.84),
          equals(IntensityDistributionMapper.patternModerate),
        );
      });

      test('maps IF 0.85-0.95 to tempo pattern', () {
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.85),
          equals(IntensityDistributionMapper.patternTempo),
        );
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.94),
          equals(IntensityDistributionMapper.patternTempo),
        );
      });

      test('maps IF 0.95-1.0 to intervals pattern', () {
        expect(
          IntensityDistributionMapper.fromIntensityFactor(0.95),
          equals(IntensityDistributionMapper.patternIntervals),
        );
        expect(
          IntensityDistributionMapper.fromIntensityFactor(1.00),
          equals(IntensityDistributionMapper.patternIntervals),
        );
      });

      test('maps IF > 1.0 to race pattern', () {
        expect(
          IntensityDistributionMapper.fromIntensityFactor(1.01),
          equals(IntensityDistributionMapper.patternRace),
        );
        expect(
          IntensityDistributionMapper.fromIntensityFactor(1.10),
          equals(IntensityDistributionMapper.patternRace),
        );
      });
    });
  });
}
