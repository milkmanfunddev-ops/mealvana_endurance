/// Activity types that a During formula can target. Values mirror the
/// strings stored in `during_workout_templates.activity_types`.
enum DuringActivity {
  running,
  cycling,
  triathlonBike,
  triathlonRun,
  triathlonTransition;

  String get storageValue => switch (this) {
        DuringActivity.running => 'running',
        DuringActivity.cycling => 'cycling',
        DuringActivity.triathlonBike => 'triathlon_bike',
        DuringActivity.triathlonRun => 'triathlon_run',
        DuringActivity.triathlonTransition => 'triathlon_transition',
      };

  String get displayLabel => switch (this) {
        DuringActivity.running => 'Running',
        DuringActivity.cycling => 'Cycling',
        DuringActivity.triathlonBike => 'Tri — Bike',
        DuringActivity.triathlonRun => 'Tri — Run',
        DuringActivity.triathlonTransition => 'Tri — Transition',
      };
}

/// Duration brackets a During formula targets. Values mirror the strings
/// stored in `during_workout_templates.duration_brackets`.
enum DuringDuration {
  underNinety,
  ninetyTo150,
  oneFiftyTo240,
  over240;

  String get storageValue => switch (this) {
        DuringDuration.underNinety => '< 90 min',
        DuringDuration.ninetyTo150 => '90-150 min',
        DuringDuration.oneFiftyTo240 => '150-240 min',
        DuringDuration.over240 => '> 240 min',
      };

  String get displayLabel => switch (this) {
        DuringDuration.underNinety => '< 90 min',
        DuringDuration.ninetyTo150 => '90–150 min',
        DuringDuration.oneFiftyTo240 => '150–240 min',
        DuringDuration.over240 => '> 240 min',
      };
}

/// Gut-training level filter (More Filters sheet, During tab).
enum DuringGutLevel {
  low,
  moderate,
  high;

  String get storageValue => name;

  String get displayLabel => switch (this) {
        DuringGutLevel.low => 'Low',
        DuringGutLevel.moderate => 'Moderate',
        DuringGutLevel.high => 'High',
      };
}
