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
  PHASE_TIMING_LABELS,
  solveLPModel,
} from "../_shared/nutrition/index.ts";
import { applyElectrolyteWaterPairing } from "../_shared/nutrition/electrolyte-water-pairing.ts";
import { getEssentialFoods } from "../_shared/nutrition/food-queries.ts";
import { logFormulaCascade } from "../_shared/nutrition/formula-decision.ts";
import {
  buildFoodsByNameMap,
  getDuringWorkoutTemplates,
  getTemplateFoodsForDuringWithConstraints,
  getTransitionFoods,
} from "../_shared/nutrition/template-food-queries.ts";
import {
  generateDuringPhaseTemplate,
  normalizeGutTrainingLevel,
  selectTemplateCandidates,
} from "../_shared/nutrition/during-template-solver.ts";
import { generateBeforePhaseV3 } from "./before-phase.ts";
import { generateDuringPhase } from "./during-phase.ts";
import { generateAfterPhase } from "./after-phase.ts";
import {
  buildPlanGenerationLogRow,
  insertPlanGenerationLog,
} from "./plan-generation-log.ts";
import {
  flattenBeforeFoods,
  validatePhaseResultAgainstTargets,
} from "./validation.ts";
import type { LPPhaseResult, PlanInputV2 } from "./types.ts";
import type { UserPinSets } from "../_shared/nutrition/pins.ts";
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

export function normalizeTransitionName(name?: string | null): string | null {
  if (!name) return null;
  const trimmed = name.trim();
  if (!trimmed) return null;
  const match = /^t?(\d+)$/i.exec(trimmed);
  if (!match) return trimmed;
  return `T${match[1]}`;
}

// Exported for the R8 producer-shaped seam test (transition-seam.test.ts):
// the generate-macros-v4 payload's transition keys must equal this
// function's lookup keys — a single-engine vector cannot see that seam.
export function collectTransitionTargets(
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

  const resolvedGutTrainingLevel = normalizeGutTrainingLevel(gutTrainingLevel);

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
        buildPreferenceSet(dislikedFoods),
      );
      if (templateResult) {
        console.log(
          `[PLAN-V3-BRICK] ${transitionName} template solved with template 0 (${templateResult.template_name})`,
        );
        // Transitions are not a pinnable scope (a T1/T2 window has no
        // activity_type × duration_bracket a pin can target), so template 0 IS
        // the transition's default formula — there is no user_pin tier here.
        logFormulaCascade({
          phase: `transition:${transitionName}`,
          source: "default_formula",
          templateId: templateResult.template_id,
          templateName: templateResult.template_name,
          reason: "transitions_are_not_pinnable",
        });
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
    // No deviceId: transition foods come from the curated `template_foods`
    // catalog only — `user_foods` is not a plan-generation source.
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
  // C4 (docs/ssot/spec/domain/catalog-conventions.md, RULED Xuan
  // 2026-09-01): max 2 items per transition — the C2 pairing water row is
  // appended AFTER the LP, giving the ruled "2 items + water". Whole
  // consumable units ride the catalog's is_indivisible flags (C3) through
  // the solver's whole-serving rounding.
  const modelOptions = {
    maxFoodItems: 2,
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
    logFormulaCascade({
      phase: `transition:${transitionName}`,
      source: "solver",
      reason: "template_0_unavailable",
    });
    return { foods: solution.foods };
  }

  // Fallback to greedy
  console.log(
    `[PLAN-V3-BRICK] ${transitionName} LP failed, using greedy fallback`,
  );
  logFormulaCascade({
    phase: `transition:${transitionName}`,
    source: "solver",
    reason: "template_0_unavailable_and_lp_failed",
  });
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
  /** Formula Kit pins, fetched by the caller. Plumbed through the brick
   * handler 2026-07-21 — previously deferred, which silently ignored a
   * triathlete's pins across every phase. */
  userPins: UserPinSets,
  /** §10 test-traffic marker (the `x-mealvana-test` request header). */
  testSource: string | null = null,
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

  const pinsActive = userPins.beforePinIds.size + userPins.duringPinIds.size +
      userPins.afterPinIds.size > 0;
  const emitEphemeralDefault = input.emit_ephemeral_default_formula === true;

  // 1. Generate before phase (shared across all segments — Algorithm C)
  console.log(
    `[PLAN-V3-BRICK] Before phase input: pre_run carbs=${input.macro_targets.pre_run?.carbs_g}, water=${input.macro_targets.pre_run?.water_ml}, hours_before=${input.hours_before}`,
  );
  const beforeResult = await generateBeforePhaseV3(supabase, {
    ...input,
    pinned_food_template_ids: userPins.beforePinIds,
    personal_formula_pins: userPins.personalFormulas,
  });
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
  // §10 / bench B-2: record each segment's cascade path — during_path alone
  // ("brick") left brick coverage unmeasurable.
  const duringSegmentPaths: Record<string, string | null> = {};
  // Segment shortfalls ride as a SIBLING key (additive; old clients ignore it)
  // so brick segments get the same honest-shortfall contract as single-
  // activity during phases instead of silently dropping them. 2026-07-21.
  const duringSegmentShortfalls: Record<
    string,
    NonNullable<LPPhaseResult["shortfalls"]>
  > = {};
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
      userPins.duringPinIds,
      pinsActive,
      userPins.personalFormulas,
      emitEphemeralDefault,
    );

    // Invariant: electrolyte never ships without water (see
    // `electrolyte-water-pairing.ts`). Each brick segment is its own phase.
    duringSegmentPaths[String(segmentOrder)] = duringResult.generation_path ??
      null;
    duringSegments[String(segmentOrder)] = await applyElectrolyteWaterPairing(
      duringResult.foods,
      {
        fluidCeilingMl: segmentTargets.water_high_ml,
        timing: PHASE_TIMING_LABELS.during,
        logPrefix: `[PLAN-V3-BRICK] Segment ${segmentOrder}`,
      },
      () => getEssentialFoods(supabase, sport, "during"),
    );
    if (duringResult.shortfalls && duringResult.shortfalls.length > 0) {
      duringSegmentShortfalls[String(segmentOrder)] = duringResult.shortfalls;
    }

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

      // Invariant: electrolyte never ships without water — transitions are
      // exactly where a lone salt tablet is most tempting to the solver.
      transitionResult.foods = await applyElectrolyteWaterPairing(
        transitionResult.foods,
        {
          fluidCeilingMl: transitionTargets.water_high_ml,
          timing: PHASE_TIMING_LABELS.during,
          logPrefix: `[PLAN-V3-BRICK] ${transitionName}`,
        },
        () => getEssentialFoods(supabase, "triathlon", "during"),
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

  // 3. Generate after phase (use 'running' activity type — brick recovery is
  // run-like). Uses the same recovery-template trigger design as
  // single-activity plans (was an LP dose path until 2026-07-21, which gave
  // brick athletes solver-dosed foods instead of the curated recovery
  // templates and ignored their After pins).
  const afterResult = input.macro_targets.post_run
    ? await generateAfterPhase(
      supabase,
      input.macro_targets.post_run,
      "running",
      input.liked_foods,
      input.willing_to_try_foods,
      input.disliked_foods,
      input.device_id,
      input.allergies,
      input.dietary_preference,
      userPins.afterPinIds,
      pinsActive,
      userPins.personalFormulas,
      emitEphemeralDefault,
    )
    : { foods: [] as FoodResult[] } as LPPhaseResult;
  // Invariant: electrolyte never ships without water.
  afterResult.foods = await applyElectrolyteWaterPairing(
    afterResult.foods,
    {
      fluidCeilingMl: input.macro_targets.post_run?.water_high_ml,
      timing: PHASE_TIMING_LABELS.after,
      logPrefix: "[PLAN-V3-BRICK] After",
    },
    () => getEssentialFoods(supabase, "running", "after"),
  );
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
      ...(Object.keys(duringSegmentShortfalls).length > 0 &&
        { during_segment_shortfalls: duringSegmentShortfalls }),
      transitions: transitions,
      after: afterResult.foods,
      // Additive siblings, same contract as single-activity plans; old
      // clients ignore them. 2026-07-21.
      after_metadata: afterResult.template_metadata ?? null,
      ...(afterResult.shortfalls && afterResult.shortfalls.length > 0
        ? { after_shortfalls: afterResult.shortfalls }
        : {}),
      ...(afterResult.pin_decision
        ? { after_pin_decision: afterResult.pin_decision }
        : {}),
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

  // Ledger: one best-effort row per brick plan (parity with single-activity;
  // brick was unlogged until 2026-07-21). Segment foods/shortfalls are
  // flattened into the during slot; the path is tagged 'brick'.
  const allSegmentFoods: FoodResult[] = Object.values(duringSegments).flat();
  const allSegmentShortfalls = Object.values(duringSegmentShortfalls).flat();
  const ledgerWrite = insertPlanGenerationLog(
    supabase,
    buildPlanGenerationLogRow({
      planId,
      input,
      activityType: "brick",
      beforeFoods: flattenBeforeFoods(
        beforeResult as Record<string, { foods?: FoodResult[] }>,
      ),
      duringResult: {
        foods: allSegmentFoods,
        generation_path: "brick",
        ...(allSegmentShortfalls.length > 0 &&
          { shortfalls: allSegmentShortfalls }),
      },
      // §10: before/after paths, per-segment during paths, test marker.
      beforeResult: beforeResult as Record<
        string,
        { foods?: FoodResult[]; pin_decision?: Record<string, unknown> }
      >,
      duringSegmentPaths,
      afterResult,
      warnings: [],
      testSource,
    }),
  );
  // deno-lint-ignore no-explicit-any
  const runtime = (globalThis as any).EdgeRuntime;
  if (typeof runtime?.waitUntil === "function") {
    runtime.waitUntil(ledgerWrite);
  } else {
    await ledgerWrite;
  }

  return jsonResponse(response);
}
