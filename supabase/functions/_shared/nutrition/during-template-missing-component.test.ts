/**
 * During Template Solver — Missing Component Food Failure Modes
 *
 * Tests what `selectTemplateCandidates()` does when a template's
 * `component_food_names` references a food that is NOT present in the
 * `foodsByName` map passed by the caller.
 *
 * Expected behavior (P6 in docs/test/edge-function-test-plan-2026.md):
 *   1. A template with any carb-contributing food absent from `foodsByName`
 *      is EXCLUDED from candidates (not thrown).
 *   2. When ALL templates are excluded this way, the return is `[]` (so the
 *      caller falls back to the rule solver) rather than throwing.
 *
 * These tests use the same mock factories as during-template-solver.test.ts.
 * No Supabase client is required — selectTemplateCandidates is a pure function.
 *
 * Run with:
 *   deno test --allow-write --node-modules-dir=none \
 *     supabase/functions/_shared/nutrition/during-template-missing-component.test.ts
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
  type GutTrainingLevel,
  selectTemplateCandidates,
} from "./during-template-solver.ts";
import type { ActivityType } from "./types.ts";
import { LogCapture, makeFood } from "./test-utils.ts";

// ============================================================================
// Test Factories (mirrored from during-template-solver.test.ts)
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
    activity_types: overrides.activity_types ?? ["running"],
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

/** Build a minimal food pool containing only the foods whose names are listed. */
function makePoolWithFoods(
  foodNames: string[],
): Map<string, FoodWithConstraints> {
  const pool = new Map<string, FoodWithConstraints>();
  for (const name of foodNames) {
    pool.set(
      name,
      makeFoodWithConstraints({
        id: name,
        name,
        display_name: name,
        per_serving: {
          carbs_g: 25,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 50,
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
  }
  return pool;
}

// ============================================================================
// Shared test context
// ============================================================================

const ACTIVITY: ActivityType = "running";
const DURATION_MINUTES = 120; // 90-150 min bracket
const GUT_LEVEL: GutTrainingLevel = "moderate";

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
// Suite 1 — Single template, missing component → excluded from candidates
// ============================================================================

describe("Missing component food — template is excluded, not thrown", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("template whose carb food is absent from foodsByName is excluded from candidates", async () => {
    // Template references 'energy_gel' as its carb source.
    // foodsByName does NOT contain 'energy_gel'.
    // Expected: template is excluded; candidates = [].
    const template = makeTemplate({
      template_number: 1,
      name: "Gel + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["energy_gel", "water"],
      component_carb_ratios: { "energy_gel": 1.0 },
    });

    // Pool has 'water' but NOT 'energy_gel'
    const foodsByName = makePoolWithFoods(["water"]);

    const candidates = selectTemplateCandidates(
      [template],
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-missing-carb-food-excluded",
      "Template 1 references energy_gel which is absent from pool — must be excluded",
    );

    assertEquals(
      candidates.length,
      0,
      "Template with missing carb food must be excluded from candidates",
    );

    // Verify a log entry was emitted describing the skip (for observability)
    const skipLogs = logs.entries.filter((e) =>
      e.raw.includes("missing foods") || e.raw.includes("Skipping template")
    );
    assert(
      skipLogs.length > 0,
      "Solver must log why the template was skipped (missing foods)",
    );
  });

  it("template with multiple carb foods — excluded when ANY carb food is absent", async () => {
    // Template requires both energy_gel and sports_drink as carb sources.
    // Pool only has energy_gel; sports_drink is missing.
    // The component_carb_ratios check must catch partial missing foods.
    const template = makeTemplate({
      template_number: 2,
      name: "Gel + Sports Drink + Water",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["moderate", "high"],
      component_food_names: ["energy_gel", "sports_drink", "water"],
      component_carb_ratios: { "energy_gel": 0.7, "sports_drink": 0.3 },
    });

    // Pool has energy_gel but NOT sports_drink
    const foodsByName = makePoolWithFoods(["energy_gel", "water"]);

    const candidates = selectTemplateCandidates(
      [template],
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-missing-one-of-two-carb-foods",
      "Template 2 requires gel + sports_drink; pool missing sports_drink — must be excluded",
    );

    assertEquals(
      candidates.length,
      0,
      "Template must be excluded when any carb-contributing food is absent from pool",
    );
  });

  it("template with only non-carb components (water + electrolyte only) is NOT excluded for missing carb ratios", async () => {
    // Non-carb components (water, electrolytes) are NOT checked against
    // foodsByName during candidate selection — only carb-contributing foods
    // (those listed in component_carb_ratios) matter. A hydration-only
    // template with empty component_carb_ratios should never be excluded on
    // account of 'water' being absent from the pool.
    const template = makeTemplate({
      template_number: 50,
      name: "Water + Electrolyte",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
      component_food_names: ["water", "electrolyte_tab"],
      component_carb_ratios: {}, // no carb sources
    });

    // Pool contains neither water nor electrolyte_tab, but since those are
    // not in component_carb_ratios the template must still pass the
    // food-availability check.
    const foodsByName = makePoolWithFoods([]); // empty pool

    const candidates = selectTemplateCandidates(
      [template],
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-hydration-only-not-excluded",
      "Hydration-only template (no carb ratios) must not be excluded despite empty carb pool",
    );

    assertEquals(
      candidates.length,
      1,
      "Hydration-only template (no carb ratios) must not be excluded due to missing non-carb foods",
    );
    assertEquals(candidates[0].template_number, 50);
  });
});

// ============================================================================
// Suite 2 — All templates excluded → returns [] without throwing
// ============================================================================

describe("All templates excluded — returns [] cleanly (caller falls back to rule solver)", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("all templates excluded → returns [] without throwing", async () => {
    // Both templates reference carb foods absent from the pool.
    // Expected: [] returned (caller falls back), no exception thrown.
    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Gel + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
      }),
      makeTemplate({
        template_number: 3,
        name: "Chew + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_chews", "water"],
        component_carb_ratios: { "energy_chews": 1.0 },
      }),
    ];

    // Pool is completely empty — both templates have missing carb foods
    const foodsByName = makePoolWithFoods([]);

    const candidates = selectTemplateCandidates(
      templates,
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-all-excluded-returns-empty-array",
      "All templates excluded (carb foods absent) — must return [], not throw",
    );

    assertEquals(
      candidates,
      [],
      "All-excluded case must return [] so caller falls back to rule solver",
    );
  });

  it("empty templates list → returns [] without throwing", async () => {
    // Edge case: the caller passes an empty templates array (e.g. DB returned
    // nothing). Must return [] cleanly.
    const candidates = selectTemplateCandidates(
      [],
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      makePoolWithFoods(["energy_gel", "water"]),
    );

    await logs.writeToFile(
      "template-empty-templates-list",
      "Empty templates list — must return [] without throwing",
    );

    assertEquals(candidates, [], "Empty templates list must return []");
  });

  it("all templates excluded by missing foods across cycling activity as well", async () => {
    // Verify the same invariant holds for cycling, which maps to additional
    // activity_type aliases (triathlon_bike etc.) — the food-missing filter
    // must fire before any activity-mapping logic short-circuits.
    const templates = [
      makeTemplate({
        template_number: 7,
        name: "Bar + Sports Drink + Water",
        activity_types: ["cycling"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_bar", "sports_drink", "water"],
        component_carb_ratios: { "energy_bar": 0.55, "sports_drink": 0.45 },
      }),
    ];

    // Neither energy_bar nor sports_drink in pool
    const foodsByName = makePoolWithFoods(["water"]);

    const candidates = selectTemplateCandidates(
      templates,
      "cycling",
      120,
      "moderate",
      foodsByName,
    );

    await logs.writeToFile(
      "template-cycling-all-excluded-missing-foods",
      "Cycling template excluded (bar + sports_drink absent) — must return []",
    );

    assertEquals(
      candidates,
      [],
      "Cycling templates with missing carb foods must also return []",
    );
  });
});

// ============================================================================
// Suite 3 — Partial exclusion: some templates pass, some are excluded
// ============================================================================

describe("Partial exclusion — excluded templates filtered out; valid ones returned", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("template with missing food is excluded; sibling with all foods present is returned", async () => {
    // Template 1 requires energy_gel (absent). Template 3 requires energy_chews
    // (present). Only template 3 should appear in candidates.
    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Gel + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
      }),
      makeTemplate({
        template_number: 3,
        name: "Chew + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_chews", "water"],
        component_carb_ratios: { "energy_chews": 1.0 },
      }),
    ];

    // Pool has energy_chews but NOT energy_gel
    const foodsByName = makePoolWithFoods(["energy_chews", "water"]);

    const candidates = selectTemplateCandidates(
      templates,
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-partial-exclusion-sibling-passes",
      "Template 1 (gel, absent) excluded; template 3 (chews, present) returned",
    );

    assertEquals(
      candidates.length,
      1,
      "Exactly one candidate should pass when one template is excluded",
    );
    assertEquals(
      candidates[0].template_number,
      3,
      "The surviving candidate should be template 3 (chews present in pool)",
    );
  });

  it("template with inactive flag is also excluded regardless of food availability", async () => {
    // Inactive templates should be filtered out before the food-availability
    // check fires — confirm both exclusion paths stack correctly.
    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Inactive Gel",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
        is_active: false, // inactive
      }),
      makeTemplate({
        template_number: 3,
        name: "Chew + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_chews", "water"],
        component_carb_ratios: { "energy_chews": 1.0 },
      }),
    ];

    // Pool has both foods — only inactivity should cause template 1 to be dropped
    const foodsByName = makePoolWithFoods(["energy_gel", "energy_chews", "water"]);

    const candidates = selectTemplateCandidates(
      templates,
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-inactive-excluded-food-present",
      "Template 1 inactive (foods present but is_active=false); template 3 returned",
    );

    assertEquals(
      candidates.length,
      1,
      "Inactive template must be excluded even when its foods are available",
    );
    assertEquals(candidates[0].template_number, 3);
  });

  it("three templates: one missing food, one inactive, one valid — only valid one returned", async () => {
    const templates = [
      makeTemplate({
        template_number: 1,
        name: "Gel + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_gel", "water"],
        component_carb_ratios: { "energy_gel": 1.0 },
        // energy_gel absent from pool below
      }),
      makeTemplate({
        template_number: 2,
        name: "Gel + Sports Drink + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["moderate", "high"],
        component_food_names: ["energy_gel", "sports_drink", "water"],
        component_carb_ratios: { "energy_gel": 0.7, "sports_drink": 0.3 },
        is_active: false, // inactive
      }),
      makeTemplate({
        template_number: 3,
        name: "Chew + Water",
        activity_types: ["running"],
        duration_brackets: ["90-150 min"],
        gut_training_levels: ["low", "moderate", "high"],
        component_food_names: ["energy_chews", "water"],
        component_carb_ratios: { "energy_chews": 1.0 },
        // energy_chews present in pool
      }),
    ];

    // energy_gel absent; energy_chews present
    const foodsByName = makePoolWithFoods(["energy_chews", "water"]);

    const candidates = selectTemplateCandidates(
      templates,
      ACTIVITY,
      DURATION_MINUTES,
      GUT_LEVEL,
      foodsByName,
    );

    await logs.writeToFile(
      "template-three-way-only-valid-returned",
      "3 templates: missing food / inactive / valid — only the valid one (template 3) returned",
    );

    assertEquals(
      candidates.length,
      1,
      "Only the one valid template should survive both exclusion paths",
    );
    assertEquals(candidates[0].template_number, 3);
  });
});
