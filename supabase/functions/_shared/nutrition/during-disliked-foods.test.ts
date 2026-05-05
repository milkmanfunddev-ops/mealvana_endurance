/**
 * Tests: Disliked Foods Should Not Appear in During-Workout Plans
 *
 * Validates that foods a user has marked as disliked are excluded from
 * the generated during-workout nutrition plan — including electrolyte
 * top-ups that currently bypass preference filtering.
 *
 * Bug report: "There were several foods that I wanted to avoid such as
 * electrolyte capsules and powders and drinks and squeezes, but they all
 * showed up on my meal plan."
 *
 * Run with:
 *   deno test --no-check --allow-read --allow-write supabase/functions/_shared/nutrition/during-disliked-foods.test.ts
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
} from "./during-template-solver.ts";
import type { MacroTargets } from "./types.ts";
import { LogCapture, makeFood, sumFoodResults } from "./test-utils.ts";

// ============================================================================
// Test Factories
// ============================================================================

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
// Food Pool with Multiple Electrolyte Types
// ============================================================================

/**
 * Build a food pool that includes several electrolyte products the user
 * might dislike: capsules, powder, electrolyte drink, squeeze gel.
 * Also includes a non-electrolyte alternative (salt-containing chew).
 */
function makePoolWithElectrolyteVariety(): Map<string, FoodWithConstraints> {
  const pool = new Map<string, FoodWithConstraints>();

  // --- Carb source ---
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

  // --- Water ---
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

  // --- Electrolyte Capsule (disliked) ---
  pool.set(
    "electrolyte_capsule",
    makeFoodWithConstraints({
      id: "electrolyte_capsule",
      name: "electrolyte_capsule",
      display_name: "Electrolyte Capsule",
      per_serving: {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 350,
        water_ml: 0,
        calories: 0,
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

  // --- Electrolyte Powder (disliked) ---
  pool.set(
    "electrolyte_powder",
    makeFoodWithConstraints({
      id: "electrolyte_powder",
      name: "electrolyte_powder",
      display_name: "Electrolyte Powder",
      per_serving: {
        carbs_g: 2,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 400,
        water_ml: 300,
        calories: 8,
      },
      product_type: "supplement",
      is_electrolyte: true,
      is_liquid: true,
      sodium_top_up_eligible: true,
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 4,
    }),
  );

  // --- Electrolyte Drink (disliked) ---
  pool.set(
    "electrolyte_drink",
    makeFoodWithConstraints({
      id: "electrolyte_drink",
      name: "electrolyte_drink",
      display_name: "Electrolyte Drink",
      per_serving: {
        carbs_g: 3,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 300,
        water_ml: 350,
        calories: 15,
      },
      product_type: "sports_drink",
      is_electrolyte: true,
      is_liquid: true,
      sodium_top_up_eligible: false, // sports_drink excluded by isSodiumTopUpFood
      min_increment: 0.5,
      min_servings: 0.5,
      max_servings: 4,
    }),
  );

  // --- Squeeze Gel (disliked) ---
  pool.set(
    "electrolyte_squeeze",
    makeFoodWithConstraints({
      id: "electrolyte_squeeze",
      name: "electrolyte_squeeze",
      display_name: "Electrolyte Squeeze",
      per_serving: {
        carbs_g: 5,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 250,
        water_ml: 30,
        calories: 20,
      },
      product_type: "supplement",
      is_electrolyte: true,
      is_indivisible: true,
      sodium_top_up_eligible: true,
      min_increment: 1,
      min_servings: 1,
      max_servings: 3,
    }),
  );

  // --- Salt Chew: an electrolyte the user does NOT dislike ---
  pool.set(
    "salt_chew",
    makeFoodWithConstraints({
      id: "salt_chew",
      name: "salt_chew",
      display_name: "Salt Chew",
      per_serving: {
        carbs_g: 3,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 200,
        water_ml: 0,
        calories: 15,
      },
      product_type: "supplement",
      is_electrolyte: true,
      is_indivisible: true,
      sodium_top_up_eligible: true,
      min_increment: 1,
      min_servings: 1,
      max_servings: 6,
    }),
  );

  return pool;
}

const DISLIKED_ELECTROLYTE_IDS = new Set([
  "electrolyte_capsule",
  "electrolyte_powder",
  "electrolyte_drink",
  "electrolyte_squeeze",
]);

const DISLIKED_ELECTROLYTE_NAMES = new Set([
  "electrolyte_capsule",
  "electrolyte_powder",
  "electrolyte_drink",
  "electrolyte_squeeze",
  "Electrolyte Capsule",
  "Electrolyte Powder",
  "Electrolyte Drink",
  "Electrolyte Squeeze",
]);

// ============================================================================
// Tests
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

describe("Disliked Foods: Template Selection", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("should not select a template whose component foods are all disliked", () => {
    const pool = makePoolWithElectrolyteVariety();

    // Template A uses electrolyte_drink as a carb source (disliked)
    // Template B uses energy_gel (not disliked)
    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Electrolyte Drink Only",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        component_food_names: ["electrolyte_drink"],
        component_carb_ratios: { "electrolyte_drink": 1.0 },
      }),
      makeTemplate({
        template_number: 2,
        name: "Gel + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
      }),
    ];

    const candidates = selectTemplateCandidates(
      templates,
      "running",
      120,
      "moderate",
      pool,
      undefined, // liked
      undefined, // willing
      DISLIKED_ELECTROLYTE_NAMES, // disliked
    );

    // Template 1 has electrolyte_drink (disliked, -20 penalty).
    // Template 2 has energy_gel (no penalty).
    // Template 2 should rank higher.
    assert(candidates.length > 0, "Should find at least one candidate");
    assertEquals(
      candidates[0].template_number,
      2,
      "Template without disliked foods should be preferred",
    );
  });

  it("should deprioritize templates containing disliked foods even among multiple options", () => {
    const pool = makePoolWithElectrolyteVariety();

    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Gel + Electrolyte Drink",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        component_food_names: ["energy_gel", "electrolyte_drink"],
        component_carb_ratios: { "energy_gel": 0.7, "electrolyte_drink": 0.3 },
      }),
      makeTemplate({
        template_number: 2,
        name: "Gel + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
      }),
    ];

    const result = selectTemplate(
      templates,
      "running",
      120,
      "moderate",
      pool,
      undefined,
      undefined,
      DISLIKED_ELECTROLYTE_NAMES,
    );

    assertExists(result);
    assertEquals(
      result.template_number,
      2,
      "Should prefer template without disliked electrolyte drink",
    );
  });
});

describe("Disliked Foods: Electrolyte Top-Up (fillElectrolytes)", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("should NOT add disliked electrolytes during sodium top-up", () => {
    const pool = makePoolWithElectrolyteVariety();
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    // High sodium target forces electrolyte top-up.
    // Gels provide ~55mg each; 2 gels = 110mg — well below 800mg target.
    // The solver MUST add electrolytes to fill the gap.
    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 800,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    assertExists(result, "Should produce a result");

    // No disliked foods should appear in the output
    const dislikedInResult = result.foods.filter((f) =>
      DISLIKED_ELECTROLYTE_IDS.has(f.food_id)
    );

    assertEquals(
      dislikedInResult.length,
      0,
      `Disliked electrolytes should not appear in plan. Found: ${
        dislikedInResult.map((f) => f.display_name ?? f.food_id).join(", ")
      }`,
    );
  });

  it("should prefer non-disliked electrolytes when available", () => {
    const pool = makePoolWithElectrolyteVariety();
    // Pool has salt_chew (not disliked) + 4 disliked electrolytes.
    // The solver should use salt_chew for sodium top-up.

    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 600,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    assertExists(result, "Should produce a result");

    const electrolytesInPlan = result.foods.filter(
      (f) =>
        f.food_id !== "energy_gel" &&
        f.food_id !== "water",
    );

    // Only salt_chew should be used for sodium, never the disliked ones
    for (const food of electrolytesInPlan) {
      assert(
        !DISLIKED_ELECTROLYTE_IDS.has(food.food_id),
        `Disliked food "${food.display_name ?? food.food_id}" should not be in plan when non-disliked alternative (salt_chew) exists`,
      );
    }
  });

  it("should not add any disliked electrolytes even if sodium target cannot be met", () => {
    // Pool with ONLY disliked electrolytes (remove salt_chew)
    const pool = makePoolWithElectrolyteVariety();
    pool.delete("salt_chew");

    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    // Sodium target that can't be met without electrolytes
    const targets: MacroTargets = {
      carbs_g: 50,
      sodium_mg: 800,
      water_ml: 700,
    };

    const result = generateDuringPhaseTemplate(
      template,
      pool,
      targets,
      120,
      "moderate",
    );

    // Should either return null (can't meet sodium without disliked foods)
    // or return a plan that accepts a sodium shortfall — but never include
    // disliked foods.
    if (result) {
      const dislikedInResult = result.foods.filter((f) =>
        DISLIKED_ELECTROLYTE_IDS.has(f.food_id)
      );
      assertEquals(
        dislikedInResult.length,
        0,
        `No disliked electrolytes should appear even if it means missing sodium target. Found: ${
          dislikedInResult.map((f) => f.display_name ?? f.food_id).join(", ")
        }`,
      );
    }
  });
});

describe("Disliked Foods: Template Component Foods", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("should not include disliked foods as template carb components", () => {
    const pool = makePoolWithElectrolyteVariety();

    // Add a sports drink (not disliked)
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
        max_per_hr_moderate: 2.5,
        min_increment: 0.5,
        min_servings: 1,
        max_servings: 4,
      }),
    );

    // Template uses electrolyte_drink as a carb source — user dislikes it
    const templateWithDisliked = makeTemplate({
      template_number: 1,
      name: "Gel + Electrolyte Drink",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      component_food_names: ["energy_gel", "electrolyte_drink", "water"],
      component_carb_ratios: { "energy_gel": 0.6, "electrolyte_drink": 0.4 },
    });

    // Alternative template without disliked foods
    const templateWithoutDisliked = makeTemplate({
      template_number: 2,
      name: "Gel + Sports Drink",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      component_food_names: ["energy_gel", "sports_drink", "water"],
      component_carb_ratios: { "energy_gel": 0.6, "sports_drink": 0.4 },
    });

    const selected = selectTemplate(
      [templateWithDisliked, templateWithoutDisliked],
      "running",
      120,
      "moderate",
      pool,
      undefined,
      undefined,
      DISLIKED_ELECTROLYTE_NAMES,
    );

    assertExists(selected, "Should select a template");
    assertEquals(
      selected.template_number,
      2,
      "Should select template without disliked electrolyte drink as carb source",
    );
  });
});

describe("Disliked Foods: getTemplateElectrolyteFoods gap", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("getTemplateElectrolyteFoods should accept and apply dislikedFoods parameter", async () => {
    // getTemplateElectrolyteFoods() only accepts (supabase, likedFoods,
    // willingToTryFoods) — it has no dislikedFoods parameter.
    // This means disliked electrolytes can leak through to the
    // post-processing sodium top-up in during-phase.ts.
    //
    // We can't call getTemplateElectrolyteFoods directly (requires
    // Supabase), so we verify the function signature has the parameter.
    // This test will fail until the fix adds the parameter.

    const mod = await import("./template-food-queries.ts");
    const fn = mod.getTemplateElectrolyteFoods;
    assertExists(fn, "getTemplateElectrolyteFoods should exist");

    // The function currently accepts 3 params (supabase, liked, willing).
    // After fix it should accept 4 (supabase, liked, willing, disliked).
    assert(
      fn.length >= 4,
      `getTemplateElectrolyteFoods should accept at least 4 parameters (including dislikedFoods), but has ${fn.length}`,
    );
  });
});
