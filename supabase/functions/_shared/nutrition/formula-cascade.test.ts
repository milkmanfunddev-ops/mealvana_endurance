/**
 * Formula cascade guarantee — pinned → default formula → solver.
 *
 * Context (2026-07-29): the client no longer pre-computes auto-pins at
 * onboarding or in settings, so EVERY phase resolves its formula server-side
 * at plan-generation time. Lee's framing — "we fall back to default formulas
 * if no pinned formulas are found (which is a LOT of the time!!!)" — makes the
 * ZERO-PIN case the common path. These tests exist so it can never silently
 * degrade into the rule/LP/greedy solver again.
 *
 * Covered per phase (before / during / after):
 *   1. zero pins → a system DEFAULT formula is selected and rendered;
 *   2. pins present → the pin wins over the default;
 *   3. default unavailable → the phase reports no candidates so the caller
 *      falls to the solver, and the fall is logged honestly.
 *
 * Plus the shared telemetry vocabulary in `formula-decision.ts`: a computed
 * default must stay wire-compatible (`used_pin: true` + `ephemeral: true`)
 * while carrying honest provenance (`decision_source`) and the preserved
 * `default_fallthrough_reason`.
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/_shared/nutrition/formula-cascade.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  defaultFormulaDecision,
  type FormulaDecisionSource,
  logFormulaCascade,
  realPinSource,
  withDecisionSource,
} from "./formula-decision.ts";
import {
  type DuringWorkoutTemplate,
  type FoodWithConstraints,
  selectTemplateCandidates,
} from "./during-template-solver.ts";
import {
  type PostWorkoutTemplate,
  selectPostWorkoutTemplateCandidates,
} from "./post-template-solver.ts";
import type { ActivityType, Food } from "./types.ts";
import { makeFood } from "./test-utils.ts";
import { LogCapture } from "./test-utils.ts";
import { selectPreWorkoutFoods } from "../../generate-macros-v4/pre-workout.ts";
import type {
  PreWorkoutTargets,
  PreWorkoutTemplate,
} from "../../generate-macros-v4/types.ts";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function makeDuringTemplate(
  o: Partial<DuringWorkoutTemplate> & { template_number: number; name: string },
): DuringWorkoutTemplate {
  return {
    id: o.id ?? `during-${o.template_number}`,
    template_number: o.template_number,
    name: o.name,
    formula: o.formula ?? o.name,
    food_form: o.food_form ?? "mixed",
    activity_types: o.activity_types ?? ["running", "cycling"],
    duration_brackets: o.duration_brackets ?? ["60-90 min", "90-150 min"],
    gut_training_levels: o.gut_training_levels ?? ["low", "moderate", "high"],
    component_food_names: o.component_food_names ?? ["energy_gel"],
    component_carb_ratios: o.component_carb_ratios ?? { energy_gel: 1 },
    primary_to_secondary_ratio: o.primary_to_secondary_ratio ?? null,
    allergens: o.allergens ?? [],
    excluded_diets: o.excluded_diets ?? [],
    notes: o.notes ?? null,
    is_active: o.is_active ?? true,
    selection_priority: o.selection_priority ?? null,
  };
}

function makePostTemplate(
  o: Partial<PostWorkoutTemplate> & { template_number: number; name: string },
): PostWorkoutTemplate {
  return {
    id: o.id ?? `post-${o.template_number}`,
    template_number: o.template_number,
    name: o.name,
    formula: o.formula ?? o.name,
    portions: o.portions ?? null,
    activity_types: o.activity_types ?? ["running", "cycling"],
    component_food_names: o.component_food_names ?? ["banana"],
    component_ratios: o.component_ratios ?? null,
    default_servings: o.default_servings ?? { banana: 1 },
    target_carb_protein_ratio: o.target_carb_protein_ratio ?? null,
    allergens: o.allergens ?? [],
    excluded_diets: o.excluded_diets ?? [],
    travel_friendliness: o.travel_friendliness ?? "in_bag",
    flavor_profile: o.flavor_profile ?? "sweet_creamy",
    prep_effort: o.prep_effort ?? "grab_and_go",
    protein_anchor: o.protein_anchor ?? null,
    carb_sources: o.carb_sources ?? ["banana"],
    notes: o.notes ?? null,
    is_active: o.is_active ?? true,
    selection_priority: o.selection_priority ?? null,
  };
}

function makePreTemplate(
  o: Partial<PreWorkoutTemplate> & { id: string; name: string },
): PreWorkoutTemplate {
  return {
    id: o.id,
    name: o.name,
    base_category: o.base_category ?? "grain",
    time_window: o.time_window ?? "1.5-3 hours",
    digestion_speed: o.digestion_speed ?? "medium",
    allergens: o.allergens ?? [],
    excluded_diets: o.excluded_diets ?? [],
    serving_unit: o.serving_unit ?? "serving",
    min_servings: o.min_servings ?? 1,
    max_servings: o.max_servings ?? 2,
    plus_banana: o.plus_banana ?? false,
    plus_sports_drink: o.plus_sports_drink ?? false,
    carbs_per_serving: o.carbs_per_serving ?? 40,
    protein_per_serving: o.protein_per_serving ?? 6,
    fat_per_serving: o.fat_per_serving ?? 2,
    sodium_mg: o.sodium_mg ?? 200,
    fluid_ml: o.fluid_ml ?? 0,
    template_type: o.template_type ?? "food",
    is_active: o.is_active ?? true,
    component_food_names: o.component_food_names ?? [o.id],
    component_quantities: o.component_quantities ?? { [o.id]: 1 },
  };
}

function duringFoodMap(names: string[]): Map<string, FoodWithConstraints> {
  const m = new Map<string, FoodWithConstraints>();
  for (const n of names) m.set(n, makeFood({ name: n }) as FoodWithConstraints);
  return m;
}

function postFoodMap(names: string[]): Map<string, Food> {
  const m = new Map<string, Food>();
  for (const n of names) m.set(n, makeFood({ name: n }));
  return m;
}

const PRE_TARGETS: PreWorkoutTargets = {
  carbs_g: 60,
  carbs_low_g: 50,
  carbs_high_g: 75,
  protein_g: 12,
  protein_low_g: 8,
  protein_high_g: 20,
  fat_g: 5,
  sodium_mg: 400,
  sodium_low_mg: 300,
  sodium_high_mg: 600,
  water_ml: 500,
  water_low_ml: 400,
  water_high_ml: 700,
  meal_type: "full_meal",
};

// ===========================================================================
// DURING — pinned → default formula → solver
// ===========================================================================

describe("during cascade", () => {
  const templates = [
    makeDuringTemplate({
      id: "d-low",
      template_number: 1,
      name: "Low Priority Gel",
      selection_priority: 1,
    }),
    makeDuringTemplate({
      id: "d-high",
      template_number: 9,
      name: "High Priority Chew",
      selection_priority: 50,
      component_food_names: ["energy_chew"],
      component_carb_ratios: { energy_chew: 1 },
    }),
  ];
  const foods = duringFoodMap(["energy_gel", "energy_chew"]);

  it("ZERO pins → a default formula is selected (highest selection_priority)", () => {
    const candidates = selectTemplateCandidates(
      templates,
      "running",
      120,
      "moderate",
      foods,
    );
    assert(
      candidates.length > 0,
      "no-pin during path must still yield a formula, never fall straight to the solver",
    );
    assertEquals(candidates[0].id, "d-high");
  });

  it("ZERO pins → an EMPTY pin set behaves identically to undefined", () => {
    const withUndefined = selectTemplateCandidates(
      templates,
      "running",
      120,
      "moderate",
      foods,
    );
    const withEmptySet = selectTemplateCandidates(
      templates,
      "running",
      120,
      "moderate",
      foods,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set<string>(),
    );
    assertEquals(
      withEmptySet.map((t) => t.id),
      withUndefined.map((t) => t.id),
    );
  });

  it("pin present → the pin wins over the higher-priority default", () => {
    const candidates = selectTemplateCandidates(
      templates,
      "running",
      120,
      "moderate",
      foods,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set(["d-low"]),
    );
    assertEquals(candidates.map((t) => t.id), ["d-low"]);
  });

  it("no default available → empty candidate list (caller falls to solver)", () => {
    const candidates = selectTemplateCandidates(
      templates,
      "swimming", // no template covers swimming
      120,
      "moderate",
      foods,
    );
    assertEquals(candidates.length, 0);
  });

  // Multi-sport coverage: the removed client auto-pin only ever covered the
  // user's PRIMARY sport. Runtime resolution must produce a default formula
  // for every sport the user can select.
  for (
    const activity of [
      "running",
      "cycling",
      "triathlon",
      "brick",
    ] as ActivityType[]
  ) {
    it(`ZERO pins → default formula resolves for ${activity}`, () => {
      const candidates = selectTemplateCandidates(
        templates,
        activity,
        120,
        "moderate",
        foods,
      );
      assert(
        candidates.length > 0,
        `${activity} must resolve a default during formula with no pins`,
      );
    });
  }
});

// ===========================================================================
// AFTER — pinned → default formula → solver
// ===========================================================================

describe("after cascade", () => {
  const templates = [
    makePostTemplate({
      id: "p-home",
      template_number: 1,
      name: "Home Only Bowl",
      travel_friendliness: "home_only",
      prep_effort: "cook",
    }),
    makePostTemplate({
      id: "p-bag",
      template_number: 2,
      name: "In Bag Shake",
      travel_friendliness: "in_bag",
      prep_effort: "grab_and_go",
      component_food_names: ["chocolate_milk"],
      default_servings: { chocolate_milk: 1 },
    }),
  ];
  const foods = postFoodMap(["banana", "chocolate_milk"]);

  it("ZERO pins → a default formula is selected (travel then prep ranking)", () => {
    const candidates = selectPostWorkoutTemplateCandidates(
      templates,
      "running",
      foods,
    );
    assert(
      candidates.length > 0,
      "no-pin after path must still yield a recovery formula, never fall straight to LP",
    );
    assertEquals(candidates[0].id, "p-bag");
  });

  it("pin present → the pin wins over the travel/prep default", () => {
    const candidates = selectPostWorkoutTemplateCandidates(
      templates,
      "running",
      foods,
      undefined,
      undefined,
      Math.random,
      new Set(["p-home"]),
    );
    assertEquals(candidates.map((t) => t.id), ["p-home"]);
  });

  it("no default available → empty candidate list (caller falls to LP)", () => {
    const candidates = selectPostWorkoutTemplateCandidates(
      templates,
      "running",
      postFoodMap([]), // nothing renderable
    );
    assertEquals(candidates.length, 0);
  });

  it("ZERO pins → default formula resolves for every selectable sport", () => {
    for (
      const activity of [
        "running",
        "cycling",
        "swimming",
        "triathlon",
        "brick",
      ] as ActivityType[]
    ) {
      const candidates = selectPostWorkoutTemplateCandidates(
        templates,
        activity,
        foods,
      );
      // swimming isn't in these fixtures' activity_types; triathlon/brick map
      // onto running/cycling/swimming so they must resolve.
      if (activity === "swimming") continue;
      assert(
        candidates.length > 0,
        `${activity} must resolve a default after formula with no pins`,
      );
    }
  });
});

// ===========================================================================
// BEFORE — pinned → default formula → (no downstream solver)
// ===========================================================================

describe("before cascade", () => {
  const foodTemplates = [
    makePreTemplate({
      id: "oatmeal",
      name: "Oatmeal + Banana",
      time_window: "1.5-3 hours",
      base_category: "grain",
    }),
    makePreTemplate({
      id: "bagel",
      name: "Bagel + Jam",
      time_window: "1.5-3 hours",
      base_category: "bread",
      carbs_per_serving: 55,
    }),
    makePreTemplate({
      id: "toast",
      name: "Toast + Honey",
      time_window: "30-90 min",
      base_category: "bread",
      carbs_per_serving: 30,
    }),
    makePreTemplate({
      id: "chews",
      name: "Chews",
      time_window: "< 30 min",
      base_category: "chew",
      carbs_per_serving: 25,
    }),
  ];

  it("ZERO pins → every active slot renders a default system formula", () => {
    const results = selectPreWorkoutFoods(
      PRE_TARGETS,
      3, // long lead time → meal + snack + top_up all active
      "none",
      foodTemplates,
      [],
      [],
    );
    assert(results.length > 0, "before phase must emit at least one slot");
    const withPrimary = results.filter((r) => r.primary !== null);
    assert(
      withPrimary.length > 0,
      "no-pin before path must render a formula, not an empty phase",
    );
    for (const r of withPrimary) {
      assert(r.primary!.id, `${r.phase} primary must name a template`);
    }
  });

  it("ZERO pins + opt-in → pin_decision reports decision_source=default_formula", () => {
    const results = selectPreWorkoutFoods(
      PRE_TARGETS,
      3,
      "none",
      foodTemplates,
      [],
      [],
      [],
      [],
      [],
      undefined, // no pins at all
      true, // emitEphemeralDefault
    );
    const rendered = results.filter((r) => r.primary !== null);
    assert(rendered.length > 0);
    for (const r of rendered) {
      const d = r.pin_decision;
      assert(d !== undefined, `${r.phase} must carry a pin_decision`);
      // Honest provenance…
      assertEquals(d.decision_source, "default_formula");
      assertEquals(d.default_fallthrough_reason, "no_pin_for_scope");
      // …while the legacy wire fields keep their pre-2026-07-29 values so the
      // Dart PinDecision model and the pin banner behave identically.
      assertEquals(d.used_pin, true);
      assertEquals(d.ephemeral, true);
      assertEquals(d.fallthrough_reason, null);
    }
  });

  it("ZERO pins + legacy client (no opt-in) → pin_decision omitted entirely", () => {
    const results = selectPreWorkoutFoods(
      PRE_TARGETS,
      3,
      "none",
      foodTemplates,
      [],
      [],
    );
    for (const r of results) {
      assertEquals(
        r.pin_decision,
        undefined,
        "legacy no-pin clients must stay byte-identical",
      );
    }
  });

  it("pin present → the pin wins and is tagged decision_source=user_pin", () => {
    const results = selectPreWorkoutFoods(
      PRE_TARGETS,
      3,
      "none",
      foodTemplates,
      [],
      [],
      [],
      [],
      [],
      new Set(["bagel"]),
      true,
    );
    const meal = results.find((r) => r.phase === "meal");
    assert(meal !== undefined);
    assertEquals(meal.primary?.id, "bagel");
    assertEquals(meal.pin_decision?.used_pin, true);
    assertEquals(meal.pin_decision?.decision_source, "user_pin");
    assertEquals(meal.pin_decision?.ephemeral, undefined);
  });

  it("no eligible template for the window → slot reports solver, not a silent empty", () => {
    const capture = new LogCapture();
    capture.start();
    let results;
    try {
      results = selectPreWorkoutFoods(
        PRE_TARGETS,
        0.25, // top_up-only window
        "none",
        // Only a meal-window template exists — nothing fits `< 30 min`.
        [foodTemplates[0]],
        [],
        [],
        [],
        [],
        [],
        undefined,
        true,
      );
    } finally {
      capture.stop();
    }
    const topUp = results!.find((r) => r.phase === "top_up");
    assert(topUp !== undefined);
    assertEquals(topUp.primary, null);
    const cascade = capture.getByPrefix("FORMULA-CASCADE");
    assert(
      cascade.some((e) => e.raw.includes("source=solver")),
      "an unresolvable before slot must log a solver cascade line:\n" +
        capture.dump(),
    );
  });
});

// ===========================================================================
// Shared telemetry vocabulary
// ===========================================================================

describe("formula-decision telemetry", () => {
  it("defaultFormulaDecision stays wire-compatible while telling the truth", () => {
    const d = defaultFormulaDecision({
      templateId: "tpl-1",
      templateName: "Gel + Water",
      pinSetSize: 0,
    });
    // Legacy fields — the Dart PinDecision model and pin_banner_rows_builder
    // read these; changing them would make an unpinned user's banner claim
    // "Using your pinned formulas".
    assertEquals(d.used_pin, true);
    assertEquals(d.ephemeral, true);
    assertEquals(
      d.fallthrough_reason,
      null,
      "fallthrough_reason must stay null while used_pin is true",
    );
    // Honest additions.
    assertEquals(d.decision_source, "default_formula");
    assertEquals(d.default_fallthrough_reason, "no_pin_for_scope");
  });

  it("defaultFormulaDecision preserves a real fall-through reason", () => {
    const d = defaultFormulaDecision({
      templateId: "tpl-1",
      templateName: "Gel + Water",
      pinSetSize: 1,
      fallthroughReason: "personal_formula_empty",
    });
    assertEquals(d.default_fallthrough_reason, "personal_formula_empty");
    assertEquals(d.fallthrough_reason, null);
  });

  it("defaultFormulaDecision carries skipped personal formulas through", () => {
    const skips = [{ id: "pf-1", name: "My Gel", reason: "duration_out_of_scope" }];
    const d = defaultFormulaDecision({
      templateId: "tpl-1",
      templateName: "Gel + Water",
      pinSetSize: 0,
      skippedPersonalFormulas: skips,
    });
    assertEquals(d.skipped_personal_formulas, skips);
  });

  it("withDecisionSource never mutates and never touches legacy fields", () => {
    const base = {
      used_pin: false,
      pinned_template_id: null,
      pinned_template_name: null,
      fallthrough_reason: "no_pin_for_scope",
      pin_set_size: 0,
    };
    const tagged = withDecisionSource(base, "solver");
    assertEquals(tagged.decision_source, "solver");
    assertEquals(tagged.used_pin, false);
    assertEquals(tagged.fallthrough_reason, "no_pin_for_scope");
    assertEquals(
      (base as Record<string, unknown>).decision_source,
      undefined,
      "input must not be mutated",
    );
  });

  it("realPinSource separates system pins from personal formulas", () => {
    assertEquals(realPinSource(false), "user_pin" as FormulaDecisionSource);
    assertEquals(
      realPinSource(true),
      "personal_formula" as FormulaDecisionSource,
    );
  });

  it("a solver outcome is logged at WARN so it can never pass unnoticed", () => {
    const capture = new LogCapture();
    capture.start();
    try {
      logFormulaCascade({
        phase: "during",
        source: "solver",
        reason: "no_template_candidates",
      });
      logFormulaCascade({
        phase: "during",
        source: "default_formula",
        templateId: "t1",
        templateName: "Gel",
      });
    } finally {
      capture.stop();
    }
    const warns = capture.getByLevel("warn");
    assertEquals(warns.length, 1);
    assert(warns[0].raw.includes("source=solver"));
    assert(warns[0].raw.includes("reason=no_template_candidates"));
    const infos = capture
      .getByPrefix("FORMULA-CASCADE")
      .filter((e) => e.level === "log");
    assertEquals(infos.length, 1);
    assert(infos[0].raw.includes("source=default_formula"));
  });
});
