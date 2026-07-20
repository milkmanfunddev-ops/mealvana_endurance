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
  buildFoodsByNameMap,
  getDuringWorkoutTemplates,
  getTemplateElectrolyteFoods,
  getTemplateFoodsForDuringWithConstraints,
  getTemplateFoodsForPhase,
} from "../_shared/nutrition/template-food-queries.ts";
import { generateDuringPhaseRuleBased } from "../_shared/nutrition/during-rule-solver.ts";
import {
  type DuringWorkoutTemplate,
  filterPinnedTemplatesInScope,
  generateDuringPhaseTemplate,
  type GutTrainingLevel,
  selectTemplateCandidates,
} from "../_shared/nutrition/during-template-solver.ts";
import { buildPreferenceSet } from "../_shared/nutrition/food-utils.ts";
import type { PersonalFormulaPin } from "../_shared/nutrition/pins.ts";
import {
  collectPersonalFormulaSkips,
  matchPersonalFormulaPin,
  personalFormulaToFoodResults,
} from "../_shared/nutrition/personal-formula-pins.ts";
import {
  backfillPinnedFluidsAndSodium,
  fluidSodiumDeficits,
} from "../_shared/nutrition/pin-backfill.ts";
import { getEssentialFoods } from "../_shared/nutrition/food-queries.ts";
import type { LPPhaseResult } from "./types.ts";
import { validatePhaseResultAgainstTargets } from "./validation.ts";
import { generateLPPhase } from "./lp-phase.ts";

// ============================================================================
// Pin telemetry helpers
// ============================================================================

/**
 * Build the initial `pin_decision` skeleton for the During section.
 *
 * Contract (Formula Kit PR 2 #18):
 *   - `pinsSupplied === true` → emit `{ used_pin: false, no_pin_for_scope,
 *     pin_set_size: 0 }`. The skeleton is refined to `used_pin: true` (and
 *     a real `pin_set_size`) downstream if a pinned template fires.
 *   - `pinsSupplied === false` → return `undefined`. The result is then
 *     spread conditionally so `pin_decision` is omitted from the wire
 *     response — byte-identical to pre-pin v3 behavior.
 *
 * The key behaviour this locks in is the scenario-4 fix: when the user has
 * pins in OTHER scopes (e.g. Before) but zero pins for the During scope,
 * `pinsSupplied` is still true (driven by the orchestrator-level
 * `pinsActive` flag) and the During section emits an honest "no pin for
 * scope" decision instead of silently omitting `pin_decision`. Without
 * this, the activity-detail banner would show only Before rows and
 * silently skip the During row.
 *
 * Exported only for unit testing.
 */
export function initialDuringPinDecision(
  pinsSupplied: boolean,
): LPPhaseResult["pin_decision"] | undefined {
  if (!pinsSupplied) return undefined;
  return {
    used_pin: false,
    pinned_template_id: null,
    pinned_template_name: null,
    fallthrough_reason: "no_pin_for_scope",
    pin_set_size: 0,
  };
}

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
  dislikedFoods?: string[],
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
    dislikedFoods,
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
 * Collect the set of component food names belonging to pinned templates
 * **that are in scope for this workout**.
 *
 * Honor-pin policy (Formula Kit PR 2 5c): foods in this set must bypass the
 * dislike/allergen/diet filters in `getTemplateFoodsForDuringWithConstraints`
 * so that the pinned template's components remain available to the solver.
 * Filtering them out at the food-loading layer leaves the template-selection
 * layer with a pinned template whose components are absent from
 * `foodsByName`, causing the solver to silently substitute or zero them.
 *
 * Scope tightening (2026-05-28): the caller passes `inScopeTemplates` —
 * templates already filtered by activity × duration_bracket via
 * `filterPinnedTemplatesInScope`. Earlier versions of this function
 * iterated over **all** pinned ids regardless of scope, which would bypass
 * dislike/allergen filters for, e.g., cycling-only components when the
 * current workout was a run. The During food query applies sport-specific
 * scoping so polluting the pool with out-of-scope components is a real
 * issue; the after-phase analog is safer because post templates have no
 * duration brackets.
 */
function derivePinnedComponentNames(
  inScopeTemplates: DuringWorkoutTemplate[],
): Set<string> {
  if (inScopeTemplates.length === 0) return new Set();
  const names = new Set<string>();
  for (const t of inScopeTemplates) {
    for (const name of t.component_food_names ?? []) {
      names.add(name);
    }
  }
  return names;
}

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
  gutTrainingLevel?: GutTrainingLevel,
  durationMinutes?: number,
  /** During-workout template ids the user has actively pinned. When an
   * in-scope pin (activity × duration_bracket match) exists, the selector
   * bypasses all preference / diet / gut-training filters. Empty/undefined
   * for pre-pin behavior. Formula Kit PR 2 substep 5b. */
  pinnedTemplateIds?: Set<string>,
  /** Whether the user has any pins at all (across any scope). When true,
   * the During section emits `pin_decision` even if `pinnedTemplateIds`
   * for THIS scope is empty — so the client can show a row reading "No
   * pin found" for the During phase. Without this, a user who has only
   * Before pins would get a silently-missing During pin_decision (the
   * scenario-4 bug from 2026-05-24 smoke testing). When omitted, falls
   * back to the pre-#18 behavior (derive from local set size) so brick
   * handler and other callers stay unchanged. Formula Kit PR 2 #18. */
  pinsActive?: boolean,
  /** User's pinned personal formulas (any phase); during-phase ones in scope
   * are honored before the template solver. Formula Kit personalization. */
  personalFormulaPins?: PersonalFormulaPin[],
  /** When true, tag the selected system formula as an EPHEMERAL default-
   * formula pin on `pin_decision` (formula-first flip). Opt-in so only
   * clients that know to keep ephemeral decisions invisible receive them —
   * old clients omit it and stay byte-identical to pre-safety-net v3.
   * 2026-07-03. */
  emitEphemeralDefault = false,
): Promise<LPPhaseResult> {
  const phaseStart = performance.now();
  const elapsed = (start: number) => Math.round(performance.now() - start);

  // Pin telemetry default: when pins were supplied but never fire, we
  // surface `no_pin_for_scope` so the client knows the user has pins that
  // didn't apply to this workout. Refined to `used_pin: true` below if the
  // template selector returns a pinned template. Omitted entirely when no
  // pins were supplied (byte-identical to pre-pin v3).
  const pinsSupplied = pinsActive ??
    (pinnedTemplateIds !== undefined && pinnedTemplateIds.size > 0);
  // `pinInScopeCount` is refined once templates load (see below). At init we
  // don't yet know how many pins match scope — treat as 0 until we do.
  let pinInScopeCount = 0;
  let duringPinDecision: LPPhaseResult["pin_decision"] | undefined =
    initialDuringPinDecision(pinsSupplied);

  // Swimming: no during-phase nutrition
  if (activityType === "swimming") {
    console.log("[PLAN-V3] Swimming activity — skipping during phase");
    return {
      foods: [],
      by_hour_data: null,
      ...(duringPinDecision && { pin_decision: duringPinDecision }),
    };
  }

  console.log(
    `[PLAN-V3] Generating during phase (${activityType}, gut=${
      gutTrainingLevel ?? "n/a"
    }, duration=${durationMinutes ?? "n/a"}min)`,
  );

  // ---- Pinned personal formula (highest priority) ----
  // An in-scope pinned personal formula is honored unconditionally, emitting
  // its self-contained components and bypassing the template solver entirely.
  if (personalFormulaPins && personalFormulaPins.length > 0) {
    const match = matchPersonalFormulaPin(
      personalFormulaPins,
      "during",
      activityType,
      durationMinutes,
    );
    if (match) {
      // During formulas are quantity-less by design (decided 2026-06-11):
      // scale the components uniformly to the phase's carb target so the
      // amounts track workout duration, keeping the formula's composition.
      let foods = personalFormulaToFoodResults(
        match,
        "Throughout activity",
        targets.carbs_g,
      );
      // Failsafe: carb scaling alone can leave the plan under the phase's
      // fluid/sodium targets (the pin path bypasses the solver's water and
      // electrolyte fill steps). Backfill with the formula's own components
      // or essential foods (water/salt) so targets are always met.
      if (foods.length > 0) {
        const deficits = fluidSodiumDeficits(foods, targets);
        if (deficits.needsBackfill) {
          const essentials = await getEssentialFoods(
            supabase,
            activityType,
            "during",
          );
          foods = backfillPinnedFluidsAndSodium(
            foods,
            targets,
            essentials,
            "Throughout activity",
            "[PLAN-V3] During",
          );
        }
      }
      if (foods.length > 0) {
        console.log(
          `[PLAN-V3] During: honoring pinned personal formula "${match.name}" ` +
            `(${foods.length} components, scaled to ${targets.carbs_g}g carbs), ` +
            `bypassing template solver`,
        );
        return {
          foods,
          by_hour_data: null,
          pin_decision: {
            used_pin: true,
            pinned_template_id: match.id,
            pinned_template_name: match.name,
            fallthrough_reason: null,
            pin_set_size: 1,
          },
        };
      }
      // Matched pin, but the formula rendered zero components (e.g. an
      // empty/corrupt `components` array on the pinned row) — previously
      // this silently fell through to the template solver with no trace in
      // logs or the wire response (item 12, 2026-07-04). Surface it on both
      // channels, then continue to the template solver below as before.
      console.warn(
        `[PLAN-V3] During: pinned personal formula "${match.name}" ` +
          `(${match.id}) matched scope but rendered 0 components — ` +
          `falling through to template solver`,
      );
      duringPinDecision = {
        used_pin: false,
        pinned_template_id: null,
        pinned_template_name: null,
        fallthrough_reason: "personal_formula_empty",
        pin_set_size: 1,
      };
    } else {
      // No personal formula matched this workout's scope. Record WHY for each
      // formula the user authored for this phase, so the client can explain
      // the miss instead of silently showing a system formula.
      //
      // Critical: this must ride alongside whatever decision is emitted
      // downstream. A system pin firing later would otherwise overwrite the
      // whole decision with `used_pin: true`, and the user would see a green
      // "pinned formula used" banner naming a formula they never chose
      // (audit 2026-07-18).
      const skips = collectPersonalFormulaSkips(
        personalFormulaPins,
        "during",
        activityType,
        durationMinutes,
      );
      if (skips.length > 0) {
        for (const s of skips) {
          console.warn(
            `[PLAN-V3] During: personal formula "${s.name}" (${s.id}) ` +
              `skipped — ${s.reason}` +
              (s.reason === "duration_out_of_scope"
                ? ` (workout is ${s.workout_bracket}, formula targets ` +
                  `${(s.formula_durations ?? []).join(", ")})`
                : ""),
          );
        }
        duringPinDecision = {
          ...(duringPinDecision ?? {
            used_pin: false,
            pinned_template_id: null,
            pinned_template_name: null,
            fallthrough_reason: "no_pin_for_scope",
            pin_set_size: 0,
          }),
          skipped_personal_formulas: skips,
        };
      }
    }
  }

  // ---- Template solver (primary path) ----
  if (gutTrainingLevel && durationMinutes && durationMinutes > 0) {
    try {
      const templateQueryStart = performance.now();
      // Load templates first so we can derive pinned-component names before
      // querying foods. The foods query needs to know which foods to bypass
      // dislike/allergen/diet filters for (honor-pin policy, PR 2 5c).
      const templates = await getDuringWorkoutTemplates(supabase);
      // Compute in-scope pin count for analytics (pin_set_size). Mirrors the
      // scope filter used by `selectTemplateCandidates`. Updated lazily here
      // because we need templates loaded first. Formula Kit PR 2 substep 7.
      //
      // We reuse the same `pinnedInScope` list to derive component-name bypass
      // for the food loader (PR 2 5c) — scope-tightened 2026-05-28 so a
      // cycling pin doesn't leak its components past dislike/allergen filters
      // on a running workout. Out-of-scope pinned templates simply aren't
      // candidates for this generation, so their components have no business
      // bypassing the food-pool filters either.
      const pinnedInScope = pinsSupplied
        ? filterPinnedTemplatesInScope(
          templates,
          activityType,
          durationMinutes,
          pinnedTemplateIds ?? new Set(),
        )
        : [];
      if (pinsSupplied) {
        pinInScopeCount = pinnedInScope.length;
        if (duringPinDecision) {
          duringPinDecision = {
            ...duringPinDecision,
            pin_set_size: pinInScopeCount,
          };
        }
      }
      const pinnedComponentNames = derivePinnedComponentNames(pinnedInScope);
      const constrainedFoods = await getTemplateFoodsForDuringWithConstraints(
        supabase,
        activityType,
        likedFoods,
        willingToTryFoods,
        dislikedFoods,
        deviceId,
        allergies,
        dietaryPreference,
        pinnedComponentNames,
      );
      console.log(
        `[PLAN-V3-TIMING] during_template_queries completed in ${
          elapsed(templateQueryStart)
        }ms ` +
          `(templates=${templates.length}, foods=${constrainedFoods.length}, ` +
          `pinnedComponents=${pinnedComponentNames.size})`,
      );

      if (templates.length > 0 && constrainedFoods.length > 0) {
        const templateSelectStart = performance.now();
        const foodsByName = buildFoodsByNameMap(constrainedFoods);
        const likedSet = buildPreferenceSet(likedFoods);
        const willingSet = buildPreferenceSet(willingToTryFoods);
        const dislikedSet = buildPreferenceSet(dislikedFoods);

        const templateCandidates = selectTemplateCandidates(
          templates,
          activityType,
          durationMinutes,
          gutTrainingLevel,
          foodsByName,
          likedSet,
          willingSet,
          dislikedSet,
          allergies,
          dietaryPreference,
          pinnedTemplateIds,
        );

        // Refine pin telemetry: the selector returns ONLY pinned templates
        // when pin override fires (per its doc), so membership of
        // candidate[0] in the pin set tells us whether a pin actually fired.
        // If no pin fired, the `no_pin_for_scope` default stays in place.
        if (pinsSupplied) {
          const first = templateCandidates[0];
          if (
            first !== undefined && (pinnedTemplateIds?.has(first.id) ?? false)
          ) {
            duringPinDecision = {
              used_pin: true,
              pinned_template_id: first.id,
              pinned_template_name: first.name,
              fallthrough_reason: null,
              pin_set_size: pinInScopeCount,
              // Preserve any personal-formula skips recorded above. A system
              // pin firing here does NOT mean the user got what they asked
              // for — before this was carried forward, the response claimed
              // `used_pin: true` naming this system pin while the user's own
              // formula had been silently dropped (audit 2026-07-18).
              ...(duringPinDecision?.skipped_personal_formulas && {
                skipped_personal_formulas:
                  duringPinDecision.skipped_personal_formulas,
              }),
            };
          }
        }
        console.log(
          `[PLAN-V3-TIMING] during_template_select completed in ${
            elapsed(templateSelectStart)
          }ms ` +
            `(candidates=${templateCandidates.length}, selected=${
              templateCandidates[0]?.template_number ?? "none"
            })`,
        );

        if (templateCandidates.length > 0) {
          const templateSolveStart = performance.now();
          let templateResult: ReturnType<typeof generateDuringPhaseTemplate> =
            null;
          let triedTemplates = 0;
          for (const template of templateCandidates) {
            triedTemplates++;
            templateResult = generateDuringPhaseTemplate(
              template,
              foodsByName,
              targets,
              durationMinutes,
              gutTrainingLevel,
              dislikedSet,
              // Pin override: when a pin fired, selectTemplateCandidates returns
              // ONLY pinned templates, so every candidate here is pin-selected.
              // Let the solver accept a macro shortfall (reported to the UI)
              // rather than returning null — fixes the pinned drink-only formula
              // not being scheduled for sub-90-min runs.
              duringPinDecision?.used_pin === true,
            );
            if (templateResult) break;
          }
          console.log(
            `[PLAN-V3-TIMING] during_template_solve completed in ${
              elapsed(templateSolveStart)
            }ms ` +
              `(result=${
                templateResult ? "success" : "null"
              }, tried=${triedTemplates})`,
          );

          if (templateResult) {
            console.log(
              `[PLAN-V3] Template solver succeeded: template ${templateResult.template_number} (${templateResult.template_name})`,
            );
            console.log(
              `[PLAN-V3-TIMING] during_phase_total completed in ${
                elapsed(phaseStart)
              }ms (path=template)`,
            );
            // Ephemeral default-formula safety net (formula-first flip):
            // the template path IS the default-formula tier — its candidates
            // are ranked by `selection_priority`, so the template that
            // rendered is the best-fit system formula for this workout. When
            // no REAL pin fired AND the client opted in, tag the outcome as
            // an ephemeral pin so the plan reads formula-first without writing
            // any `formula_pins` rows. For opted-out (old) clients this falls
            // back to the pre-safety-net conditional emission, byte-identical
            // to legacy v3. Behavior of the food output is unchanged either
            // way; this only enriches telemetry.
            const emittedPinDecision = duringPinDecision?.used_pin === true
              ? duringPinDecision
              : emitEphemeralDefault
              ? {
                used_pin: true,
                ephemeral: true,
                pinned_template_id: templateResult.template_id,
                pinned_template_name: templateResult.template_name,
                fallthrough_reason: null,
                pin_set_size: duringPinDecision?.pin_set_size ?? 0,
                // An ephemeral default formula is even less "what the user
                // asked for" than a real system pin — carry the skips so the
                // banner can still explain the miss.
                ...(duringPinDecision?.skipped_personal_formulas && {
                  skipped_personal_formulas:
                    duringPinDecision.skipped_personal_formulas,
                }),
              }
              : duringPinDecision;
            return {
              foods: templateResult.foods,
              by_hour_data: null,
              template_metadata: {
                template_id: templateResult.template_id,
                template_number: templateResult.template_number,
                template_name: templateResult.template_name,
                template_formula: templateResult.template_formula,
              },
              ...(templateResult.shortfalls &&
                templateResult.shortfalls.length > 0 && {
                shortfalls: templateResult.shortfalls,
              }),
              ...(emittedPinDecision && { pin_decision: emittedPinDecision }),
            };
          }

          // Option A guard (parity with after-phase commit aa652f11):
          // pin override selected a template but `generateDuringPhaseTemplate`
          // returned null for every candidate (validation failed). Without
          // this the wire would claim `used_pin: true` while the section
          // actually served rule-solver or LP foods — exactly the kind of
          // banner/data inconsistency that surfaced for After in the
          // 2026-05-26 Chocolate Milk Solo smoke test. Downgrade to
          // `used_pin: false` with `pinned_template_unrenderable` so the
          // wire reflects reality. Option B food-load bypass via
          // pinnedComponentNames should make this unreachable in practice;
          // this stays as belt-and-braces.
          if (duringPinDecision?.used_pin === true) {
            console.log(
              `[PLAN-V3] Pin override selected ${
                templateCandidates[0]?.template_number
              } (${
                templateCandidates[0]?.name
              }) but generateDuringPhaseTemplate returned null for all ${triedTemplates} candidates — downgrading pin_decision.used_pin to false (pinned_template_unrenderable)`,
            );
            duringPinDecision = {
              used_pin: false,
              pinned_template_id: null,
              pinned_template_name: null,
              fallthrough_reason: "pinned_template_unrenderable",
              pin_set_size: duringPinDecision.pin_set_size,
              ...(duringPinDecision.skipped_personal_formulas && {
                skipped_personal_formulas:
                  duringPinDecision.skipped_personal_formulas,
              }),
            };
          }

          console.log(
            "[PLAN-V3] Template solver returned null for all candidates (validation failed), falling back to rule solver",
          );
        } else {
          console.log(
            "[PLAN-V3] No matching template found, falling back to rule solver",
          );
        }
      } else {
        console.log(
          `[PLAN-V3] Template solver skipped: ${templates.length} templates, ${constrainedFoods.length} constrained foods`,
        );
      }
    } catch (err) {
      console.warn(
        "[PLAN-V3] Template solver error (falling back to rule solver):",
        err,
      );
    }
  }

  // ---- Rule solver (fallback) ----
  const ruleFoodsQueryStart = performance.now();
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
  console.log(
    `[PLAN-V3-TIMING] during_rule_food_query completed in ${
      elapsed(ruleFoodsQueryStart)
    }ms ` +
      `(foods=${foods.length})`,
  );

  if (foods.length === 0) {
    console.log("[PLAN-V3] No during foods found, trying expanded pool");
    const expandedFoodsQueryStart = performance.now();
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
    console.log(
      `[PLAN-V3-TIMING] during_expanded_food_query completed in ${
        elapsed(expandedFoodsQueryStart)
      }ms ` +
        `(foods=${foods.length})`,
    );
  }

  if (foods.length === 0) {
    console.log("[PLAN-V3] No during foods available at all");
    console.log(
      `[PLAN-V3-TIMING] during_phase_total completed in ${
        elapsed(phaseStart)
      }ms (path=empty)`,
    );
    return {
      foods: [],
      ...(duringPinDecision && { pin_decision: duringPinDecision }),
    };
  }

  const ruleSolveStart = performance.now();
  const ruleResult = generateDuringPhaseRuleBased(foods, targets, activityType);
  console.log(
    `[PLAN-V3-TIMING] during_rule_solve completed in ${
      elapsed(ruleSolveStart)
    }ms`,
  );
  const ruleValidation = validatePhaseResultAgainstTargets(
    ruleResult.foods,
    targets,
    "during",
  );

  if (ruleValidation.ok) {
    console.log(
      `[PLAN-V3-TIMING] during_phase_total completed in ${
        elapsed(phaseStart)
      }ms (path=rule)`,
    );
    return {
      foods: ruleResult.foods,
      by_hour_data: null,
      ...(duringPinDecision && { pin_decision: duringPinDecision }),
    };
  }

  console.warn(
    `[PLAN-V3] During rule-solver out of range (${
      ruleValidation.issues.join("; ")
    }). ` +
      `Retrying with LP solver.`,
  );

  // ---- LP solver (last resort) ----
  const lpStart = performance.now();
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
  console.log(
    `[PLAN-V3-TIMING] during_lp_fallback completed in ${elapsed(lpStart)}ms`,
  );

  const lpValidation = validatePhaseResultAgainstTargets(
    lpResult.foods,
    targets,
    "during",
  );
  if (!lpValidation.ok) {
    console.warn(
      `[PLAN-V3] During phase LP out of range (non-fatal): ${
        lpValidation.issues.join("; ")
      }`,
    );
  }

  console.log(
    `[PLAN-V3-TIMING] during_phase_total completed in ${
      elapsed(phaseStart)
    }ms (path=lp)`,
  );
  return {
    ...lpResult,
    ...(duringPinDecision && { pin_decision: duringPinDecision }),
  };
}
