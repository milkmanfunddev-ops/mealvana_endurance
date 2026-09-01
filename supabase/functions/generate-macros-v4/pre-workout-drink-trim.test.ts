/**
 * Pre-workout drink selection + sodium trim — regression tests for the two
 * before-phase bugs found 2026-07-21 via the strict-macro E2E suite:
 *
 * 1. before-water 0%: `pickDrink` used ABSOLUTE carb/protein caps, so a plan
 *    already 1g over its protein band rejected every drink — including
 *    zero-protein water. (Same bug class as the #22 sodium fix, which had
 *    only been applied to sodium; pickElectrolyte was already correct.)
 * 2. before-sodium 154%: carb-driven food selection can spend more sodium
 *    than the session band allows and nothing could subtract. Pass 1.6
 *    (`trimSodiumOverage`) now trims add-ons — never primaries — until
 *    sodium is within `sodium_high`, keeping carbs at/above the low band.
 *
 * Run with:
 *   deno test --allow-write --node-modules-dir=none \
 *     supabase/functions/generate-macros-v4/pre-workout-drink-trim.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { pickDrink, trimSodiumOverage } from "./pre-workout.ts";
import type {
  AddOn,
  PlanState,
  PreWorkoutPhaseResult,
  PreWorkoutTemplate,
} from "./types.ts";

// ============================================================================
// Fixtures
// ============================================================================

function drinkTemplate(
  over: Partial<PreWorkoutTemplate> & { name: string },
): PreWorkoutTemplate {
  return {
    id: `tpl-${over.name}`,
    base_category: "Hydration",
    time_window: "< 30 min",
    digestion_speed: "Fast",
    allergens: [],
    serving_unit: "1 cup (8 oz)",
    min_servings: 0.5,
    max_servings: 3,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 0,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 0,
    fluid_ml: 240,
    template_type: "drink",
    is_active: true,
    component_food_names: ["water"],
    component_quantities: { water: 1 },
    ...over,
  } as PreWorkoutTemplate;
}

const WATER = drinkTemplate({ name: "Water" });
const SPORTS_DRINK = drinkTemplate({
  name: "Sports Drink",
  carbs_per_serving: 14,
  sodium_mg: 110,
  fluid_ml: 237,
  max_servings: 2,
});

function makeState(over: Partial<PlanState> = {}): PlanState {
  return {
    used_foods: new Set(),
    sports_drink_used: false,
    used_categories: new Set(),
    carbs_delivered: 143,
    protein_delivered: 22,
    sodium_delivered: 581,
    fluid_delivered: 0,
    carbs_target: 150,
    carbs_low: 131,
    carbs_high: 169,
    protein_target: 15,
    protein_low: 9,
    protein_high: 21,
    sodium_target: 450,
    sodium_low: 300,
    sodium_high: 600,
    fluid_target: 360,
    fluid_low: 300,
    fluid_high: 420,
    ...over,
  };
}

function callPickDrink(state: PlanState, drinks: PreWorkoutTemplate[]) {
  return pickDrink(
    drinks,
    state.protein_delivered,
    state.sodium_delivered,
    state.fluid_delivered,
    state.protein_high,
    state.sodium_target,
    state.fluid_target,
    state.sodium_high,
    state.fluid_high,
    state.carbs_delivered,
    state.carbs_high,
  );
}

// ============================================================================
// Bug 1 — pickDrink headroom caps
// ============================================================================

describe("pickDrink — headroom caps (before-water 0% regression)", () => {
  it("selects water when protein is ALREADY over the high band", () => {
    // The Average Female Half repro: protein 22 > high 21 before drinks.
    // The old absolute cap rejected water here and shipped a no-water plan.
    const state = makeState(); // protein_delivered 22 > protein_high 21
    const drink = callPickDrink(state, [WATER, SPORTS_DRINK]);
    assertExists(drink, "water must be selectable despite protein overage");
    assertEquals(drink!.name, "Water");
    assert(drink!.fluid_ml >= state.fluid_target * 0.85, "fills the fluid target");
  });

  it("selects water when carbs are ALREADY over the high band", () => {
    const state = makeState({ carbs_delivered: 175 }); // > carbs_high 169
    const drink = callPickDrink(state, [WATER, SPORTS_DRINK]);
    assertExists(drink, "water must be selectable despite carb overage");
    assertEquals(drink!.name, "Water");
  });

  it("still rejects drinks whose OWN delta exceeds remaining headroom", () => {
    // Sodium headroom is 19mg (581 of 600) — sports drink adds >=55mg, water 0.
    const state = makeState();
    const drink = callPickDrink(state, [SPORTS_DRINK]);
    assertEquals(drink, null, "sports drink must not fit a 19mg sodium headroom");
  });
});

// ============================================================================
// Bug 2 — sodium overage trim
// ============================================================================

function phaseResult(
  phase: "meal" | "snack" | "top_up",
  totals: { carbs: number; sodium: number; fluid: number },
  addOns: AddOn[] = [],
): PreWorkoutPhaseResult {
  return {
    phase,
    primary: null,
    add_ons: addOns,
    total_carbs_g: totals.carbs,
    total_protein_g: 0,
    total_fat_g: 0,
    total_sodium_mg: totals.sodium,
    total_fluid_ml: totals.fluid,
  } as PreWorkoutPhaseResult;
}

describe("trimSodiumOverage (before-sodium 154% regression)", () => {
  it("removes the cheapest-carb-cost add-on until sodium is within the high band", () => {
    // The Very Heavy Marathon repro shape: 692.5mg delivered vs high 600,
    // with a 100mg sports-drink add-on on the snack.
    const sportsDrinkAddOn: AddOn = {
      type: "sports_drink",
      carbs_g: 15,
      sodium_mg: 100,
      fluid_ml: 240,
      servings: 1,
    };
    const results = [
      phaseResult("meal", { carbs: 249, sodium: 25, fluid: 0 }),
      phaseResult("snack", { carbs: 106.5, sodium: 567.5, fluid: 240 }, [
        sportsDrinkAddOn,
      ]),
      phaseResult("top_up", { carbs: 50, sodium: 100, fluid: 0 }),
    ];
    const state = makeState({
      carbs_delivered: 405.5,
      sodium_delivered: 692.5,
      fluid_delivered: 240,
      carbs_target: 440,
      carbs_low: 385,
      carbs_high: 495,
    });

    trimSodiumOverage(results, state, state.carbs_low);

    assert(
      state.sodium_delivered <= state.sodium_high + 1e-6,
      `sodium ${state.sodium_delivered} must be within high ${state.sodium_high}`,
    );
    assertEquals(results[1].add_ons.length, 0, "the add-on was removed");
    assertEquals(state.sodium_delivered, 592.5);
    assert(
      state.carbs_delivered >= state.carbs_low - 1e-6,
      "carbs must stay at/above the low band",
    );
    assertEquals(results[1].total_sodium_mg, 467.5);
    assertEquals(results[1].total_fluid_ml, 0, "fluid bookkeeping updated");
  });

  it("never trims below the carb low band (overage stays, honestly)", () => {
    // Removing the only add-on would drop carbs under the low band — the trim
    // must refuse and leave the overage in place rather than starve carbs.
    const bananaAddOn: AddOn = {
      type: "banana",
      carbs_g: 27,
      sodium_mg: 1,
      fluid_ml: 90,
      servings: 1,
    };
    const results = [
      phaseResult("meal", { carbs: 132, sodium: 650, fluid: 90 }, [bananaAddOn]),
    ];
    const state = makeState({
      carbs_delivered: 132,
      sodium_delivered: 650,
      carbs_target: 150,
      carbs_low: 131, // 132 - 27 = 105 < 131 → banana is NOT removable
    });

    trimSodiumOverage(results, state, state.carbs_low);

    assertEquals(results[0].add_ons.length, 1, "add-on kept — carbs floor wins");
    assertEquals(state.sodium_delivered, 650, "overage remains (primaries never trimmed)");
  });

  it("no-op when sodium is already within the band", () => {
    const results = [
      phaseResult("meal", { carbs: 100, sodium: 400, fluid: 0 }, [{
        type: "sports_drink",
        carbs_g: 15,
        sodium_mg: 100,
        fluid_ml: 240,
        servings: 1,
      }]),
    ];
    const state = makeState({ carbs_delivered: 100, sodium_delivered: 400 });
    trimSodiumOverage(results, state, 50);
    assertEquals(results[0].add_ons.length, 1);
    assertEquals(state.sodium_delivered, 400);
  });
});

// ============================================================================
// Eating-occasion tiers — SSOT pre-workout-carbs.md v2, invariant 6.
//
// The boundaries moved from 90 min / 30 min to 120 min / 30 min when carbs v2
// was ratified: `meal` iff t >= TIER_MEAL_MIN (120), `snack` iff
// t >= TIER_TOPOFF_MAX (30), `top_off` always. The old 1.5 h expectations
// (Notion spec 31fe3fdb) are superseded, not merely renumbered.
// ============================================================================

import { calculatePreWorkoutTargets, getActiveSubPhases } from "./pre-workout.ts";

describe("Eating-occasion tiers (carbs v2 — 120 min / 30 min)", () => {
  it(">= 120 min gets all three occasions", () => {
    assertEquals(getActiveSubPhases(2.0), ["meal", "snack", "top_up"]);
    assertEquals(getActiveSubPhases(3.0), ["meal", "snack", "top_up"]);
    assertEquals(getActiveSubPhases(4.0), ["meal", "snack", "top_up"]);
  });

  it("30-119 min gets snack + top-off — 1.5 h no longer earns a meal", () => {
    assertEquals(getActiveSubPhases(1.99), ["snack", "top_up"]);
    assertEquals(getActiveSubPhases(1.5), ["snack", "top_up"]);
    assertEquals(getActiveSubPhases(1.0), ["snack", "top_up"]);
    assertEquals(getActiveSubPhases(0.5), ["snack", "top_up"]);
  });

  it("< 30 min gets top-off only", () => {
    assertEquals(getActiveSubPhases(0.49), ["top_up"]);
    assertEquals(getActiveSubPhases(0), ["top_up"]);
  });

  it("both boundaries are inclusive at the bottom", () => {
    assertEquals(getActiveSubPhases(120 / 60), ["meal", "snack", "top_up"]);
    assertEquals(getActiveSubPhases(119.999 / 60), ["snack", "top_up"]);
    assertEquals(getActiveSubPhases(30 / 60), ["snack", "top_up"]);
    assertEquals(getActiveSubPhases(29.999 / 60), ["top_up"]);
  });

  it("target tiers move with the same boundaries (meal_type)", () => {
    assertEquals(
      calculatePreWorkoutTargets(70, 2.0, false, "medium", "mild").meal_type,
      "full_meal",
    );
    assertEquals(
      calculatePreWorkoutTargets(70, 1.5, false, "medium", "mild").meal_type,
      "snack",
    );
    assertEquals(
      calculatePreWorkoutTargets(70, 1.0, false, "medium", "mild").meal_type,
      "snack",
    );
    assertEquals(
      calculatePreWorkoutTargets(70, 0.25, false, "medium", "mild").meal_type,
      "top_up",
    );
  });
});
