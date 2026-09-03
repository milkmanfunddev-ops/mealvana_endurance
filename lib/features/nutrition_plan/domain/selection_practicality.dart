/// Selection practicality — food-recommendation §6(a) (RULED Xuan,
/// 2026-09-03, thread-refined). TS twin:
/// `supabase/functions/_shared/nutrition/practicality.ts` (§8 twin contract —
/// every rule binds both engines).
///
/// The meal tier prefers COMPOSED templates:
///  * single-item scaling is capped at 2× before another template is
///    preferred (the Banana-×3 case returns a composed pick or an honest
///    shortfall — never a single food scaled past 2× to fake a meal);
///  * a meal-tier feeding has ≥ 2 components unless the catalog flags the
///    template `single_food_sufficient`.
///
/// SELECTION-path rules (faces 3–4). Pins bypass them (§1a labeled override).
library;

/// §6(a): a single item may scale to at most this many servings in the meal
/// tier.
const double kMealSingleItemScaleCap = 2;

enum MealTierRejectionReason {
  singleItemScaleExceeds2x('single_item_scale_exceeds_2x'),
  mealRequires2Components('meal_requires_2_components');

  const MealTierRejectionReason(this.wireName);
  final String wireName;
}

class MealTierCheck {
  const MealTierCheck.allowed()
      : allowed = true,
        reason = null;
  const MealTierCheck.rejected(MealTierRejectionReason this.reason)
      : allowed = false;

  final bool allowed;
  final MealTierRejectionReason? reason;
}

/// Is this candidate admissible for the MEAL tier? Multi-component templates
/// always pass; a single-component candidate fails when hitting its carb
/// target would scale it past 2×, and otherwise needs the
/// `single_food_sufficient` flag.
MealTierCheck mealTierCandidateCheck({
  required int componentCount,
  bool singleFoodSufficient = false,
  double? carbsPerServingG,
  double? carbTargetG,
}) {
  if (componentCount >= 2) return const MealTierCheck.allowed();

  final perServing = carbsPerServingG ?? 0;
  if (carbTargetG != null && carbTargetG > 0 && perServing > 0) {
    final scale = carbTargetG / perServing;
    if (scale > kMealSingleItemScaleCap + 1e-9) {
      return const MealTierCheck.rejected(
        MealTierRejectionReason.singleItemScaleExceeds2x,
      );
    }
  }
  if (!singleFoodSufficient) {
    return const MealTierCheck.rejected(
      MealTierRejectionReason.mealRequires2Components,
    );
  }
  return const MealTierCheck.allowed();
}
