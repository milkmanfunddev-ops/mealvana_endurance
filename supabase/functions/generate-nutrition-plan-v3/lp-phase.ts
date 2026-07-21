/**
 * LP-based phase generation for nutrition plan V3.
 *
 * Used as the fallback for the AFTER phase only. The during phase no longer
 * has an LP tier (2026-07-21 refactor): its rule solver + closing gap-fill
 * pass strictly dominate the LP fallback, which ran on a different food pool
 * with no gut caps and shipped unvalidated output.
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import {
  type ActivityType,
  buildLPModel,
  type FoodResult,
  getOptimizationWeights,
  getSportConfig,
  greedyFallback,
  type MacroTargets,
  type Phase,
  solveLPModel,
} from "../_shared/nutrition/index.ts";
import { getTemplateFoodsForPhase } from "../_shared/nutrition/template-food-queries.ts";
import type { LPPhaseResult } from "./types.ts";
import { validatePhaseResultAgainstTargets } from "./validation.ts";

/**
 * Generate a phase using the LP solver with greedy fallback.
 */
export async function generateLPPhase(
  supabase: ReturnType<typeof createServiceClient>,
  phase: Phase,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  console.log(`[PLAN-V3] Generating ${phase} phase via LP solver`);

  // Get foods for this phase from template_foods table
  let foods = await getTemplateFoodsForPhase(
    supabase,
    phase,
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
    console.log(`[PLAN-V3] No foods found for ${phase} phase`);
    return { foods: [] };
  }

  console.log(`[PLAN-V3] ${phase}: ${foods.length} foods available`);

  // After phase: filter out foods that are clearly not recovery foods.
  if (phase === "after" && targets.carbs_g > 0) {
    const beforeCount = foods.length;
    foods = foods.filter((f) => {
      const isHighCarbNoProtein = f.per_serving.protein_g < 1 &&
        f.per_serving.carbs_g > targets.carbs_g * 0.5;
      if (isHighCarbNoProtein) {
        console.log(
          `[PLAN-V3] after: excluding ${f.name} (${f.per_serving.carbs_g}g carbs, ${f.per_serving.protein_g}g protein — not suitable for recovery)`,
        );
      }
      return !isHighCarbNoProtein;
    });
    if (foods.length < beforeCount) {
      console.log(
        `[PLAN-V3] after: filtered ${
          beforeCount - foods.length
        } non-recovery foods, ${foods.length} remaining`,
      );
    }
  }

  const sportConfig = getSportConfig(activityType);
  const phaseConfig = sportConfig.phases[phase];
  const dynamicMaxServingsCap = phase === "after" && targets.water_ml > 2000
    ? Math.max(phaseConfig.maxServingsCap, 8)
    : phaseConfig.maxServingsCap;

  // Get optimization weights for this phase
  const weights = getOptimizationWeights(activityType, phase);

  const modelOptions = {
    maxFoodItems: phaseConfig.maxFoods,
    maxServingsCap: dynamicMaxServingsCap,
    selectionPenalty: 0.1,
  };

  // Build and solve LP model
  const model = buildLPModel(
    foods,
    targets,
    phase,
    weights,
    undefined,
    undefined,
    modelOptions,
  );
  const solution = solveLPModel(model, foods, phase);

  let resultFoods: FoodResult[];
  if (solution && solution.foods.length > 0) {
    console.log(`[PLAN-V3] ${phase} LP solved: ${solution.foods.length} foods`);
    resultFoods = solution.foods;
  } else {
    // Fallback to greedy
    console.log(`[PLAN-V3] ${phase} LP failed, using greedy fallback`);
    const greedyResult = greedyFallback(foods, targets, phase);
    resultFoods = greedyResult.foods;
  }

  // If phase output is out-of-range and imported user foods are present in the pool,
  // retry without imported user foods.
  const initialValidation = validatePhaseResultAgainstTargets(
    resultFoods,
    targets,
    phase,
  );
  if (!initialValidation.ok) {
    const hasImportedUserFoods = foods.some((f) =>
      f.is_user_food === true &&
      (!f.product_type || f.product_type === "import")
    );

    if (hasImportedUserFoods) {
      const sanitizedFoods = foods.filter((f) =>
        !(f.is_user_food === true &&
          (!f.product_type || f.product_type === "import"))
      );

      if (sanitizedFoods.length > 0) {
        console.warn(
          `[PLAN-V3] ${phase}: out-of-range with imported user foods. ` +
            `Retrying with imported user foods removed (${foods.length} -> ${sanitizedFoods.length}). Issues: ${
              initialValidation.issues.join("; ")
            }`,
        );

        const retryModel = buildLPModel(
          sanitizedFoods,
          targets,
          phase,
          weights,
          undefined,
          undefined,
          modelOptions,
        );
        const retrySolution = solveLPModel(retryModel, sanitizedFoods, phase);
        let retryFoods: FoodResult[];
        if (retrySolution && retrySolution.foods.length > 0) {
          retryFoods = retrySolution.foods;
        } else {
          retryFoods = greedyFallback(sanitizedFoods, targets, phase).foods;
        }

        const retryValidation = validatePhaseResultAgainstTargets(
          retryFoods,
          targets,
          phase,
        );

        if (
          retryValidation.ok ||
          retryValidation.issues.length < initialValidation.issues.length
        ) {
          resultFoods = retryFoods;
          console.log(
            `[PLAN-V3] ${phase}: adopted sanitized retry result (issues ${initialValidation.issues.length} -> ${retryValidation.issues.length})`,
          );
        } else {
          console.warn(
            `[PLAN-V3] ${phase}: keeping original result (sanitized retry not better).`,
          );
        }
      }
    }
  }

  return { foods: resultFoods };
}
