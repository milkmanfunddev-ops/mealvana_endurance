/**
 * Pin Override Tests for After (Post-Workout) Phase
 *
 * Covers two layers:
 *
 *   1. `derivePinnedPostComponentNames` — pure helper that collects the
 *      component food names of pinned post-workout templates so they can
 *      bypass dislike / allergen / diet filters at food load (PR 3 #35
 *      fix, parity with During PR 2 5c).
 *
 *   2. `selectPostWorkoutTemplateCandidates` pin-override path — symmetric
 *      with `during-template-pinned.test.ts`. When any in-scope pin exists
 *      the selector returns the pinned set unconditionally, bypassing
 *      allergen / diet / food-availability filters per locked Formula Kit
 *      pin policy.
 *
 * Not covered (would require new Supabase mock infra; deferred):
 *   - `getTemplateFoodsForPhase` filter bypass — exercised end-to-end by
 *     the 2026-05-26 Chocolate Milk Solo smoke test on dev.
 *   - Option A guard inline in `generateAfterPhase` (downgrade pin_decision
 *     when render returns null) — defensive code, unreachable once Option B
 *     food-load bypass is in place.
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/generate-nutrition-plan-v3/after-phase-pinned.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  filterPinnedPostTemplatesInScope,
  type PostWorkoutTemplate,
  selectPostWorkoutTemplateCandidates,
} from "../_shared/nutrition/post-template-solver.ts";
import type { Food } from "../_shared/nutrition/types.ts";
import { makeFood } from "../_shared/nutrition/test-utils.ts";
import { derivePinnedPostComponentNames } from "./after-phase.ts";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function makeTemplate(
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
// derivePinnedPostComponentNames
// ===========================================================================

describe("derivePinnedPostComponentNames", () => {
  const chocoSolo = makeTemplate({
    template_number: 17,
    name: "Chocolate Milk Solo",
    component_food_names: ["chocolate_milk"],
  });
  const bananaPB = makeTemplate({
    template_number: 3,
    name: "Banana + Peanut Butter",
    component_food_names: ["banana", "peanut_butter"],
  });
  const yogurtBerry = makeTemplate({
    template_number: 5,
    name: "Greek Yogurt + Berries",
    component_food_names: ["greek_yogurt", "blueberry"],
  });
  const allTemplates = [chocoSolo, bananaPB, yogurtBerry];

  it("undefined pinnedTemplateIds → empty set", () => {
    const names = derivePinnedPostComponentNames(allTemplates, undefined);
    assertEquals(names.size, 0);
  });

  it("empty pinnedTemplateIds → empty set", () => {
    const names = derivePinnedPostComponentNames(
      allTemplates,
      new Set<string>(),
    );
    assertEquals(names.size, 0);
  });

  it("single pinned template → its components", () => {
    const names = derivePinnedPostComponentNames(
      allTemplates,
      new Set([chocoSolo.id]),
    );
    assertEquals(names.size, 1);
    assert(names.has("chocolate_milk"));
  });

  it("multiple pinned templates → union of components", () => {
    const names = derivePinnedPostComponentNames(
      allTemplates,
      new Set([chocoSolo.id, bananaPB.id]),
    );
    assertEquals(names.size, 3);
    assert(names.has("chocolate_milk"));
    assert(names.has("banana"));
    assert(names.has("peanut_butter"));
  });

  it("templates not in pinned set are ignored", () => {
    const names = derivePinnedPostComponentNames(
      allTemplates,
      new Set([yogurtBerry.id]),
    );
    assertEquals(names.size, 2);
    assert(names.has("greek_yogurt"));
    assert(names.has("blueberry"));
    assert(!names.has("chocolate_milk"));
    assert(!names.has("banana"));
  });

  it("pinned id with no matching template → no components contributed", () => {
    const names = derivePinnedPostComponentNames(
      allTemplates,
      new Set(["post-doesnt-exist"]),
    );
    assertEquals(names.size, 0);
  });
});

// ===========================================================================
// filterPinnedPostTemplatesInScope
// ===========================================================================

describe("filterPinnedPostTemplatesInScope", () => {
  it("filters by pinnedTemplateIds membership", () => {
    const t1 = makeTemplate({ template_number: 1, name: "A" });
    const t2 = makeTemplate({ template_number: 2, name: "B" });
    const result = filterPinnedPostTemplatesInScope(
      [t1, t2],
      "running",
      new Set([t1.id]),
    );
    assertEquals(result.length, 1);
    assertEquals(result[0].id, t1.id);
  });

  it("excludes templates whose activity_types don't overlap", () => {
    const runOnly = makeTemplate({
      template_number: 1,
      name: "Run Only",
      activity_types: ["running"],
    });
    const swimOnly = makeTemplate({
      template_number: 2,
      name: "Swim Only",
      activity_types: ["swimming"],
    });
    const result = filterPinnedPostTemplatesInScope(
      [runOnly, swimOnly],
      "running",
      new Set([runOnly.id, swimOnly.id]),
    );
    assertEquals(result.length, 1);
    assertEquals(result[0].id, runOnly.id);
  });

  it("empty activity_types treated as universal (in scope for any sport)", () => {
    const universal = makeTemplate({
      template_number: 1,
      name: "Universal",
      activity_types: [],
    });
    const result = filterPinnedPostTemplatesInScope(
      [universal],
      "swimming",
      new Set([universal.id]),
    );
    assertEquals(result.length, 1);
  });

  it("excludes inactive templates even when pinned and in scope", () => {
    const inactive = makeTemplate({
      template_number: 1,
      name: "Inactive",
      is_active: false,
    });
    const result = filterPinnedPostTemplatesInScope(
      [inactive],
      "running",
      new Set([inactive.id]),
    );
    assertEquals(result.length, 0);
  });
});

// ===========================================================================
// selectPostWorkoutTemplateCandidates — pin override path
// ===========================================================================

describe("selectPostWorkoutTemplateCandidates pin override", () => {
  const chocoSolo = makeTemplate({
    template_number: 17,
    name: "Chocolate Milk Solo",
    component_food_names: ["chocolate_milk"],
    activity_types: ["running", "cycling"],
    // dairy allergen would normally filter this out
    allergens: ["dairy"],
  });
  const banana = makeTemplate({
    template_number: 3,
    name: "Banana",
    component_food_names: ["banana"],
    activity_types: ["running"],
  });

  it("undefined pinnedTemplateIds → pre-pin behavior (no override)", () => {
    const foods = foodsMap([makeFood({ name: "banana" })]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [banana, chocoSolo],
      "running",
      foods,
      ["dairy"], // user is dairy-allergic
      undefined,
      Math.random,
      undefined, // no pins
    );
    // chocoSolo is filtered out by dairy allergen; only banana survives
    assertEquals(candidates.length, 1);
    assertEquals(candidates[0].id, banana.id);
  });

  it("empty pinnedTemplateIds → pre-pin behavior (no override)", () => {
    const foods = foodsMap([makeFood({ name: "banana" })]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [banana, chocoSolo],
      "running",
      foods,
      ["dairy"],
      undefined,
      Math.random,
      new Set<string>(),
    );
    assertEquals(candidates.length, 1);
    assertEquals(candidates[0].id, banana.id);
  });

  it("in-scope pin overrides allergen filter", () => {
    // No foods map needed — pin override bypasses food-availability filter too.
    const foods = foodsMap([]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [banana, chocoSolo],
      "running",
      foods,
      ["dairy"], // would normally drop chocoSolo
      undefined,
      Math.random,
      new Set([chocoSolo.id]),
    );
    assertEquals(candidates.length, 1);
    assertEquals(candidates[0].id, chocoSolo.id);
    assertEquals(candidates[0].name, "Chocolate Milk Solo");
  });

  it("in-scope pin overrides diet filter", () => {
    const veganBlocked = makeTemplate({
      template_number: 10,
      name: "Whey Shake",
      activity_types: ["running"],
      excluded_diets: ["vegan"],
    });
    const foods = foodsMap([]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [veganBlocked],
      "running",
      foods,
      undefined,
      "vegan",
      Math.random,
      new Set([veganBlocked.id]),
    );
    assertEquals(candidates.length, 1);
    assertEquals(candidates[0].id, veganBlocked.id);
  });

  it("in-scope pin bypasses food-availability filter", () => {
    // chocolate_milk is NOT in foodsByName — the bug we fixed.
    // Selector must STILL return chocoSolo when pinned + in scope.
    const foods = foodsMap([makeFood({ name: "banana" })]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [chocoSolo],
      "running",
      foods,
      undefined,
      undefined,
      Math.random,
      new Set([chocoSolo.id]),
    );
    assertEquals(candidates.length, 1);
    assertEquals(candidates[0].id, chocoSolo.id);
  });

  it("out-of-scope pin → falls through to normal selection", () => {
    const swimOnlyPinned = makeTemplate({
      template_number: 20,
      name: "Swim Only Pinned",
      activity_types: ["swimming"],
    });
    const foods = foodsMap([makeFood({ name: "banana" })]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [swimOnlyPinned, banana],
      "running",
      foods,
      undefined,
      undefined,
      Math.random,
      new Set([swimOnlyPinned.id]),
    );
    // Pin is out of scope for running; non-pin path returns banana
    assertEquals(candidates.length, 1);
    assertEquals(candidates[0].id, banana.id);
  });

  it("multiple in-scope pins → ranked by selection_priority DESC", () => {
    const lowPriority = makeTemplate({
      template_number: 1,
      name: "Low",
      activity_types: ["running"],
      selection_priority: 1,
    });
    const highPriority = makeTemplate({
      template_number: 2,
      name: "High",
      activity_types: ["running"],
      selection_priority: 10,
    });
    const foods = foodsMap([]);
    const candidates = selectPostWorkoutTemplateCandidates(
      [lowPriority, highPriority],
      "running",
      foods,
      undefined,
      undefined,
      Math.random,
      new Set([lowPriority.id, highPriority.id]),
    );
    assertEquals(candidates.length, 2);
    assertEquals(candidates[0].id, highPriority.id);
  });

  it("multiple in-scope pins with equal priority → tie broken by random", () => {
    const a = makeTemplate({
      template_number: 1,
      name: "A",
      activity_types: ["running"],
      selection_priority: 5,
    });
    const b = makeTemplate({
      template_number: 2,
      name: "B",
      activity_types: ["running"],
      selection_priority: 5,
    });
    const foods = foodsMap([]);
    // Deterministic random: pick(0) on first call.
    // The selector sorts pinnedInScope ASC by template_number first, then
    // applies random pick across the tie block. random()=0 → idx 0 → a stays
    // at front. Use random()=0.6 → idx 1 → b swapped to front.
    const candidatesA = selectPostWorkoutTemplateCandidates(
      [a, b],
      "running",
      foods,
      undefined,
      undefined,
      () => 0.0,
      new Set([a.id, b.id]),
    );
    assertEquals(candidatesA[0].id, a.id);

    const candidatesB = selectPostWorkoutTemplateCandidates(
      [a, b],
      "running",
      foods,
      undefined,
      undefined,
      () => 0.6,
      new Set([a.id, b.id]),
    );
    assertEquals(candidatesB[0].id, b.id);
  });
});
