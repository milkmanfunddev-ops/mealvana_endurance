/**
 * After (post-workout) Phase generation for nutrition plan V3.
 *
 * Post-workout recovery in the 30–60 min window is treated as a trigger, not
 * a macro-dosing event. We pick one template the athlete is most likely to
 * actually eat — no carbs/protein/sodium/fluid solver, no body-size scaling.
 *
 * Flow:
 *   1. Load active post_workout_templates and after-phase template foods.
 *   2. Filter by diet + allergies + food availability.
 *   3. Rank by Travel (in_bag > cooler_friendly > home_only) then Prep
 *      (grab_and_go > assemble > cook). Break remaining ties randomly.
 *   4. Render the canonical portion from the template's default_servings map.
 *
 * If no template fits (rare — all 21 should be reachable for most athletes),
 * fall back to the LP solver so the athlete still gets *something*.
 *
 * Athlete-facing explanation: Notion "Post-Workout Recovery: What Matters in
 * the First Hour".
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import {
  type ActivityType,
  type Food,
  type MacroTargets,
} from "../_shared/nutrition/index.ts";
import {
  buildFoodMap,
  getPostWorkoutTemplates,
  getTemplateFoodsForPhase,
} from "../_shared/nutrition/template-food-queries.ts";
import {
  filterPinnedPostTemplatesInScope,
  type PostWorkoutTemplate,
  renderPostTemplatePortion,
  selectPostWorkoutTemplateCandidates,
} from "../_shared/nutrition/post-template-solver.ts";
import type { PersonalFormulaPin } from "../_shared/nutrition/pins.ts";
import {
  matchPersonalFormulaPin,
  personalFormulaToFoodResults,
} from "../_shared/nutrition/personal-formula-pins.ts";
import {
  backfillPinnedFluidsAndSodium,
  fluidSodiumDeficits,
} from "../_shared/nutrition/pin-backfill.ts";
import { getEssentialFoods } from "../_shared/nutrition/food-queries.ts";
import {
  defaultFormulaDecision,
  logFormulaCascade,
  withDecisionSource,
} from "../_shared/nutrition/formula-decision.ts";
import type { LPPhaseResult } from "./types.ts";
import { generateLPPhase } from "./lp-phase.ts";

/**
 * Build the initial `pin_decision` skeleton for the After section.
 * Mirrors `initialDuringPinDecision` in during-phase.ts.
 *
 * Contract:
 *   - `pinsSupplied === true` → emit `{ used_pin: false, no_pin_for_scope,
 *     pin_set_size: 0 }`. Refined to `used_pin: true` and a real
 *     `pin_set_size` downstream if a pinned template fires.
 *   - `pinsSupplied === false` → return `undefined`; result is spread
 *     conditionally so `pin_decision` is omitted from the wire response —
 *     byte-identical to pre-pin v3 behavior.
 *
 * Formula Kit PR 3 substep 7.
 */
export function initialAfterPinDecision(
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

/**
 * Collect the set of component food names belonging to pinned post-workout
 * templates.
 *
 * Honor-pin policy (PR 3 #35 fix, parity with During PR 2 5c): foods in this
 * set bypass the dislike / allergen / diet filters in
 * `getTemplateFoodsForPhase` so the pinned template's components remain
 * available to the renderer. Without this, a user who pins Chocolate Milk
 * Solo while also disliking `chocolate_milk` would have chocolate milk
 * stripped from the food pool, `renderPostTemplatePortion` would return
 * null (component missing from foodsByName), and the plan would fall
 * through to LP — while the pin_decision wire still claimed honored.
 *
 * Iterates ALL active templates and filters by pinnedTemplateIds rather
 * than restricting to in-scope pins, mirroring during-phase. Over-inclusive
 * is harmless here: foods only needed by an out-of-scope pin (e.g. a
 * cycling-only pin during a running plan) just won't be selected by the
 * solver because that template won't be a candidate anyway.
 */
export function derivePinnedPostComponentNames(
  templates: PostWorkoutTemplate[],
  pinnedTemplateIds: Set<string> | undefined,
): Set<string> {
  const names = new Set<string>();
  if (!pinnedTemplateIds || pinnedTemplateIds.size === 0) return names;
  for (const t of templates) {
    if (!pinnedTemplateIds.has(t.id)) continue;
    for (const name of t.component_food_names ?? []) {
      names.add(name);
    }
  }
  return names;
}

/**
 * Union of all component food names across the active post-workout templates.
 *
 * Used to widen the no-pin After SQL fetch so pantry foods that some post
 * templates depend on (e.g. peanut_butter, jam, milk, granola, mixed_berries)
 * are reachable even when their `template_foods.categories` only includes
 * `before_run`. These widened foods are still subject to dislike / allergen /
 * diet filters at STEP 4 — they only bypass the category WHERE clause, not
 * the user-preference filter chain.
 *
 * Without this, templates like "PB+J on Whole Wheat" or "Yogurt + Berries +
 * Granola" silently lose components in the no-pin path and either render
 * partially or fall through to LP. Fixes #36 (companion to PR 3 #35 which
 * handled the pin-path widening only).
 */
export function deriveAllPostComponentNames(
  templates: PostWorkoutTemplate[],
): Set<string> {
  const names = new Set<string>();
  for (const t of templates) {
    for (const name of t.component_food_names ?? []) {
      names.add(name);
    }
  }
  return names;
}

/**
 * Pick + render a post-workout recovery template.
 *
 * `targets` is accepted to keep the function signature aligned with the other
 * phase generators, but it is intentionally NOT used for selection or
 * portioning — see file header.
 */
export async function generateAfterPhase(
  supabase: ReturnType<typeof createServiceClient>,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  allergies?: string[],
  dietaryPreference?: string,
  /**
   * Set of post_workout_templates.id values the user has actively pinned. When
   * an in-scope pin exists (activity_type overlap), the solver bypasses all
   * diet / allergen / availability filters. Empty/undefined for pre-pin
   * behavior. Formula Kit PR 3 substep 7.
   */
  afterPinnedTemplateIds?: Set<string>,
  /**
   * Whether the user has any pins at all (across any scope). When true, the
   * After section emits `pin_decision` even if `afterPinnedTemplateIds` for
   * THIS scope is empty — mirrors the During-section behavior so the
   * activity-detail banner can show a row reading "No pin found" for the
   * After phase. Without this, a user who has only Before/During pins would
   * get a silently-missing After `pin_decision`. Formula Kit PR 3 substep 7
   * (parity with PR 2 #18).
   */
  pinsActive?: boolean,
  /** User's pinned personal formulas (any phase); after-phase ones in scope
   * are honored before the template solver. Formula Kit personalization. */
  personalFormulaPins?: PersonalFormulaPin[],
  /** When true, tag the selected system formula as an EPHEMERAL default-
   * formula pin on `pin_decision` (formula-first flip). Opt-in so only
   * clients that keep ephemeral decisions invisible receive them — old
   * clients omit it and stay byte-identical to pre-safety-net v3. 2026-07-03. */
  emitEphemeralDefault = false,
): Promise<LPPhaseResult> {
  const phaseStart = performance.now();
  const elapsed = (start: number) => Math.round(performance.now() - start);

  // Set when a matched personal-formula pin renders zero components (see
  // below) — carried forward into `afterPinDecision`'s initial skeleton so
  // the wire surfaces a real reason instead of silently looking like "no
  // pin at all". Item 12 (personal formulas silently dropped), 2026-07-04.
  let personalFormulaFallthrough: LPPhaseResult["pin_decision"] | null = null;

  // ---- Pinned personal formula (highest priority) ----
  // An in-scope pinned personal formula is honored unconditionally, emitting
  // its self-contained components and bypassing the template solver.
  if (personalFormulaPins && personalFormulaPins.length > 0) {
    const match = matchPersonalFormulaPin(
      personalFormulaPins,
      "after",
      activityType,
    );
    if (match) {
      // Scale the formula's components uniformly to the recovery carb target
      // (decided 2026-06-12: all phases scale; authored quantities are the
      // formula's composition ratio, not exact amounts).
      let foods = personalFormulaToFoodResults(
        match,
        "Within 30 minutes",
        targets.carbs_g,
      );
      // Failsafe: backfill fluids/sodium up to the recovery targets — the
      // pin path bypasses all solver fill steps (see pin-backfill.ts).
      if (foods.length > 0) {
        const deficits = fluidSodiumDeficits(foods, targets);
        if (deficits.needsBackfill) {
          const essentials = await getEssentialFoods(
            supabase,
            activityType,
            "after",
          );
          foods = backfillPinnedFluidsAndSodium(
            foods,
            targets,
            essentials,
            "Within 30 minutes",
            "[PLAN-V3] After",
          );
        }
      }
      if (foods.length > 0) {
        console.log(
          `[PLAN-V3] After: honoring pinned personal formula "${match.name}" ` +
            `(${foods.length} components, scaled to ${targets.carbs_g}g ` +
            `carbs), bypassing template solver`,
        );
        logFormulaCascade({
          phase: "after",
          source: "personal_formula",
          templateId: match.id,
          templateName: match.name,
          pinSetSize: 1,
        });
        return {
          foods,
          by_hour_data: null,
          generation_path: "personal_formula",
          pin_decision: {
            used_pin: true,
            decision_source: "personal_formula",
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
      // logs or the wire response. Surface it on both channels, then
      // continue to the template solver below as before.
      console.warn(
        `[PLAN-V3] After: pinned personal formula "${match.name}" ` +
          `(${match.id}) matched scope but rendered 0 components — ` +
          `falling through to template solver`,
      );
      personalFormulaFallthrough = {
        used_pin: false,
        decision_source: "default_formula",
        pinned_template_id: null,
        pinned_template_name: null,
        fallthrough_reason: "personal_formula_empty",
        default_fallthrough_reason: "personal_formula_empty",
        pin_set_size: 1,
      };
    }
  }

  // Pin telemetry skeleton. Refined once templates load + candidate selection
  // returns. Omitted entirely when no pins were supplied anywhere (byte-
  // identical to pre-pin v3) UNLESS a personal-formula pin matched but
  // rendered empty above — that case always surfaces regardless of whether
  // after-TEMPLATE pins were also supplied.
  const pinsSupplied = pinsActive ??
    (afterPinnedTemplateIds !== undefined &&
      afterPinnedTemplateIds.size > 0);
  let afterPinDecision: LPPhaseResult["pin_decision"] | undefined =
    personalFormulaFallthrough ?? initialAfterPinDecision(pinsSupplied);

  console.log(
    `[PLAN-V3] Generating after phase (${activityType}, diet=${
      dietaryPreference ?? "none"
    }, allergies=${
      (allergies ?? []).join(",") || "none"
    }, after_pins=${afterPinnedTemplateIds?.size ?? 0}, pinsSupplied=${pinsSupplied})`,
  );

  try {
    const queryStart = performance.now();
    // Templates must load before foods: we need to know which templates the
    // user pinned so we can pre-compute pinned component names and pass them
    // to the food loader for filter bypass (#35 fix). The cost of going
    // sequential is one extra round-trip vs the prior Promise.all; the
    // correctness win is that pinned templates' components survive
    // dislike/allergen/diet filtering.
    const templates = await getPostWorkoutTemplates(supabase);
    const pinnedComponentNames = derivePinnedPostComponentNames(
      templates,
      afterPinnedTemplateIds,
    );
    // Widen the no-pin path too: pull in every post-template component name
    // even when the row lives in `before_run` category. Pin-path bypass at
    // STEP 4 is unchanged — extra names face full dislike/allergen/diet
    // filtering. Fixes #36.
    const extraComponentNames = deriveAllPostComponentNames(templates);
    const afterFoods = await getTemplateFoodsForPhase(
      supabase,
      "after",
      activityType,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
      // No deviceId: the after-phase pool is curated `template_foods` only —
      // `user_foods` is not a plan-generation source (food-source policy).
      false,
      allergies,
      dietaryPreference,
      pinnedComponentNames,
      extraComponentNames,
    );
    console.log(
      `[PLAN-V3-TIMING] after_template_queries completed in ${
        elapsed(queryStart)
      }ms (templates=${templates.length}, foods=${afterFoods.length}, pinnedComponents=${pinnedComponentNames.size}, extraComponents=${extraComponentNames.size})`,
    );

    if (templates.length > 0 && afterFoods.length > 0) {
      // Refine `pin_set_size` once templates load. Mirrors the during-phase
      // pattern — pinInScopeCount is independent of whether the pin actually
      // fires (the selector may still bypass for other reasons later, but
      // analytics want the raw "how many pinned templates were eligible"
      // signal).
      if (
        afterPinDecision &&
        afterPinnedTemplateIds !== undefined &&
        afterPinnedTemplateIds.size > 0
      ) {
        const pinInScopeCount = filterPinnedPostTemplatesInScope(
          templates,
          activityType,
          afterPinnedTemplateIds,
        ).length;
        afterPinDecision = {
          ...afterPinDecision,
          pin_set_size: pinInScopeCount,
        };
      }

      const selectStart = performance.now();
      const foodsByName: Map<string, Food> = buildFoodMap(afterFoods);

      // No liked/willing/disliked scoring — the algorithm ranks purely by
      // selection_priority + random. Disliked foods are excluded upstream in
      // getTemplateFoodsForPhase EXCEPT for components of pinned templates,
      // which bypass dislike/allergen/diet filters via pinnedComponentNames
      // (PR 3 #35 fix). Non-pinned templates whose components depend on a
      // disliked food still won't survive the food-availability filter. When
      // an in-scope pin exists, the selector returns the pinned set
      // unconditionally and its components have already been loaded.
      const candidates = selectPostWorkoutTemplateCandidates(
        templates,
        activityType,
        foodsByName,
        allergies,
        dietaryPreference,
        Math.random,
        afterPinnedTemplateIds,
      );
      console.log(
        `[PLAN-V3-TIMING] after_template_select completed in ${
          elapsed(selectStart)
        }ms (candidates=${candidates.length}, top=${
          candidates[0]?.template_number ?? "none"
        })`,
      );

      // Refine pin_decision: the selector returns ONLY pinned templates when
      // pin override fires, so if the top candidate's id is in the pin set we
      // know the pin won. Otherwise the `no_pin_for_scope` default stays.
      if (pinsSupplied && afterPinDecision) {
        const first = candidates[0];
        if (
          first !== undefined &&
          afterPinnedTemplateIds !== undefined &&
          afterPinnedTemplateIds.has(first.id)
        ) {
          afterPinDecision = {
            used_pin: true,
            decision_source: "user_pin",
            pinned_template_id: first.id,
            pinned_template_name: first.name,
            fallthrough_reason: null,
            pin_set_size: afterPinDecision.pin_set_size,
          };
        }
      }

      // Default-formula tier: the non-pin post path already selects and renders
      // a single SYSTEM template (a formula) via its tuned travel/prep
      // ranking — that IS the after phase's default formula, and since the
      // client stopped pre-computing auto-pins (2026-07-29) it is the COMMON
      // outcome. When no REAL pin fired we tag it as an ephemeral pin so the
      // plan reads formula-first, without writing `formula_pins` rows and
      // without disturbing the deliberate travel/prep selection order.
      //
      // NOTE: `selection_priority` is deliberately NOT the after-phase ranking
      // key (see post-template-solver.ts header). A parallel default-formula
      // ranker that re-sorted post survivors by `selection_priority` used to
      // live in `_shared/nutrition/default-formula.ts`; it was orphaned and
      // contradicted this order, and was deleted 2026-07-29.
      const afterEphemeral = emitEphemeralDefault &&
        !(afterPinDecision?.used_pin === true) &&
        candidates.length > 0;

      if (candidates.length > 0) {
        const renderStart = performance.now();
        const rendered = renderPostTemplatePortion(
          candidates[0],
          foodsByName,
        );
        console.log(
          `[PLAN-V3-TIMING] after_template_render completed in ${
            elapsed(renderStart)
          }ms (result=${rendered ? "success" : "null"})`,
        );

        if (rendered) {
          // When a real pin didn't fire but the safety net promoted a default
          // formula, tag the outcome as an ephemeral pin so the plan reads
          // formula-first (no `formula_pins` rows written).
          const usedRealPin = afterPinDecision?.used_pin === true;
          logFormulaCascade({
            phase: "after",
            source: usedRealPin ? "user_pin" : "default_formula",
            templateId: rendered.template_id,
            templateName: rendered.template_name,
            reason: usedRealPin
              ? null
              : afterPinDecision?.fallthrough_reason ?? "no_pin_for_scope",
            pinSetSize: afterPinDecision?.pin_set_size ?? 0,
          });
          const emittedPinDecision = usedRealPin
            ? afterPinDecision
            : afterEphemeral
            ? defaultFormulaDecision({
              templateId: rendered.template_id,
              templateName: rendered.template_name,
              pinSetSize: afterPinDecision?.pin_set_size ?? 0,
              fallthroughReason: afterPinDecision?.fallthrough_reason,
            })
            : afterPinDecision;
          console.log(
            `[PLAN-V3] Post-workout template selected: ${rendered.template_number} (${rendered.template_name})${
              afterPinDecision?.used_pin
                ? " [pin override]"
                : afterEphemeral
                ? " [ephemeral default formula]"
                : ""
            }`,
          );
          console.log(
            `[PLAN-V3-TIMING] after_phase_total completed in ${
              elapsed(phaseStart)
            }ms (path=template)`,
          );
          return {
            foods: rendered.foods,
            by_hour_data: null,
            generation_path: "template",
            template_metadata: {
              template_id: rendered.template_id,
              template_number: rendered.template_number,
              template_name: rendered.template_name,
              template_formula: rendered.template_formula,
              template_portions: rendered.template_portions,
              protein_anchor: rendered.protein_anchor,
              flavor_profile: rendered.flavor_profile,
              prep_effort: rendered.prep_effort,
              travel_friendliness: rendered.travel_friendliness,
            },
            ...(emittedPinDecision && { pin_decision: emittedPinDecision }),
          };
        }

        // Option A guard: render returned null after the selector said "pin
        // wins". Without this, the wire would claim `used_pin: true` while
        // the section actually served LP foods — exactly the inconsistency
        // that surfaced in the 2026-05-26 smoke test (Chocolate Milk Solo
        // pinned, banner said honored, section showed LP output). Downgrade
        // to `used_pin: false` with `pinned_template_unrenderable` so the
        // wire reflects reality. Option B (food-load bypass) should make
        // this unreachable; this stays as belt-and-braces.
        if (afterPinDecision?.used_pin === true) {
          console.log(
            `[PLAN-V3] Pin override selected ${
              candidates[0]?.template_number
            } (${candidates[0]?.name}) but render returned null — downgrading pin_decision.used_pin to false (pinned_template_unrenderable)`,
          );
          afterPinDecision = {
            used_pin: false,
            decision_source: "solver",
            pinned_template_id: null,
            pinned_template_name: null,
            fallthrough_reason: "pinned_template_unrenderable",
            default_fallthrough_reason: "pinned_template_unrenderable",
            pin_set_size: afterPinDecision.pin_set_size,
          };
        }

        console.log(
          "[PLAN-V3] Post-workout template render returned null, falling back to LP",
        );
      } else {
        console.log(
          "[PLAN-V3] No matching post-workout template (diet/allergy/availability filtered everything), falling back to LP",
        );
      }
    } else {
      console.log(
        `[PLAN-V3] Post-workout template path skipped: ${templates.length} templates, ${afterFoods.length} after foods`,
      );
    }
  } catch (err) {
    console.warn(
      "[PLAN-V3] Post-workout template path errored (falling back to LP):",
      err,
    );
  }

  // ---- LP solver (rare fallback for empty filter pool) ----
  const lpStart = performance.now();
  const lpResult = await generateLPPhase(
    supabase,
    "after",
    targets,
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    allergies,
    dietaryPreference,
  );
  console.log(
    `[PLAN-V3-TIMING] after_lp_fallback completed in ${elapsed(lpStart)}ms`,
  );

  console.log(
    `[PLAN-V3-TIMING] after_phase_total completed in ${
      elapsed(phaseStart)
    }ms (path=lp)`,
  );
  // No recovery formula rendered — neither a pin nor the default (travel/prep
  // ranked) template tier produced one, so LP dosed the foods instead. Logged
  // as a warning so the no-pin path can never regress into the solver
  // silently.
  logFormulaCascade({
    phase: "after",
    source: "solver",
    reason: afterPinDecision?.fallthrough_reason ?? "no_template_candidates",
    pinSetSize: afterPinDecision?.pin_set_size ?? 0,
  });
  return {
    ...lpResult,
    generation_path: "lp",
    ...(afterPinDecision &&
      { pin_decision: withDecisionSource(afterPinDecision, "solver") }),
  };
}
