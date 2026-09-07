/// `MealIconKey` in `meal-icon.ts` — the 23 glyph keys persisted on
/// `meal_library.icon` / `plan_meals.icon` / `saved_meals.icon`.
///
/// Classification lives in `meal_icon_classifier.dart`; this is just the key.
enum MealIcon {
  bowl('bowl'),
  oats('oats'),
  chicken('chicken'),
  meat('meat'),
  fish('fish'),
  egg('egg'),
  salad('salad'),
  bread('bread'),
  wrap('wrap'),
  pasta('pasta'),
  soup('soup'),
  pizza('pizza'),
  drink('drink'),
  fruit('fruit'),
  nuts('nuts'),
  yogurt('yogurt'),
  potato('potato'),
  beans('beans'),
  tofu('tofu'),
  baked('baked'),
  snack('snack'),
  sweet('sweet'),
  utensils('utensils');

  const MealIcon(this.wire);

  final String wire;

  /// Returns `null` for an unknown or null key — callers fall back to
  /// [MealIconClassifier] (the "stored key wins if valid" rule).
  static MealIcon? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MealIcon.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}
