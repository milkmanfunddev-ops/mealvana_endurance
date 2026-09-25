/// Two completed Final Surge workouts as the dev account's feed sent them on
/// 2026-09-24 (Finding 29-002; `.scratch/testing-wave/runs/29/
/// console-redacted.log` lines 15993-16068). Every key in the logged key list
/// is present; the log prints only non-null values, so the keys it skipped
/// are null here. `WorkoutDate` is naive local midnight and `WorkoutTime` is
/// the recorded start, also naive local.
library;

/// "Easy": planned 8 mi with a pace range in the description, run as
/// 3.5 mi in 33:41.
const Map<String, dynamic> fsCompletedEasy = {
  'WorkoutKey': 'd67e6590-af7e-47bb-9508-e14739db5da5',
  'WorkoutURL':
      'https://log.finalsurge.com/WorkoutDetails?s=f71d3644-6ae5-4910-b098-a019a515520e&id=d67e6590-af7e-47bb-9508-e14739db5da5',
  'WorkoutDate': '2026-09-24T00:00:00',
  'WorkoutTime': '05:32:02',
  'WorkoutCode': null,
  'WorkoutTitle': 'Easy',
  'WorkoutDescription':
      '@ 8:45 - 9:38\n\nFinish with 6 x 20 second strides',
  'WorkoutTypeName': 'Run',
  'WorkoutSubTypeName': null,
  'WorkoutCompleted': true,
  'WorkoutRace': false,
  'WorkoutIcon': 1,
  'PlannedTime': null,
  'PlannedDistance': 8.0,
  'PlannedDistanceType': 'mi',
  'PlannedPace': null,
  'PlannedPaceType': null,
  'ActualTime': 2021.254,
  'ActualDistanceMeters': 5704.1698,
  'HasStructuredWorkout': false,
  'StructuredWorkoutURLs': {
    'zwo': null,
    'mrc': null,
    'fit': null,
    'json_garmin_v1': null,
    'json_fs_v1': null,
  },
};

/// "Run": no plan at all (no title, description, planned time or distance),
/// run as 3.9 mi in 35:54.
const Map<String, dynamic> fsCompletedRun = {
  'WorkoutKey': '3de79f1a-d03f-453d-8df5-5c921936603d',
  'WorkoutURL':
      'https://log.finalsurge.com/WorkoutDetails?s=f71d3644-6ae5-4910-b098-a019a515520e&id=3de79f1a-d03f-453d-8df5-5c921936603d',
  'WorkoutDate': '2026-09-24T00:00:00',
  'WorkoutTime': '07:28:33',
  'WorkoutCode': null,
  'WorkoutTitle': null,
  'WorkoutDescription': null,
  'WorkoutTypeName': 'Run',
  'WorkoutSubTypeName': null,
  'WorkoutCompleted': true,
  'WorkoutRace': false,
  'WorkoutIcon': 1,
  'PlannedTime': null,
  'PlannedDistance': null,
  'PlannedDistanceType': null,
  'PlannedPace': null,
  'PlannedPaceType': null,
  'ActualTime': 2154.255,
  'ActualDistanceMeters': 6218.839,
  'HasStructuredWorkout': false,
  'StructuredWorkoutURLs': {
    'zwo': null,
    'mrc': null,
    'fit': null,
    'json_garmin_v1': null,
    'json_fs_v1': null,
  },
};

/// The same "Easy" workout as a later feed sends it without the completion
/// fields (the not-yet-run shape): the plan only.
Map<String, dynamic> fsEasyWithoutCompletion() => {
  ...fsCompletedEasy,
  'WorkoutCompleted': false,
  'ActualTime': null,
  'ActualDistanceMeters': null,
};
