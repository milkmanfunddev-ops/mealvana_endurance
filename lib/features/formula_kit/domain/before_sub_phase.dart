/// Sub-phase filter for Before formulas — drives the "Timing" chip row on
/// the Before tab. Values mirror the existing `templates.meal_type` strings
/// (`full_meal`, `snack`, `top_up`) so we can filter without remapping.
enum BeforeSubPhase {
  meal,
  snack,
  topUp;

  /// Value as it appears in `templates.meal_type` (and in analytics).
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
}

/// Digestion-speed filter for the More Filters sheet on the Before tab.
/// Values mirror `templates.digestion_speed`.
enum FormulaDigestionSpeed {
  fast,
  medium,
  slow;

  String get storageValue => name;

  String get displayLabel => switch (this) {
        FormulaDigestionSpeed.fast => 'Fast',
        FormulaDigestionSpeed.medium => 'Medium',
        FormulaDigestionSpeed.slow => 'Slow',
      };
}
