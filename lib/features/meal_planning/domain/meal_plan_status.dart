/// `MealPlan.status` in `contracts.ts`.
enum MealPlanStatus {
  draft('draft'),
  confirmed('confirmed'),
  archived('archived');

  const MealPlanStatus(this.wire);

  final String wire;

  static MealPlanStatus? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MealPlanStatus.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static MealPlanStatus requireWire(String? value) =>
      fromWire(value) ??
      (throw FormatException('Unknown MealPlanStatus "$value"'));
}
