/// How a [MealLog] entry was originally created.
///
/// Wire values match the `meal_logs.source` CHECK constraint in the database
/// (`'photo'|'manual'|'describe'|'saved'|'recipe'|'jade_baseline'`).
///
/// Forward-compat: [fromWireValue] returns `null` for unknown/null values so
/// an older binary reading a value written by a newer client skips the row
/// instead of crashing — mirrors [MealSlot.fromWireValue].
enum MealLogSource {
  /// Logged via the camera-scan / photo-analysis flow.
  photo('photo'),

  /// Typed in manually by the user (name + macros).
  manual('manual'),

  /// Described to the Mealvana AI AI in natural language.
  describe('describe'),

  /// Copied from a saved meal in the user's favorites.
  saved('saved'),

  /// Scaled from a recipe in the curated recipe catalog.
  recipe('recipe'),

  /// Prepopulated by Mealvana AI as part of a baseline daily plan.
  aiCoachBaseline('jade_baseline');

  const MealLogSource(this.wireValue);

  /// String stored in Drift + Supabase.
  final String wireValue;

  /// Parse a wire value string.
  ///
  /// Returns `null` for unknown or null values (forward-compat).
  static MealLogSource? fromWireValue(String? value) {
    if (value == null) return null;
    for (final source in MealLogSource.values) {
      if (source.wireValue == value) return source;
    }
    return null;
  }
}
