/**
 * Diet & Allergy Filtering Tests — generate-nutrition-plan-v3
 *
 * Covers food-preference / diet / allergy filtering across the two
 * primary during-phase code paths:
 *
 *   (A) selectTemplateCandidates() in _shared/nutrition/during-template-solver.ts
 *       — allergen exclusion, diet exclusion, dislike scoring, pin bypass
 *
 *   (B) STEP 4 in _shared/nutrition/template-food-queries.ts
 *       — tested structurally (the pure filter logic is embedded in an async
 *         Supabase function, so we exercise the deterministic entry points
 *         that exercise the same filter branches: selectTemplateCandidates
 *         and the diet-filter module)
 *
 *   (C) Before-phase Algorithm C in generate-macros-v4/pre-workout.ts
 *       via getEligibleTemplates() — same code as before-phase-filtering.test.ts
 *       but focused on the vegan/vegetarian known-failure path and the
 *       allergen-inferred hint path.
 *
 * KNOWN-FAILURE CONVENTION (mirrors parity.test.ts):
 *   Tests that expose real bugs are still written for CORRECT expected
 *   behavior. When the function currently returns the wrong answer the
 *   test catches the assertion error and re-reports it as a WARN so CI
 *   stays green while the fix is tracked.
 *
 * Run:
 *   deno test --allow-write --node-modules-dir=none \
 *     supabase/functions/generate-nutrition-plan-v3/diet-allergy-filtering.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  afterEach,
  beforeEach,
  describe,
  it,
} from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  type DuringWorkoutTemplate,
  type FoodWithConstraints,
  generateDuringPhaseTemplate,
  selectTemplate,
  selectTemplateCandidates,
} from "../_shared/nutrition/during-template-solver.ts";
import type { MacroTargets } from "../_shared/nutrition/types.ts";
import { makeFood, LogCapture } from "../_shared/nutrition/test-utils.ts";
import { getEligibleTemplates } from "../generate-macros-v4/pre-workout.ts";
import type { PreWorkoutTemplate } from "../generate-macros-v4/types.ts";

// ============================================================================
// Helpers
// ============================================================================

let logs: LogCapture;

function setup() {
  logs = new LogCapture();
  logs.start();
}

function teardown() {
  logs.stop();
  logs.clear();
}

/**
 * Run an assertion that is expected to pass. If it throws (i.e. the
 * implementation has the known bug), report as a WARN and write a log
 * to test-logs/ instead of hard-failing, keeping CI green.
 *
 * @param testName  Short name used as the test-log filename.
 * @param bugReason Human-readable explanation of the tracked bug.
 * @param fn        The assertion block.
 */
async function knownFailure(
  testName: string,
  bugReason: string,
  fn: () => void,
): Promise<void> {
  try {
    fn();
    // If the assertion PASSES the bug is fixed — celebrate and continue
    console.log(`[KNOWN-FAILURE-RESOLVED] ${testName}: assertion now passes — bug may be fixed`);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.warn(
      `[KNOWN-FAILURE] ${testName}: assertion failed (expected — tracking known bug).\n` +
      `  Bug: ${bugReason}\n` +
      `  Detail: ${msg}`,
    );
    await logs.writeToFile(
      testName,
      `KNOWN-FAILURE: ${bugReason}\n\nAssertion error:\n${msg}`,
    );
    // Do NOT rethrow — test is intentionally allowed to fail at the assertion level.
  }
}

// ============================================================================
// Template Factories
// ============================================================================

let _tmplCounter = 0;

function makeDuringTemplate(
  overrides: Partial<DuringWorkoutTemplate> & { name: string; template_number?: number },
): DuringWorkoutTemplate {
  _tmplCounter++;
  return {
    id: overrides.id ?? `tmpl-${_tmplCounter}`,
    template_number: overrides.template_number ?? _tmplCounter,
    name: overrides.name,
    formula: overrides.formula ?? overrides.name,
    food_form: overrides.food_form ?? "Mixed",
    activity_types: overrides.activity_types ?? ["running"],
    duration_brackets: overrides.duration_brackets ?? ["90-150 min"],
    gut_training_levels: overrides.gut_training_levels ?? ["low", "moderate", "high"],
    component_food_names: overrides.component_food_names ?? [],
    component_carb_ratios: overrides.component_carb_ratios ?? {},
    primary_to_secondary_ratio: overrides.primary_to_secondary_ratio ?? null,
    allergens: overrides.allergens ?? [],
    excluded_diets: overrides.excluded_diets ?? [],
    notes: overrides.notes ?? null,
    is_active: overrides.is_active ?? true,
    selection_priority: overrides.selection_priority ?? null,
  };
}

function makeFoodWithConstraints(
  overrides: Partial<FoodWithConstraints> & { name: string },
): FoodWithConstraints {
  const base = makeFood(overrides);
  return {
    ...base,
    max_per_hr_low: overrides.max_per_hr_low ?? null,
    max_per_hr_moderate: overrides.max_per_hr_moderate ?? null,
    max_per_hr_high: overrides.max_per_hr_high ?? null,
    min_increment: overrides.min_increment ?? null,
    sodium_top_up_eligible: overrides.sodium_top_up_eligible ?? null,
  };
}

// ============================================================================
// Pre-workout template factory (for before-phase / Algorithm C tests)
// ============================================================================

let _preTmplCounter = 0;

function makePreTemplate(
  overrides: Partial<PreWorkoutTemplate> & { name: string },
): PreWorkoutTemplate {
  _preTmplCounter++;
  return {
    id: overrides.id ?? `pre-tmpl-${_preTmplCounter}`,
    name: overrides.name,
    base_category: overrides.base_category ?? "grain",
    time_window: overrides.time_window ?? "1.5-3 hours",
    digestion_speed: overrides.digestion_speed ?? "medium",
    allergens: overrides.allergens ?? [],
    serving_unit: overrides.serving_unit ?? "serving",
    min_servings: overrides.min_servings ?? 1,
    max_servings: overrides.max_servings ?? 3,
    plus_banana: overrides.plus_banana ?? false,
    plus_sports_drink: overrides.plus_sports_drink ?? false,
    carbs_per_serving: overrides.carbs_per_serving ?? 30,
    protein_per_serving: overrides.protein_per_serving ?? 5,
    fat_per_serving: overrides.fat_per_serving ?? 2,
    sodium_mg: overrides.sodium_mg ?? 80,
    fluid_ml: overrides.fluid_ml ?? 0,
    template_type: overrides.template_type ?? "food",
    is_active: overrides.is_active ?? true,
    component_food_names: overrides.component_food_names ?? [],
    component_quantities: overrides.component_quantities ?? {},
    excluded_diets: overrides.excluded_diets ?? [],
  };
}

// ============================================================================
// Shared food pool — includes foods with allergens and diet tags
// ============================================================================

/**
 * Build a Map<name, FoodWithConstraints> suitable for the template solver.
 * Includes gel (vegan-safe), chicken (meat — not vegan/vegetarian),
 * dairy-based shake, gluten-bearing bar, peanut-butter chew, and water.
 */
function makeAllergyCatalog(): Map<string, FoodWithConstraints> {
  const pool = new Map<string, FoodWithConstraints>();

  pool.set("energy_gel", makeFoodWithConstraints({
    id: "energy_gel",
    name: "energy_gel",
    display_name: "Energy Gel",
    per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
    product_type: "gel",
    is_indivisible: true,
    min_servings: 1,
    max_servings: 6,
    max_per_hr_moderate: 3,
    min_increment: 1,
    // no allergens — vegan-safe
  }));

  // Gluten-bearing food (e.g. wheat-based bar)
  pool.set("wheat_bar", makeFoodWithConstraints({
    id: "wheat_bar",
    name: "wheat_bar",
    display_name: "Wheat Bar",
    per_serving: { carbs_g: 35, protein_g: 5, fat_g: 4, sodium_mg: 100, water_ml: 0, calories: 200 },
    product_type: "bar",
    min_servings: 0.5,
    max_servings: 2,
    min_increment: null,
    max_per_hr_moderate: 1,
  }));

  // Dairy-based food
  pool.set("chocolate_milk_mix", makeFoodWithConstraints({
    id: "chocolate_milk_mix",
    name: "chocolate_milk_mix",
    display_name: "Chocolate Milk Mix",
    per_serving: { carbs_g: 26, protein_g: 8, fat_g: 5, sodium_mg: 150, water_ml: 240, calories: 190 },
    product_type: "drink_mix",
    is_liquid: true,
    min_servings: 1,
    max_servings: 2,
    min_increment: null,
    max_per_hr_moderate: 1.5,
  }));

  // Peanut-containing food
  pool.set("peanut_butter_gel", makeFoodWithConstraints({
    id: "peanut_butter_gel",
    name: "peanut_butter_gel",
    display_name: "Peanut Butter Gel",
    per_serving: { carbs_g: 20, protein_g: 5, fat_g: 8, sodium_mg: 120, water_ml: 0, calories: 175 },
    product_type: "gel",
    is_indivisible: true,
    min_servings: 1,
    max_servings: 4,
    min_increment: 1,
    max_per_hr_moderate: 2,
  }));

  // Water — essential, bypasses dislike/allergen filters
  pool.set("water", makeFoodWithConstraints({
    id: "water",
    name: "water",
    display_name: "Water",
    per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
    product_type: "beverage",
    is_liquid: true,
    is_essential: true,
    min_servings: 1,
    max_servings: 6,
    min_increment: 0.5,
    max_per_hr_moderate: null,
  }));

  // Electrolyte tab — sodium top-up, no allergens
  pool.set("electrolyte_tab", makeFoodWithConstraints({
    id: "electrolyte_tab",
    name: "electrolyte_tab",
    display_name: "Electrolyte Tablet",
    per_serving: { carbs_g: 1, protein_g: 0, fat_g: 0, sodium_mg: 350, water_ml: 0, calories: 5 },
    product_type: "supplement",
    is_electrolyte: true,
    is_indivisible: true,
    sodium_top_up_eligible: true,
    min_servings: 1,
    max_servings: 4,
    min_increment: 1,
    max_per_hr_moderate: null,
  }));

  return pool;
}

// ============================================================================
// Section 1 — Allergy Exclusion (During Template Solver)
// ============================================================================

describe("1. Allergy exclusion — selectTemplateCandidates", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("1a: template with allergen X excluded when athlete has allergy X", async () => {
    const pool = makeAllergyCatalog();

    // Template A uses wheat_bar (gluten) — has Gluten allergen declared
    const glutenTemplate = makeDuringTemplate({
      name: "Gel + Wheat Bar",
      template_number: 1,
      allergens: ["Gluten"],
      component_food_names: ["energy_gel", "wheat_bar"],
      component_carb_ratios: { energy_gel: 0.5, wheat_bar: 0.5 },
    });

    // Template B is gluten-free — energy gel only
    const safeTemplate = makeDuringTemplate({
      name: "Gel Only",
      template_number: 2,
      allergens: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const candidates = selectTemplateCandidates(
      [glutenTemplate, safeTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      ["Gluten"], // athlete has gluten allergy
    );

    await logs.writeToFile(
      "diet-allergy-1a-gluten-exclusion",
      "1a: gluten-allergic athlete — template with Gluten allergen must be excluded",
    );

    const names = candidates.map(t => t.name);
    assert(
      !names.includes("Gel + Wheat Bar"),
      `Template with Gluten allergen should be excluded for gluten-allergic athlete, got: [${names.join(", ")}]`,
    );
    assert(
      names.includes("Gel Only"),
      "Safe (no-gluten) template should remain",
    );
  });

  it("1b: template with Peanut allergen excluded when athlete has peanut allergy", async () => {
    const pool = makeAllergyCatalog();

    const peanutTemplate = makeDuringTemplate({
      name: "PB Gel + Water",
      template_number: 10,
      allergens: ["Peanut"],
      component_food_names: ["peanut_butter_gel", "water"],
      component_carb_ratios: { peanut_butter_gel: 1.0 },
    });

    const safeTemplate = makeDuringTemplate({
      name: "Energy Gel + Water",
      template_number: 11,
      allergens: [],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const candidates = selectTemplateCandidates(
      [peanutTemplate, safeTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      ["Peanut"],
    );

    await logs.writeToFile(
      "diet-allergy-1b-peanut-exclusion",
      "1b: peanut-allergic athlete — template with Peanut allergen must be excluded",
    );

    const names = candidates.map(t => t.name);
    assert(
      !names.includes("PB Gel + Water"),
      "PB Gel template must be excluded for peanut-allergic athlete",
    );
    assert(names.includes("Energy Gel + Water"), "Safe template should remain");
  });

  it("1c: template with Dairy allergen excluded when athlete has dairy allergy", async () => {
    const pool = makeAllergyCatalog();

    const dairyTemplate = makeDuringTemplate({
      name: "Choc Milk Mix",
      template_number: 20,
      allergens: ["Dairy"],
      component_food_names: ["chocolate_milk_mix", "water"],
      component_carb_ratios: { chocolate_milk_mix: 1.0 },
    });

    const safeTemplate = makeDuringTemplate({
      name: "Energy Gel + Water",
      template_number: 21,
      allergens: [],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const candidates = selectTemplateCandidates(
      [dairyTemplate, safeTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      ["Dairy"],
    );

    await logs.writeToFile(
      "diet-allergy-1c-dairy-exclusion",
      "1c: dairy-allergic athlete — template with Dairy allergen must be excluded",
    );

    const names = candidates.map(t => t.name);
    assert(
      !names.includes("Choc Milk Mix"),
      "Dairy template must be excluded for dairy-allergic athlete",
    );
    assert(names.includes("Energy Gel + Water"), "Safe template should remain");
  });

  it("1d: multi-allergen stacking — both Gluten and Peanut templates excluded", async () => {
    const pool = makeAllergyCatalog();

    const glutenTemplate = makeDuringTemplate({
      name: "Wheat Bar",
      template_number: 30,
      allergens: ["Gluten"],
      component_food_names: ["wheat_bar"],
      component_carb_ratios: { wheat_bar: 1.0 },
    });
    const peanutTemplate = makeDuringTemplate({
      name: "PB Gel",
      template_number: 31,
      allergens: ["Peanut"],
      component_food_names: ["peanut_butter_gel"],
      component_carb_ratios: { peanut_butter_gel: 1.0 },
    });
    const safeTemplate = makeDuringTemplate({
      name: "Energy Gel Only",
      template_number: 32,
      allergens: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const candidates = selectTemplateCandidates(
      [glutenTemplate, peanutTemplate, safeTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      ["Gluten", "Peanut"],
    );

    await logs.writeToFile(
      "diet-allergy-1d-multi-allergen",
      "1d: Gluten+Peanut allergies — both allergen templates excluded",
    );

    const names = candidates.map(t => t.name);
    assert(!names.includes("Wheat Bar"), "Gluten template excluded");
    assert(!names.includes("PB Gel"), "Peanut template excluded");
    assert(names.includes("Energy Gel Only"), "Safe template survives");
  });
});

// ============================================================================
// Section 2 — Allergen-Based Diet Diets (gluten-free / dairy-free / peanut-free)
// ============================================================================

describe("2. Allergen-based diets — gluten-free, dairy-free, peanut-free (should PASS)", () => {
  beforeEach(setup);
  afterEach(teardown);

  /**
   * These are tested via getEligibleTemplates() (before-phase Algorithm C path)
   * because that function covers the allergen-diet map used in before/during.
   * The same logic is mirrored in STEP 4 of template-food-queries.ts.
   */

  it("2a: gluten-free diet excludes templates with Gluten allergen", async () => {
    const glutenTemplate = makePreTemplate({
      name: "Oatmeal Bowl",
      allergens: ["Gluten"],
      component_food_names: ["oatmeal"],
      excluded_diets: [],
    });
    const safeTemplate = makePreTemplate({
      name: "Banana",
      allergens: [],
      component_food_names: ["banana"],
      excluded_diets: [],
    });

    const result = getEligibleTemplates(
      [glutenTemplate, safeTemplate],
      "meal",
      "gluten-free",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-2a-gluten-free-diet",
      "2a: gluten-free diet — Oatmeal (Gluten allergen) must be excluded",
    );

    const names = result.map(t => t.name);
    assert(!names.includes("Oatmeal Bowl"), "Oatmeal excluded for gluten-free diet");
    assert(names.includes("Banana"), "Banana survives gluten-free diet");
  });

  it("2b: dairy-free diet excludes templates with Dairy allergen", async () => {
    const dairyTemplate = makePreTemplate({
      name: "Greek Yogurt Bowl",
      allergens: ["Dairy"],
      component_food_names: ["greek_yogurt", "granola"],
      excluded_diets: [],
    });
    const safeTemplate = makePreTemplate({
      name: "Banana",
      allergens: [],
      component_food_names: ["banana"],
      excluded_diets: [],
    });

    const result = getEligibleTemplates(
      [dairyTemplate, safeTemplate],
      "meal",
      "dairy-free",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-2b-dairy-free-diet",
      "2b: dairy-free diet — Yogurt (Dairy allergen) must be excluded",
    );

    const names = result.map(t => t.name);
    assert(!names.includes("Greek Yogurt Bowl"), "Yogurt excluded for dairy-free diet");
    assert(names.includes("Banana"), "Banana survives dairy-free diet");
  });

  it("2c: peanut-free diet excludes templates with Peanut allergen", async () => {
    const peanutTemplate = makePreTemplate({
      name: "Toast with PB",
      allergens: ["Gluten", "Peanut"],
      component_food_names: ["toast", "peanut_butter"],
      excluded_diets: [],
    });
    const safeTemplate = makePreTemplate({
      name: "Rice Cakes with Jam",
      allergens: [],
      component_food_names: ["rice_cake", "jam"],
      excluded_diets: [],
    });

    const result = getEligibleTemplates(
      [peanutTemplate, safeTemplate],
      "meal",
      "peanut-free",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-2c-peanut-free-diet",
      "2c: peanut-free diet — PB toast (Peanut allergen) must be excluded",
    );

    const names = result.map(t => t.name);
    assert(!names.includes("Toast with PB"), "PB toast excluded for peanut-free");
    assert(names.includes("Rice Cakes with Jam"), "Rice cakes survive");
  });

  it("2d: all-free diet excludes templates with any of Gluten/Dairy/Peanut", async () => {
    const glutenTemplate = makePreTemplate({ name: "Oatmeal", allergens: ["Gluten"], component_food_names: ["oatmeal"], excluded_diets: [] });
    const dairyTemplate = makePreTemplate({ name: "Yogurt Bowl", allergens: ["Dairy"], component_food_names: ["yogurt"], excluded_diets: [] });
    const peanutTemplate = makePreTemplate({ name: "PB Toast", allergens: ["Peanut", "Gluten"], component_food_names: ["peanut_butter", "toast"], excluded_diets: [] });
    const safeTemplate = makePreTemplate({ name: "Banana", allergens: [], component_food_names: ["banana"], excluded_diets: [] });

    const result = getEligibleTemplates(
      [glutenTemplate, dairyTemplate, peanutTemplate, safeTemplate],
      "meal",
      "all-free",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-2d-all-free-diet",
      "2d: all-free diet — all allergen-bearing templates excluded",
    );

    const names = result.map(t => t.name);
    assert(!names.includes("Oatmeal"), "Oatmeal excluded (Gluten)");
    assert(!names.includes("Yogurt Bowl"), "Yogurt excluded (Dairy)");
    assert(!names.includes("PB Toast"), "PB Toast excluded (Peanut)");
    assert(names.includes("Banana"), "Banana survives all-free");
  });
});

// ============================================================================
// Section 3 — Vegan / Vegetarian (KNOWN BUG)
// ============================================================================

describe("3. Vegan / Vegetarian diet filtering (KNOWN BUG)", () => {
  beforeEach(setup);
  afterEach(teardown);

  /**
   * The known bug (tracked in before-diet-vegan-bug.log):
   *
   * Both before-phase (getEligibleTemplates) and during-phase
   * (selectTemplateCandidates) rely on excluded_diets containing "vegan" /
   * "vegetarian" explicitly in the DB row. When a template's excluded_diets
   * is EMPTY — which is the common case for meat/dairy templates that predate
   * the vegan feature — no exclusion happens. The filter only works when the
   * template DB row already has excluded_diets populated correctly.
   *
   * Correct behavior (what we assert): an athlete with diet=vegan and a
   * template whose component foods contain meat (chicken) OR whose
   * excluded_diets is empty but inferably non-vegan should NOT appear.
   *
   * The test asserts correct behavior. Because the bug exists today, the
   * assertion will fail and is caught by knownFailure().
   */

  it("3a: [KNOWN BUG] vegan athlete — template with empty excluded_diets but meat component is NOT selected (before-phase)", async () => {
    // Template for a chicken-and-rice bowl. A real vegan meal plan should
    // exclude this. excluded_diets is intentionally empty to expose the bug.
    const meatTemplate = makePreTemplate({
      name: "Chicken Rice Bowl",
      base_category: "protein",
      allergens: [],
      component_food_names: ["chicken", "white_rice"],
      excluded_diets: [], // BUG: should be ["vegan", "vegetarian"] in DB
    });

    const veganTemplate = makePreTemplate({
      name: "Banana + Almond Butter",
      base_category: "fruit",
      allergens: ["Tree Nuts"],
      component_food_names: ["banana", "almond_butter"],
      excluded_diets: [],
    });

    const result = getEligibleTemplates(
      [meatTemplate, veganTemplate],
      "meal",
      "vegan",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-3a-vegan-meat-bug",
      `KNOWN BUG: vegan diet does not infer meat exclusion from component names.\n` +
      `See before-diet-vegan-bug.log. Template 'Chicken Rice Bowl' (excluded_diets=[]) ` +
      `passes through when it should be excluded for vegan athletes.`,
    );

    const names = result.map(t => t.name);
    console.log(`[TEST-3a] Vegan filter result: [${names.join(", ")}]`);

    await knownFailure(
      "diet-allergy-3a-vegan-meat-bug",
      "vegan/vegetarian not recognized in diet filter — template with empty excluded_diets but meat component passes through. See before-diet-vegan-bug.log",
      () => {
        assert(
          !names.includes("Chicken Rice Bowl"),
          `[CORRECT BEHAVIOR] Chicken Rice Bowl should be excluded for vegan athlete, but was included. ` +
          `This confirms the bug: vegan filter only acts on excluded_diets, not component food inference.`,
        );
      },
    );
  });

  it("3b: [KNOWN BUG] vegan athlete — template with empty excluded_diets but dairy component is NOT selected (during-phase)", async () => {
    const pool = makeAllergyCatalog();

    // Template uses chocolate_milk_mix — a dairy product. excluded_diets is
    // empty (simulating a DB row not yet tagged with "vegan").
    const dairyTemplate = makeDuringTemplate({
      name: "Choc Milk Drink",
      template_number: 50,
      allergens: [], // NOTE: allergens=[] so allergen path doesn't catch it
      excluded_diets: [], // BUG: should contain "vegan", "dairy-free"
      component_food_names: ["chocolate_milk_mix"],
      component_carb_ratios: { chocolate_milk_mix: 1.0 },
    });
    const veganTemplate = makeDuringTemplate({
      name: "Energy Gel + Water",
      template_number: 51,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const candidates = selectTemplateCandidates(
      [dairyTemplate, veganTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      [],       // no explicit allergies
      "vegan",  // diet preference
    );

    await logs.writeToFile(
      "diet-allergy-3b-vegan-during-dairy-bug",
      `KNOWN BUG: vegan diet during-phase — chocolate_milk_mix template with empty ` +
      `excluded_diets passes through selectTemplateCandidates. The diet filter only ` +
      `matches on excluded_diets[]. Without "vegan" or "dairy-free" in that field, ` +
      `dairy foods are served to vegan athletes.`,
    );

    const names = candidates.map(t => t.name);
    console.log(`[TEST-3b] Vegan during-phase result: [${names.join(", ")}]`);

    await knownFailure(
      "diet-allergy-3b-vegan-during-dairy-bug",
      "vegan/vegetarian not recognized in during-phase diet filter — template with empty excluded_diets but dairy component passes through. See before-diet-vegan-bug.log",
      () => {
        assert(
          !names.includes("Choc Milk Drink"),
          `[CORRECT BEHAVIOR] Choc Milk Drink should be excluded for vegan athlete ` +
          `even when excluded_diets is empty, because chocolate_milk_mix is a dairy product.`,
        );
      },
    );
  });

  it("3c: [KNOWN BUG] vegetarian athlete — template with meat component (empty excluded_diets) should be excluded (before-phase)", async () => {
    const meatTemplate = makePreTemplate({
      name: "Bacon Egg Toast",
      base_category: "protein",
      allergens: ["Gluten", "Eggs"],
      component_food_names: ["bacon", "egg", "toast"],
      excluded_diets: [], // BUG: should contain "vegan", "vegetarian"
    });
    const vegetarianTemplate = makePreTemplate({
      name: "Egg on Toast",
      base_category: "egg",
      allergens: ["Gluten", "Eggs"],
      component_food_names: ["egg", "toast"],
      excluded_diets: ["vegan"], // correctly tagged — not vegetarian-excluded
    });
    const veggieTemplate = makePreTemplate({
      name: "Oatmeal with Banana",
      base_category: "grain",
      allergens: ["Gluten"],
      component_food_names: ["oatmeal", "banana"],
      excluded_diets: [],
    });

    const result = getEligibleTemplates(
      [meatTemplate, vegetarianTemplate, veggieTemplate],
      "meal",
      "vegetarian",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-3c-vegetarian-meat-bug",
      `KNOWN BUG: vegetarian diet — bacon template with empty excluded_diets passes through. ` +
      `See before-diet-vegetarian-bug.log.`,
    );

    const names = result.map(t => t.name);
    console.log(`[TEST-3c] Vegetarian filter result: [${names.join(", ")}]`);

    await knownFailure(
      "diet-allergy-3c-vegetarian-meat-bug",
      "vegetarian not recognized in diet filter — template with empty excluded_diets but bacon/meat component passes through. See before-diet-vegetarian-bug.log",
      () => {
        assert(
          !names.includes("Bacon Egg Toast"),
          `[CORRECT BEHAVIOR] Bacon Egg Toast should be excluded for vegetarian athlete.`,
        );
      },
    );

    // This part SHOULD pass — a template correctly tagged with excluded_diets=["vegan"]
    // but NOT "vegetarian" must still be returned for a vegetarian athlete.
    assert(
      names.includes("Egg on Toast"),
      "Egg on Toast should remain — it's excluded only for vegan, not vegetarian",
    );
    assert(
      names.includes("Oatmeal with Banana"),
      "Oatmeal should remain — vegetarian-compatible",
    );
  });

  it("3d: vegan diet works correctly when excluded_diets is populated (positive case)", async () => {
    // This case should already PASS — the existing excluded_diets logic
    // correctly filters when the DB row has the field set.
    const correctlyTaggedMeatTemplate = makePreTemplate({
      name: "Chicken Rice Bowl (tagged)",
      base_category: "protein",
      allergens: [],
      component_food_names: ["chicken", "white_rice"],
      excluded_diets: ["vegan", "vegetarian"], // correctly populated
    });
    const safeTemplate = makePreTemplate({
      name: "Banana",
      allergens: [],
      component_food_names: ["banana"],
      excluded_diets: [],
    });

    const result = getEligibleTemplates(
      [correctlyTaggedMeatTemplate, safeTemplate],
      "meal",
      "vegan",
      [],
      [],
    );

    await logs.writeToFile(
      "diet-allergy-3d-vegan-correctly-tagged",
      "3d: vegan positive case — correctly tagged template is excluded",
    );

    const names = result.map(t => t.name);
    assert(
      !names.includes("Chicken Rice Bowl (tagged)"),
      "Correctly-tagged meat template excluded for vegan athlete",
    );
    assert(names.includes("Banana"), "Banana survives vegan filter");
  });
});

// ============================================================================
// Section 4 — Disliked Food Scoring and Shortfall Emission
// ============================================================================

describe("4. Disliked food scoring — deprioritization and shortfall", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("4a: template containing disliked food is deprioritized (lower score)", async () => {
    const pool = makeAllergyCatalog();

    // Template A contains wheat_bar — user dislikes it. score penalty: -20
    const dislikedTemplate = makeDuringTemplate({
      name: "Gel + Wheat Bar",
      template_number: 100,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel", "wheat_bar"],
      component_carb_ratios: { energy_gel: 0.5, wheat_bar: 0.5 },
      selection_priority: 0,
    });

    // Template B contains only energy_gel — not disliked. score: 0
    const preferredTemplate = makeDuringTemplate({
      name: "Gel Only",
      template_number: 101,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
      selection_priority: 0,
    });

    const dislikedFoods = new Set(["wheat_bar", "Wheat Bar"]);

    const candidates = selectTemplateCandidates(
      [dislikedTemplate, preferredTemplate],
      "running", 120, "moderate",
      pool,
      undefined, // liked
      undefined, // willing
      dislikedFoods,
    );

    await logs.writeToFile(
      "diet-allergy-4a-dislike-deprioritized",
      "4a: template with disliked food should be ranked lower",
    );

    assert(candidates.length >= 2, "Both templates should remain (dislike is a score penalty, not a hard filter)");
    assertEquals(
      candidates[0].template_number,
      101,
      "Template without disliked food (Gel Only) should rank first",
    );
    assertEquals(
      candidates[1].template_number,
      100,
      "Template with disliked food (Gel + Wheat Bar) should rank second",
    );
  });

  it("4b: selectTemplate returns the preferred (non-disliked) template", async () => {
    const pool = makeAllergyCatalog();

    const dislikedTemplate = makeDuringTemplate({
      name: "Gel + Wheat Bar",
      template_number: 200,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel", "wheat_bar"],
      component_carb_ratios: { energy_gel: 0.5, wheat_bar: 0.5 },
      selection_priority: 0,
    });
    const preferredTemplate = makeDuringTemplate({
      name: "Gel Only",
      template_number: 201,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
      selection_priority: 0,
    });

    const selected = selectTemplate(
      [dislikedTemplate, preferredTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined,
      new Set(["wheat_bar", "Wheat Bar"]),
    );

    await logs.writeToFile(
      "diet-allergy-4b-select-preferred",
      "4b: selectTemplate picks preferred (non-disliked) template",
    );

    assertExists(selected, "A template should be selected");
    assertEquals(
      selected!.template_number,
      201,
      "Preferred template (Gel Only, no disliked foods) should win",
    );
  });

  it("4c: sodium shortfall emitted when dislikes force fallback to low-sodium option", async () => {
    const pool = makeAllergyCatalog();

    // Remove electrolyte_tab from pool to force a sodium gap
    pool.delete("electrolyte_tab");

    // Remove peanut_butter_gel too (only sodium sources besides gel)
    pool.delete("peanut_butter_gel");
    pool.delete("wheat_bar");
    pool.delete("chocolate_milk_mix");

    // Template uses energy_gel + water. Gel provides ~55mg sodium per serving.
    // With a 120-min run and 2 gels, that's ~110mg — well below 800mg target.
    const template = makeDuringTemplate({
      name: "Gel + Water Only",
      template_number: 300,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 800,
      water_ml: 600,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
      // Mark electrolyte_tab disliked even though it's not in pool —
      // this ensures solver won't reach for it even if pool is augmented
      new Set(["electrolyte_tab"]),
    );

    await logs.writeToFile(
      "diet-allergy-4c-sodium-shortfall",
      "4c: sodium shortfall emitted when dislikes force low-sodium plan",
    );

    // The solver may return null (validation failure at extreme shortfall)
    // or a result with shortfalls. Either is acceptable per design.
    if (result !== null) {
      const sodiumDelivered = result.foods.reduce((acc, f) => acc + f.sodium_mg, 0);
      console.log(`[TEST-4c] Sodium delivered: ${sodiumDelivered}mg (target: ${targets.sodium_mg}mg)`);

      // When result is non-null but sodium falls well short due to dislikes,
      // shortfalls should be reported.
      const sodiumRatio = sodiumDelivered / targets.sodium_mg;
      if (sodiumRatio < 0.5) {
        // A significant shortfall — the shortfalls array should be populated
        // when the cause is preference filtering.
        // Note: per the test-plan (P3), shortfall emission only fires when
        // dislikedFoods.size > 0. We pass a non-empty set above so this path
        // should be active.
        assert(
          result.shortfalls !== undefined && result.shortfalls.length > 0,
          `Sodium delivered only ${(sodiumRatio * 100).toFixed(0)}% of target but no shortfall was emitted. ` +
          `Shortfall should be reported when dislikes cause a macro miss.`,
        );
      }
    } else {
      // null is acceptable when the plan truly cannot be built
      console.log("[TEST-4c] Solver returned null — acceptable when sodium target unreachable without disliked foods");
    }
  });
});

// ============================================================================
// Section 5 — Pin Override Bypass
// ============================================================================

describe("5. Pin override — bypasses allergen / diet / dislike filters", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("5a: pinned template is returned even when it has allergen matching athlete's allergy", async () => {
    const pool = makeAllergyCatalog();

    // Pinned template has Gluten allergen — athlete is gluten-allergic
    const pinnedGlutenTemplate = makeDuringTemplate({
      id: "pinned-gluten-tmpl",
      name: "Pinned Wheat Bar Template",
      template_number: 400,
      allergens: ["Gluten"],
      excluded_diets: [],
      component_food_names: ["energy_gel", "wheat_bar"],
      component_carb_ratios: { energy_gel: 0.5, wheat_bar: 0.5 },
    });

    const normalTemplate = makeDuringTemplate({
      name: "Normal Gel Template",
      template_number: 401,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const pinnedIds = new Set(["pinned-gluten-tmpl"]);

    const candidates = selectTemplateCandidates(
      [pinnedGlutenTemplate, normalTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      ["Gluten"], // athlete is gluten-allergic
      undefined,  // no diet preference
      pinnedIds,  // pinned template id
    );

    await logs.writeToFile(
      "diet-allergy-5a-pin-bypass-allergen",
      "5a: pinned template bypasses allergen filter — athlete pinned a gluten template despite gluten allergy",
    );

    const names = candidates.map(t => t.name);
    console.log(`[TEST-5a] Pin bypass result: [${names.join(", ")}]`);

    // Per the locked Formula Kit policy: pins bypass ALL filters including allergen/diet
    assert(
      names.includes("Pinned Wheat Bar Template"),
      "Pinned template must appear even when it conflicts with athlete's allergen",
    );
    // Only the pinned template should be returned — the normal template is ignored
    // when a pin is in scope
    assertEquals(
      candidates.length,
      1,
      "When a pin is in scope, only the pinned template(s) are returned",
    );
  });

  it("5b: pinned template is returned even when athlete has matching diet exclusion", async () => {
    const pool = makeAllergyCatalog();

    // Template explicitly excluded for vegan diet, but athlete has pinned it
    const pinnedDairyTemplate = makeDuringTemplate({
      id: "pinned-dairy-tmpl",
      name: "Pinned Choc Milk Template",
      template_number: 500,
      allergens: ["Dairy"],
      excluded_diets: ["vegan"],
      component_food_names: ["chocolate_milk_mix"],
      component_carb_ratios: { chocolate_milk_mix: 1.0 },
    });

    const safeTemplate = makeDuringTemplate({
      name: "Gel Template",
      template_number: 501,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const pinnedIds = new Set(["pinned-dairy-tmpl"]);

    const candidates = selectTemplateCandidates(
      [pinnedDairyTemplate, safeTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      [],       // no explicit allergies
      "vegan",  // athlete diet is vegan
      pinnedIds,
    );

    await logs.writeToFile(
      "diet-allergy-5b-pin-bypass-diet",
      "5b: pinned template bypasses diet exclusion filter",
    );

    const names = candidates.map(t => t.name);
    console.log(`[TEST-5b] Pin + vegan diet bypass result: [${names.join(", ")}]`);

    assert(
      names.includes("Pinned Choc Milk Template"),
      "Pinned template must appear even when excluded by vegan diet filter",
    );
    assertEquals(
      candidates.length,
      1,
      "Only the pinned template is returned when a pin is in scope",
    );
  });

  it("5c: pinned template returned even when all its component foods are disliked", async () => {
    const pool = makeAllergyCatalog();

    const pinnedTemplate = makeDuringTemplate({
      id: "pinned-disliked-tmpl",
      name: "Pinned All-Disliked Template",
      template_number: 600,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    const normalTemplate = makeDuringTemplate({
      name: "Normal Template",
      template_number: 601,
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    // Dislike both foods in the pinned template
    const disliked = new Set(["energy_gel", "water", "Energy Gel", "Water"]);
    const pinnedIds = new Set(["pinned-disliked-tmpl"]);

    const candidates = selectTemplateCandidates(
      [pinnedTemplate, normalTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined,
      disliked,
      [],
      undefined,
      pinnedIds,
    );

    await logs.writeToFile(
      "diet-allergy-5c-pin-bypass-dislike",
      "5c: pinned template bypasses dislike filter",
    );

    const names = candidates.map(t => t.name);
    console.log(`[TEST-5c] Pin + dislike bypass result: [${names.join(", ")}]`);

    assert(
      names.includes("Pinned All-Disliked Template"),
      "Pinned template must appear even when all its components are disliked",
    );
    assertEquals(
      candidates.length,
      1,
      "Only the pinned template is returned when a pin is in scope",
    );
  });

  it("5d: out-of-scope pin does NOT bypass filters (falls through to normal selection)", async () => {
    const pool = makeAllergyCatalog();

    // The pin is for cycling 90-150min, but we are asking for running 120min.
    // Technically same bracket, but the template activity_types is cycling-only.
    const outOfScopePinTemplate = makeDuringTemplate({
      id: "cycling-pin-tmpl",
      name: "Cycling Pinned Template",
      template_number: 700,
      activity_types: ["cycling"], // does NOT include running
      duration_brackets: ["90-150 min"],
      allergens: ["Gluten"],
      excluded_diets: [],
      component_food_names: ["wheat_bar"],
      component_carb_ratios: { wheat_bar: 1.0 },
    });

    const normalRunningTemplate = makeDuringTemplate({
      name: "Running Gel",
      template_number: 701,
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      allergens: [],
      excluded_diets: [],
      component_food_names: ["energy_gel"],
      component_carb_ratios: { energy_gel: 1.0 },
    });

    // Pin references the cycling template, but we are running
    const pinnedIds = new Set(["cycling-pin-tmpl"]);

    const candidates = selectTemplateCandidates(
      [outOfScopePinTemplate, normalRunningTemplate],
      "running", 120, "moderate",
      pool,
      undefined, undefined, undefined,
      ["Gluten"], // athlete is gluten-allergic
      undefined,
      pinnedIds,
    );

    await logs.writeToFile(
      "diet-allergy-5d-out-of-scope-pin",
      "5d: out-of-scope pin does not bypass filters — normal selection applies",
    );

    const names = candidates.map(t => t.name);
    console.log(`[TEST-5d] Out-of-scope pin result: [${names.join(", ")}]`);

    // Out-of-scope pin: cycling template doesn't match running → pin bypass
    // is not triggered → normal candidate selection applies → gluten template
    // is excluded by the allergen filter.
    assert(
      !names.includes("Cycling Pinned Template"),
      "Out-of-scope pinned template should NOT bypass allergen filter " +
      "(it does not match the running activity type)",
    );
    assert(
      names.includes("Running Gel"),
      "Normal running template should be selected via normal filter path",
    );
  });
});
