/**
 * Before Phase V3 — Algorithm C Transformation Layer (Orchestrator)
 *
 * Calls V4's Algorithm C (selectPreWorkoutFoods) for food selection,
 * then transforms the output into V2's BeforePhaseResult shape so that
 * during/after phases and the Dart client remain unchanged.
 *
 * Module structure:
 * - before-phase-db.ts: DB queries (pre_workout_templates, template_foods)
 * - before-phase-substitution.ts: User food matching + substitution
 * - before-phase-explosion.ts: Component explosion + macro normalization
 * - before-phase.ts (this file): Thin orchestrator
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import type { PreWorkoutPhaseResult, PreWorkoutTargets } from "../generate-macros-v4/types.ts";
import { selectPreWorkoutFoods, splitTargets } from "../generate-macros-v4/pre-workout.ts";
import type { BeforePhaseResult } from "../_shared/nutrition/templates/types.ts";

import { fetchPreWorkoutTemplates, fetchTemplateFoodsByName } from "./before-phase-db.ts";
import { fetchUserFoodsForBefore, findSubstitutions } from "./before-phase-substitution.ts";
import { phaseResultToSubPhaseResult } from "./before-phase-explosion.ts";

// ============================================================================
// Input & Helper Types
// ============================================================================

interface BeforePhaseInput {
  hours_before: number;
  weight_kg: number;
  pre_run_selections?: PreWorkoutPhaseResult[];
  macro_targets: {
    pre_run: {
      carbs_g: number;
      carbs_low_g?: number;
      carbs_high_g?: number;
      protein_g?: number;
      protein_low_g?: number;
      protein_high_g?: number;
      fat_g?: number;
      sodium_mg: number;
      sodium_low_mg?: number;
      sodium_high_mg?: number;
      water_ml: number;
      water_low_ml?: number;
      water_high_ml?: number;
    };
  };
  dietary_preference?: string;
  liked_foods?: string[];
  disliked_foods?: string[];
  willing_to_try_foods?: string[];
  allergies?: string[];
  device_id?: string;
}

function inferMealType(hoursBefore: number, isFasted: boolean): string {
  if (isFasted) return "fasted";
  if (hoursBefore >= 2.5) return "full_meal";
  if (hoursBefore >= 1.0) return "snack";
  return "top_up";
}

function fallbackRange(
  target: number,
  low?: number,
  high?: number,
  lowPct = 0.9,
  highPct = 1.1,
): { low: number; high: number } {
  if (target <= 0) {
    return { low: 0, high: 0 };
  }
  if (low != null && high != null) {
    return { low: Math.max(0, low), high: Math.max(0, high) };
  }
  return {
    low: Math.round(target * lowPct),
    high: Math.round(target * highPct),
  };
}

/**
 * Use the incoming V4 targets/ranges as the canonical pre-workout contract.
 * We only compute fallback ranges when low/high are missing.
 */
function buildTargetsFromInput(input: BeforePhaseInput): PreWorkoutTargets {
  const pre = input.macro_targets.pre_run;
  const isFasted = (pre.carbs_g ?? 0) <= 0 && (pre.water_ml ?? 0) <= 0;
  const carbs = Math.round(pre.carbs_g ?? 0);
  const protein = Math.round(pre.protein_g ?? 0);
  const sodium = Math.round(pre.sodium_mg ?? 0);
  const water = Math.round(pre.water_ml ?? 0);
  const fat = Math.round(pre.fat_g ?? 0);

  const carbRange = fallbackRange(carbs, pre.carbs_low_g, pre.carbs_high_g, 0.875, 1.125);
  const proteinRange = fallbackRange(
    protein,
    pre.protein_low_g,
    pre.protein_high_g,
    input.hours_before < 1 ? 0 : 0.85,
    input.hours_before < 1 ? 0 : 1.15,
  );
  const sodiumRange = fallbackRange(sodium, pre.sodium_low_mg, pre.sodium_high_mg, 0.85, 1.15);
  const waterRange = fallbackRange(water, pre.water_low_ml, pre.water_high_ml, 0.85, 1.15);

  return {
    carbs_g: carbs,
    carbs_low_g: carbRange.low,
    carbs_high_g: carbRange.high,
    protein_g: protein,
    protein_low_g: proteinRange.low,
    protein_high_g: proteinRange.high,
    fat_g: fat,
    sodium_mg: sodium,
    sodium_low_mg: sodiumRange.low,
    sodium_high_mg: sodiumRange.high,
    water_ml: water,
    water_low_ml: waterRange.low,
    water_high_ml: waterRange.high,
    meal_type: inferMealType(input.hours_before, isFasted),
  };
}

// ============================================================================
// Main Entry Point
// ============================================================================

export async function generateBeforePhaseV3(
  supabase: ReturnType<typeof createServiceClient>,
  input: BeforePhaseInput,
): Promise<BeforePhaseResult> {
  console.log(
    `[PLAN-V3] Generating before phase with Algorithm C (hours_before=${input.hours_before})`,
  );

  // 0. Handle fasted state
  const preTargets = input.macro_targets.pre_run;
  const noPreFuelTargets =
    (preTargets.carbs_g ?? 0) <= 0 &&
    (preTargets.protein_g ?? 0) <= 0 &&
    (preTargets.sodium_mg ?? 0) <= 0 &&
    (preTargets.water_ml ?? 0) <= 0;
  if (noPreFuelTargets) {
    console.log("[PLAN-V3] Fasted state detected, skipping before phase");
    return {};
  }

  // 1. Build targets directly from incoming V4 macro contract.
  const targets = buildTargetsFromInput(input);
  console.log(
    `[PLAN-V3] Pre targets (from input): carbs=${targets.carbs_g}g [${targets.carbs_low_g}-${targets.carbs_high_g}], ` +
      `protein=${targets.protein_g}g [${targets.protein_low_g}-${targets.protein_high_g}], ` +
      `sodium=${targets.sodium_mg}mg [${targets.sodium_low_mg}-${targets.sodium_high_mg}], ` +
      `water=${targets.water_ml}ml [${targets.water_low_ml}-${targets.water_high_ml}], type=${targets.meal_type}`,
  );

  let phaseResults: PreWorkoutPhaseResult[];
  if (input.pre_run_selections && input.pre_run_selections.length > 0) {
    console.log(
      `[PLAN-V3] Using provided pre_run_selections (${input.pre_run_selections.length} phases)`,
    );
    phaseResults = input.pre_run_selections;
  } else {
    // 2. Fetch pre_workout_templates (3 types in parallel)
    const [foodTemplates, drinkTemplates, electrolyteTemplates] = await Promise
      .all([
        fetchPreWorkoutTemplates(supabase, "food"),
        fetchPreWorkoutTemplates(supabase, "drink"),
        fetchPreWorkoutTemplates(supabase, "electrolyte"),
      ]);

    console.log(
      `[PLAN-V3] Fetched templates: ${foodTemplates.length} food, ${drinkTemplates.length} drink, ${electrolyteTemplates.length} electrolyte`,
    );

    // 3. Run Algorithm C food selection (fallback path)
    const diet = input.dietary_preference ?? "none";
    phaseResults = selectPreWorkoutFoods(
      targets,
      input.hours_before,
      diet,
      foodTemplates,
      drinkTemplates,
      electrolyteTemplates,
      input.liked_foods ?? [],
      input.disliked_foods ?? [],
      input.allergies,
    );
  }

  if (phaseResults.length === 0) {
    console.log("[PLAN-V3] Algorithm C returned no phases (fasted)");
    return {};
  }

  // 4. Collect all unique component food names from selected templates
  const allComponentNames = new Set<string>();
  for (const pr of phaseResults) {
    for (const sel of [pr.primary, pr.stack, pr.drink, pr.electrolyte]) {
      if (sel?.component_food_names) {
        for (const name of sel.component_food_names) {
          allComponentNames.add(name);
        }
      }
    }
  }

  // 5. Fetch template_foods for components
  const templateFoodsMap = await fetchTemplateFoodsByName(
    supabase,
    Array.from(allComponentNames),
  );
  console.log(
    `[PLAN-V3] Fetched ${templateFoodsMap.size} template_foods for ${allComponentNames.size} component names`,
  );

  // 5.5. Fetch user foods and find substitutions for before-phase components
  let substitutions = new Map<string, import("./before-phase-substitution.ts").UserFoodForSubstitution>();
  if (input.device_id) {
    const userFoods = await fetchUserFoodsForBefore(supabase, input.device_id);
    if (userFoods.length > 0) {
      substitutions = findSubstitutions(
        phaseResults,
        templateFoodsMap,
        userFoods,
        input.disliked_foods,
      );
      console.log(
        `[PLAN-V3] Found ${substitutions.size} user food substitutions for before phase`,
      );
    }
  }

  // 6. Get phase targets for the SubPhaseResult shape
  const phaseTargetsMap = splitTargets(targets, input.hours_before);

  // 7. Transform V4 → V2 (exploding composites into individual FoodResults, with user substitutions)
  const beforeResult: BeforePhaseResult = {};

  for (const phaseResult of phaseResults) {
    const phaseTargets = phaseTargetsMap.get(phaseResult.phase) ?? {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0,
    };

    const subPhaseResult = phaseResultToSubPhaseResult(
      phaseResult,
      phaseTargets,
      input.hours_before,
      templateFoodsMap,
      substitutions,
    );

    console.log(
      `[PLAN-V3] ${phaseResult.phase}: ${subPhaseResult.foods.length} foods (exploded), carbs=${phaseResult.total_carbs_g}g`,
    );

    if (phaseResult.phase === "meal") beforeResult.meal = subPhaseResult;
    else if (phaseResult.phase === "snack") beforeResult.snack = subPhaseResult;
    else if (phaseResult.phase === "top_up") {
      beforeResult.top_up = subPhaseResult;
    }
  }

  return beforeResult;
}
