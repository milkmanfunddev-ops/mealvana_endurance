/**
 * During Phase generation for nutrition plan V3.
 *
 * - generateDuringPhase(): Rule-based solver with LP fallback
 * - postProcessDuringPhase(): Electrolyte supplement post-processing (deprecated)
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import { roundToIncrement } from "../_shared/utils.ts";
import {
  type ActivityType,
  buildLPModel,
  calculateTotals,
  type FoodResult,
  getOptimizationWeights,
  getSportConfig,
  greedyFallback,
  type MacroTargets,
  POST_PROCESS_THRESHOLDS,
  solveLPModel,
} from "../_shared/nutrition/index.ts";
import {
  getTemplateElectrolyteFoods,
  getTemplateFoodsForPhase,
} from "../_shared/nutrition/template-food-queries.ts";
import { generateDuringPhaseRuleBased } from "../_shared/nutrition/during-rule-solver.ts";
import type { LPPhaseResult } from "./types.ts";
import { validatePhaseResultAgainstTargets } from "./validation.ts";
import { generateLPPhase } from "./lp-phase.ts";

// ============================================================================
// During Phase Post-Processing (Two-Pass Approach)
// ============================================================================

/**
 * @deprecated No longer used for during phase (rule solver handles electrolytes inline).
 * Kept for potential future use.
 *
 * Post-process during-phase results to fill sodium deficit with electrolyte supplements.
 *
 * Pass 1 (LP solver) focuses on carbs + preference with reduced sodium weight.
 * Pass 2 (this function) adds electrolyte supplements to fill any sodium gap.
 *
 * Adapted from v1's postProcessPhase() pattern.
 */
export async function postProcessDuringPhase(
  supabase: ReturnType<typeof createServiceClient>,
  resultFoods: FoodResult[],
  targets: MacroTargets,
  maxFoodsAllowed: number,
  likedFoods?: string[],
  willingToTryFoods?: string[],
): Promise<FoodResult[]> {
  const totals = calculateTotals(resultFoods);
  const sodiumDeficit = targets.sodium_mg - totals.sodium_mg;
  const deficitPercent = targets.sodium_mg > 0
    ? sodiumDeficit / targets.sodium_mg
    : 0;
  const existingElectrolyteIndex = resultFoods.findIndex(
    (f) => f.is_electrolyte === true || f.timing_category === "electrolyte",
  );

  console.log(
    `[POST-PROCESS-DURING] Totals: sodium=${totals.sodium_mg.toFixed(0)}mg, ` +
      `target=${targets.sodium_mg}mg, deficit=${sodiumDeficit.toFixed(0)}mg (${
        (deficitPercent * 100).toFixed(1)
      }%)`,
  );

  // Skip if sodium deficit is within threshold
  if (deficitPercent <= POST_PROCESS_THRESHOLDS.sodium_deficit_percent) {
    console.log(
      `[POST-PROCESS-DURING] Sodium within threshold (${
        (deficitPercent * 100).toFixed(1)
      }% <= ${(POST_PROCESS_THRESHOLDS.sodium_deficit_percent *
        100)}%), skipping`,
    );
    return resultFoods;
  }

  // Skip if already at max food items and we can't edit an existing electrolyte item.
  if (resultFoods.length >= maxFoodsAllowed && existingElectrolyteIndex < 0) {
    console.log(
      `[POST-PROCESS-DURING] Already ${resultFoods.length} foods, skipping electrolyte addition`,
    );
    return resultFoods;
  }

  // If an electrolyte already exists, top it up first instead of skipping.
  if (existingElectrolyteIndex >= 0) {
    const existing = resultFoods[existingElectrolyteIndex];
    const currentServings = Math.max(1, existing.quantity || 1);
    const sodiumPerServing = existing.sodium_mg / currentServings;

    if (sodiumPerServing > 0) {
      let additionalServings = sodiumDeficit / sodiumPerServing;
      const isIndivisible = existing.is_indivisible ?? true;
      additionalServings = isIndivisible
        ? Math.max(1, Math.round(additionalServings))
        : roundToIncrement(additionalServings);

      const maxSodiumAllowed = targets.sodium_mg * 1.1;
      const maxAdditionalForCap = (maxSodiumAllowed - totals.sodium_mg) /
        sodiumPerServing;
      const cappedAdditional = isIndivisible
        ? Math.max(0, Math.floor(maxAdditionalForCap))
        : roundToIncrement(Math.max(0, maxAdditionalForCap));
      additionalServings = Math.min(additionalServings, cappedAdditional);

      if (additionalServings > 0) {
        const nextServings = currentServings + additionalServings;
        const perServingCarbs = existing.carbs_grams / currentServings;
        const perServingProtein = existing.protein_grams / currentServings;
        const perServingFat = existing.fat_grams / currentServings;
        const perServingFluids = existing.fluids_ml / currentServings;
        const perServingCalories = existing.calories / currentServings;

        const updated = {
          ...existing,
          quantity: nextServings,
          carbs_grams: existing.carbs_grams +
            perServingCarbs * additionalServings,
          protein_grams: existing.protein_grams +
            perServingProtein * additionalServings,
          fat_grams: existing.fat_grams + perServingFat * additionalServings,
          sodium_mg: existing.sodium_mg + sodiumPerServing * additionalServings,
          fluids_ml: existing.fluids_ml + perServingFluids * additionalServings,
          calories: Math.round(
            existing.calories + perServingCalories * additionalServings,
          ),
        } as FoodResult;

        const updatedFoods = [...resultFoods];
        updatedFoods[existingElectrolyteIndex] = updated;
        return updatedFoods;
      }
    }
  }

  // Fetch electrolyte foods
  const electrolytes = await getTemplateElectrolyteFoods(
    supabase,
    likedFoods,
    willingToTryFoods,
  );
  if (electrolytes.length === 0) {
    console.log(`[POST-PROCESS-DURING] No electrolyte foods available`);
    return resultFoods;
  }

  // Sort by sodium-to-water ratio (prefer high sodium, low water — tablets over drinks)
  const sortedElectrolytes = [...electrolytes].sort((a, b) => {
    const ratioA = a.per_serving.sodium_mg /
      Math.max(1, a.per_serving.water_ml);
    const ratioB = b.per_serving.sodium_mg /
      Math.max(1, b.per_serving.water_ml);
    return ratioB - ratioA;
  });

  const best = sortedElectrolytes[0];

  // Calculate needed servings to fill deficit
  if (best.per_serving.sodium_mg <= 0) {
    console.log(
      `[POST-PROCESS-DURING] Best electrolyte has 0mg sodium, skipping`,
    );
    return resultFoods;
  }

  let neededServings = sodiumDeficit / best.per_serving.sodium_mg;

  // Enforce is_indivisible rounding (electrolytes are typically tablets)
  neededServings = best.is_indivisible
    ? Math.max(1, Math.round(neededServings))
    : roundToIncrement(neededServings);

  // Cap: don't overshoot sodium by more than 10%
  const maxSodiumAllowed = targets.sodium_mg * 1.1;
  const maxServingsForCap = (maxSodiumAllowed - totals.sodium_mg) /
    best.per_serving.sodium_mg;
  const cappedServings = best.is_indivisible
    ? Math.max(1, Math.floor(maxServingsForCap))
    : roundToIncrement(Math.max(0.5, maxServingsForCap));

  neededServings = Math.min(neededServings, cappedServings);

  if (neededServings <= 0) {
    console.log(
      `[POST-PROCESS-DURING] Needed servings <= 0 after capping, skipping`,
    );
    return resultFoods;
  }

  console.log(
    `[POST-PROCESS-DURING] Adding ${neededServings}x "${
      best.display_name ?? best.name
    }" ` +
      `(${(best.per_serving.sodium_mg * neededServings).toFixed(0)}mg sodium)`,
  );

  const electrolyteFoodResult: FoodResult = {
    food_id: best.id,
    quantity: neededServings,
    carbs_grams: best.per_serving.carbs_g * neededServings,
    protein_grams: best.per_serving.protein_g * neededServings,
    fat_grams: best.per_serving.fat_g * neededServings,
    sodium_mg: best.per_serving.sodium_mg * neededServings,
    fluids_ml: best.per_serving.water_ml * neededServings,
    calories: best.per_serving.calories * neededServings,
    timing: "Throughout activity",
    display_name: best.display_name ?? undefined,
    display_name_plural: best.display_name_plural ?? undefined,
    description: best.description ?? undefined,
    image_address: best.image_address ?? undefined,
    is_liquid: false,
    is_electrolyte: true,
    is_drink: false,
    is_indivisible: best.is_indivisible ?? true,
    timing_category: "electrolyte",
    product_type: best.product_type,
  };

  return [...resultFoods, electrolyteFoodResult];
}

// ============================================================================
// During Phase (Rule-Based)
// ============================================================================

/**
 * Generate during-phase food selection using deterministic rules.
 * Swimming returns empty immediately. Run/bike use the rule solver.
 * No server-side by-hour apportionment (client creates empty buckets).
 */
export async function generateDuringPhase(
  supabase: ReturnType<typeof createServiceClient>,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  // Swimming: no during-phase nutrition
  if (activityType === "swimming") {
    console.log("[PLAN-V3] Swimming activity — skipping during phase");
    return { foods: [], by_hour_data: null };
  }

  console.log(
    `[PLAN-V3] Generating during phase via rule solver (${activityType})`,
  );

  // Get foods from template_foods table
  let foods = await getTemplateFoodsForPhase(
    supabase,
    "during",
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    false,
    allergies,
    dietaryPreference,
  );

  if (foods.length === 0) {
    console.log("[PLAN-V3] No during foods found, trying expanded pool");
    foods = await getTemplateFoodsForPhase(
      supabase,
      "during",
      activityType,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
      deviceId,
      true,
      allergies,
      dietaryPreference,
    );
  }

  if (foods.length === 0) {
    console.log("[PLAN-V3] No during foods available at all");
    return { foods: [] };
  }

  const ruleResult = generateDuringPhaseRuleBased(foods, targets, activityType);
  const ruleValidation = validatePhaseResultAgainstTargets(
    ruleResult.foods,
    targets,
    "during",
  );

  if (ruleValidation.ok) {
    return { foods: ruleResult.foods, by_hour_data: null };
  }

  console.warn(
    `[PLAN-V3] During rule-solver out of range (${
      ruleValidation.issues.join("; ")
    }). ` +
      `Retrying with LP solver.`,
  );

  const lpResult = await generateLPPhase(
    supabase,
    "during",
    targets,
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    undefined,
    undefined,
    allergies,
    dietaryPreference,
  );

  const lpValidation = validatePhaseResultAgainstTargets(
    lpResult.foods,
    targets,
    "during",
  );
  if (!lpValidation.ok) {
    // Return best-effort LP result with warning instead of throwing
    console.warn(
      `[PLAN-V3] During phase LP out of range (non-fatal): ${
        lpValidation.issues.join("; ")
      }`,
    );
  }

  return lpResult;
}
