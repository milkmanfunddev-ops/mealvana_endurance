/**
 * Default-formula selector tests (formula-first flip, 2026-07-03).
 *
 * Covers:
 *   - `pickHighestPriorityTemplate` — best-fit by selection_priority DESC,
 *     tie-broken by template_number ASC; null/undefined priority ranks last.
 *   - `selectDefaultPostFormulaId` — returns the highest-priority renderable,
 *     diet/allergen-safe post template; null when everything is filtered.
 *
 * `selectDefaultDuringFormulaId` is a thin wrapper over the already-tested
 * `selectTemplateCandidates` (returns candidates[0].id), so it is exercised
 * transitively by diet-allergy-filtering.test.ts rather than duplicated here.
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/_shared/nutrition/default-formula.test.ts
 */

import {
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  pickHighestPriorityTemplate,
  selectDefaultPostFormulaId,
} from "./default-formula.ts";
import type { PostWorkoutTemplate } from "./post-template-solver.ts";
import type { Food } from "./types.ts";
import { makeFood } from "./test-utils.ts";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function makePostTemplate(
  overrides: Partial<PostWorkoutTemplate> & {
    template_number: number;
    name: string;
  },
): PostWorkoutTemplate {
  return {
    id: overrides.id ?? `post-${overrides.template_number}`,
    template_number: overrides.template_number,
    name: overrides.name,
    formula: overrides.formula ?? overrides.name,
    portions: overrides.portions ?? null,
    activity_types: overrides.activity_types ?? ["running", "cycling"],
    component_food_names: overrides.component_food_names ?? ["banana"],
    component_ratios: overrides.component_ratios ?? null,
    default_servings: overrides.default_servings ?? { banana: 1 },
    target_carb_protein_ratio: overrides.target_carb_protein_ratio ?? null,
    allergens: overrides.allergens ?? [],
    excluded_diets: overrides.excluded_diets ?? [],
    travel_friendliness: overrides.travel_friendliness ?? "in_bag",
    flavor_profile: overrides.flavor_profile ?? "sweet_creamy",
    prep_effort: overrides.prep_effort ?? "grab_and_go",
    protein_anchor: overrides.protein_anchor ?? null,
    carb_sources: overrides.carb_sources ?? ["banana"],
    notes: overrides.notes ?? null,
    is_active: overrides.is_active ?? true,
    selection_priority: overrides.selection_priority ?? null,
  };
}

function foodsMap(foods: Food[]): Map<string, Food> {
  const m = new Map<string, Food>();
  for (const f of foods) m.set(f.name, f);
  return m;
}

// ===========================================================================
// pickHighestPriorityTemplate
// ===========================================================================

describe("pickHighestPriorityTemplate", () => {
  it("empty list → null", () => {
    assertEquals(pickHighestPriorityTemplate([]), null);
  });

  it("picks the highest selection_priority", () => {
    const a = makePostTemplate({ template_number: 1, name: "A", selection_priority: 3 });
    const b = makePostTemplate({ template_number: 2, name: "B", selection_priority: 9 });
    const c = makePostTemplate({ template_number: 3, name: "C", selection_priority: 5 });
    assertEquals(pickHighestPriorityTemplate([a, b, c])?.name, "B");
  });

  it("ties on priority broken by lower template_number", () => {
    const a = makePostTemplate({ template_number: 8, name: "A", selection_priority: 7 });
    const b = makePostTemplate({ template_number: 2, name: "B", selection_priority: 7 });
    assertEquals(pickHighestPriorityTemplate([a, b])?.name, "B");
  });

  it("null/undefined priority ranks below any real value", () => {
    const nullPri = makePostTemplate({ template_number: 1, name: "N", selection_priority: null });
    const realPri = makePostTemplate({ template_number: 9, name: "R", selection_priority: 0 });
    assertEquals(pickHighestPriorityTemplate([nullPri, realPri])?.name, "R");
  });

  it("all-null priorities → lowest template_number wins", () => {
    const a = makePostTemplate({ template_number: 5, name: "A", selection_priority: null });
    const b = makePostTemplate({ template_number: 1, name: "B", selection_priority: null });
    assertEquals(pickHighestPriorityTemplate([a, b])?.name, "B");
  });
});

// ===========================================================================
// selectDefaultPostFormulaId
// ===========================================================================

describe("selectDefaultPostFormulaId", () => {
  const foods = foodsMap([
    makeFood({ name: "banana" }),
    makeFood({ name: "chocolate_milk" }),
  ]);

  it("returns the highest-priority renderable template id", () => {
    const low = makePostTemplate({
      id: "low",
      template_number: 1,
      name: "Low",
      selection_priority: 1,
      component_food_names: ["banana"],
      default_servings: { banana: 1 },
    });
    const high = makePostTemplate({
      id: "high",
      template_number: 2,
      name: "High",
      selection_priority: 8,
      component_food_names: ["chocolate_milk"],
      default_servings: { chocolate_milk: 1 },
    });
    assertEquals(
      selectDefaultPostFormulaId([low, high], "running", foods),
      "high",
    );
  });

  it("skips a template whose component food is unavailable", () => {
    const missing = makePostTemplate({
      id: "missing",
      template_number: 1,
      name: "Missing",
      selection_priority: 99,
      component_food_names: ["unicorn_gel"],
      default_servings: { unicorn_gel: 1 },
    });
    const ok = makePostTemplate({
      id: "ok",
      template_number: 2,
      name: "OK",
      selection_priority: 2,
      component_food_names: ["banana"],
      default_servings: { banana: 1 },
    });
    assertEquals(
      selectDefaultPostFormulaId([missing, ok], "running", foods),
      "ok",
    );
  });

  it("respects allergen filtering (returns null when all filtered)", () => {
    const nutty = makePostTemplate({
      id: "nutty",
      template_number: 1,
      name: "Nutty",
      selection_priority: 5,
      allergens: ["Peanut"],
      component_food_names: ["banana"],
      default_servings: { banana: 1 },
    });
    assertEquals(
      selectDefaultPostFormulaId([nutty], "running", foods, ["peanut"]),
      null,
    );
  });

  it("returns null when no templates match the activity", () => {
    const swimOnly = makePostTemplate({
      id: "swim",
      template_number: 1,
      name: "Swim",
      selection_priority: 5,
      activity_types: ["swimming"],
    });
    assertEquals(
      selectDefaultPostFormulaId([swimOnly], "running", foods),
      null,
    );
  });
});
