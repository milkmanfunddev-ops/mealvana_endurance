import '../../nutrition_plan/domain/food.dart';

/// Canonical component shape + macro math for personal formulas.
///
/// `PersonalFormula.components` is stored opaque (a JSON array of
/// `Map<String, dynamic>`). This helper finalizes that shape (deferred "to
/// PR 4" in the table comment) and centralizes the totals computation so the
/// editor, detail screen, and edge function all agree on the contract.
///
/// Each component carries the food's **per-serving** macros snapshotted at the
/// time it was added, plus a `quantity` multiplier. Snapshotting means the
/// edge function can render a pinned formula with zero extra food lookups and
/// the UI can recompute totals locally without re-fetching foods.
///
/// Component keys:
/// ```jsonc
/// {
///   "food_id": "uuid",            // template_foods.id or user_foods.id
///   "food_name": "Banana",        // display name at time of add
///   "quantity": 1.5,              // servings multiplier
///   "serving_unit": "medium",     // optional, for display
///   "source": "template",         // "template" | "user"
///   "carbs_per_serving": 27.0,
///   "protein_per_serving": 1.3,
///   "fat_per_serving": 0.4,
///   "sodium_mg": 1,               // per serving
///   "fluid_ml_per_serving": 0,
///   "calories_per_serving": 105
/// }
/// ```
class FormulaMacros {
  const FormulaMacros._();

  // ── Component keys ─────────────────────────────────────────────────────
  static const kFoodId = 'food_id';
  static const kFoodName = 'food_name';
  static const kQuantity = 'quantity';
  static const kServingUnit = 'serving_unit';
  static const kSource = 'source';
  static const kCarbsPerServing = 'carbs_per_serving';
  static const kProteinPerServing = 'protein_per_serving';
  static const kFatPerServing = 'fat_per_serving';
  static const kSodiumMg = 'sodium_mg';
  static const kFluidMlPerServing = 'fluid_ml_per_serving';
  static const kCaloriesPerServing = 'calories_per_serving';

  static const sourceTemplate = 'template';
  static const sourceUser = 'user';

  /// Build a canonical component map from a selected [food] + [quantity].
  ///
  /// [isUserFood] flags whether the food came from the user's own library
  /// (`user_foods`) vs the system catalog (`template_foods`); it drives the
  /// `source` discriminator the edge function uses when resolving components.
  static Map<String, dynamic> componentFromFood(
    Food food,
    double quantity, {
    required bool isUserFood,
  }) {
    return <String, dynamic>{
      kFoodId: food.id,
      kFoodName: food.displayName?.isNotEmpty == true
          ? food.displayName
          : food.name,
      kQuantity: quantity,
      kServingUnit: food.servingUnit,
      kSource: isUserFood ? sourceUser : sourceTemplate,
      kCarbsPerServing: food.carbsPerServing,
      kProteinPerServing: food.proteinPerServing,
      kFatPerServing: food.fatPerServing,
      kSodiumMg: food.sodiumMg,
      kFluidMlPerServing: food.fluidMlPerServing,
      kCaloriesPerServing: food.caloriesPerServing,
    };
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0.0;

  static double quantityOf(Map<String, dynamic> component) {
    final q = component[kQuantity];
    return q is num ? q.toDouble() : 1.0;
  }

  static String nameOf(Map<String, dynamic> component) =>
      (component[kFoodName] as String?) ?? 'Food';

  /// Per-component macro totals (per-serving × quantity), for display rows.
  static FormulaTotals totalsForComponent(Map<String, dynamic> component) {
    final q = quantityOf(component);
    return FormulaTotals(
      carbsG: (_num(component[kCarbsPerServing]) * q).round(),
      proteinG: (_num(component[kProteinPerServing]) * q).round(),
      fatG: (_num(component[kFatPerServing]) * q).round(),
      sodiumMg: (_num(component[kSodiumMg]) * q).round(),
      fluidsMl: (_num(component[kFluidMlPerServing]) * q).round(),
      calories: (_num(component[kCaloriesPerServing]) * q).round(),
    );
  }

  /// Uniform multiplier that scales a during formula's authored quantities so
  /// its total carbs hit [targetCarbsG], preserving the formula's composition
  /// (every component scales by the same factor, water included). Returns 1
  /// (no scaling) when the target is non-positive or the formula has no carbs
  /// to scale (e.g. water + electrolytes only).
  ///
  /// During formulas are quantity-less by design (decided 2026-06-11) — their
  /// stored quantities are placeholders, and plan generation derives amounts
  /// from the phase's carb target. Mirrored in the edge function by
  /// `carbScaleFactor` in `personal-formula-pins.ts` — keep in sync.
  static double carbScaleFactor(
    List<Map<String, dynamic>> components,
    double targetCarbsG,
  ) {
    if (targetCarbsG <= 0) return 1;
    var baseCarbs = 0.0;
    for (final c in components) {
      final q = quantityOf(c);
      if (q <= 0) continue;
      baseCarbs += _num(c[kCarbsPerServing]) * q;
    }
    if (baseCarbs <= 0) return 1;
    return targetCarbsG / baseCarbs;
  }

  /// A scaled quantity rounded to user-meaningful 0.5 steps, floored at 0.5
  /// so no component vanishes from the user's formula. Mirrors `roundHalf` in
  /// `personal-formula-pins.ts` — keep in sync.
  static double scaledQuantity(double authoredQuantity, double scaleFactor) {
    final scaled = (authoredQuantity * scaleFactor * 2).round() / 2;
    return scaled < 0.5 ? 0.5 : scaled;
  }

  /// Aggregate macro totals across all [components]. Returned values are the
  /// denormalized `personal_formulas.total_*` columns (rounded ints).
  static FormulaTotals totalsFor(List<Map<String, dynamic>> components) {
    var carbs = 0.0, protein = 0.0, fat = 0.0, sodium = 0.0, fluids = 0.0;
    var calories = 0.0;
    for (final c in components) {
      final q = quantityOf(c);
      carbs += _num(c[kCarbsPerServing]) * q;
      protein += _num(c[kProteinPerServing]) * q;
      fat += _num(c[kFatPerServing]) * q;
      sodium += _num(c[kSodiumMg]) * q;
      fluids += _num(c[kFluidMlPerServing]) * q;
      calories += _num(c[kCaloriesPerServing]) * q;
    }
    return FormulaTotals(
      carbsG: carbs.round(),
      proteinG: protein.round(),
      fatG: fat.round(),
      sodiumMg: sodium.round(),
      fluidsMl: fluids.round(),
      calories: calories.round(),
    );
  }
}

/// Rounded macro totals for a formula (or a single component).
class FormulaTotals {
  const FormulaTotals({
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
    required this.fluidsMl,
    required this.calories,
  });

  final int carbsG;
  final int proteinG;
  final int fatG;
  final int sodiumMg;
  final int fluidsMl;
  final int calories;

  static const zero = FormulaTotals(
    carbsG: 0,
    proteinG: 0,
    fatG: 0,
    sodiumMg: 0,
    fluidsMl: 0,
    calories: 0,
  );
}
