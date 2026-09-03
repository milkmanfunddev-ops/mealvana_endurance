/**
 * Selection practicality — food-recommendation §6(a) (RULED Xuan, 2026-09-03,
 * thread-refined). Dart twin:
 * `lib/features/nutrition_plan/domain/selection_practicality.dart` (§8 twin
 * contract — every rule binds both engines).
 *
 * The meal tier prefers COMPOSED templates:
 *  - single-item scaling is capped at 2× before another template is
 *    preferred (the Banana-×3 case returns a composed pick or an honest
 *    shortfall — never a single food scaled past 2× to fake a meal);
 *  - a meal-tier feeding has ≥ 2 components unless the catalog flags the
 *    template `single_food_sufficient`.
 *
 * These are SELECTION-path rules (faces 3–4). Pins bypass them (§1a labeled
 * override). The two constants here are the only ruled portion policy —
 * wider per-product caps remain unruled (manifest exclusion).
 */

/** §6(a): a single item may scale to at most this many servings in the meal
 * tier. */
export const MEAL_SINGLE_ITEM_SCALE_CAP = 2;

export type MealTierRejectionReason =
  | "single_item_scale_exceeds_2x"
  | "meal_requires_2_components";

export interface MealTierCheck {
  allowed: boolean;
  reason: MealTierRejectionReason | null;
}

/**
 * Is this candidate admissible for the MEAL tier? Multi-component templates
 * always pass; a single-component candidate fails when hitting its carb
 * target would scale it past 2×, and otherwise needs the
 * `single_food_sufficient` flag.
 */
export function mealTierCandidateCheck(args: {
  componentCount: number;
  singleFoodSufficient?: boolean;
  carbsPerServingG?: number | null;
  carbTargetG?: number | null;
}): MealTierCheck {
  if (args.componentCount >= 2) return { allowed: true, reason: null };

  const perServing = args.carbsPerServingG ?? 0;
  const target = args.carbTargetG ?? null;
  if (target != null && target > 0 && perServing > 0) {
    const scale = target / perServing;
    if (scale > MEAL_SINGLE_ITEM_SCALE_CAP + 1e-9) {
      return { allowed: false, reason: "single_item_scale_exceeds_2x" };
    }
  }
  if (!(args.singleFoodSufficient ?? false)) {
    return { allowed: false, reason: "meal_requires_2_components" };
  }
  return { allowed: true, reason: null };
}
