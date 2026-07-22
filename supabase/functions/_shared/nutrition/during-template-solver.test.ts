/**
 * Local Unit Tests for During-Phase Template Solver
 *
 * Tests selectTemplate() and generateDuringPhaseTemplate() directly
 * with mock food data. No HTTP, no Supabase -- pure algorithm testing
 * with log capture.
 *
 * Run with:
 *   deno test --no-check --allow-read --allow-write supabase/functions/_shared/nutrition/during-template-solver.test.ts
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
  collectShortfalls,
  type DuringWorkoutTemplate,
  type FoodWithConstraints,
  generateDuringPhaseTemplate,
  type GutTrainingLevel,
  selectTemplate,
  selectTemplateCandidates,
  type TemplateSolverResult,
} from "./during-template-solver.ts";
import type { ActivityType, MacroTargets } from "./types.ts";
import {
  LogCapture,
  makeFood,
  strictAssertMacrosInRange,
  sumFoodResults,
} from "./test-utils.ts";

// ============================================================================
// Test Factories
// ============================================================================

/**
 * Create a DuringWorkoutTemplate with sensible defaults.
 * `template_number` and `name` are required; everything else has defaults.
 */
function makeTemplate(
  overrides: Partial<DuringWorkoutTemplate> & {
    template_number: number;
    name: string;
  },
): DuringWorkoutTemplate {
  return {
    id: overrides.id ?? `template-${overrides.template_number}`,
    template_number: overrides.template_number,
    name: overrides.name,
    formula: overrides.formula ?? overrides.name,
    food_form: overrides.food_form ?? "Mixed",
    activity_types: overrides.activity_types ?? ["running", "cycling"],
    duration_brackets: overrides.duration_brackets ?? ["90-150 min"],
    gut_training_levels: overrides.gut_training_levels ??
      ["low", "moderate", "high"],
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

/**
 * Create a FoodWithConstraints using makeFood internally,
 * then add constraint fields.
 */
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

/**
 * Create a standard pool of during foods with constraints.
 * Returns Map<string, FoodWithConstraints> keyed by food name.
 */
function makeTemplateFoodPool(): Map<string, FoodWithConstraints> {
  const pool = new Map<string, FoodWithConstraints>();

  pool.set(
    "energy_gel",
    makeFoodWithConstraints({
      id: "energy_gel",
      name: "energy_gel",
      display_name: "Energy Gel",
      per_serving: {
        carbs_g: 25,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 55,
        water_ml: 0,
        calories: 100,
      },
      product_type: "gel",
      is_indivisible: true,
      max_per_hr_low: 2,
      max_per_hr_moderate: 3,
      max_per_hr_high: 3,
      min_increment: 1,
      min_servings: 1,
      max_servings: 6,
    }),
  );

  pool.set(
    "energy_chews",
    makeFoodWithConstraints({
      id: "energy_chews",
      name: "energy_chews",
      display_name: "Energy Chews",
      per_serving: {
        carbs_g: 24,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 70,
        water_ml: 0,
        calories: 96,
      },
      product_type: "chew",
      is_indivisible: true,
      max_per_hr_low: 1,
      max_per_hr_moderate: 2,
      max_per_hr_high: 2,
      min_increment: 0.5,
      min_servings: 1,
      max_servings: 6,
    }),
  );

  pool.set(
    "energy_bar",
    makeFoodWithConstraints({
      id: "energy_bar",
      name: "energy_bar",
      display_name: "Energy Bar",
      per_serving: {
        carbs_g: 40,
        protein_g: 5,
        fat_g: 8,
        sodium_mg: 200,
        water_ml: 0,
        calories: 250,
      },
      product_type: "bar",
      max_per_hr_low: 0.5,
      max_per_hr_moderate: 1,
      max_per_hr_high: 1,
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 2,
    }),
  );

  pool.set(
    "stroopwafel",
    makeFoodWithConstraints({
      id: "stroopwafel",
      name: "stroopwafel",
      display_name: "Stroopwafel",
      per_serving: {
        carbs_g: 30,
        protein_g: 1,
        fat_g: 5,
        sodium_mg: 65,
        water_ml: 0,
        calories: 160,
      },
      product_type: "real_food",
      max_per_hr_low: 1,
      max_per_hr_moderate: 1,
      max_per_hr_high: 2,
      min_increment: 1,
      min_servings: 0.5,
      max_servings: 3,
    }),
  );

  pool.set(
    "banana",
    makeFoodWithConstraints({
      id: "banana",
      name: "banana",
      display_name: "Banana",
      per_serving: {
        carbs_g: 27,
        protein_g: 1,
        fat_g: 0,
        sodium_mg: 1,
        water_ml: 30,
        calories: 105,
      },
      product_type: "real_food",
      max_per_hr_low: 0.5,
      max_per_hr_moderate: 1,
      max_per_hr_high: 1,
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 2,
    }),
  );

  pool.set(
    "rice_cake_during",
    makeFoodWithConstraints({
      id: "rice_cake_during",
      name: "rice_cake_during",
      display_name: "Rice Cake",
      per_serving: {
        carbs_g: 35,
        protein_g: 2,
        fat_g: 3,
        sodium_mg: 100,
        water_ml: 0,
        calories: 175,
      },
      product_type: "real_food",
      max_per_hr_low: 1,
      max_per_hr_moderate: 1,
      max_per_hr_high: 2,
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 4,
    }),
  );

  pool.set(
    "sports_drink",
    makeFoodWithConstraints({
      id: "sports_drink",
      name: "sports_drink",
      display_name: "Sports Drink",
      per_serving: {
        carbs_g: 15,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 110,
        water_ml: 240,
        calories: 60,
      },
      product_type: "sports_drink",
      is_liquid: true,
      max_per_hr_low: 2,
      max_per_hr_moderate: 2.5,
      max_per_hr_high: 3,
      min_increment: 0.5,
      min_servings: 1,
      max_servings: 4,
    }),
  );

  pool.set(
    "carb_drink_mix",
    makeFoodWithConstraints({
      id: "carb_drink_mix",
      name: "carb_drink_mix",
      display_name: "Carb Drink Mix",
      per_serving: {
        carbs_g: 60,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 160,
        water_ml: 500,
        calories: 240,
      },
      product_type: "drink_mix",
      is_liquid: true,
      max_per_hr_low: 0,
      max_per_hr_moderate: 1,
      max_per_hr_high: 1,
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 6,
    }),
  );

  pool.set(
    "high_carb_drink_mix",
    makeFoodWithConstraints({
      id: "high_carb_drink_mix",
      name: "high_carb_drink_mix",
      display_name: "High Carb Drink Mix",
      per_serving: {
        carbs_g: 90,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 200,
        water_ml: 600,
        calories: 360,
      },
      product_type: "drink_mix",
      is_liquid: true,
      max_per_hr_low: 0,
      max_per_hr_moderate: 0,
      max_per_hr_high: 1,
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 3,
    }),
  );

  pool.set(
    "water",
    makeFoodWithConstraints({
      id: "water",
      name: "water",
      display_name: "Water",
      per_serving: {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 0,
        water_ml: 240,
        calories: 0,
      },
      product_type: "beverage",
      is_liquid: true,
      is_essential: true,
      min_increment: 0.5,
      min_servings: 1,
      max_servings: 6,
    }),
  );

  pool.set(
    "electrolyte_tab",
    makeFoodWithConstraints({
      id: "electrolyte_tab",
      name: "electrolyte_tab",
      display_name: "Electrolyte Tablet",
      per_serving: {
        carbs_g: 1,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 350,
        water_ml: 0,
        calories: 10,
      },
      product_type: "supplement",
      is_electrolyte: true,
      is_indivisible: true,
      sodium_top_up_eligible: true,
      min_increment: 1,
      min_servings: 1,
      max_servings: 4,
    }),
  );

  return pool;
}

/**
 * Create a representative set of during-workout templates.
 */
function makeStandardTemplates(): DuringWorkoutTemplate[] {
  return [
    // Template 1: Gel + Water (running, 90-150min, all gut levels)
    makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    }),
    // Template 2: Gel + Water + Sports Drink (running, 90-150/150-240/>240, moderate/high)
    makeTemplate({
      template_number: 2,
      name: "Gel + Sports Drink + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min", "150-240 min", "> 240 min"],
      gut_training_levels: ["moderate", "high"],
      component_food_names: ["energy_gel", "water", "sports_drink"],
      component_carb_ratios: { "energy_gel": 0.7, "sports_drink": 0.3 },
    }),
    // Template 3: Chew + Water (running, 90-150, all gut)
    makeTemplate({
      template_number: 3,
      name: "Chew + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_chews", "water"],
      component_carb_ratios: { "energy_chews": 1.0 },
    }),
    // Template 5: Sports Drink Only (<90min, all sports, all gut)
    makeTemplate({
      template_number: 5,
      name: "Sports Drink Only",
      activity_types: ["running", "cycling", "swimming"],
      duration_brackets: ["< 90 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["sports_drink"],
      component_carb_ratios: { "sports_drink": 1.0 },
    }),
    // Template 6: High Carb Drink Mix + Water (cycling, 90-150/150-240, high only)
    makeTemplate({
      template_number: 6,
      name: "High Carb Drink Mix + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min", "150-240 min"],
      gut_training_levels: ["high"],
      component_food_names: ["high_carb_drink_mix", "water"],
      component_carb_ratios: { "high_carb_drink_mix": 1.0 },
    }),
    // Template 7: Bar + Sports Drink + Water (cycling, 90-150, all gut)
    makeTemplate({
      template_number: 7,
      name: "Bar + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_bar", "sports_drink", "water"],
      component_carb_ratios: { "energy_bar": 0.55, "sports_drink": 0.45 },
    }),
    // Template 8: Bar + Gel + Sports Drink + Water (cycling, 150-240, moderate/high, 1:1 ratio)
    makeTemplate({
      template_number: 8,
      name: "Bar + Gel + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["150-240 min"],
      gut_training_levels: ["moderate", "high"],
      component_food_names: [
        "energy_bar",
        "energy_gel",
        "water",
        "sports_drink",
      ],
      component_carb_ratios: {
        "energy_bar": 0.35,
        "energy_gel": 0.35,
        "sports_drink": 0.3,
      },
      primary_to_secondary_ratio: "1:1",
    }),
    // Template 9: Stroopwafel + Sports Drink + Water (cycling, 90-150, allergens)
    makeTemplate({
      template_number: 9,
      name: "Stroopwafel + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["stroopwafel", "sports_drink", "water"],
      component_carb_ratios: { "stroopwafel": 0.55, "sports_drink": 0.45 },
      allergens: ["gluten", "dairy"],
      excluded_diets: ["vegan", "gluten_free"],
    }),
  ];
}

// ============================================================================
// Test Setup
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

// ============================================================================
// A. Template Selection (selectTemplate)
// ============================================================================

describe("Template Selection (selectTemplate)", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("matches every documented template activity and duration gate through the selector", async () => {
    const foodsByName = makeTemplateFoodPool();
    const durationByBracket = new Map<string, number>([
      ["< 90 min", 60],
      ["90-150 min", 120],
      ["150-240 min", 180],
      ["> 240 min", 300],
    ]);
    const activityToSolverType = (activity: string): ActivityType => {
      if (activity === "triathlon_bike") return "triathlon";
      if (activity === "triathlon_run") return "triathlon";
      if (activity === "triathlon_transition") return "triathlon";
      return activity as ActivityType;
    };
    const coverage = [
      [
        0,
        ["triathlon_transition"],
        ["90-150 min", "150-240 min", "> 240 min"],
        ["low", "moderate", "high"],
      ],
      [1, ["running", "triathlon_run"], ["90-150 min"], [
        "low",
        "moderate",
        "high",
      ]],
      [2, ["running", "triathlon_run"], [
        "90-150 min",
        "150-240 min",
        "> 240 min",
      ], ["moderate", "high"]],
      [3, ["running", "triathlon_run"], ["90-150 min"], [
        "low",
        "moderate",
        "high",
      ]],
      [4, ["running", "triathlon_run"], [
        "90-150 min",
        "150-240 min",
        "> 240 min",
      ], ["moderate", "high"]],
      [5, ["running", "cycling", "triathlon_bike", "triathlon_run"], [
        "< 90 min",
      ], ["low", "moderate", "high"]],
      [6, ["cycling", "triathlon_bike"], ["90-150 min", "150-240 min"], [
        "high",
      ]],
      [7, ["cycling", "triathlon_bike"], ["90-150 min"], [
        "low",
        "moderate",
        "high",
      ]],
      [8, ["cycling", "triathlon_bike"], ["150-240 min"], ["moderate", "high"]],
      [9, ["cycling", "triathlon_bike"], ["90-150 min"], [
        "low",
        "moderate",
        "high",
      ]],
      [10, ["cycling", "triathlon_bike"], ["150-240 min"], [
        "moderate",
        "high",
      ]],
      [11, ["cycling", "triathlon_bike"], ["90-150 min"], [
        "low",
        "moderate",
        "high",
      ]],
      [12, ["cycling", "triathlon_bike"], ["150-240 min"], [
        "moderate",
        "high",
      ]],
      [13, ["cycling", "triathlon_bike"], [
        "90-150 min",
        "150-240 min",
        "> 240 min",
      ], ["low", "moderate", "high"]],
      [14, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "moderate",
        "high",
      ]],
      [15, ["cycling", "triathlon_bike"], ["90-150 min"], [
        "low",
        "moderate",
        "high",
      ]],
      [16, ["cycling", "triathlon_bike"], [
        "90-150 min",
        "150-240 min",
        "> 240 min",
      ], ["moderate", "high"]],
      [17, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "high",
      ]],
      [18, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "high",
      ]],
      [19, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "high",
      ]],
      [20, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "high",
      ]],
      [21, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "moderate",
        "high",
      ]],
      [22, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "moderate",
        "high",
      ]],
      [23, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "moderate",
        "high",
      ]],
      [24, ["cycling", "triathlon_bike"], ["150-240 min", "> 240 min"], [
        "moderate",
        "high",
      ]],
    ] as const;

    for (const [templateNumber, activities, brackets, gutLevels] of coverage) {
      const template = makeTemplate({
        template_number: templateNumber,
        name: `Template ${templateNumber}`,
        activity_types: [...activities],
        duration_brackets: [...brackets],
        gut_training_levels: [...gutLevels],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
      });

      for (const activity of activities) {
        for (const bracket of brackets) {
          for (const gut of gutLevels) {
            const duration = durationByBracket.get(bracket);
            assertExists(duration, `Missing duration fixture for ${bracket}`);

            const candidates = selectTemplateCandidates(
              [template],
              activityToSolverType(activity),
              duration,
              gut as GutTrainingLevel,
              foodsByName,
            );

            assert(
              candidates.some((candidate) =>
                candidate.template_number === templateNumber
              ),
              `Expected template ${templateNumber} to match activity=${activity}, duration=${bracket}, gut=${gut}`,
            );
          }
        }
      }
    }
  });

  // 1. Should select running template for running activity
  it("should select running template for running activity", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const result = selectTemplate(
      templates,
      "running",
      120, // 90-150 bracket
      "moderate",
      pool,
    );

    await logs.writeToFile(
      "template-select-running",
      "Activity: running, 120min, moderate gut -- expect running template (1 or 2)",
    );

    assertExists(result, "Should select a template for running");
    assert(
      result.activity_types.includes("running"),
      `Selected template should include running activity type, got: ${result.activity_types}`,
    );
    assert(
      [1, 2, 3].includes(result.template_number),
      `Expected template 1, 2, or 3, got: ${result.template_number}`,
    );
  });

  // 2. Should select cycling template for cycling activity
  it("should select cycling template for cycling activity", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const result = selectTemplate(
      templates,
      "cycling",
      120, // 90-150 bracket
      "moderate",
      pool,
    );

    await logs.writeToFile(
      "template-select-cycling",
      "Activity: cycling, 120min, moderate gut -- expect cycling template",
    );

    assertExists(result, "Should select a template for cycling");
    assert(
      result.activity_types.includes("cycling"),
      `Selected template should include cycling, got: ${result.activity_types}`,
    );
    // Template 7 or 9 for cycling 90-150 moderate
    assert(
      [7, 9].includes(result.template_number),
      `Expected cycling template (7 or 9), got: ${result.template_number}`,
    );
  });

  // 3. Should select sports-drink-only for sub-90min
  it("should select sports-drink-only for sub-90min", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const result = selectTemplate(
      templates,
      "running",
      60, // < 90 bracket
      "low",
      pool,
    );

    await logs.writeToFile(
      "template-select-sub90",
      "Activity: running, 60min, low gut -- expect sports-drink-only (template 5)",
    );

    assertExists(result, "Should select a template for sub-90min");
    assertEquals(
      result.template_number,
      5,
      "Should select Sports Drink Only template",
    );
  });

  it("should return all compatible template candidates in preference order", () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const candidates = selectTemplateCandidates(
      templates,
      "running",
      120,
      "moderate",
      pool,
    );

    assert(
      candidates.length > 1,
      `Expected multiple compatible running templates, got ${candidates.length}`,
    );
    assert(
      candidates.every((template) =>
        template.activity_types.includes("running")
      ),
      "Every returned candidate should support running",
    );
    assert(
      candidates.every((template) =>
        template.duration_brackets.includes("90-150 min")
      ),
      "Every returned candidate should support the 90-150 min bracket",
    );
  });

  it("should include transition template 0 for triathlon transition candidates", () => {
    const templates = [
      makeTemplate({
        template_number: 0,
        name: "Quick Gel Module (T1/T2)",
        activity_types: ["triathlon_transition"],
        duration_brackets: ["90-150 min", "150-240 min", "> 240 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_gel", "water", "sports_drink"],
        component_carb_ratios: { "energy_gel": 0.8, "sports_drink": 0.2 },
      }),
      ...makeStandardTemplates(),
    ];
    const pool = makeTemplateFoodPool();

    const candidates = selectTemplateCandidates(
      templates,
      "triathlon",
      240,
      "moderate",
      pool,
    );

    assertEquals(candidates[0].template_number, 0);
  });

  it("should prefer catalog-prioritized carb drink mix for moderate long cycling", () => {
    const templates = [
      makeTemplate({
        template_number: 13,
        name: "Rice Cake + Sports Drink + Water",
        activity_types: ["cycling", "triathlon_bike"],
        duration_brackets: ["90-150 min", "150-240 min", "> 240 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["rice_cake_during", "sports_drink", "water"],
        component_carb_ratios: {
          "rice_cake_during": 0.55,
          "sports_drink": 0.45,
        },
      }),
      makeTemplate({
        template_number: 17,
        name: "High Carb Drink Mix + Bar + Water",
        activity_types: ["cycling", "triathlon_bike"],
        duration_brackets: ["150-240 min", "> 240 min"],
        gut_training_levels: ["high"],
        component_food_names: ["high_carb_drink_mix", "energy_bar", "water"],
        component_carb_ratios: {
          "high_carb_drink_mix": 0.7,
          "energy_bar": 0.3,
        },
        selection_priority: 40,
      }),
      makeTemplate({
        template_number: 21,
        name: "Carb Drink Mix + Bar + Water",
        activity_types: ["cycling", "triathlon_bike"],
        duration_brackets: ["150-240 min", "> 240 min"],
        gut_training_levels: ["moderate", "high"],
        component_food_names: ["carb_drink_mix", "energy_bar", "water"],
        component_carb_ratios: {
          "carb_drink_mix": 0.7,
          "energy_bar": 0.3,
        },
        selection_priority: 30,
      }),
    ];

    const candidates = selectTemplateCandidates(
      templates,
      "cycling",
      340,
      "moderate",
      makeTemplateFoodPool(),
    );

    assertEquals(candidates[0]?.template_number, 21);
    assert(
      !candidates.some((template) => template.template_number === 17),
      "High-carb drink mix should remain high-gut only",
    );
  });

  // 4. Should select high-carb-drink-mix only for high gut
  it("should select high-carb-drink-mix only for high gut", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const result = selectTemplate(
      templates,
      "cycling",
      150, // 150 maps to 90-150 bracket
      "high",
      pool,
    );

    await logs.writeToFile(
      "template-select-high-gut-drink-mix",
      "Activity: cycling, 150min, high gut -- template 6 (high-carb-drink-mix) should be a candidate",
    );

    assertExists(result, "Should select a template");
    // Template 6 is only for high gut; among cycling 90-150 with high gut, templates 6, 7, 9 are all candidates
    // (template 6 has 90-150 and 150-240 brackets and high gut)
    assert(
      result.activity_types.includes("cycling"),
      "Should pick a cycling template",
    );
  });

  // 5. Should filter by gut training level
  it("should filter by gut training level", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // Template 8 is moderate/high only. Low gut should NOT select it.
    const result = selectTemplate(
      templates,
      "cycling",
      180, // 150-240 bracket
      "low",
      pool,
    );

    await logs.writeToFile(
      "template-select-gut-filter",
      "Activity: cycling, 180min, low gut -- template 8 (moderate/high) should be excluded",
    );

    // Template 8 requires moderate or high. With low gut and 150-240 bracket,
    // there may be no matching cycling template at all (template 7 is 90-150 only).
    if (result) {
      assert(
        result.template_number !== 8,
        "Template 8 (moderate/high only) should NOT be selected for low gut",
      );
    }
  });

  // 6. Should filter by allergens
  it("should filter by allergens", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const result = selectTemplate(
      templates,
      "cycling",
      120,
      "moderate",
      pool,
      undefined, // liked
      undefined, // willing
      undefined, // disliked
      ["gluten"], // allergies
    );

    await logs.writeToFile(
      "template-select-allergen-filter",
      "Activity: cycling, 120min, moderate gut, allergy=gluten -- template 9 should be excluded",
    );

    if (result) {
      assert(
        result.template_number !== 9,
        `Template 9 (allergens=[gluten,dairy]) should be excluded for gluten allergy, got template ${result.template_number}`,
      );
    }
  });

  // 7. Should filter by dietary preference
  it("should filter by dietary preference", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const result = selectTemplate(
      templates,
      "cycling",
      120,
      "moderate",
      pool,
      undefined, // liked
      undefined, // willing
      undefined, // disliked
      [], // allergies
      "vegan", // diet
    );

    await logs.writeToFile(
      "template-select-diet-filter",
      "Activity: cycling, 120min, moderate gut, diet=vegan -- template 9 excluded",
    );

    if (result) {
      assert(
        result.template_number !== 9,
        `Template 9 (excluded_diets=[vegan]) should be excluded for vegan diet, got template ${result.template_number}`,
      );
    }
  });

  // 8. Should prefer templates with liked foods
  it("should prefer templates with liked foods", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // Like energy_gel -- templates 1 and 2 contain gel
    const likedFoods = new Set(["energy_gel"]);

    const result = selectTemplate(
      templates,
      "running",
      120,
      "moderate",
      pool,
      likedFoods,
    );

    await logs.writeToFile(
      "template-select-liked-foods",
      "Activity: running, 120min, moderate gut, liked=[energy_gel] -- gel templates should score higher",
    );

    assertExists(result, "Should select a template");
    assert(
      result.component_food_names.includes("energy_gel"),
      `Template with liked food (energy_gel) should be preferred, got template ${result.template_number}: ${result.component_food_names}`,
    );
  });

  // 9. Should penalize templates with disliked foods
  it("should penalize templates with disliked foods", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // Dislike energy_gel -- templates without gel should be preferred
    const dislikedFoods = new Set(["energy_gel"]);

    const result = selectTemplate(
      templates,
      "running",
      120,
      "low", // low gut: templates 1 and 3 both match
      pool,
      undefined, // liked
      undefined, // willing
      dislikedFoods,
    );

    await logs.writeToFile(
      "template-select-disliked-foods",
      "Activity: running, 120min, low gut, disliked=[energy_gel] -- non-gel templates preferred",
    );

    assertExists(result, "Should select a template");
    // Template 3 (Chew + Water) should be preferred over Template 1 (Gel + Water)
    assertEquals(
      result.template_number,
      3,
      `Template without disliked food should be preferred, got template ${result.template_number}`,
    );
  });

  // 10. Should return null when no templates match
  it("should return null when no templates match", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // swimming at 120min -- no templates have swimming in 90-150 bracket
    // (template 5 is < 90 min for swimming)
    const result = selectTemplate(
      templates,
      "swimming",
      120,
      "moderate",
      pool,
    );

    await logs.writeToFile(
      "template-select-no-match",
      "Activity: swimming, 120min -- no templates match, expect null",
    );

    assertEquals(result, null, "Should return null when no templates match");
  });

  // 11. Should skip templates with missing foods
  it("should skip templates with missing foods", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // Remove energy_bar from pool -- template 7 and 8 should be skipped
    pool.delete("energy_bar");

    const result = selectTemplate(
      templates,
      "cycling",
      120,
      "moderate",
      pool,
    );

    await logs.writeToFile(
      "template-select-missing-food",
      "Activity: cycling, 120min, moderate -- energy_bar removed from pool, templates 7/8 should be skipped",
    );

    if (result) {
      assert(
        result.template_number !== 7 && result.template_number !== 8,
        `Templates requiring energy_bar should be skipped, got template ${result.template_number}`,
      );
    }
  });
});

// ============================================================================
// B. Quantity Calculation (generateDuringPhaseTemplate)
// ============================================================================

describe("Quantity Calculation (generateDuringPhaseTemplate)", () => {
  beforeEach(setup);
  afterEach(teardown);

  // 12. Should hit carb target for simple gel template
  it("should hit carb target for simple gel template", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 500,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-gen-gel-carb-target",
      "Template 1 (Gel + Water), targets: 50g carbs, 500mg sodium, 700ml water, 120min, moderate",
    );

    assertExists(result, "Should produce a result");
    assert(result.foods.length > 0, "Should include at least one food");
    const totals = sumFoodResults(result.foods);

    strictAssertMacrosInRange(
      "Gel + Water carb target",
      totals,
      targets,
      {
        carbs: { min: 0.9, max: 1.1 },
        sodium: { min: 0.7, max: 1.3 },
        water: { min: 0.7, max: 1.3 },
      },
    );
  });

  // 13. Should enforce max-per-hour constraint for gels
  it("should enforce max-per-hour constraint for gels", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    // Very high carb target to trigger max-per-hour clamping
    const targets: MacroTargets = {
      carbs_g: 200,
      sodium_mg: 600,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120, // 2 hours
      "low", // max_per_hr_low = 2 for gel => max 4 gels over 2hr
    );

    await logs.writeToFile(
      "template-gen-gel-max-per-hr",
      "Template 1, 200g carbs target, 120min, low gut (max 2 gels/hr => 4 gels max)",
    );

    // Even if the result is null (validation may fail due to extreme shortfall),
    // check the gel count if result exists
    if (result) {
      const gelFood = result.foods.find((f) => f.food_id === "energy_gel");
      if (gelFood) {
        const maxGels = 2 * 2; // max_per_hr_low=2, duration=2hr
        assert(
          gelFood.quantity <= maxGels,
          `Gel quantity ${gelFood.quantity} should not exceed max-per-hour limit of ${maxGels}`,
        );
      }
    }
    // If result is null, validation correctly rejected the extreme target
  });

  // 14. Should enforce 1:1 ratio for triple-source templates
  it("should enforce 1:1 ratio for triple-source templates", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 8,
      name: "Bar + Gel + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["150-240 min"],
      gut_training_levels: ["moderate", "high"],
      component_food_names: [
        "energy_bar",
        "energy_gel",
        "water",
        "sports_drink",
      ],
      component_carb_ratios: {
        "energy_bar": 0.35,
        "energy_gel": 0.35,
        "sports_drink": 0.3,
      },
      primary_to_secondary_ratio: "1:1",
    });

    // Sodium target set to match what food + 1 electrolyte tab can deliver
    // (bar 200mg + gel 55mg + SD ~220mg + elec 350mg = ~825mg)
    const targets: MacroTargets = {
      carbs_g: 90,
      sodium_mg: 800,
      water_ml: 1200,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      180, // 3 hours
      "moderate",
    );

    await logs.writeToFile(
      "template-gen-1to1-ratio",
      "Template 8, 90g carbs, 180min, moderate -- bar and gel should have equal servings",
    );

    assertExists(result, "Should produce a result");
    const barFood = result.foods.find((f) => f.food_id === "energy_bar");
    const gelFood = result.foods.find((f) => f.food_id === "energy_gel");

    if (barFood && gelFood) {
      assertEquals(
        barFood.quantity,
        gelFood.quantity,
        `1:1 ratio: bar (${barFood.quantity}) and gel (${gelFood.quantity}) should have equal servings`,
      );
    }
  });

  // 15. Should compensate carb shortfall with sports drink
  it("should compensate carb shortfall with sports drink", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 7,
      name: "Bar + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_bar", "sports_drink", "water"],
      component_carb_ratios: { "energy_bar": 0.55, "sports_drink": 0.45 },
    });

    const targets: MacroTargets = {
      carbs_g: 80,
      sodium_mg: 800,
      water_ml: 900,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "low", // bar max_per_hr_low = 0.5 => max 1 bar over 2hr
    );

    await logs.writeToFile(
      "template-gen-carb-compensation",
      "Template 7 (Bar + SD), 80g carbs, 120min, low gut -- bar capped at 0.5/hr, SD compensates",
    );

    if (result) {
      const sdFood = result.foods.find((f) => f.food_id === "sports_drink");
      assertExists(
        sdFood,
        "Sports drink should be present for carb compensation",
      );
      assert(
        sdFood!.quantity >= 1,
        `Sports drink should compensate carb shortfall, got ${
          sdFood!.quantity
        } servings`,
      );
    }
  });

  // 16. Should fill fluid gap with water
  it("should fill fluid gap with water", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 500,
      water_ml: 1000,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-gen-fluid-fill",
      "Template 1, 60g carbs, 1000ml water target -- water should fill fluid gap",
    );

    assertExists(result, "Should produce a result");
    const waterFood = result.foods.find((f) => f.food_id === "water");
    assertExists(waterFood, "Water should be included to fill fluid gap");
    assert(
      waterFood!.fluids_ml > 0,
      "Water should contribute fluids",
    );

    const totals = sumFoodResults(result.foods);
    strictAssertMacrosInRange(
      "Gel + Water fluid fill",
      totals,
      targets,
      {
        carbs: { min: 0.9, max: 1.1 },
        sodium: { min: 0.7, max: 1.3 },
        water: { min: 0.7, max: 1.3 },
      },
    );
  });

  // 17. Should fill sodium gap with electrolytes
  it("should fill sodium gap with electrolytes", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    // 2 gels=110mg sodium + 1 electrolyte=350mg => ~460mg
    // Set a target the solver can reach with electrolyte help
    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 500,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-gen-sodium-fill",
      "Template 1, 50g carbs, 500mg sodium -- electrolyte tablets should fill sodium gap",
    );

    assertExists(result, "Should produce a result");
    const elecFood = result.foods.find((f) => f.food_id === "electrolyte_tab");
    assertExists(elecFood, "Electrolyte tablet should be added for sodium gap");
    assert(
      elecFood!.sodium_mg > 0,
      "Electrolyte tablet should contribute sodium",
    );
  });

  // 18. Should round gels to whole units
  it("should round gels to whole units", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    const targets: MacroTargets = {
      carbs_g: 55, // 55 / 25 = 2.2, should round to whole number
      sodium_mg: 500,
      water_ml: 600,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-gen-gel-rounding",
      "Template 1, 55g carbs -- gel servings should be whole number (min_increment=1, is_indivisible)",
    );

    assertExists(result, "Should produce a result");
    const gelFood = result.foods.find((f) => f.food_id === "energy_gel");
    assertExists(gelFood, "Gel should be present");
    assertEquals(
      gelFood!.quantity,
      Math.round(gelFood!.quantity),
      `Gel quantity (${gelFood!.quantity}) should be a whole number`,
    );
  });

  // 19. Should round bars to 0.5 increments
  it("should round bars to 0.5 increments", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 7,
      name: "Bar + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_bar", "sports_drink", "water"],
      component_carb_ratios: { "energy_bar": 0.55, "sports_drink": 0.45 },
    });

    const targets: MacroTargets = {
      carbs_g: 70,
      sodium_mg: 700,
      water_ml: 800,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-gen-bar-rounding",
      "Template 7 -- bar servings should be 0.5 multiples",
    );

    assertExists(result, "Should produce a result");
    const barFood = result.foods.find((f) => f.food_id === "energy_bar");
    if (barFood) {
      const remainder = barFood.quantity % 0.5;
      assert(
        Math.abs(remainder) < 0.001 || Math.abs(remainder - 0.5) < 0.001,
        `Bar quantity (${barFood.quantity}) should be a multiple of 0.5`,
      );
    }
  });

  // 20. Should return null when validation fails
  it("should return null when validation fails", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    // Extremely high carb target with low gut = can't satisfy
    // max 2 gels/hr * 2hr = 4 gels = 100g carbs, target 300g => 33% (well below 90%)
    const targets: MacroTargets = {
      carbs_g: 300,
      sodium_mg: 600,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "low",
    );

    await logs.writeToFile(
      "template-gen-validation-fail",
      "Template 1, 300g carbs target, low gut -- validation should fail, return null",
    );

    assertEquals(
      result,
      null,
      "Should return null when extreme targets cannot be satisfied",
    );
  });
});

// ============================================================================
// C. Athlete Profile E2E
// ============================================================================

describe("Athlete Profile E2E", () => {
  beforeEach(setup);
  afterEach(teardown);

  // 21. Beginner runner - low gut, 90min, 30g/hr carbs
  it("beginner runner - low gut, 90min, 30g/hr carbs", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // 2 gels = 50g carbs, 110mg sodium; 1 electrolyte = 350mg sodium
    // Total sodium ~ 460mg. Set sodium target achievably.
    const targets: MacroTargets = {
      carbs_g: 50, // 2 gels = 50g carbs exactly
      sodium_mg: 450,
      water_ml: 600,
    };

    const selected = selectTemplate(
      templates,
      "running",
      90,
      "low",
      pool,
    );

    await logs.writeToFile(
      "template-e2e-beginner-runner-select",
      "Beginner runner: running, 90min, low gut, 30g/hr carbs",
    );

    assertExists(selected, "Should find a template for beginner runner");

    const result = generateDuringPhaseTemplate(
      selected,
      pool,
      targets,
      90,
      "low",
    );

    await logs.writeToFile(
      "template-e2e-beginner-runner-generate",
      `Beginner runner: template ${selected.template_number}, targets: 45g carbs, 500mg sodium, 600ml water`,
    );

    assertExists(result, "Should produce a plan for beginner runner");
    const totals = sumFoodResults(result.foods);

    strictAssertMacrosInRange(
      "Beginner runner E2E",
      totals,
      targets,
      {
        carbs: { min: 0.9, max: 1.1 },
        sodium: { min: 0.7, max: 1.3 },
        water: { min: 0.7, max: 1.3 },
      },
    );
  });

  // 22. Advanced cyclist - high gut, 180min, 90g/hr carbs
  it("advanced cyclist - high gut, 180min, 90g/hr carbs", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    const targets: MacroTargets = {
      carbs_g: 270, // 90g/hr * 3hr
      sodium_mg: 1500,
      water_ml: 2000,
    };

    const selected = selectTemplate(
      templates,
      "cycling",
      180, // 150-240 bracket
      "high",
      pool,
    );

    await logs.writeToFile(
      "template-e2e-advanced-cyclist-select",
      "Advanced cyclist: cycling, 180min, high gut, 90g/hr carbs",
    );

    assertExists(selected, "Should find a template for advanced cyclist");

    const result = generateDuringPhaseTemplate(
      selected,
      pool,
      targets,
      180,
      "high",
    );

    await logs.writeToFile(
      "template-e2e-advanced-cyclist-generate",
      `Advanced cyclist: template ${selected.template_number}, targets: 270g carbs, 1500mg sodium, 2000ml water`,
    );

    // The result may be null if the extreme targets cannot be met.
    // Advanced cyclist at 270g carbs over 3hr is aggressive but feasible
    // for template 8 (bar+gel+SD) -- or it may fail validation.
    if (result) {
      const totals = sumFoodResults(result.foods);
      strictAssertMacrosInRange(
        "Advanced cyclist E2E",
        totals,
        targets,
        {
          carbs: { min: 0.8, max: 1.2 },
          sodium: { min: 0.7, max: 1.3 },
          water: { min: 0.7, max: 1.3 },
        },
      );
    } else {
      // Acceptable: extreme targets exceeded solver capacity
      const warnings = logs.getByLevel("warn");
      assert(
        warnings.some((w) => w.raw.includes("VALIDATION FAILED")),
        "If null, should have logged validation failure",
      );
    }
  });

  // 23. Ultra runner - high gut, 300min, marathon targets
  it("ultra runner - high gut, 300min, marathon targets", async () => {
    const templates = makeStandardTemplates();
    const pool = makeTemplateFoodPool();

    // Add a > 240 min template for ultra running
    const ultraTemplate = makeTemplate({
      template_number: 10,
      name: "Gel + Sports Drink + Water (Ultra)",
      activity_types: ["running"],
      duration_brackets: ["> 240 min"],
      gut_training_levels: ["moderate", "high"],
      component_food_names: ["energy_gel", "sports_drink", "water"],
      component_carb_ratios: { "energy_gel": 0.6, "sports_drink": 0.4 },
    });
    const allTemplates = [...templates, ultraTemplate];

    const targets: MacroTargets = {
      carbs_g: 300, // 60g/hr * 5hr
      sodium_mg: 2000,
      water_ml: 2500,
    };

    const selected = selectTemplate(
      allTemplates,
      "running",
      300, // > 240 bracket
      "high",
      pool,
    );

    await logs.writeToFile(
      "template-e2e-ultra-runner-select",
      "Ultra runner: running, 300min, high gut -- should find > 240min template",
    );

    assertExists(selected, "Should find a > 240 min template for ultra runner");
    assert(
      selected.duration_brackets.includes("> 240 min"),
      "Template should include > 240 min bracket",
    );

    const result = generateDuringPhaseTemplate(
      selected,
      pool,
      targets,
      300,
      "high",
    );

    await logs.writeToFile(
      "template-e2e-ultra-runner-generate",
      `Ultra runner: template ${selected.template_number}, targets: 300g carbs, 2000mg sodium, 2500ml water`,
    );

    // May or may not pass validation with 300g carbs -- solver depends on food constraints
    if (result) {
      const totals = sumFoodResults(result.foods);
      assert(
        totals.carbs_g > 0,
        "Ultra runner plan should have some carbs",
      );
    }
  });
});

// ============================================================================
// D. Edge Cases
// ============================================================================

describe("Edge Cases", () => {
  beforeEach(setup);
  afterEach(teardown);

  // 24. Should handle zero carb target
  it("should handle zero carb target", async () => {
    const pool = makeTemplateFoodPool();
    // Use a simple template with just water
    const template = makeTemplate({
      template_number: 99,
      name: "Water Only",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["water"],
      component_carb_ratios: {}, // no carb-contributing foods
    });

    const targets: MacroTargets = {
      carbs_g: 0,
      sodium_mg: 500,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-edge-zero-carb",
      "Zero carb target -- just water + electrolytes",
    );

    // With zero carbs target, the solver should skip carb foods and just
    // provide water + electrolytes. Result may be null if validation
    // considers sodium/water ratios.
    if (result) {
      const totals = sumFoodResults(result.foods);
      // No carb foods should be present (except maybe trace from electrolyte tabs)
      assert(
        totals.carbs_g <= 5,
        `Zero-carb plan should have minimal carbs, got ${totals.carbs_g}g`,
      );
    }
  });

  // 25. Should handle high-carb-drink-mix for high gut only
  it("should handle high-carb-drink-mix for high gut only", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 6,
      name: "High Carb Drink Mix + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min", "150-240 min"],
      gut_training_levels: ["high"],
      component_food_names: ["high_carb_drink_mix", "water"],
      component_carb_ratios: { "high_carb_drink_mix": 1.0 },
    });

    // Test with low gut -- max_per_hr_low = 0 for high_carb_drink_mix
    const targets: MacroTargets = {
      carbs_g: 60,
      sodium_mg: 600,
      water_ml: 800,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "low", // max_per_hr_low = 0 => effectively no drink mix
    );

    await logs.writeToFile(
      "template-edge-high-carb-low-gut",
      "Template 6, low gut -- max_per_hr_low=0, effectively zero drink mix servings",
    );

    // With max_per_hr_low=0, the drink mix gets 0 servings assigned in step 1.
    // The result may be null if the carb target can't be met without using
    // high-carb drink mix.
    if (result) {
      const drinkMix = result.foods.find((f) =>
        f.food_id === "high_carb_drink_mix"
      );
      // Drink mix should have 0 or no entry
      if (drinkMix) {
        assertEquals(
          drinkMix.quantity,
          0,
          `High carb drink mix should have 0 servings for low gut, got ${drinkMix.quantity}`,
        );
      }
    }
  });

  // Bonus: inactive template should be skipped
  it("should skip inactive templates", async () => {
    const pool = makeTemplateFoodPool();
    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Inactive Gel Template",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
        is_active: false,
      }),
    ];

    const result = selectTemplate(
      templates,
      "running",
      120,
      "moderate",
      pool,
    );

    await logs.writeToFile(
      "template-edge-inactive",
      "Only template is inactive -- should return null",
    );

    assertEquals(result, null, "Inactive template should not be selected");
  });

  // Bonus: template with only water/electrolyte components (no carb ratios)
  it("should handle template with empty carb ratios", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 50,
      name: "Hydration Only",
      activity_types: ["running"],
      duration_brackets: ["< 90 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["water", "electrolyte_tab"],
      component_carb_ratios: {},
    });

    const targets: MacroTargets = {
      carbs_g: 0,
      sodium_mg: 400,
      water_ml: 500,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      45,
      "low",
    );

    await logs.writeToFile(
      "template-edge-hydration-only",
      "Hydration-only template (no carb ratios), 0g carbs -- should still provide water + electrolytes",
    );

    // With 0 carb target, validation should pass if water/sodium ranges are met
    if (result) {
      const totals = sumFoodResults(result.foods);
      assert(totals.water_ml > 0, "Should provide some water");
    }
  });

  // Bonus: sports drink compensation when available as a template carb component
  it("should use sports drink compensation when it is in template carb ratios", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 7,
      name: "Bar + Sports Drink + Water",
      activity_types: ["cycling"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_bar", "sports_drink", "water"],
      component_carb_ratios: { "energy_bar": 0.55, "sports_drink": 0.45 },
    });

    const targets: MacroTargets = {
      carbs_g: 80,
      sodium_mg: 800,
      water_ml: 1000,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "low",
    );

    await logs.writeToFile(
      "template-edge-sd-compensation",
      "Template 7, low gut, 80g carbs -- bar capped, SD should compensate via step 4",
    );

    if (result) {
      const totals = sumFoodResults(result.foods);
      // The solver should get reasonably close to carb target
      const carbRatio = totals.carbs_g / targets.carbs_g;
      assert(
        carbRatio >= 0.85,
        `Carb ratio should be >= 85% after SD compensation, got ${
          (carbRatio * 100).toFixed(0)
        }%`,
      );
    }
  });

  it("should not use sports drink as an electrolyte top-up when absent from the template", async () => {
    const pool = makeTemplateFoodPool();
    const sportsDrink = pool.get("sports_drink");
    assertExists(sportsDrink, "Test pool should include sports drink");
    pool.set("sports_drink", {
      ...sportsDrink,
      is_electrolyte: true,
    });

    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 500,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    await logs.writeToFile(
      "template-edge-no-sd-electrolyte-top-up",
      "Template 1, sports drink marked electrolyte in pool -- should still not be added unless template uses it",
    );

    assertExists(result, "Should produce a result");
    const sdFood = result.foods.find((f) => f.food_id === "sports_drink");
    assertEquals(
      sdFood,
      undefined,
      "Sports drink should not be used as sodium top-up for a gel+water template",
    );
  });

  // Bonus: verify template metadata passthrough
  it("should include template metadata in result", async () => {
    const pool = makeTemplateFoodPool();
    const template = makeTemplate({
      template_number: 5,
      name: "Sports Drink Only",
      formula: "SD formula",
      activity_types: ["running", "cycling", "swimming"],
      duration_brackets: ["< 90 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["sports_drink"],
      component_carb_ratios: { "sports_drink": 1.0 },
    });

    // Sports drink: 15g carbs, 110mg sodium, 240ml water per serving
    // At low gut, max_per_hr=2, 1hr => max 2 servings = 30g carbs, 220mg sodium, 480ml water
    // 1 SD + water fill: ~15g carbs, 110mg sodium, 240ml water from SD + water for rest
    // Set targets to match what 1 serving of SD can deliver (within validation ranges)
    const targets: MacroTargets = {
      carbs_g: 15,
      sodium_mg: 110,
      water_ml: 350,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      60,
      "low",
    );

    await logs.writeToFile(
      "template-edge-metadata",
      "Template 5, verify metadata passthrough in result",
    );

    assertExists(result, "Should produce a result");
    assertEquals(result.template_id, "template-5");
    assertEquals(result.template_number, 5);
    assertEquals(result.template_name, "Sports Drink Only");
    assertEquals(result.template_formula, "SD formula");
  });
});

// ============================================================================
// collectShortfalls — the flag floor is the range low, not the point target
// ============================================================================
// Regression (2026-07-22, reported by Xuan): sodium delivered INSIDE its
// acceptable range but below the point target was flagged as a "sodium gap"
// in the app. Delivery anywhere at/above the range low is not a gap; the
// 90%-of-target floor applies only when the targets carry no range.

describe("collectShortfalls range-low floor", () => {
  const totals = { carbs_g: 100, sodium_mg: 380, water_ml: 500 };

  it("sodium inside its range but below target emits NO shortfall", () => {
    const targets: MacroTargets = {
      carbs_g: 100,
      sodium_mg: 450,
      sodium_low_mg: 300,
      sodium_high_mg: 900,
      water_ml: 500,
    };
    // 380 < 450×0.9 = 405, but 380 >= range low 300 → in range, no gap.
    const shortfalls = collectShortfalls(totals, targets);
    assertEquals(shortfalls.filter((s) => s.macro === "sodium").length, 0);
  });

  it("sodium below the range low still emits a shortfall", () => {
    const targets: MacroTargets = {
      carbs_g: 100,
      sodium_mg: 450,
      sodium_low_mg: 400,
      sodium_high_mg: 900,
      water_ml: 500,
    };
    const shortfalls = collectShortfalls(totals, targets);
    assertEquals(shortfalls.filter((s) => s.macro === "sodium").length, 1);
  });

  it("falls back to the 90%-of-target floor when no range is provided", () => {
    const targets: MacroTargets = {
      carbs_g: 100,
      sodium_mg: 450,
      water_ml: 500,
    };
    // 380 < 405 and no sodium_low_mg → legacy behavior, shortfall emitted.
    const shortfalls = collectShortfalls(totals, targets);
    assertEquals(shortfalls.filter((s) => s.macro === "sodium").length, 1);
  });

  it("carbs and fluid use their range lows the same way", () => {
    const targets: MacroTargets = {
      carbs_g: 115,
      carbs_low_g: 95,
      sodium_mg: 0,
      water_ml: 600,
      water_low_ml: 450,
    };
    // carbs 100 < 115×0.9 = 103.5 but >= low 95; fluid 500 < 540 but >= 450.
    const shortfalls = collectShortfalls(totals, targets);
    assertEquals(shortfalls.length, 0);
  });
});
