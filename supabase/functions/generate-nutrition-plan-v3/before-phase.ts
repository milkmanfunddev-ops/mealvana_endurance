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
import {
  getActiveSubPhases,
  selectPreWorkoutFoods,
  splitTargets,
} from "../generate-macros-v4/pre-workout.ts";
import type {
  BeforePhaseResult,
  SubPhaseResult,
} from "../_shared/nutrition/templates/types.ts";
import { getSubPhaseTimingLabel } from "../_shared/nutrition/templates/pre-workout-targets.ts";
import type { PersonalFormulaPin } from "../_shared/nutrition/pins.ts";
import {
  matchBeforePersonalFormulaForSlot,
  personalFormulaToFoodResults,
} from "../_shared/nutrition/personal-formula-pins.ts";
import {
  backfillPinnedFluidsAndSodium,
  fluidSodiumDeficits,
} from "../_shared/nutrition/pin-backfill.ts";
import { getEssentialFoods } from "../_shared/nutrition/food-queries.ts";
import { logFormulaCascade } from "../_shared/nutrition/formula-decision.ts";
import { applyElectrolyteWaterPairing } from "../_shared/nutrition/electrolyte-water-pairing.ts";

import { fetchPreWorkoutTemplates, fetchTemplateFoodsByName } from "./before-phase-db.ts";
import { reconcileBeforePhaseAfterPins } from "./before-phase-reconcile.ts";
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
  /** Pre-workout template ids the user has actively pinned. When in scope
   * (template.time_window matches a sub_phase's window), bypasses all
   * preference / diet / scale-clamp filters. Optional; omit or pass empty
   * Set for pre-pin behavior. Formula Kit PR 2 substep 5b. */
  pinned_food_template_ids?: Set<string>;
  /** User's pinned personal formulas (any phase). In-scope before ones overlay
   * their matching sub-phase slot after Algorithm C runs (per-slot, since the
   * before phase can return meal + snack + top_up). Formula Kit personalization. */
  personal_formula_pins?: PersonalFormulaPin[];
  /** Client opt-in for default-formula telemetry on the before phase. Was
   * silently dropped on this fallback path until 2026-07-29: plan-v3 called
   * `selectPreWorkoutFoods` without it, so a plan generated WITHOUT
   * `pre_run_selections` (no macros-v4 round-trip — e.g. a re-generate, or the
   * brick handler) lost every before-phase `pin_decision` for an unpinned
   * user. Now that the client no longer pre-computes auto-pins, that was the
   * common path. */
  emit_ephemeral_default_formula?: boolean;
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
      input.pinned_food_template_ids,
      input.emit_ephemeral_default_formula === true,
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

  // 8. Overlay pinned personal formulas onto their matching sub-phase slot.
  //
  // A before personal formula carries a single timing tag (full_meal / snack /
  // top_up). The before phase can emit up to three slots (meal + snack +
  // top_up) for a long-lead-time plan, so honoring is PER-SLOT, not a
  // whole-phase early return like during/after:
  //   • anything pinned for an active sub-phase replaces that slot's foods
  //     (honored unconditionally — its components carry their own macros);
  //   • a sub-phase with no matching pin stays algorithmic;
  //   • a pin whose timing isn't an active sub-phase this plan doesn't fire;
  //   • an untagged before pin is skipped (timing is required).
  const personalPins = input.personal_formula_pins;
  const pinnedSlots = new Set<"meal" | "snack" | "top_up">();
  if (personalPins && personalPins.length > 0) {
    const activeSlots = getActiveSubPhases(input.hours_before);
    // Essential foods (water/salt) for the fluid/sodium backfill — fetched
    // once, lazily, only when some slot's pinned formula runs short.
    let essentialsPool: Awaited<ReturnType<typeof getEssentialFoods>> | null =
      null;
    for (const slot of activeSlots) {
      const formula = matchBeforePersonalFormulaForSlot(personalPins, slot);
      if (!formula) continue;
      const slotTargets = phaseTargetsMap.get(slot) ?? {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 0,
        water_ml: 0,
      };
      // Scale the formula's components uniformly to the slot's carb target
      // (decided 2026-06-12: all phases scale; authored quantities are the
      // formula's composition ratio, not exact amounts).
      let foods = personalFormulaToFoodResults(
        formula,
        getSubPhaseTimingLabel(slot, input.hours_before),
        slotTargets.carbs_g,
      );
      if (foods.length === 0) {
        // Matched pin, but the formula rendered zero components (e.g. an
        // empty/corrupt `components` array on the pinned row) — previously
        // this silently fell through to the algorithmic selection with no
        // trace in logs or the wire response (item 12, 2026-07-04). Surface
        // it on both channels so it's actually debuggable/visible to the
        // client's pin banner.
        console.warn(
          `[PLAN-V3] Before ${slot}: pinned personal formula "${formula.name}" ` +
            `(${formula.id}) matched scope but rendered 0 components — ` +
            `keeping algorithmic selection for this slot`,
        );
        const existing = slot === "meal"
          ? beforeResult.meal
          : slot === "snack"
          ? beforeResult.snack
          : beforeResult.top_up;
        if (existing) {
          existing.pin_decision = {
            used_pin: false,
            decision_source: "default_formula",
            pinned_template_id: null,
            pinned_template_name: null,
            fallthrough_reason: "personal_formula_empty",
            default_fallthrough_reason: "personal_formula_empty",
            pin_set_size: 1,
          };
        }
        logFormulaCascade({
          phase: `before:${slot}`,
          source: "default_formula",
          reason: "personal_formula_empty",
          pinSetSize: 1,
        });
        continue; // empty formula → keep algorithmic
      }

      // Failsafe: backfill fluids/sodium up to the slot's targets — the
      // overlay bypasses Algorithm C's fill steps (see pin-backfill.ts).
      const deficits = fluidSodiumDeficits(foods, slotTargets);
      if (deficits.needsBackfill) {
        // Before phase has no activity axis — essential foods (water/salt)
        // are activity-independent anyway.
        essentialsPool ??= await getEssentialFoods(supabase, "running", "before");
        foods = backfillPinnedFluidsAndSodium(
          foods,
          slotTargets,
          essentialsPool,
          getSubPhaseTimingLabel(slot, input.hours_before),
          `[PLAN-V3] Before ${slot}`,
        );
      }

      const pinnedSubPhase: SubPhaseResult = {
        sub_phase_type: slot,
        targets: slotTargets,
        foods,
        template_id: formula.id,
        template_name: formula.name,
        pin_decision: {
          used_pin: true,
          decision_source: "personal_formula",
          pinned_template_id: formula.id,
          pinned_template_name: formula.name,
          fallthrough_reason: null,
          pin_set_size: 1,
        },
      };
      logFormulaCascade({
        phase: `before:${slot}`,
        source: "personal_formula",
        templateId: formula.id,
        templateName: formula.name,
        pinSetSize: 1,
      });

      if (slot === "meal") beforeResult.meal = pinnedSubPhase;
      else if (slot === "snack") beforeResult.snack = pinnedSubPhase;
      else if (slot === "top_up") beforeResult.top_up = pinnedSubPhase;
      pinnedSlots.add(slot);

      console.log(
        `[PLAN-V3] Before ${slot}: honoring pinned personal formula ` +
          `"${formula.name}" (${foods.length} components, scaled to ` +
          `${slotTargets.carbs_g}g carbs), overlaying slot`,
      );
    }
  }

  // 9. Reconcile the phase after pin overlays: Algorithm C sized the top_up's
  // drink/electrolyte against ITS OWN meal + snack; when pins replaced those
  // slots, the stale gap-fill can push the phase outside every range at once
  // (bug 3abe3fdb754c818c93e8fbbd801dae8e). Trims non-pinned excess toward
  // the targets and fills a carb-floor gap from the universal add-on pool.
  if (pinnedSlots.size > 0) {
    reconcileBeforePhaseAfterPins(
      beforeResult,
      targets,
      pinnedSlots,
      new Set(input.disliked_foods ?? []),
    );
  }

  // 10. Invariant: an electrolyte never ships without water alongside it.
  //
  // Algorithm C picks the top_up drink (`pickDrink`) and the electrolyte
  // (`pickElectrolyte`) INDEPENDENTLY — `pickDrink` returning null does not
  // stop `pickElectrolyte` from firing, so a dry tablet can land in a slot
  // with no drink at all. This pass is what closes that gap; see
  // `electrolyte-water-pairing.ts`.
  //
  // The before phase has no per-slot fluid band (SubPhaseTargets carries only
  // a point `water_ml`), so the ceiling is the PHASE-level `water_high_ml`
  // less whatever the other slots already deliver.
  await ensureBeforePhaseWaterPairing(supabase, beforeResult, targets, input);

  return beforeResult;
}

/** Total fluid across every before sub-phase. */
function beforePhaseFluidMl(result: BeforePhaseResult): number {
  return (["meal", "snack", "top_up"] as const).reduce(
    (sum, slot) =>
      sum +
      (result[slot]?.foods ?? []).reduce((s, f) => s + (f.fluids_ml || 0), 0),
    0,
  );
}

/**
 * Apply the electrolyte↔water pairing invariant to each before sub-phase,
 * charging every addition against the shared phase fluid ceiling.
 */
async function ensureBeforePhaseWaterPairing(
  supabase: ReturnType<typeof createServiceClient>,
  result: BeforePhaseResult,
  targets: PreWorkoutTargets,
  input: BeforePhaseInput,
): Promise<void> {
  let essentialsPool: Awaited<ReturnType<typeof getEssentialFoods>> | null =
    null;
  const loadPool = async () => {
    essentialsPool ??= await getEssentialFoods(supabase, "running", "before");
    return essentialsPool;
  };

  for (const slot of ["meal", "snack", "top_up"] as const) {
    const subPhase = result[slot];
    if (!subPhase || subPhase.foods.length === 0) continue;

    const slotFluid = subPhase.foods.reduce(
      (s, f) => s + (f.fluids_ml || 0),
      0,
    );
    const otherSlotsFluid = beforePhaseFluidMl(result) - slotFluid;
    const ceiling = targets.water_high_ml != null
      ? Math.max(0, targets.water_high_ml - otherSlotsFluid)
      : undefined;

    subPhase.foods = await applyElectrolyteWaterPairing(
      subPhase.foods,
      {
        fluidCeilingMl: ceiling,
        timing: getSubPhaseTimingLabel(slot, input.hours_before),
        logPrefix: `[PLAN-V3] Before ${slot}`,
      },
      loadPool,
    );
  }
}
