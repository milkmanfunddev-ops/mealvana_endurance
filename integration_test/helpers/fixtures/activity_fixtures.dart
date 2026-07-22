/// Test activity fixtures for integration testing
/// Provides a variety of running and cycling activities
class ActivityFixtures {
  /// 5K run - short distance, fast pace
  static Map<String, dynamic> get fiveK => {
    'distance_miles': 3.1,
    'pace_minutes': 8.0,
    'pace_seconds': 0,
    'sport_type': 'running',
    'activity_type': 'race',
    'activity_date': DateTime.now()
        .add(const Duration(days: 7))
        .toIso8601String(),
  };

  /// 10K run - moderate distance
  static Map<String, dynamic> get tenK => {
    'distance_miles': 6.2,
    'pace_minutes': 8.0,
    'pace_seconds': 30,
    'sport_type': 'running',
    'activity_type': 'race',
    'activity_date': DateTime.now()
        .add(const Duration(days: 14))
        .toIso8601String(),
  };

  /// Half marathon - popular race distance
  static Map<String, dynamic> get halfMarathon => {
    'distance_miles': 13.1,
    'pace_minutes': 9.0,
    'pace_seconds': 0,
    'sport_type': 'running',
    'activity_type': 'race',
    'activity_date': DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String(),
  };

  /// Marathon - classic endurance race
  static Map<String, dynamic> get marathon => {
    'distance_miles': 26.2,
    'pace_minutes': 9.0,
    'pace_seconds': 30,
    'sport_type': 'running',
    'activity_type': 'race',
    'activity_date': DateTime.now()
        .add(const Duration(days: 60))
        .toIso8601String(),
  };

  /// Ultra marathon - 50 miles
  static Map<String, dynamic> get ultraMarathon => {
    'distance_miles': 50.0,
    'pace_minutes': 12.0,
    'pace_seconds': 0,
    'sport_type': 'running',
    'activity_type': 'race',
    'activity_date': DateTime.now()
        .add(const Duration(days: 90))
        .toIso8601String(),
  };

  /// Century ride - 100 miles cycling
  static Map<String, dynamic> get century => {
    'distance_miles': 100.0,
    'pace_minutes': null, // Cycling uses different pace metrics
    'pace_seconds': null,
    'sport_type': 'cycling',
    'activity_type': 'training',
    'activity_date': DateTime.now()
        .add(const Duration(days: 21))
        .toIso8601String(),
  };

  /// Long training run - marathon training
  static Map<String, dynamic> get longRun => {
    'distance_miles': 20.0,
    'pace_minutes': 10.0,
    'pace_seconds': 0,
    'sport_type': 'running',
    'activity_type': 'training',
    'activity_date': DateTime.now()
        .add(const Duration(days: 3))
        .toIso8601String(),
  };

  /// Easy recovery run
  static Map<String, dynamic> get easyRun => {
    'distance_miles': 5.0,
    'pace_minutes': 10.0,
    'pace_seconds': 30,
    'sport_type': 'running',
    'activity_type': 'training',
    'activity_date': DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String(),
  };

  /// Helper to get all running activities
  static List<Map<String, dynamic>> get allRunningActivities => [
    fiveK,
    tenK,
    halfMarathon,
    marathon,
    ultraMarathon,
    longRun,
    easyRun,
  ];

  /// Helper to get race activities only
  static List<Map<String, dynamic>> get raceActivities => [
    fiveK,
    tenK,
    halfMarathon,
    marathon,
    ultraMarathon,
  ];

  /// Helper to create a custom activity
  static Map<String, dynamic> custom({
    required double distanceMiles,
    int? paceMinutes,
    int? paceSeconds,
    String sportType = 'running',
    String activityType = 'training',
    DateTime? activityDate,
  }) {
    return {
      'distance_miles': distanceMiles,
      'pace_minutes': paceMinutes,
      'pace_seconds': paceSeconds,
      'sport_type': sportType,
      'activity_type': activityType,
      'activity_date':
          (activityDate ?? DateTime.now().add(const Duration(days: 7)))
              .toIso8601String(),
    };
  }

  /// Helper to calculate total duration from pace and distance
  static Duration calculateDuration(
    double distanceMiles,
    int paceMinutes,
    int paceSeconds,
  ) {
    final paceInMinutes = paceMinutes + (paceSeconds / 60.0);
    final totalMinutes = distanceMiles * paceInMinutes;
    return Duration(minutes: totalMinutes.round());
  }
}
