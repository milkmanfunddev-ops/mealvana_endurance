/// Where a meal reference points (`MealRef.source`, `PlanMeal.source`).
enum MealSource {
  /// `meal_library` row — id like `D-048`.
  library('library'),

  /// `saved_meals` row — id is the uuid.
  saved('saved');

  const MealSource(this.wire);

  final String wire;

  static MealSource? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MealSource.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static MealSource requireWire(String? value) =>
      fromWire(value) ?? (throw FormatException('Unknown MealSource "$value"'));
}

/// Where a day-planner slot points (`DaySlotRef.source`) — a plan meal, a
/// saved meal, or a library meal.
enum DaySlotSource {
  plan('plan'),
  saved('saved'),
  library('library');

  const DaySlotSource(this.wire);

  final String wire;

  static DaySlotSource? fromWire(String? value) {
    if (value == null) return null;
    for (final v in DaySlotSource.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static DaySlotSource requireWire(String? value) =>
      fromWire(value) ??
      (throw FormatException('Unknown DaySlotSource "$value"'));
}

/// `MealRef.kind` — an assembly is 1–6 plain components with no method
/// ("chicken, rice & broccoli"); a recipe has steps.
enum MealKind {
  assembly('assembly'),
  recipe('recipe');

  const MealKind(this.wire);

  final String wire;

  static MealKind? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MealKind.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}
