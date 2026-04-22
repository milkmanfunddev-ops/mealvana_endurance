/**
 * Brick workout handler for nutrition plan V3.
 *
 * Handles multi-segment (swim/bike/run) brick workouts with:
 * - Shared before phase (Algorithm C)
 * - Per-segment during phases
 * - Transition phases (T1, T2) between segments
 * - Shared after phase (LP solver)
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import { jsonResponse } from "../_shared/responses.ts";
import {
  type ActivityType,
  adjustTargetsForOverrides,
  buildLPModel,
  type FoodResult,
  getOptimizationWeights,
  greedyFallback,
  type MacroTargets,
  solveLPModel,
} from "../_shared/nutrition/index.ts";
import {
  buildFoodsByNameMap,
  getDuringWorkoutTemplates,
  getTemplateFoodsForDuringWithConstraints,
  getTransitionFoods,
} from "../_shared/nutrition/template-food-queries.ts";
import {
  generateDuringPhaseTemplate,
  type GutTrainingLevel,
  selectTemplateCandidates,
} from "../_shared/nutrition/during-template-solver.ts";
import { generateBeforePhaseV3 } from "./before-phase.ts";
import { generateDuringPhase } from "./during-phase.ts";
import { generateLPPhase } from "./lp-phase.ts";
import {
  flattenBeforeFoods,
  validatePhaseResultAgainstTargets,
} from "./validation.ts";
import type { LPPhaseResult, PlanInputV2 } from "./types.ts";
import { buildPreferenceSet } from "../_shared/nutrition/food-utils.ts";

// ============================================================================
// Transition Targets (Distance-Based)
// ============================================================================

/**
 * Zero-default transition targets fallback.
 *
 * NOTE: getTransitionTargets with hardcoded duration tiers has been deleted.
 * The plan function is now a pure consumer of transition targets from the
 * macros payload (generate-macros-v4 now computes 300 ml fixed transitions
 * per the spec). This fallback fires only if the macros payload is missing
 * transition fields — which should not happen in production after Phase 1.
 */
function getTransitionTargets(
  _segments: Array<
    { sport: string; duration_minutes: number; macro_targets: MacroTargets }
  >,
  _transitionIndex: number,
): MacroTargets {
  console.warn(
    '[brick-handler] getTransitionTargets fallback fired — macros payload is missing transition fields. ' +
    'This indicates generate-macros-v4 did not provide transition data. Returning zero defaults.',
  );
  return {
    carbs_g: 0,
    carbs_low_g: 0,
    carbs_high_g: 0,
    sodium_mg: 0,
    sodium_low_mg: 0,
    sodium_high_mg: 0,
    water_ml: 0,
    water_low_ml: 0,
    water_high_ml: 0,
  };
}

function normalizeTransitionName(name?: string | null): string | null {
  if (!name) return null;
  const trimmed = name.trim();
  if (!trimmed) return null;
  const match = /^t?(\d+)$/i.exec(trimmed);
  if (!match) return trimmed;
  return `T${match[1]}`;
}

function collectTransitionTargets(
  input: PlanInputV2,
): Map<string, MacroTargets> {
  const collected: Array<Record<string, unknown>> = [];
  const fromBrickPhases = input.brick_phases?.transitions ?? [];
  const fromMacroPhases = input.macro_targets?.phases?.transitions ?? [];
  for (const t of fromBrickPhases) collected.push(t as Record<string, unknown>);
  for (const t of fromMacroPhases) collected.push(t as Record<string, unknown>);

  const map = new Map<string, MacroTargets>();
  for (const raw of collected) {
    const key = normalizeTransitionName(
      (raw.transition_name as string | undefined) ??
        (raw.transition_id as string | undefined),
    );
    if (!key) continue;

    const carbs = Number(raw.carbs_g ?? 0);
    const sodium = Number(raw.sodium_mg ?? 0);
    const water = Number(raw.water_ml ?? 0);
    const carbsLow = raw.carbs_low_g != null
      ? Number(raw.carbs_low_g)
      : undefined;
    const carbsHigh = raw.carbs_high_g != null
      ? Number(raw.carbs_high_g)
      : undefined;
    const sodiumLow = raw.sodium_low_mg != null
      ? Number(raw.sodium_low_mg)
      : undefined;
    const sodiumHigh = raw.sodium_high_mg != null
      ? Number(raw.sodium_high_mg)
      : undefined;
    const waterLow = raw.water_low_ml != null
      ? Number(raw.water_low_ml)
      : undefined;
    const waterHigh = raw.water_high_ml != null
      ? Number(raw.water_high_ml)
      : undefined;
    map.set(
      key,
      adjustTargetsForOverrides({
        carbs_g: Number.isFinite(carbs) ? carbs : 0,
        ...(carbsLow != null && Number.isFinite(carbsLow) &&
          { carbs_low_g: carbsLow }),
        ...(carbsHigh != null && Number.isFinite(carbsHigh) &&
          { carbs_high_g: carbsHigh }),
        sodium_mg: Number.isFinite(sodium) ? sodium : 0,
        ...(sodiumLow != null && Number.isFinite(sodiumLow) &&
          { sodium_low_mg: sodiumLow }),
        ...(sodiumHigh != null && Number.isFinite(sodiumHigh) &&
          { sodium_high_mg: sodiumHigh }),
        water_ml: Number.isFinite(water) ? water : 0,
        ...(waterLow != null && Number.isFinite(waterLow) &&
          { water_low_ml: waterLow }),
        ...(waterHigh != null && Number.isFinite(waterHigh) &&
          { water_high_ml: waterHigh }),
      }),
    );
  }
  return map;
}

// ============================================================================
// Transition Phase
// ============================================================================

/**
 * Generate transition-phase food selection for brick workout T1/T2 phases.
 * Uses LP solver with small targets (quick-consume foods like gels, drinks).
 * Skips food generation when all targets are 0 (sprint/olympic distance).
 */
async function generateTransitionPhase(
  supabase: ReturnType<typeof createServiceClient>,
  transitionName: string,
  targets: MacroTargets,
  totalDurationMinutes: number,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  allergies?: string[],
  dietaryPreference?: string,
  gutTrainingLevel?: string,
): Promise<LPPhaseResult> {
  console.log(
    `[PLAN-V3-BRICK] Generating transition phase ${transitionName}: carbs=${targets.carbs_g}g, sodium=${targets.sodium_mg}mg, water=${targets.water_ml}ml`,
  );

  // Skip food generation when all targets are 0 (sprint/olympic distance)
  if (
    targets.carbs_g === 0 && targets.sodium_mg === 0 && targets.water_ml === 0
  ) {
    console.log(
      `[PLAN-V3-BRICK] ${transitionName}: all targets are 0, returning empty foods`,
    );
    return { foods: [] };
  }

  const resolvedGutTrainingLevel = (
    gutTrainingLevel === "low" ||
      gutTrainingLevel === "moderate" ||
      gutTrainingLevel === "high"
      ? gutTrainingLevel
      : "moderate"
  ) as GutTrainingLevel;

  try {
    const [templates, constrainedFoods] = await Promise.all([
      getDuringWorkoutTemplates(supabase),
      getTemplateFoodsForDuringWithConstraints(
        supabase,
        "triathlon",
        likedFoods,
        willingToTryFoods,
        dislikedFoods,
        deviceId,
        allergies,
        dietaryPreference,
      ),
    ]);
    const foodsByName = buildFoodsByNameMap(constrainedFoods);
    const templateCandidates = selectTemplateCandidates(
      templates,
      "triathlon",
      totalDurationMinutes,
      resolvedGutTrainingLevel,
      foodsByName,
      buildPreferenceSet(likedFoods),
      buildPreferenceSet(willingToTryFoods),
      buildPreferenceSet(dislikedFoods),
      allergies,
      dietaryPreference,
    ).filter((template) => template.template_number === 0);

    if (templateCandidates.length > 0) {
      const templateResult = generateDuringPhaseTemplate(
        templateCandidates[0],
        foodsByName,
        targets,
        60,
        resolvedGutTrainingLevel,
      );
      if (templateResult) {
        console.log(
          `[PLAN-V3-BRICK] ${transitionName} template solved with template 0 (${templateResult.template_name})`,
        );
        return { foods: templateResult.foods };
      }
      console.log(
        `[PLAN-V3-BRICK] ${transitionName} template 0 failed validation, using transition LP fallback`,
      );
    } else {
      console.log(
        `[PLAN-V3-BRICK] ${transitionName}: template 0 not available for total duration ${totalDurationMinutes}min, using transition LP fallback`,
      );
    }
  } catch (err) {
    console.warn(
      `[PLAN-V3-BRICK] ${transitionName} template 0 path failed, using transition LP fallback:`,
      err,
    );
  }

  const foods = await getTransitionFoods(
    supabase,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    allergies,
    dietaryPreference,
  );

  if (foods.length === 0) {
    console.log(
      `[PLAN-V3-BRICK] No transition foods available for ${transitionName}`,
    );
    return { foods: [] };
  }

  console.log(
    `[PLAN-V3-BRICK] ${transitionName}: ${foods.length} transition foods available`,
  );

  // Use LP solver with 'during' phase weights (transition is similar to during)
  const weights = getOptimizationWeights("running", "during");
  const modelOptions = {
    maxFoodItems: 3,
    maxServingsCap: 2,
    selectionPenalty: 0.5,
    enforceWaterMin: true,
  };

  const model = buildLPModel(
    foods,
    targets,
    "during",
    weights,
    undefined,
    undefined,
    modelOptions,
  );
  const solution = solveLPModel(model, foods, "during");

  if (solution && solution.foods.length > 0) {
    console.log(
      `[PLAN-V3-BRICK] ${transitionName} LP solved: ${solution.foods.length} foods`,
    );
    return { foods: solution.foods };
  }

  // Fallback to greedy
  console.log(
    `[PLAN-V3-BRICK] ${transitionName} LP failed, using greedy fallback`,
  );
  const greedyResult = greedyFallback(foods, targets, "during");
  return { foods: greedyResult.foods };
}

// ============================================================================
// Brick Workout Handler
// ============================================================================

/**
 * Handle brick workout plan generation.
 * Generates before (shared), per-segment during phases, transition phases, and after.
 */
export async function handleBrickPlan(
  supabase: ReturnType<typeof createServiceClient>,
  input: PlanInputV2,
  planId: string,
): Promise<Response> {
  const segments = input.brick_segments ?? [];
  if (segments.length === 0) {
    console.log(
      "[PLAN-V3-BRICK] No brick_segments provided, falling back to standard plan",
    );
    throw new Error("No brick_segments provided for brick activity");
  }

  console.log(
    `[PLAN-V3-BRICK] Starting brick plan generation with ${segments.length} segments`,
  );

  // 1. Generate before phase (shared across all segments — Algorithm C)
  console.log(
    `[PLAN-V3-BRICK] Before phase input: pre_run carbs=${input.macro_targets.pre_run?.carbs_g}, water=${input.macro_targets.pre_run?.water_ml}, hours_before=${input.hours_before}`,
  );
  const beforeResult = await generateBeforePhaseV3(supabase, input);
  const beforeSubPhases = Object.keys(beforeResult);
  const beforeFoodCount = beforeSubPhases.reduce((sum, key) => {
    const sp = (beforeResult as Record<string, { foods?: unknown[] }>)[key];
    return sum + (sp?.foods?.length ?? 0);
  }, 0);
  console.log(
    `[PLAN-V3-BRICK] Before phase result: sub-phases=[${
      beforeSubPhases.join(",")
    }], total foods=${beforeFoodCount}`,
  );
  const beforeValidation = validatePhaseResultAgainstTargets(
    flattenBeforeFoods(
      beforeResult as Record<string, { foods?: FoodResult[] }>,
    ),
    input.macro_targets.pre_run,
    "before",
  );
  if (!beforeValidation.ok) {
    console.warn(
      `[PLAN-V3-BRICK] Before phase out of range (non-fatal): ${
        beforeValidation.issues.join("; ")
      }`,
    );
  }

  // 2. Generate during phase for each segment + transitions between them
  const duringSegments: Record<string, FoodResult[]> = {};
  const transitions: Record<string, FoodResult[]> = {};
  const segmentTargetsList: Array<{
    segment_order: number;
    sport: string;
    carbs_g: number;
    carbs_low_g?: number;
    carbs_high_g?: number;
    sodium_mg: number;
    sodium_low_mg?: number;
    sodium_high_mg?: number;
    water_ml: number;
    water_low_ml?: number;
    water_high_ml?: number;
  }> = [];
  const transitionTargetsList: Array<{
    transition_name: string;
    carbs_g: number;
    carbs_low_g?: number;
    carbs_high_g?: number;
    sodium_mg: number;
    sodium_low_mg?: number;
    sodium_high_mg?: number;
    water_ml: number;
    water_low_ml?: number;
    water_high_ml?: number;
  }> = [];
  const transitionTargetOverrides = collectTransitionTargets(input);

  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];
    const segmentOrder = i + 1;
    const sport = segment.sport as ActivityType;
    const segmentTargets: MacroTargets = adjustTargetsForOverrides({
      carbs_g: segment.macro_targets.carbs_g,
      sodium_mg: segment.macro_targets.sodium_mg,
      water_ml: segment.macro_targets.water_ml,
      ...(segment.macro_targets.carbs_low_g != null &&
        { carbs_low_g: segment.macro_targets.carbs_low_g }),
      ...(segment.macro_targets.carbs_high_g != null &&
        { carbs_high_g: segment.macro_targets.carbs_high_g }),
      ...(segment.macro_targets.sodium_low_mg != null &&
        { sodium_low_mg: segment.macro_targets.sodium_low_mg }),
      ...(segment.macro_targets.sodium_high_mg != null &&
        { sodium_high_mg: segment.macro_targets.sodium_high_mg }),
      ...(segment.macro_targets.water_low_ml != null &&
        { water_low_ml: segment.macro_targets.water_low_ml }),
      ...(segment.macro_targets.water_high_ml != null &&
        { water_high_ml: segment.macro_targets.water_high_ml }),
    });

    console.log(
      `[PLAN-V3-BRICK] Segment ${segmentOrder} (${sport}): carbs=${segmentTargets.carbs_g}g, sodium=${segmentTargets.sodium_mg}mg, water=${segmentTargets.water_ml}ml`,
    );

    segmentTargetsList.push({
      segment_order: segmentOrder,
      sport: segment.sport,
      carbs_g: segmentTargets.carbs_g,
      ...(segmentTargets.carbs_low_g != null &&
        { carbs_low_g: segmentTargets.carbs_low_g }),
      ...(segmentTargets.carbs_high_g != null &&
        { carbs_high_g: segmentTargets.carbs_high_g }),
      sodium_mg: segmentTargets.sodium_mg,
      ...(segmentTargets.sodium_low_mg != null &&
        { sodium_low_mg: segmentTargets.sodium_low_mg }),
      ...(segmentTargets.sodium_high_mg != null &&
        { sodium_high_mg: segmentTargets.sodium_high_mg }),
      water_ml: segmentTargets.water_ml,
      ...(segmentTargets.water_low_ml != null &&
        { water_low_ml: segmentTargets.water_low_ml }),
      ...(segmentTargets.water_high_ml != null &&
        { water_high_ml: segmentTargets.water_high_ml }),
    });

    // Generate during phase for this segment
    const duringResult = await generateDuringPhase(
      supabase,
      segmentTargets,
      sport,
      input.liked_foods,
      input.willing_to_try_foods,
      input.disliked_foods,
      input.device_id,
      input.allergies,
      input.dietary_preference,
      input.gut_training_level,
      segment.duration_minutes,
    );

    duringSegments[String(segmentOrder)] = duringResult.foods;

    // Generate transition after each segment (except the last)
    if (i < segments.length - 1) {
      const transitionName = `T${i + 1}`;
      const transitionTargets = transitionTargetOverrides.get(transitionName) ??
        adjustTargetsForOverrides(getTransitionTargets(segments, i));

      transitionTargetsList.push({
        transition_name: transitionName,
        carbs_g: transitionTargets.carbs_g,
        ...(transitionTargets.carbs_low_g != null &&
          { carbs_low_g: transitionTargets.carbs_low_g }),
        ...(transitionTargets.carbs_high_g != null &&
          { carbs_high_g: transitionTargets.carbs_high_g }),
        sodium_mg: transitionTargets.sodium_mg,
        ...(transitionTargets.sodium_low_mg != null &&
          { sodium_low_mg: transitionTargets.sodium_low_mg }),
        ...(transitionTargets.sodium_high_mg != null &&
          { sodium_high_mg: transitionTargets.sodium_high_mg }),
        water_ml: transitionTargets.water_ml,
        ...(transitionTargets.water_low_ml != null &&
          { water_low_ml: transitionTargets.water_low_ml }),
        ...(transitionTargets.water_high_ml != null &&
          { water_high_ml: transitionTargets.water_high_ml }),
      });

      const transitionResult = await generateTransitionPhase(
        supabase,
        transitionName,
        transitionTargets,
        segments.reduce((sum, s) => sum + s.duration_minutes, 0),
        input.liked_foods,
        input.willing_to_try_foods,
        input.disliked_foods,
        input.device_id,
        input.allergies,
        input.dietary_preference,
        input.gut_training_level,
      );

      const transitionValidation = validatePhaseResultAgainstTargets(
        transitionResult.foods,
        transitionTargets,
        "during",
      );
      if (!transitionValidation.ok) {
        console.warn(
          `[PLAN-V3-BRICK] ${transitionName} out of range (non-fatal): ${
            transitionValidation.issues.join("; ")
          }`,
        );
      }

      transitions[transitionName] = transitionResult.foods;
    }
  }

  // 3. Generate after phase (use 'running' activity type — brick recovery is run-like)
  const afterResult = input.macro_targets.post_run
    ? await generateLPPhase(
      supabase,
      "after",
      input.macro_targets.post_run,
      "running",
      input.liked_foods,
      input.willing_to_try_foods,
      input.disliked_foods,
      input.device_id,
      undefined,
      undefined,
      input.allergies,
      input.dietary_preference,
    )
    : { foods: [] as FoodResult[] };
  if (input.macro_targets.post_run) {
    const afterValidation = validatePhaseResultAgainstTargets(
      afterResult.foods,
      input.macro_targets.post_run,
      "after",
    );
    if (!afterValidation.ok) {
      console.warn(
        `[PLAN-V3-BRICK] After phase out of range (non-fatal): ${
          afterValidation.issues.join("; ")
        }`,
      );
    }
  }

  // 4. Build response matching V1 brick format
  const response = {
    success: true,
    plan_id: planId,
    activity_type: "brick",
    plan: {
      before: beforeResult,
      during_segments: duringSegments,
      transitions: transitions,
      after: afterResult.foods,
    },
    macro_targets: {
      pre_run: input.macro_targets.pre_run,
      during_run: input.macro_targets.during_run,
      post_run: input.macro_targets.post_run,
      activity_type: "brick",
      phases: {
        before: input.macro_targets.pre_run,
        during_segments: segmentTargetsList,
        transitions: transitionTargetsList,
        after: input.macro_targets.post_run,
      },
    },
  };

  console.log(
    `[PLAN-V3-BRICK] Brick plan generated successfully (plan_id=${planId}, segments=${segments.length}, transitions=${
      Object.keys(transitions).length
    })`,
  );

  return jsonResponse(response);
}
