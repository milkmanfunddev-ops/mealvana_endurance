/// Aggregated nutritional totals for a set of [MealLog] entries.
///
/// Returned by [MealLoggingService.consumedTotalsForDate] and used by the
/// Daily Macros tab to render the consumed-vs-target progress bars.
///
/// All macro fields default to zero — callers can safely add without null
/// checks.
class ConsumedTotals {
  const ConsumedTotals({
    this.calories = 0,
    this.carbsG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.sodiumMg = 0,
  });

  /// Summed calories for the period.
  final int calories;

  /// Summed carbohydrates in grams.
  final double carbsG;

  /// Summed protein in grams.
  final double proteinG;

  /// Summed fat in grams.
  final double fatG;

  /// Summed sodium in milligrams.
  final double sodiumMg;

  /// Combine two [ConsumedTotals] by summing each field.
  ///
  /// Enables concise fold patterns:
  /// ```dart
  /// final totals = logs.fold(
  ///   const ConsumedTotals(),
  ///   (acc, log) => acc + log.totals,
  /// );
  /// ```
  ConsumedTotals operator +(ConsumedTotals other) {
    return ConsumedTotals(
      calories: calories + other.calories,
      carbsG: carbsG + other.carbsG,
      proteinG: proteinG + other.proteinG,
      fatG: fatG + other.fatG,
      sodiumMg: sodiumMg + other.sodiumMg,
    );
  }

  /// Aggregate a collection of [ConsumedTotals] into one.
  ///
  /// Returns [ConsumedTotals.zero] when [items] is empty.
  static ConsumedTotals fold(Iterable<ConsumedTotals> items) {
    return items.fold(const ConsumedTotals(), (acc, t) => acc + t);
  }

  /// All-zeros sentinel (same as the default constructor; provided for
  /// explicit intent at call sites).
  static const ConsumedTotals zero = ConsumedTotals();

  /// True when every field is zero (i.e. nothing was consumed).
  bool get isZero =>
      calories == 0 &&
      carbsG == 0 &&
      proteinG == 0 &&
      fatG == 0 &&
      sodiumMg == 0;

  @override
  String toString() =>
      'ConsumedTotals(calories: $calories, carbs: ${carbsG}g, '
      'protein: ${proteinG}g, fat: ${fatG}g, sodium: ${sodiumMg}mg)';
}
