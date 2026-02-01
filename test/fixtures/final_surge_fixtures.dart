/// Final Surge API Test Fixtures
///
/// Real workout data structure captured from Final Surge API
/// Used to validate transformations and edge cases.
///
/// Key discoveries from API testing:
/// - WorkoutTypeName includes: "Run", "Bike", "Swim", "Walk", "Rest Day", "Recovery/Rehab"
/// - Pace info is in WorkoutDescription as "@ 9:12 - 10:01" format, NOT in PlannedPace
/// - PlannedTime is in SECONDS when present
/// - WorkoutKey is the unique ID (UUID format)
/// - WorkoutIcon: 1=Run, 2=Bike, 3=Swim, 6=Rest Day, 7=Recovery, 11=Walk
library;

/// Test fixtures for Final Surge API responses
class FinalSurgeFixtures {
  // ===========================================================================
  // RUNNING WORKOUTS
  // ===========================================================================

  /// Running workout with all fields populated (based on real API response)
  static const Map<String, dynamic> runningWorkoutComplete = {
    'WorkoutKey': '79f28709-f623-4cb5-b99a-4c3161e6d20f',
    'WorkoutURL':
        'https://log.finalsurge.com/WorkoutDetails?s=f71d3644-6ae5-4910-b098-a019a515520e&id=79f28709-f623-4cb5-b99a-4c3161e6d20f',
    'WorkoutDate': '2025-12-23T00:00:00',
    'WorkoutTime': null,
    'WorkoutCode': null,
    'WorkoutTitle': 'Marathon Tempo',
    'WorkoutDescription': '@ 8:00\n\nEasy warmup, then marathon pace',
    'WorkoutTypeName': 'Run',
    'WorkoutSubTypeName': 'Tempo',
    'WorkoutCompleted': false,
    'WorkoutRace': false,
    'WorkoutIcon': 1,
    'PlannedTime': 4800, // 80 minutes in SECONDS
    'PlannedDistance': 10.0,
    'PlannedDistanceType': 'mi',
    'PlannedPace': null, // Note: Pace often comes from WorkoutDescription instead
    'PlannedPaceType': null,
    'ActualTime': null,
    'ActualDistanceMeters': null,
    'HasStructuredWorkout': false,
  };

  /// Running workout with pace RANGE in description
  static const Map<String, dynamic> runningWorkoutPaceRange = {
    'WorkoutKey': 'e888d59a-d496-4b58-a569-a1294c0a831e',
    'WorkoutURL':
        'https://log.finalsurge.com/WorkoutDetails?s=test&id=e888d59a-d496-4b58-a569-a1294c0a831e',
    'WorkoutDate': '2025-12-24T00:00:00',
    'WorkoutTitle': 'Easy Recovery',
    'WorkoutDescription': '@ 9:12 - 10:01\n\nNice and easy', // RANGE format
    'WorkoutTypeName': 'Run',
    'WorkoutSubTypeName': null,
    'WorkoutCompleted': false,
    'WorkoutIcon': 1,
    'PlannedTime': 2700, // 45 minutes in SECONDS
    'PlannedDistance': 5.0,
    'PlannedDistanceType': 'mi',
    'PlannedPace': null,
    'PlannedPaceType': null,
  };

  /// Running workout with pace in description - alternate format "9:12-10:01"
  static const Map<String, dynamic> runningWorkoutPaceRangeNoSpace = {
    'WorkoutKey': 'alternate-pace-format',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=alternate',
    'WorkoutDate': '2025-12-25T00:00:00',
    'WorkoutTitle': 'Moderate Run',
    'WorkoutDescription': '@ 8:30-9:30', // No spaces around dash
    'WorkoutTypeName': 'Run',
    'WorkoutIcon': 1,
    'PlannedTime': 3600,
    'PlannedDistance': 6.0,
    'PlannedDistanceType': 'mi',
  };

  /// Running workout with distance and time but NO pace in description
  /// Tests the calculated pace feature: pace = duration / distance
  /// 5400 seconds (90 min) / 12 miles = 7.5 min/mi pace
  static const Map<String, dynamic> runningWorkoutCalculatedPace = {
    'WorkoutKey': 'calculated-pace-workout',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=calculated',
    'WorkoutDate': '2025-12-26T00:00:00',
    'WorkoutTitle': 'Long Run',
    'WorkoutDescription': 'Easy effort, no specific pace target', // NO pace info
    'WorkoutTypeName': 'Run',
    'WorkoutSubTypeName': 'Long Run',
    'WorkoutCompleted': false,
    'WorkoutIcon': 1,
    'PlannedTime': 5400, // 90 minutes in SECONDS
    'PlannedDistance': 12.0,
    'PlannedDistanceType': 'mi',
    'PlannedPace': null, // Final Surge often doesn't populate this
    'PlannedPaceType': null,
  };

  // ===========================================================================
  // WALK WORKOUTS - should map to running/easy
  // ===========================================================================

  /// Walk workout - should map to ActivityType.running with IntensityLevel.easy
  static const Map<String, dynamic> walkWorkout = {
    'WorkoutKey': 'walk-12347',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=walk-12347',
    'WorkoutDate': '2025-12-26T00:00:00',
    'WorkoutTitle': 'Active Recovery Walk',
    'WorkoutDescription': 'Nice easy walk for recovery',
    'WorkoutTypeName': 'Walk',
    'WorkoutSubTypeName': null,
    'WorkoutCompleted': false,
    'WorkoutIcon': 11,
    'PlannedTime': 2400, // 40 minutes
    'PlannedDistance': 2.0,
    'PlannedDistanceType': 'mi',
    'PlannedPace': null,
  };

  // ===========================================================================
  // SWIMMING WORKOUTS
  // ===========================================================================

  /// Swimming workout with meters
  static const Map<String, dynamic> swimmingWorkout = {
    'WorkoutKey': 'swim-12348',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=swim-12348',
    'WorkoutDate': '2025-12-27T00:00:00',
    'WorkoutTitle': 'Pool Intervals',
    'WorkoutDescription': '4x500m with 30s rest',
    'WorkoutTypeName': 'Swim',
    'WorkoutSubTypeName': 'Intervals',
    'WorkoutCompleted': false,
    'WorkoutIcon': 3,
    'PlannedTime': 2400, // 40 minutes
    'PlannedDistance': 2000.0,
    'PlannedDistanceType': 'm', // meters
    'PlannedPace': null,
  };

  /// Swimming workout with yards
  static const Map<String, dynamic> swimmingWorkoutYards = {
    'WorkoutKey': 'swim-yards',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=swim-yards',
    'WorkoutDate': '2025-12-28T00:00:00',
    'WorkoutTitle': 'Easy Swim',
    'WorkoutDescription': null,
    'WorkoutTypeName': 'Swim',
    'WorkoutIcon': 3,
    'PlannedTime': 1800, // 30 minutes
    'PlannedDistance': 1650.0,
    'PlannedDistanceType': 'yd', // yards
  };

  // ===========================================================================
  // CYCLING WORKOUTS
  // ===========================================================================

  /// Cycling workout
  static const Map<String, dynamic> cyclingWorkout = {
    'WorkoutKey': 'bike-12349',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=bike-12349',
    'WorkoutDate': '2025-12-29T00:00:00',
    'WorkoutTitle': 'Endurance Ride',
    'WorkoutDescription': 'Zone 2 endurance',
    'WorkoutTypeName': 'Bike',
    'WorkoutSubTypeName': 'Endurance',
    'WorkoutCompleted': false,
    'WorkoutIcon': 2,
    'PlannedTime': 5400, // 90 minutes
    'PlannedDistance': 30.0,
    'PlannedDistanceType': 'mi',
    'PlannedPace': null,
  };

  /// Cycling workout with km
  static const Map<String, dynamic> cyclingWorkoutKm = {
    'WorkoutKey': 'bike-km',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=bike-km',
    'WorkoutDate': '2025-12-30T00:00:00',
    'WorkoutTitle': 'Metric Ride',
    'WorkoutDescription': null,
    'WorkoutTypeName': 'Bike',
    'WorkoutIcon': 2,
    'PlannedTime': 3600, // 60 minutes
    'PlannedDistance': 40.0,
    'PlannedDistanceType': 'km',
  };

  // ===========================================================================
  // STRUCTURED WORKOUTS
  // ===========================================================================

  /// Running workout with HasStructuredWorkout=true and StructuredWorkoutURLs
  static const Map<String, dynamic> structuredWorkout = {
    'WorkoutKey': 'structured-workout-001',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=structured-001',
    'WorkoutDate': '2026-02-01T00:00:00',
    'WorkoutTitle': 'Interval Session',
    'WorkoutDescription': 'Warmup, 4x1000m, Cooldown',
    'WorkoutTypeName': 'Run',
    'WorkoutSubTypeName': 'Intervals',
    'WorkoutCompleted': false,
    'WorkoutRace': false,
    'WorkoutIcon': 1,
    'PlannedTime': 3600, // 60 minutes
    'PlannedDistance': 8.0,
    'PlannedDistanceType': 'mi',
    'HasStructuredWorkout': true,
    'StructuredWorkoutURLs': {
      'json_fs_v1': 'https://log.finalsurge.com/API/v1/StructuredWorkout/structured-workout-001?format=json_fs_v1',
    },
  };

  /// Structured workout response body (json_fs_v1 format)
  /// 10 min warmup @ 65% FTP, 4x(4 min @ 105% FTP + 2 min @ 55% FTP), 10 min cooldown @ 60% FTP
  static const Map<String, dynamic> structuredWorkoutResponse = {
    'Steps': [
      // Warmup: 10 min at easy effort
      {
        'Type': 'WorkoutStep',
        'Duration': {'Unit': 'Minute', 'Value': 10},
        'IntensityTarget': {'Unit': 'PercentFTP', 'Value': 0.65},
      },
      // 4 x (4 min hard + 2 min recovery)
      {
        'Type': 'WorkoutRepeatStep',
        'RepeatCount': 4,
        'Steps': [
          {
            'Type': 'WorkoutStep',
            'Duration': {'Unit': 'Minute', 'Value': 4},
            'IntensityTarget': {'Unit': 'PercentFTP', 'Value': 1.05},
          },
          {
            'Type': 'WorkoutStep',
            'Duration': {'Unit': 'Minute', 'Value': 2},
            'IntensityTarget': {'Unit': 'PercentFTP', 'Value': 0.55},
          },
        ],
      },
      // Cooldown: 10 min at easy effort
      {
        'Type': 'WorkoutStep',
        'Duration': {'Unit': 'Minute', 'Value': 10},
        'IntensityTarget': {'Unit': 'PercentFTP', 'Value': 0.60},
      },
    ],
  };

  /// Expected distribution from structuredWorkoutResponse:
  /// - Warmup: 10 min @ 65% FTP → conversational
  /// - Intervals: 4 x (4 min @ 105% + 2 min @ 55%) = 16 min all-out + 8 min conversational
  /// - Cooldown: 10 min @ 60% FTP → conversational
  /// Total: 44 min
  /// - Conversational: 10 + 8 + 10 = 28 min → 64%
  /// - Tempo: 0 min → 0%
  /// - All-Out: 16 min → 36%
  static const Map<String, int> expectedStructuredDistribution = {
    'conversational': 64,
    'tempo': 0,
    'allOut': 36,
  };

  /// Structured workout with ramp step
  static const Map<String, dynamic> structuredWorkoutWithRamp = {
    'Steps': [
      {
        'Type': 'WorkoutRampStep',
        'Duration': {'Unit': 'Minute', 'Value': 10},
        'IntensityTargetStart': {'Unit': 'PercentFTP', 'Value': 0.50},
        'IntensityTargetEnd': {'Unit': 'PercentFTP', 'Value': 0.75},
      },
      {
        'Type': 'WorkoutStep',
        'Duration': {'Unit': 'Minute', 'Value': 20},
        'IntensityTarget': {'Unit': 'PercentFTP', 'Value': 0.88},
      },
      {
        'Type': 'WorkoutRampStep',
        'Duration': {'Unit': 'Minute', 'Value': 10},
        'IntensityTargetStart': {'Unit': 'PercentFTP', 'Value': 0.75},
        'IntensityTargetEnd': {'Unit': 'PercentFTP', 'Value': 0.50},
      },
    ],
  };

  // ===========================================================================
  // WORKOUTS WITH MISSING DATA - test defaults
  // ===========================================================================

  /// Workout with MISSING distance/time/pace - tests sensible defaults
  static const Map<String, dynamic> workoutMissingData = {
    'WorkoutKey': 'missing-12350',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=missing-12350',
    'WorkoutDate': '2025-12-31T00:00:00',
    'WorkoutTitle': 'Run TBD',
    'WorkoutDescription': null,
    'WorkoutTypeName': 'Run',
    'WorkoutIcon': 1,
    // Missing: PlannedTime, PlannedDistance, PlannedDistanceType
    'PlannedTime': null,
    'PlannedDistance': null,
    'PlannedDistanceType': null,
  };

  /// Workout with null/empty fields
  static const Map<String, dynamic> workoutNullFields = {
    'WorkoutKey': 'null-12351',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=null-12351',
    'WorkoutDate': '2026-01-01T00:00:00',
    'WorkoutTitle': null, // null title
    'WorkoutDescription': '', // empty description
    'WorkoutTypeName': 'Run',
    'WorkoutIcon': 1,
    'PlannedTime': null,
    'PlannedDistance': null,
    'PlannedDistanceType': null,
  };

  /// Cycling workout missing data - tests cycling defaults
  static const Map<String, dynamic> cyclingMissingData = {
    'WorkoutKey': 'bike-missing',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=bike-missing',
    'WorkoutDate': '2026-01-02T00:00:00',
    'WorkoutTitle': 'Bike TBD',
    'WorkoutTypeName': 'Bike',
    'WorkoutIcon': 2,
    'PlannedTime': null,
    'PlannedDistance': null,
    'PlannedDistanceType': null,
  };

  /// Swimming workout missing data - tests swimming defaults
  static const Map<String, dynamic> swimmingMissingData = {
    'WorkoutKey': 'swim-missing',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=swim-missing',
    'WorkoutDate': '2026-01-03T00:00:00',
    'WorkoutTitle': 'Swim TBD',
    'WorkoutTypeName': 'Swim',
    'WorkoutIcon': 3,
    'PlannedTime': null,
    'PlannedDistance': null,
    'PlannedDistanceType': null,
  };

  // ===========================================================================
  // NON-SUPPORTED WORKOUT TYPES - should be filtered out
  // ===========================================================================

  /// Rest Day - should be filtered out
  static const Map<String, dynamic> restDayWorkout = {
    'WorkoutKey': 'rest-day',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=rest-day',
    'WorkoutDate': '2026-01-04T00:00:00',
    'WorkoutTitle': null,
    'WorkoutDescription': null,
    'WorkoutTypeName': 'Rest Day',
    'WorkoutIcon': 6,
    'PlannedTime': null,
    'PlannedDistance': null,
  };

  /// Recovery/Rehab - should be filtered out
  static const Map<String, dynamic> recoveryWorkout = {
    'WorkoutKey': 'recovery',
    'WorkoutURL': 'https://log.finalsurge.com/WorkoutDetails?s=test&id=recovery',
    'WorkoutDate': '2026-01-05T00:00:00',
    'WorkoutTitle': 'Foam Rolling',
    'WorkoutDescription': null,
    'WorkoutTypeName': 'Recovery/Rehab',
    'WorkoutIcon': 7,
    'PlannedTime': null,
    'PlannedDistance': null,
  };

  // ===========================================================================
  // FULL API RESPONSE FIXTURE
  // ===========================================================================

  /// Full API response structure for testing sync service
  static const Map<String, dynamic> fullApiResponse = {
    'Success': true,
    'ErrorNumber': null,
    'ErrorMessage': null,
    'Workouts': [
      runningWorkoutComplete,
      runningWorkoutPaceRange,
      walkWorkout,
      swimmingWorkout,
      cyclingWorkout,
      restDayWorkout,
      recoveryWorkout,
    ],
  };

  /// API error response
  static const Map<String, dynamic> apiErrorResponse = {
    'Success': false,
    'ErrorNumber': 401,
    'ErrorMessage': 'Invalid or expired access token',
    'Workouts': null,
  };

  // ===========================================================================
  // EXPECTED TRANSFORMATION RESULTS
  // ===========================================================================

  /// Expected values after transforming runningWorkoutComplete
  static const Map<String, dynamic> expectedRunningWorkoutTransformed = {
    'activityType': 'running',
    'durationMinutes': 80, // 4800 seconds / 60
    'distanceMiles': 10.0,
    'paceTargetMinutesPerMile': 8.0, // from "@ 8:00"
    'paceMinMinutesPerMile': null,
    'paceMaxMinutesPerMile': null,
    'workoutSubtype': 'Tempo',
  };

  /// Expected values after transforming runningWorkoutPaceRange
  static const Map<String, dynamic> expectedPaceRangeTransformed = {
    'activityType': 'running',
    'durationMinutes': 45, // 2700 seconds / 60
    'distanceMiles': 5.0,
    'paceTargetMinutesPerMile': 9.6083, // midpoint of 9:12 (9.2) and 10:01 (10.0167)
    'paceMinMinutesPerMile': 9.2, // 9:12
    'paceMaxMinutesPerMile': 10.0167, // 10:01
  };

  /// Expected values after transforming walkWorkout
  static const Map<String, dynamic> expectedWalkTransformed = {
    'activityType': 'running', // Walk maps to running
    'intensityLevel': 'easy', // Walk is always easy
    'workoutSubtype': 'Walk', // Store original type
    'durationMinutes': 40,
    'distanceMiles': 2.0,
  };

  /// Expected values for running defaults (when data missing)
  static const Map<String, dynamic> expectedRunningDefaults = {
    'distanceMiles': 3.0,
    'durationMinutes': 30,
    'paceTargetMinutesPerMile': 10.0,
  };

  /// Expected values for cycling defaults (when data missing)
  static const Map<String, dynamic> expectedCyclingDefaults = {
    'distanceMiles': 10.0,
    'durationMinutes': 45,
  };

  /// Expected values for swimming defaults (when data missing)
  static const Map<String, dynamic> expectedSwimmingDefaults = {
    'distanceMeters': 1000.0,
    'durationMinutes': 30,
  };
}

/// Supported workout types that we import into Mealvana
const List<String> supportedWorkoutTypes = ['Run', 'Walk', 'Bike', 'Swim'];

/// Workout types that should be filtered out
const List<String> unsupportedWorkoutTypes = [
  'Rest Day',
  'Recovery/Rehab',
  'Strength',
  'Cross Training',
  'Other',
];

/// WorkoutIcon to type mapping (from API documentation)
const Map<int, String> workoutIconToType = {
  1: 'Run',
  2: 'Bike',
  3: 'Swim',
  6: 'Rest Day',
  7: 'Recovery/Rehab',
  11: 'Walk',
};
