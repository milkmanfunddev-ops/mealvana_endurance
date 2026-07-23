/**
 * During Phase generation for nutrition plan V3.
 *
 * Structure (2026-07-21 refactor, bug 3a3e3fdb Critical):
 *   Stage 1 — one food pool, loaded once (`getTemplateFoodsForDuringWithConstraints`).
 *             Every solver below consumes the same pool, so falling from one
 *             tier to the next can no longer change which foods exist.
 *   Stage 2 — best-effort plan selection:
 *             pinned personal formula → template solver → rule solver.
 *   Stage 3 — one closing pass for every path: carb gap-fill from the unused
 *             pool (gut-cap clamped), then shortfall computation. A plan can
 *             leave this function under-target ONLY with a populated
 *             `shortfalls` field.
 *
 * The former LP last-resort tier is gone: it played by different rules
 * (different food pool, no gut caps, unvalidated output) and is strictly
 * dominated by rule solver + gap-fill. `postProcessDuringPhase` went with it.
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import {
  type ActivityType,
  calculateTotals,
  type FoodResult,
  type MacroTargets,
} from "../_shared/nutrition/index.ts";
import {
  buildFoodsByNameMap,
  getDuringWorkoutTemplates,
  getTemplateFoodsForDuringWithConstraints,
} from "../_shared/nutrition/template-food-queries.ts";
import { generateDuringPhaseRuleBased } from "../_shared/nutrition/during-rule-solver.ts";
import {
  collectShortfalls,
  type DuringWorkoutTemplate,
  filterPinnedTemplatesInScope,
  type FoodWithConstraints,
  generateDuringPhaseTemplate,
  type GutTrainingLevel,
  normalizeGutTrainingLevel,
  selectTemplateCandidates,
} from "../_shared/nutrition/during-template-solver.ts";
import { gapFillDuringCarbs } from "../_shared/nutrition/during-gap-fill.ts";
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
// Closing pass (Stage 3)
// ============================================================================

/**
 * Apply the closing pass to a during-phase food list: optional carb gap-fill
 * from the shared pool, then shortfall computation on the FINAL totals. Every
 * exit of `generateDuringPhase` (except swimming) goes through here, which is
 * what guarantees the invariant: under-target ⇒ `shortfalls` populated.
 */
function finalizeDuringFoods(
  foods: FoodResult[],
  pool: FoodWithConstraints[],
  targets: MacroTargets,
  durationMinutes: number | undefined,
  gutLevel: GutTrainingLevel,
  dislikedSet: Set<string> | undefined,
  options: { gapFill: boolean },
): { foods: FoodResult[]; shortfalls: LPPhaseResult["shortfalls"] } {
  let finalFoods = foods;
  if (options.gapFill) {
    const fill = gapFillDuringCarbs(
      foods,
      pool,
      targets,
      durationMinutes,
      gutLevel,
    );
    finalFoods = fill.foods;
  }
  const shortfalls = collectShortfalls(
    calculateTotals(finalFoods),
    targets,
    dislikedSet,
  );
  return {
    foods: finalFoods,
    shortfalls: shortfalls.length > 0 ? shortfalls : undefined,
  };
}

// ============================================================================
// During Phase
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
 * Generate during-phase food selection.
 * Swimming returns empty immediately. Run/bike use the template solver with a
 * rule-solver fallback, followed by the closing gap-fill + shortfall pass.
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
  /** Raw client value; normalized to a valid level internally. A null or
   * invalid value (e.g. the legacy `'medium'` literal) must never disable
   * the formula engine — that was the accidental-8g-carbs bug (3a3e3fdb). */
  gutTrainingLevel?: string,
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

  // Gut training is a CONSTRAINT INPUT (per-hour caps, template matching),
  // never an on/off switch for the engine. Normalize whatever the client
  // sent; a missing profile or a legacy invalid literal degrades to
  // 'moderate', not to "skip the formula tier entirely".
  const gutLevel = normalizeGutTrainingLevel(gutTrainingLevel);
  if (gutTrainingLevel !== gutLevel) {
    console.log(
      `[PLAN-V3] Normalized gut_training_level ${
        JSON.stringify(gutTrainingLevel ?? null)
      } -> "${gutLevel}"`,
    );
  }

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
      generation_path: "swimming",
      ...(duringPinDecision && { pin_decision: duringPinDecision }),
    };
  }

  console.log(
    `[PLAN-V3] Generating during phase (${activityType}, gut=${gutLevel}, ` +
      `duration=${durationMinutes ?? "n/a"}min)`,
  );

  const dislikedSet = buildPreferenceSet(dislikedFoods);

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
        // No gap-fill on a personal formula — it is user-authored and scaled
        // to the carb target by construction; anything it still can't cover
        // is reported honestly rather than papered over with system foods.
        const closed = finalizeDuringFoods(
          foods,
          [],
          targets,
          durationMinutes,
          gutLevel,
          dislikedSet,
          { gapFill: false },
        );
        return {
          foods: closed.foods,
          by_hour_data: null,
          generation_path: "personal_formula",
          ...(closed.shortfalls && { shortfalls: closed.shortfalls }),
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

  // ---- Stage 1: shared pool + templates, loaded ONCE ----
  // Templates load first so pinned-component names can bypass the pool's
  // dislike/allergen/diet filters (honor-pin policy, PR 2 5c). The SAME pool
  // then feeds the template solver, the rule solver, and the gap-fill pass.
  const poolQueryStart = performance.now();
  const templates = await getDuringWorkoutTemplates(supabase);
  // Compute in-scope pin count for analytics (pin_set_size). Mirrors the
  // scope filter used by `selectTemplateCandidates`. Formula Kit PR 2
  // substep 7. The same list drives component-name bypass for the food
  // loader (PR 2 5c), scope-tightened 2026-05-28 so a cycling pin doesn't
  // leak its components past dislike/allergen filters on a running workout.
  const pinnedInScope =
    pinsSupplied && durationMinutes !== undefined && durationMinutes > 0
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
    `[PLAN-V3-TIMING] during_pool_queries completed in ${
      elapsed(poolQueryStart)
    }ms ` +
      `(templates=${templates.length}, foods=${constrainedFoods.length}, ` +
      `pinnedComponents=${pinnedComponentNames.size})`,
  );

  // ---- Stage 2a: template solver (primary path) ----
  // Guarded ONLY by duration now — gut level is normalized above and must
  // never skip this block (that skip was Failure Mode A of bug 3a3e3fdb).
  if (
    durationMinutes !== undefined && durationMinutes > 0 &&
    templates.length > 0 && constrainedFoods.length > 0
  ) {
    try {
      const templateSelectStart = performance.now();
      const foodsByName = buildFoodsByNameMap(constrainedFoods);
      const likedSet = buildPreferenceSet(likedFoods);
      const willingSet = buildPreferenceSet(willingToTryFoods);

      const templateCandidates = selectTemplateCandidates(
        templates,
        activityType,
        durationMinutes,
        gutLevel,
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
            gutLevel,
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
          // ---- Stage 3: closing pass (gap-fill + shortfalls) ----
          // Gap-fill runs for pinned and unpinned templates alike: pins stay
          // fully honored (fill only appends, never replaces) and the fill is
          // clamped to the gut-training per-hour caps, so a `low`-gut athlete
          // is never silently overfed (decision: Lee, 2026-07-20).
          const closed = finalizeDuringFoods(
            templateResult.foods,
            constrainedFoods,
            targets,
            durationMinutes,
            gutLevel,
            dislikedSet,
            { gapFill: true },
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
            foods: closed.foods,
            by_hour_data: null,
            generation_path: "template",
            template_metadata: {
              template_id: templateResult.template_id,
              template_number: templateResult.template_number,
              template_name: templateResult.template_name,
              template_formula: templateResult.template_formula,
            },
            ...(closed.shortfalls && { shortfalls: closed.shortfalls }),
            ...(emittedPinDecision && { pin_decision: emittedPinDecision }),
          };
        }

        // Option A guard (parity with after-phase commit aa652f11):
        // pin override selected a template but `generateDuringPhaseTemplate`
        // returned null for every candidate (validation failed). Without
        // this the wire would claim `used_pin: true` while the section
        // actually served rule-solver foods — exactly the kind of
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
    } catch (err) {
      console.warn(
        "[PLAN-V3] Template solver error (falling back to rule solver):",
        err,
      );
    }
  } else if (durationMinutes === undefined || durationMinutes <= 0) {
    console.log(
      `[PLAN-V3] Template solver skipped: no positive duration_minutes (${
        durationMinutes ?? "n/a"
      })`,
    );
  } else {
    console.log(
      `[PLAN-V3] Template solver skipped: ${templates.length} templates, ${constrainedFoods.length} constrained foods`,
    );
  }

  // ---- Stage 2b: rule solver (fallback) — SAME pool as the template tier ----
  if (constrainedFoods.length === 0) {
    console.log("[PLAN-V3] No during foods available at all");
    const closed = finalizeDuringFoods(
      [],
      [],
      targets,
      durationMinutes,
      gutLevel,
      dislikedSet,
      { gapFill: false },
    );
    console.log(
      `[PLAN-V3-TIMING] during_phase_total completed in ${
        elapsed(phaseStart)
      }ms (path=empty)`,
    );
    return {
      foods: [],
      generation_path: "empty",
      ...(closed.shortfalls && { shortfalls: closed.shortfalls }),
      ...(duringPinDecision && { pin_decision: duringPinDecision }),
    };
  }

  const ruleSolveStart = performance.now();
  const ruleResult = generateDuringPhaseRuleBased(
    constrainedFoods,
    targets,
    activityType,
  );
  console.log(
    `[PLAN-V3-TIMING] during_rule_solve completed in ${
      elapsed(ruleSolveStart)
    }ms`,
  );

  // ---- Stage 3: closing pass (gap-fill + shortfalls) ----
  const closed = finalizeDuringFoods(
    ruleResult.foods,
    constrainedFoods,
    targets,
    durationMinutes,
    gutLevel,
    dislikedSet,
    { gapFill: true },
  );
  console.log(
    `[PLAN-V3-TIMING] during_phase_total completed in ${
      elapsed(phaseStart)
    }ms (path=rule)`,
  );
  return {
    foods: closed.foods,
    by_hour_data: null,
    generation_path: "rule",
    ...(closed.shortfalls && { shortfalls: closed.shortfalls }),
    ...(duringPinDecision && { pin_decision: duringPinDecision }),
  };
}
