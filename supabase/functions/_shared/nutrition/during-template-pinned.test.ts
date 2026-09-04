/**
 * Pin Override Tests for During-Phase Template Solver
 *
 * Verifies the Formula Kit pin override behavior on `selectTemplateCandidates`:
 * when an in-scope pinned template is supplied, all filters
 * (allergen / diet / gut-training / preference / food-availability) are
 * bypassed and the pinned template is returned. When `pinnedTemplateIds` is
 * undefined or empty, behavior is byte-identical to pre-pin v3.
 *
 * Locked policy (2026-05-21, revised 2026-05-22): in-scope pins are honored
 * unconditionally. The only fallthrough reason is `no_pin_for_scope` and is
 * surfaced by the caller (orchestrator), not by `selectTemplateCandidates`
 * itself — which simply falls through to normal candidate selection when no
 * pinned templates match the scope.
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/_shared/nutrition/during-template-pinned.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  type DuringWorkoutTemplate,
  filterPinnedTemplatesInScope,
  type FoodWithConstraints,
  selectTemplateCandidates,
} from "./during-template-solver.ts";
import { makeFood } from "./test-utils.ts";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

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
    component_food_names: overrides.component_food_names ?? ["energy_gel"],
    component_carb_ratios: overrides.component_carb_ratios ?? {
      energy_gel: 1.0,
    },
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

function makeMinimalPool(): Map<string, FoodWithConstraints> {
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
  return pool;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("selectTemplateCandidates pin override", () => {
  it("pin override: bypasses allergen filter when pin matches scope", () => {
    const pinned = makeTemplate({
      template_number: 42,
      name: "Pinned w/ Peanut",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["high"],
      allergens: ["peanut"], // user is allergic, but pin overrides
    });
    const decoy = makeTemplate({
      template_number: 1,
      name: "Plain Gel",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const result = selectTemplateCandidates(
      [pinned, decoy],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      ["peanut"], // allergen — would normally filter pinned out
      undefined,
      new Set(["template-42"]),
    );

    assertEquals(result.length, 1, "Only pinned template should be returned");
    assertEquals(result[0].id, "template-42");
  });

  it("pin override: bypasses gut-training filter (locked policy 2026-05-22)", () => {
    // User is gut-training "low" but pin is restricted to "high" only.
    // Pre-pin policy would have filtered this out; pin policy honors it.
    const pinned = makeTemplate({
      template_number: 50,
      name: "Pinned (High Only)",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["high"], // user is "low"
    });
    const decoy = makeTemplate({
      template_number: 2,
      name: "Low-friendly Gel",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      gut_training_levels: ["low", "moderate", "high"],
    });

    const result = selectTemplateCandidates(
      [pinned, decoy],
      "running",
      120,
      "low",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set(["template-50"]),
    );

    assertEquals(result.length, 1);
    assertEquals(result[0].id, "template-50");
  });

  it("pin override: bypasses excluded_diets filter", () => {
    const pinned = makeTemplate({
      template_number: 60,
      name: "Pinned (Excludes Vegan)",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      excluded_diets: ["vegan"],
    });
    const decoy = makeTemplate({
      template_number: 3,
      name: "Vegan-friendly Gel",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const result = selectTemplateCandidates(
      [pinned, decoy],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      undefined,
      "vegan",
      new Set(["template-60"]),
    );

    assertEquals(result.length, 1);
    assertEquals(result[0].id, "template-60");
  });

  it("pin override: bypasses food-availability filter (missing component food)", () => {
    // Pinned template references a food that's NOT in the pool. Pre-pin policy
    // would filter it out; pin override returns it anyway.
    const pinned = makeTemplate({
      template_number: 70,
      name: "Pinned w/ Missing Food",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
      component_food_names: ["mystery_meat_that_does_not_exist"],
      component_carb_ratios: { mystery_meat_that_does_not_exist: 1.0 },
    });
    const decoy = makeTemplate({
      template_number: 4,
      name: "Plain Gel",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const result = selectTemplateCandidates(
      [pinned, decoy],
      "running",
      120,
      "moderate",
      makeMinimalPool(), // doesn't contain "mystery_meat..."
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set(["template-70"]),
    );

    assertEquals(result.length, 1);
    assertEquals(result[0].id, "template-70");
  });

  it("pin scope: pin for cycling does NOT fire when scope is running", () => {
    const pinned = makeTemplate({
      template_number: 80,
      name: "Cycling-only pin",
      activity_types: ["cycling"], // does not include running
      duration_brackets: ["90-150 min"],
    });
    const runningTemplate = makeTemplate({
      template_number: 5,
      name: "Running Gel",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const result = selectTemplateCandidates(
      [pinned, runningTemplate],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set(["template-80"]),
    );

    // Pin out of scope → falls through to normal selection; pin not returned.
    assert(
      result.length > 0,
      "Expected fallthrough to return at least one normal candidate",
    );
    assert(
      !result.some((t) => t.id === "template-80"),
      "Out-of-scope pin must NOT appear in result",
    );
    assert(
      result.some((t) => t.id === "template-5"),
      "Normal candidate should be returned via fallthrough",
    );
  });

  it("pin scope: pin for wrong duration bracket falls through", () => {
    const pinned = makeTemplate({
      template_number: 90,
      name: "Long-only pin",
      activity_types: ["running"],
      duration_brackets: ["> 240 min"], // running is 120min → bracket mismatch
    });
    const inBracketTemplate = makeTemplate({
      template_number: 6,
      name: "90-150 Template",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const result = selectTemplateCandidates(
      [pinned, inBracketTemplate],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set(["template-90"]),
    );

    assert(
      !result.some((t) => t.id === "template-90"),
      "Pin in wrong duration bracket must NOT appear",
    );
    assert(
      result.some((t) => t.id === "template-6"),
      "In-bracket fallthrough candidate should appear",
    );
  });

  it("pin order: multiple in-scope pins returned in template_number order", () => {
    const pin1 = makeTemplate({
      template_number: 25,
      name: "Pin Mid",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });
    const pin2 = makeTemplate({
      template_number: 99,
      name: "Pin High",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });
    const pin3 = makeTemplate({
      template_number: 7,
      name: "Pin Low",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const result = selectTemplateCandidates(
      [pin1, pin2, pin3],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set(["template-25", "template-99", "template-7"]),
    );

    assertEquals(result.length, 3);
    assertEquals(
      result.map((t) => t.template_number),
      [7, 25, 99],
      "Pins must be sorted by template_number ascending",
    );
  });

  it("no-pin parity: undefined pinnedTemplateIds yields identical result to pre-pin behavior", () => {
    const t1 = makeTemplate({
      template_number: 10,
      name: "T1",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });
    const t2 = makeTemplate({
      template_number: 11,
      name: "T2",
      activity_types: ["running"],
      duration_brackets: ["90-150 min"],
    });

    const withoutPin = selectTemplateCandidates(
      [t1, t2],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
    );

    const withEmptySet = selectTemplateCandidates(
      [t1, t2],
      "running",
      120,
      "moderate",
      makeMinimalPool(),
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set<string>(),
    );

    assertEquals(
      withoutPin.map((t) => t.template_number),
      withEmptySet.map((t) => t.template_number),
      "Empty Set must produce byte-identical ordering to omitted param",
    );
    assert(withoutPin.length >= 1, "Expected normal selection to return candidates");
  });
});

// ---------------------------------------------------------------------------
// Brick-leg pin scope override (Lee 2026-09-04): a brick's bike leg matches
// Cycling AND Tri — Bike scoped pins; run leg Running AND Tri — Run. The
// override widens PIN scope only — unpinned candidate selection is untouched.
// ---------------------------------------------------------------------------

describe("brick-leg pin scope override", () => {
  const triBikeTemplate = makeTemplate({
    template_number: 7,
    name: "High Carb Drink Mix + Water",
    activity_types: ["triathlon_bike"],
    duration_brackets: ["90-150 min"],
  });

  it("tri_bike pinned template is OUT of scope for bare cycling", () => {
    const result = filterPinnedTemplatesInScope(
      [triBikeTemplate],
      "cycling",
      100,
      new Set([triBikeTemplate.id]),
    );
    assertEquals(result.length, 0);
  });

  it("tri_bike pinned template matches a brick bike leg via the override", () => {
    const result = filterPinnedTemplatesInScope(
      [triBikeTemplate],
      "cycling",
      100,
      new Set([triBikeTemplate.id]),
      ["cycling", "triathlon_bike"],
    );
    assertEquals(result.length, 1);
    assertEquals(result[0].id, triBikeTemplate.id);
  });

  it("override does not defeat the duration bracket", () => {
    const result = filterPinnedTemplatesInScope(
      [triBikeTemplate],
      "cycling",
      300, // "> 240 min" — template targets 90-150 only
      new Set([triBikeTemplate.id]),
      ["cycling", "triathlon_bike"],
    );
    assertEquals(result.length, 0);
  });

  it("selectTemplateCandidates pin override honors the scope override", () => {
    const foodsByName = new Map<string, FoodWithConstraints>();
    const result = selectTemplateCandidates(
      [triBikeTemplate],
      "cycling",
      100,
      "moderate",
      foodsByName,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      new Set([triBikeTemplate.id]),
      ["cycling", "triathlon_bike"],
    );
    assertEquals(result.length, 1);
    assertEquals(result[0].id, triBikeTemplate.id);
  });
});
