/**
 * LP-based phase generation for nutrition plan V3.
 *
 * Used primarily for the after phase and as LP fallback for during phase.
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import {
  type ActivityType,
  buildLPModel,
  deriveTimingCategory,
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
import { generateByHourData } from "./by-hour-apportionment.ts";
import { postProcessDuringPhase } from "./during-phase.ts";
import { validatePhaseResultAgainstTargets } from "./validation.ts";

/**
 * Generate a phase (during or after) using the LP solver with greedy fallback.
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
  durationMinutes?: number,
  gutTrainingLevel?: string,
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  console.log(`[PLAN-V3] Generating ${phase} phase via LP solver`);
  const isDuringPhase = phase === "during";
  const useDefaultDuringFilter = isDuringPhase && activityType === "running";

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

  // Hydration strategy: filter food pool based on carb demand per hour
  if (isDuringPhase && durationMinutes && durationMinutes > 0) {
    const durationHours = durationMinutes / 60;
    const carbsPerHour = targets.carbs_g / durationHours;

    if (carbsPerHour <= 30) {
      const before = foods.length;
      foods = foods.filter((f) => {
        const tc = deriveTimingCategory(f);
        return tc !== "fuel_drink";
      });
      if (foods.length < before) {
        console.log(
          `[PLAN-V3] Hydration strategy: electrolyte_water (removed ${
            before - foods.length
          } fuel drinks, carbsPerHour=${carbsPerHour.toFixed(1)})`,
        );
      }
    } else if (carbsPerHour > 60) {
      console.log(
        `[PLAN-V3] Hydration strategy: sports_drink (high carb demand, carbsPerHour=${
          carbsPerHour.toFixed(1)
        })`,
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

  // Two-pass approach for during phase:
  // Pass 1: LP solver with reduced sodium weight so carbs + preference dominate
  // Pass 2: Post-processing adds electrolyte supplements to fill sodium deficit
  const weightOverrides = isDuringPhase ? { sodium: 0.05 } : undefined;
  const constraintOverrides = isDuringPhase
    ? { sodium: { min: 0.0, max: 1.1 } }
    : undefined;
  const modelOptions = {
    maxFoodItems: phaseConfig.maxFoods,
    maxServingsCap: dynamicMaxServingsCap,
    selectionPenalty: isDuringPhase ? 1.0 : 0.1,
    maxElectrolyteSupplements: isDuringPhase && activityType === "running"
      ? 1
      : undefined,
    enforceWaterMin: isDuringPhase,
    randomVariance: isDuringPhase,
  };

  // Build and solve LP model
  let model = buildLPModel(
    foods,
    targets,
    phase,
    weights,
    weightOverrides,
    constraintOverrides,
    modelOptions,
  );
  let solution = solveLPModel(model, foods, phase);

  // Running during default policy:
  // if default pool is infeasible, retry with all during foods.
  if (useDefaultDuringFilter && (!solution || solution.foods.length === 0)) {
    const expandedFoods = await getTemplateFoodsForPhase(
      supabase,
      phase,
      activityType,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
      deviceId,
      true,
      allergies,
      dietaryPreference,
    );
    if (expandedFoods.length > foods.length) {
      console.log(
        `[PLAN-V3] during running default pool infeasible; retrying with expanded food pool (${foods.length} -> ${expandedFoods.length})`,
      );
      foods = expandedFoods;
      model = buildLPModel(
        foods,
        targets,
        phase,
        weights,
        weightOverrides,
        constraintOverrides,
        modelOptions,
      );
      solution = solveLPModel(model, foods, phase);
    }
  }

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

  // Pass 2: Post-process during phase to add electrolyte supplements for sodium deficit
  if (isDuringPhase) {
    resultFoods = await postProcessDuringPhase(
      supabase,
      resultFoods,
      targets,
      phaseConfig.maxFoods,
      likedFoods,
      willingToTryFoods,
    );
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
          weightOverrides,
          constraintOverrides,
          modelOptions,
        );
        const retrySolution = solveLPModel(retryModel, sanitizedFoods, phase);
        let retryFoods: FoodResult[];
        if (retrySolution && retrySolution.foods.length > 0) {
          retryFoods = retrySolution.foods;
        } else {
          retryFoods = greedyFallback(sanitizedFoods, targets, phase).foods;
        }

        if (isDuringPhase) {
          retryFoods = await postProcessDuringPhase(
            supabase,
            retryFoods,
            targets,
            phaseConfig.maxFoods,
            likedFoods,
            willingToTryFoods,
          );
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

  // Generate by-hour data for during phase
  let byHourData = null;
  if (isDuringPhase && durationMinutes && durationMinutes >= 60) {
    byHourData = generateByHourData(
      resultFoods,
      durationMinutes,
      activityType,
      gutTrainingLevel ?? "moderate",
    );
    if (byHourData) {
      console.log(
        `[PLAN-V3] Generated by-hour data: ${byHourData.assignments.length} assignments for ${durationMinutes}min`,
      );
    }
  }

  return { foods: resultFoods, by_hour_data: byHourData };
}
