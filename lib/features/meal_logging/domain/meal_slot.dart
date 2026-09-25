/// Identifies which meal period a log entry belongs to.
///
/// Wire values match the `meal_logs.slot` CHECK constraint in the database.
/// Every read and write path uses [wireValue] to avoid depending on enum
/// positional order.
enum MealSlot {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack'),

  // Loading-day slot taxonomy (carb-loading@v1, CL-5): three additional
  // periods so a log can be tagged to any of the six ruled slots. On
  // loading-day surfaces the legacy [snack] folds into Afternoon Snack at
  // display time — no data migration.
  morningSnack('morning_snack'),
  afternoonSnack('afternoon_snack'),
  eveningSnack('evening_snack');

  const MealSlot(this.wireValue);

  /// String stored in Drift + Supabase.
  final String wireValue;

  /// Human-readable label suitable for display in the UI layer.
  ///
  /// Intentionally placed here (not in the UI layer) because repositories and
  /// services also format log entries for logging/analytics, but the **actual
  /// display strings** shown to users must come from ContentService in the
  /// presentation layer. This label is a fallback for non-UI contexts only.
  String get label {
    switch (this) {
      case MealSlot.breakfast:
        return 'Breakfast';
      case MealSlot.lunch:
        return 'Lunch';
      case MealSlot.dinner:
        return 'Dinner';
      case MealSlot.snack:
        return 'Snack';
      case MealSlot.morningSnack:
        return 'Morning Snack';
      case MealSlot.afternoonSnack:
        return 'Afternoon Snack';
      case MealSlot.eveningSnack:
        return 'Evening Snack';
    }
  }

  /// Parse a wire value string.
  ///
  /// Returns `null` for unknown or null values (forward-compat — an older
  /// binary reading a value from a newer server should skip, not crash).
  static MealSlot? fromWireValue(String? value) {
    if (value == null) return null;
    for (final slot in MealSlot.values) {
      if (slot.wireValue == value) return slot;
    }
    return null;
  }
}
