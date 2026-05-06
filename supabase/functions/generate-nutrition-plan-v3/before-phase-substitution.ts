/**
 * Before Phase — User Food Substitution
 *
 * Finds user foods that can substitute for template components based on
 * product_type matching and carb profile similarity.
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

/** Fetch user foods suitable for before phase substitution. */
export async function fetchUserFoodsForBefore(
  supabase: ReturnType<typeof createServiceClient>,
  deviceId: string,
): Promise<UserFoodForSubstitution[]> {
  // Look up user_id from device_id
  const { data: userData } = await supabase
    .from("users")
    .select("id")
    .eq("device_id", deviceId)
    .single();

  const userId = userData?.id;
  if (!userId) {
    console.log(
      "[PLAN-V3-SUBST] No user found for device_id, skipping substitution",
    );
    return [];
  }

  const { data: userFoods, error } = await supabase
    .from("user_foods")
    .select(`
      id, name, display_name, display_name_plural,
      carbs_per_serving, protein_per_serving, fat_per_serving,
      sodium_mg, fluid_ml_per_serving, calories_per_serving,
      serving_size, serving_unit, serving_amount,
      product_type, is_electrolyte, categories
    `)
    .eq("user_id", userId)
    .eq("is_deleted", false)
    .eq("to_exclude_from_solver", false)
    .not("product_type", "is", null)
    .neq("product_type", "import");

  if (error) {
    console.warn(
      `[PLAN-V3-SUBST] Failed to fetch user foods: ${error.message}`,
    );
    return [];
  }

  // Filter: must be suitable for before phase
  const beforeFoods = (userFoods ?? []).filter((f: Record<string, unknown>) => {
    const categories = f.categories as string[] | null;
    if (!categories || categories.length === 0) return true;
    return categories.includes("before_run");
  });

  console.log(
    `[PLAN-V3-SUBST] Found ${beforeFoods.length} user foods for before-phase substitution`,
  );

  return beforeFoods.map((
    f: Record<string, unknown>,
  ): UserFoodForSubstitution => ({
    id: f.id as string,
    name: f.name as string,
    display_name: (f.display_name as string) ?? null,
    display_name_plural: (f.display_name_plural as string) ?? null,
    carbs_per_serving: (f.carbs_per_serving as number) ?? 0,
    protein_per_serving: (f.protein_per_serving as number) ?? 0,
    fat_per_serving: (f.fat_per_serving as number) ?? 0,
    sodium_mg: (f.sodium_mg as number) ?? 0,
    fluid_ml_per_serving: (f.fluid_ml_per_serving as number) ?? 0,
    calories_per_serving: (f.calories_per_serving as number) ?? 0,
    serving_size: (f.serving_size as string) ?? null,
    serving_unit: (f.serving_unit as string) ?? null,
    serving_amount: (f.serving_amount as number) ?? null,
    product_type: f.product_type as string,
    is_electrolyte: (f.is_electrolyte as boolean) ?? false,
  }));
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
