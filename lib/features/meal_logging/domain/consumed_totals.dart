import 'meal_component.dart';

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

/// Totals for ONE meal log, summed from its items, where an unknown stays
/// unknown (`null ≠ 0`).
///
/// A field is null when no item carries a value for it; otherwise it is the
/// sum of the items that do. A stated zero on an item counts as known. These
/// are the values written to a `meal_logs` row's denormalised columns, so a
/// quick add whose items have no sodium saves `sodium_mg` null rather than 0
/// (Finding 26-004). Day-level displays keep using [ConsumedTotals].
class MealTotals {
  const MealTotals({
    this.calories,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
  });

  factory MealTotals.ofComponents(Iterable<MealComponent> components) {
    int? calories;
    double? carbsG;
    double? proteinG;
    double? fatG;
    double? sodiumMg;
    for (final c in components) {
      if (c.calories != null) calories = (calories ?? 0) + c.calories!;
      if (c.carbG != null) carbsG = (carbsG ?? 0) + c.carbG!;
      if (c.proteinG != null) proteinG = (proteinG ?? 0) + c.proteinG!;
      if (c.fatG != null) fatG = (fatG ?? 0) + c.fatG!;
      if (c.sodiumMg != null) sodiumMg = (sodiumMg ?? 0) + c.sodiumMg!;
    }
    return MealTotals(
      calories: calories,
      carbsG: carbsG,
      proteinG: proteinG,
      fatG: fatG,
      sodiumMg: sodiumMg,
    );
  }

  final int? calories;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final double? sodiumMg;
}
