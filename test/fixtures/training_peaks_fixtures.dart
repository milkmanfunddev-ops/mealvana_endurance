/// Training Peaks API Test Fixtures
///
/// Real workout data structure captured from Training Peaks API.
/// Used to validate transformations and edge cases.
///
/// Key discoveries from API testing:
/// - Distance is ALWAYS in METERS (convert to miles: m * 0.000621371)
/// - TotalTime is in DECIMAL HOURS (convert to minutes: h * 60)
/// - Workout ID is Int64 (store as String for safety)
/// - Pace is NOT provided (calculate from distance/time)
/// - Structure field contains JSON for structured workouts
library;

import 'dart:convert';

/// Test fixtures for Training Peaks API responses
class TrainingPeaksFixtures {
  // ===========================================================================
  // STRUCTURED WORKOUT FIXTURES
  // ===========================================================================

  /// Structured workout with intervals - full Structure JSON
  /// 10 min warmup @ 60% FTP, 4x(3 min @ 105% FTP + 2 min @ 55% FTP), 10 min cooldown @ 60% FTP
  static final Map<String, dynamic> structuredWorkout = {
    'Id': 123456789,
    'WorkoutDay': '2026-01-15T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Track Intervals',
    'Description': '4x1000m with recoveries',
    'TotalTimePlanned': 0.75, // 45 minutes in decimal hours
    'DistancePlanned': 8000.0, // meters
    'TSSPlanned': 65.0,
    'IFPlanned': 0.95,
    'Structure': jsonEncode([
      // 10 min warmup at 60% FTP
      {
        'Type': 'Step',
        'Length': {'Unit': 'Minute', 'Value': 10},
        'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 0.60},
      },
      // 4 x (3 min hard + 2 min recovery)
      {
        'Type': 'Repetition',
        'RepeatCount': 4,
        'Steps': [
          {
            'Type': 'Step',
            'Length': {'Unit': 'Minute', 'Value': 3},
            'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 1.05},
          },
          {
            'Type': 'Step',
            'Length': {'Unit': 'Minute', 'Value': 2},
            'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 0.55},
          },
        ],
      },
      // 10 min cooldown at 60% FTP
      {
        'Type': 'Step',
        'Length': {'Unit': 'Minute', 'Value': 10},
        'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 0.60},
      },
    ]),
  };

  /// Expected distribution from structuredWorkout:
  /// - Warmup: 10 min @ 60% FTP → conversational
  /// - Intervals: 4 x (3 min @ 105% + 2 min @ 55%) = 12 min all-out + 8 min conversational
  /// - Cooldown: 10 min @ 60% FTP → conversational
  /// Total: 40 min
  /// - Conversational: 10 + 8 + 10 = 28 min → 70%
  /// - Tempo: 0 min → 0%
  /// - All-Out: 12 min → 30%
  static const Map<String, int> expectedStructuredDistribution = {
    'conversational': 70,
    'tempo': 0,
    'allOut': 30,
  };

  /// Structured workout with seconds as duration unit
  static final Map<String, dynamic> structuredWorkoutSeconds = {
    'Id': 123456790,
    'WorkoutDay': '2026-01-16T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Speed Work',
    'TotalTimePlanned': 0.5, // 30 minutes
    'Structure': jsonEncode([
      // 600 seconds warmup at 65% FTP
      {
        'Type': 'Step',
        'Length': {'Unit': 'Second', 'Value': 600},
        'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 0.65},
      },
      // 6 x (90 sec hard + 90 sec easy)
      {
        'Type': 'Repetition',
        'RepeatCount': 6,
        'Steps': [
          {
            'Type': 'Step',
            'Length': {'Unit': 'Second', 'Value': 90},
            'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 1.10},
          },
          {
            'Type': 'Step',
            'Length': {'Unit': 'Second', 'Value': 90},
            'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 0.50},
          },
        ],
      },
      // 600 seconds cooldown
      {
        'Type': 'Step',
        'Length': {'Unit': 'Second', 'Value': 600},
        'IntensityTarget': {'Unit': 'PercentOfFtp', 'Value': 0.60},
      },
    ]),
  };

  /// Structured workout using HR zones instead of FTP
  static final Map<String, dynamic> structuredWorkoutHrZones = {
    'Id': 123456791,
    'WorkoutDay': '2026-01-17T00:00:00',
    'WorkoutType': 'Bike',
    'Title': 'HR Zone Workout',
    'TotalTimePlanned': 1.0, // 60 minutes
    'Structure': jsonEncode([
      {
        'Type': 'Step',
        'Length': {'Unit': 'Minute', 'Value': 20},
        'IntensityTarget': {'Unit': 'PercentOfMaxHr', 'Value': 0.70},
      },
      {
        'Type': 'Step',
        'Length': {'Unit': 'Minute', 'Value': 20},
        'IntensityTarget': {'Unit': 'PercentOfMaxHr', 'Value': 0.88},
      },
      {
        'Type': 'Step',
        'Length': {'Unit': 'Minute', 'Value': 20},
        'IntensityTarget': {'Unit': 'PercentOfMaxHr', 'Value': 0.70},
      },
    ]),
  };

  /// Expected: 20 min conversational (70%) + 20 min tempo (88%) + 20 min conversational (70%)
  /// = 40 min conversational (67%), 20 min tempo (33%)
  static const Map<String, int> expectedHrZonesDistribution = {
    'conversational': 67,
    'tempo': 33,
    'allOut': 0,
  };

  // ===========================================================================
  // IF-BASED WORKOUT FIXTURES (no structure)
  // ===========================================================================

  /// Workout with IF but no structure - should use IF-based heuristics
  static const Map<String, dynamic> workoutWithIF = {
    'Id': 234567890,
    'WorkoutDay': '2026-01-18T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Steady Run', // Neutral title
    'TotalTimePlanned': 1.0, // 60 minutes
    'DistancePlanned': 12000.0, // meters
    'TSSPlanned': 70.0,
    'IFPlanned': 0.82, // Should map to moderate pattern
    'Structure': null,
  };

  /// High IF workout - should map to tempo pattern
  static const Map<String, dynamic> workoutWithHighIF = {
    'Id': 234567891,
    'WorkoutDay': '2026-01-19T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Hard Effort', // Neutral-ish title
    'TotalTimePlanned': 0.75,
    'IFPlanned': 0.92, // Should map to tempo pattern
    'Structure': null,
  };

  /// Very high IF workout - should map to intervals pattern
  static const Map<String, dynamic> workoutWithVeryHighIF = {
    'Id': 234567892,
    'WorkoutDay': '2026-01-20T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Quality Session',
    'TotalTimePlanned': 0.5,
    'IFPlanned': 0.98, // Should map to intervals pattern
    'Structure': null,
  };

  /// Above threshold IF - should map to race pattern
  static const Map<String, dynamic> workoutWithRaceIF = {
    'Id': 234567893,
    'WorkoutDay': '2026-01-21T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Time Trial',
    'TotalTimePlanned': 0.33,
    'IFPlanned': 1.05, // Should map to race pattern
    'Structure': null,
  };

  /// Low IF workout - should map to easy pattern
  static const Map<String, dynamic> workoutWithLowIF = {
    'Id': 234567894,
    'WorkoutDay': '2026-01-22T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Morning Jog',
    'TotalTimePlanned': 0.75,
    'IFPlanned': 0.65, // Should map to easy pattern
    'Structure': null,
  };

  // ===========================================================================
  // KEYWORD-BASED WORKOUT FIXTURES (no structure, no IF)
  // ===========================================================================

  /// Easy recovery workout - keyword only
  static const Map<String, dynamic> easyRunWorkout = {
    'Id': 345678901,
    'WorkoutDay': '2026-01-23T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Easy Recovery Run',
    'Description': 'Nice and easy, keep heart rate low',
    'TotalTimePlanned': 0.75, // 45 minutes
    'DistancePlanned': 8000.0,
    'TSSPlanned': null,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Tempo run workout - keyword only
  static const Map<String, dynamic> tempoRunWorkout = {
    'Id': 345678902,
    'WorkoutDay': '2026-01-24T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Tempo Run',
    'Description': 'Comfortably hard effort',
    'TotalTimePlanned': 0.83, // 50 minutes
    'DistancePlanned': 10000.0,
    'TSSPlanned': null,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Threshold workout - keyword only
  static const Map<String, dynamic> thresholdWorkout = {
    'Id': 345678903,
    'WorkoutDay': '2026-01-25T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Lactate Threshold Workout',
    'TotalTimePlanned': 1.0,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Race workout - keyword only
  static const Map<String, dynamic> raceWorkout = {
    'Id': 345678904,
    'WorkoutDay': '2026-01-26T00:00:00',
    'WorkoutType': 'Run',
    'Title': '5K Race',
    'Description': 'Go for PR!',
    'TotalTimePlanned': 0.33, // 20 minutes
    'DistancePlanned': 5000.0,
    'TSSPlanned': null,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Interval/speed workout - keyword only
  static const Map<String, dynamic> intervalWorkout = {
    'Id': 345678905,
    'WorkoutDay': '2026-01-27T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Track Speed Intervals',
    'Description': '8x400m with 200m jog recovery',
    'TotalTimePlanned': 0.75,
    'DistancePlanned': 6000.0,
    'TSSPlanned': null,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Long run workout - keyword only
  static const Map<String, dynamic> longRunWorkout = {
    'Id': 345678906,
    'WorkoutDay': '2026-01-28T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Long Endurance Run',
    'Description': 'Build aerobic base',
    'TotalTimePlanned': 2.0, // 120 minutes
    'DistancePlanned': 24000.0,
    'TSSPlanned': null,
    'IFPlanned': null,
    'Structure': null,
  };

  /// VO2max workout - keyword only
  static const Map<String, dynamic> vo2maxWorkout = {
    'Id': 345678907,
    'WorkoutDay': '2026-01-29T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'VO2max Session',
    'Description': '5x3min at VO2max pace',
    'TotalTimePlanned': 0.83,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Walk workout - should map to easy pattern
  static const Map<String, dynamic> walkWorkout = {
    'Id': 345678908,
    'WorkoutDay': '2026-01-30T00:00:00',
    'WorkoutType': 'Walk',
    'Title': 'Active Recovery Walk',
    'TotalTimePlanned': 0.5,
    'IFPlanned': null,
    'Structure': null,
  };

  // ===========================================================================
  // NO DATA FIXTURES
  // ===========================================================================

  /// Workout with no intensity hints at all
  static const Map<String, dynamic> workoutNoHints = {
    'Id': 456789012,
    'WorkoutDay': '2026-01-31T00:00:00',
    'WorkoutType': 'Run',
    'Title': 'Run', // Generic title
    'TotalTimePlanned': 1.0,
    'DistancePlanned': 10000.0,
    'TSSPlanned': null,
    'IFPlanned': null,
    'Structure': null,
  };

  /// Workout with empty/null fields
  static const Map<String, dynamic> workoutEmptyFields = {
    'Id': 456789013,
    'WorkoutDay': '2026-02-01T00:00:00',
    'WorkoutType': 'Run',
    'Title': null,
    'Description': '',
    'TotalTimePlanned': null,
    'IFPlanned': null,
    'Structure': '',
  };

  // ===========================================================================
  // CYCLING FIXTURES
  // ===========================================================================

  /// Cycling sweet spot workout
  static const Map<String, dynamic> cyclingSweetSpot = {
    'Id': 567890123,
    'WorkoutDay': '2026-02-02T00:00:00',
    'WorkoutType': 'Bike',
    'Title': 'Sweet Spot Intervals',
    'TotalTimePlanned': 1.5,
    'IFPlanned': 0.88,
    'Structure': null,
  };

  /// Cycling endurance ride
  static const Map<String, dynamic> cyclingEndurance = {
    'Id': 567890124,
    'WorkoutDay': '2026-02-03T00:00:00',
    'WorkoutType': 'Bike',
    'Title': 'Endurance Ride',
    'TotalTimePlanned': 2.5,
    'IFPlanned': null,
    'Structure': null,
  };

  // ===========================================================================
  // EXPECTED HEURISTIC DISTRIBUTIONS
  // ===========================================================================

  /// Easy/Recovery pattern: 95/5/0
  static const Map<String, int> expectedEasyPattern = {
    'conversational': 95,
    'tempo': 5,
    'allOut': 0,
  };

  /// Long Run pattern: 80/15/5
  static const Map<String, int> expectedLongRunPattern = {
    'conversational': 80,
    'tempo': 15,
    'allOut': 5,
  };

  /// Moderate pattern: 70/25/5
  static const Map<String, int> expectedModeratePattern = {
    'conversational': 70,
    'tempo': 25,
    'allOut': 5,
  };

  /// Tempo pattern: 30/60/10
  static const Map<String, int> expectedTempoPattern = {
    'conversational': 30,
    'tempo': 60,
    'allOut': 10,
  };

  /// Intervals pattern: 40/30/30
  static const Map<String, int> expectedIntervalsPattern = {
    'conversational': 40,
    'tempo': 30,
    'allOut': 30,
  };

  /// Race pattern: 10/30/60
  static const Map<String, int> expectedRacePattern = {
    'conversational': 10,
    'tempo': 30,
    'allOut': 60,
  };
}
