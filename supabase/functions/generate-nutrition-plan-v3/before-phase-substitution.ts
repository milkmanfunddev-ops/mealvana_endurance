/**
 * Before Phase — User Food Substitution (DISABLED)
 *
 * Historically this found `user_foods` that could substitute for a before-phase
 * template component, matched on product_type and carb profile.
 *
 * FOOD-SOURCE POLICY (2026-07-29): plan generation draws foods ONLY from the
 * curated `template_foods` catalog. `user_foods` — user-created, barcode-scanned
 * and branded grocery items — must not reach any generated plan, including
 * fallbacks. The only legitimate user-originating source is a pinned personal
 * formula, which is self-contained (components carry their own macros, no
 * food-pool lookup — see `personal-formula-pins.ts`).
 *
 * `fetchUserFoodsForBefore` therefore performs NO query and always returns an
 * empty list, so `findSubstitutions` always returns an empty map and the
 * explosion path in `before-phase-explosion.ts` always renders the original
 * curated component. The matching machinery below is retained (still exercised
 * by unit tests, still type-referenced by the explosion module) but is
 * unreachable in production with an empty food list.
 *
 * Do not reintroduce the query.
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import type { PreWorkoutPhaseResult } from "../generate-macros-v4/types.ts";
import type { TemplateFoodRow } from "./before-phase-db.ts";

// ============================================================================
// Types
// ============================================================================

export interface UserFoodForSubstitution {
  id: string;
  name: string;
  display_name: string | null;
  display_name_plural: string | null;
  carbs_per_serving: number;
  protein_per_serving: number;
  fat_per_serving: number;
  sodium_mg: number;
  fluid_ml_per_serving: number;
  calories_per_serving: number;
  serving_size: string | null;
  serving_unit: string | null;
  serving_amount: number | null;
  product_type: string;
  is_electrolyte: boolean;
}

// ============================================================================
// Product Type Matching
// ============================================================================

/**
 * Maps user food product_type → template component product_types it can substitute for.
 */
const USER_TO_TEMPLATE_TYPE_MAP: Record<string, string[]> = {
  gel: ["energy_gel", "gel"],
  chew: ["energy_chews", "chew"],
  bar: ["granola_bar", "bar", "energy_bar", "cereal_bar"],
  waffle: ["granola_bar", "waffle", "bar"],
  sports_drink: ["sports_drink", "sports_drink_mix", "coconut_water"],
  drink_mix: ["sports_drink_mix", "electrolyte_drink_mix", "sports_drink"],
  electrolyte_only: ["electrolyte_tablet", "electrolyte_drink_mix"],
  real_food: [
    "toast", "bagel", "oatmeal", "cereal", "rice_cake", "yogurt",
    "banana", "real_food", "real_food_carbs",
  ],
  real_food_carbs: [
    "toast", "bagel", "oatmeal", "cereal", "rice_cake", "real_food_carbs",
  ],
  solid_carb_snacks: ["granola_bar", "bar", "rice_cake"],
  recovery_shake: ["smoothie", "recovery_shake", "yogurt"],
};

/** Infer is_liquid from product_type */
export function isLiquidProductType(productType: string): boolean {
  return [
    "sports_drink", "drink_mix", "recovery_shake",
    "electrolytes_fluids", "hydration_with_carbs",
  ].includes(productType);
}

// ============================================================================
// Fetch User Foods
// ============================================================================

/**
 * Fetch user foods suitable for before-phase substitution.
 *
 * DISABLED by the food-source policy (see file header): always returns an empty
 * list without querying `user_foods`. The signature is kept so `before-phase.ts`
 * needs no change, and so the disablement lives in exactly one place.
 */
// deno-lint-ignore require-await
export async function fetchUserFoodsForBefore(
  _supabase: ReturnType<typeof createServiceClient>,
  _deviceId: string,
): Promise<UserFoodForSubstitution[]> {
  console.log(
    "[PLAN-V3-SUBST] user_foods substitution is disabled by policy — " +
      "before-phase components come from the curated catalog only",
  );
  return [];
}

// ============================================================================
// Find Substitutions
// ============================================================================

/**
 * Find user food substitutions for template components.
 * Returns a map of componentName → userFood that should replace it.
 *
 * Matching: user food product_type must map to the component's product_type,
 * and carbs per serving must be within 50% tolerance.
 * Never substitutes essential components (water).
 * Never substitutes with a food the user has marked as disliked/avoided.
 */
export function findSubstitutions(
  phaseResults: PreWorkoutPhaseResult[],
  templateFoodsMap: Map<string, TemplateFoodRow>,
  userFoods: UserFoodForSubstitution[],
  dislikedFoods?: string[],
): Map<string, UserFoodForSubstitution> {
  if (userFoods.length === 0) return new Map();

  const dislikedLower = (dislikedFoods ?? []).map((d) => d.toLowerCase());

  const substitutions = new Map<string, UserFoodForSubstitution>();
  const usedUserFoods = new Set<string>();

  for (const pr of phaseResults) {
    for (const selection of [pr.primary, pr.stack, pr.drink, pr.electrolyte]) {
      if (!selection?.component_food_names) continue;

      for (const compName of selection.component_food_names) {
        const tf = templateFoodsMap.get(compName);
        if (!tf) continue;

        // Never substitute water or other essential liquids
        if (compName === "water" || compName === "plain_water") continue;

        const compProductType = tf.product_type ?? compName;

        const candidates = userFoods.filter((uf) => {
          if (usedUserFoods.has(uf.id)) return false;

          // Never substitute with a food the user has marked as disliked/avoided
          if (dislikedLower.length > 0) {
            const nameLower = uf.name.toLowerCase();
            const displayLower = (uf.display_name ?? "").toLowerCase();
            if (
              dislikedLower.includes(nameLower) ||
              dislikedLower.includes(displayLower) ||
              dislikedLower.includes(uf.id)
            ) {
              console.log(
                `[PLAN-V3-SUBST] Skipping disliked user food '${uf.name}' for substitution`,
              );
              return false;
            }
          }

          const allowedTypes = USER_TO_TEMPLATE_TYPE_MAP[uf.product_type] ?? [];
          if (
            !allowedTypes.includes(compProductType) &&
            uf.product_type !== compProductType
          ) {
            return false;
          }

          // Nutritional similarity: carbs within 50% tolerance
          const compCarbs = tf.carbs_g;
          if (compCarbs > 0) {
            const carbDiff = Math.abs(uf.carbs_per_serving - compCarbs);
            if (carbDiff / compCarbs > 0.5) return false;
          }

          return true;
        });

        if (candidates.length === 0) continue;

        // Pick the candidate with closest carb profile
        const best = candidates.reduce((a, b) => {
          const diffA = Math.abs(a.carbs_per_serving - tf.carbs_g);
          const diffB = Math.abs(b.carbs_per_serving - tf.carbs_g);
          return diffA <= diffB ? a : b;
        });

        substitutions.set(compName, best);
        usedUserFoods.add(best.id);
        console.log(
          `[PLAN-V3-SUBST] Substituting '${compName}' (${compProductType}) → user food '${best.name}' (${best.product_type})`,
        );
      }
    }
  }

  return substitutions;
}
