/// `MealType` / `DaySlot` in `contracts.ts` — the same four values serve both
/// a meal's type and a day-planner slot.
enum MealType {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack');

  const MealType(this.wire);

  /// String on the wire and in Supabase.
  final String wire;

  /// Parse a wire value. Returns `null` for unknown or null values
  /// (forward-compat — callers decide whether that is fatal).
  static MealType? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MealType.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  /// Parse a wire value that must be present and valid.
  static MealType requireWire(String? value) =>
      fromWire(value) ?? (throw FormatException('Unknown MealType "$value"'));
}
