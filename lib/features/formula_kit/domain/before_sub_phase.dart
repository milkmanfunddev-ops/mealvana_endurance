/// Sub-phase filter for Before formulas — drives the "Timing" chip row on
/// the Before tab.
///
/// `pre_workout_templates` doesn't have a direct meal/snack/top-up column;
/// we derive the sub-phase from `time_window`:
///   `1.5-3 hours` → Meal,  `30-90 min` → Snack,  `< 30 min` → Top-up.
///
/// The `storageValue` strings (`full_meal`, `snack`, `top_up`) are kept
/// stable so analytics payloads don't drift across the table migration.
enum BeforeSubPhase {
  meal,
  snack,
  topUp;

  /// Logical bucket id used in analytics and filter state. Not a column
  /// value — see `fromTimeWindow` for how the bucket is derived.
  String get storageValue => switch (this) {
    BeforeSubPhase.meal => 'full_meal',
    BeforeSubPhase.snack => 'snack',
    BeforeSubPhase.topUp => 'top_up',
  };

  String get displayLabel => switch (this) {
    BeforeSubPhase.meal => 'Meal',
    BeforeSubPhase.snack => 'Snack',
    BeforeSubPhase.topUp => 'Top-up',
  };

  /// Sub-label shown under the chip in the design ("Light, easy", etc.).
  String get subDisplayLabel => switch (this) {
    BeforeSubPhase.meal => 'Full meal',
    BeforeSubPhase.snack => 'Light snack',
    BeforeSubPhase.topUp => 'Quick top-up',
  };

  static BeforeSubPhase? fromStorageValue(String? value) {
    return switch (value) {
      'full_meal' => BeforeSubPhase.meal,
      'snack' => BeforeSubPhase.snack,
      'top_up' => BeforeSubPhase.topUp,
      _ => null,
    };
  }

  /// Derive the sub-phase from the live `pre_workout_templates.time_window`
  /// string. Unknown windows return `null` so the row is shown in the "All"
  /// view but excluded from any sub-phase filter.
  static BeforeSubPhase? fromTimeWindow(String? timeWindow) {
    return switch (timeWindow) {
      '1.5-3 hours' => BeforeSubPhase.meal,
      '30-90 min' => BeforeSubPhase.snack,
      '< 30 min' => BeforeSubPhase.topUp,
      _ => null,
    };
  }
}

/// Digestion-speed filter for the More Filters sheet on the Before tab.
/// Values mirror `pre_workout_templates.digestion_speed` after lowercasing.
///
/// NOTE: the `pre_workout_templates.digestion_speed` CHECK constraint only
/// permits `'Fast'` and `'Medium'` — there is no `'Slow'` pre-workout formula
/// in the catalog. A `slow` value here would render a filter chip that always
/// returns an empty list, so it is intentionally omitted.
enum FormulaDigestionSpeed {
  fast,
  medium;

  String get storageValue => name;

  String get displayLabel => switch (this) {
    FormulaDigestionSpeed.fast => 'Fast',
    FormulaDigestionSpeed.medium => 'Medium',
  };
}
