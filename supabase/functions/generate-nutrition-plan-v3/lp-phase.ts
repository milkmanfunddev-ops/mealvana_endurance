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
  reconcilePhaseHydrationAndSodium,
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
  /** @deprecated Ignored. Retained to keep the positional signature stable for
   * existing callers; it used to resolve a user id for a `user_foods` lookup
   * that no longer exists (food-source policy). Do not reintroduce. */
  _deviceId?: string,
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
    // No deviceId: the LP fallback pool is curated `template_foods` only —
    // `user_foods` is not a plan-generation source (food-source policy).
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

  // Validate the result for observability. There used to be a second solve here
  // that retried with imported `user_foods` stripped out of the pool; the pool
  // no longer contains any user foods at all (food-source policy — see
  // template-food-queries.ts), so that retry was unreachable and is gone.
  const validation = validatePhaseResultAgainstTargets(
    resultFoods,
    targets,
    phase,
  );
  if (!validation.ok) {
    console.warn(
      `[PLAN-V3] ${phase}: result out of range. Issues: ${
        validation.issues.join("; ")
      }`,
    );
  }

  // Closing pass: the LP optimizes a linear preference score inside [min,max]
  // bands, so it settles on a vertex — typically a range EDGE for sodium and
  // fluid rather than the point target. Pull them back toward target from the
  // same pool, strictly under every band ceiling. Mirrors what
  // during-gap-fill.ts does for during-phase carbs. (2026-07-29)
  resultFoods =
    reconcilePhaseHydrationAndSodium(resultFoods, foods, targets).foods;

  return { foods: resultFoods };
}
