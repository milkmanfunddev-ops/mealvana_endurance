/**
 * During Phase — Empty Food Pool Failure Modes
 *
 * Tests what happens when `generateDuringPhaseRuleBased` is called with an
 * empty (or near-empty) food catalog. Asserts:
 *   1. Empty pool returns `{foods:[]}` without throwing.
 *   2. Numeric outputs are free of NaN/Infinity/negative values.
 *   3. (knownFailure) Empty pool SHOULD surface a shortfall/warning in the
 *      result — today it is silent, which hides the failure from the caller.
 *
 * These tests correspond to P1 in docs/test/edge-function-test-plan-2026.md.
 *
 * Run with:
 *   deno test --allow-write --node-modules-dir=none \
 *     supabase/functions/generate-nutrition-plan-v3/during-phase-empty-pool.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it, beforeEach, afterEach } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { generateDuringPhaseRuleBased } from "../_shared/nutrition/during-rule-solver.ts";
import type { Food, MacroTargets } from "../_shared/nutrition/types.ts";
import {
  LogCapture,
  makeFood,
  makeDuringFoods,
  DURING_STANDARD,
  DURING_MARATHON,
  DURING_SHORT,
} from "../_shared/nutrition/test-utils.ts";

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
// Helpers
// ============================================================================

/** Ensure no numeric field in any FoodResult is NaN, Infinity, or negative. */
function assertNumericSanity(
  foods: Array<{
    carbs_grams: number;
    sodium_mg: number;
    fluids_ml: number;
    protein_grams: number;
    fat_grams?: number;
    calories?: number;
    quantity?: number;
  }>,
  label: string,
): void {
  for (const f of foods) {
    const fields: Array<[string, number | undefined]> = [
      ["carbs_grams", f.carbs_grams],
      ["sodium_mg", f.sodium_mg],
      ["fluids_ml", f.fluids_ml],
      ["protein_grams", f.protein_grams],
      ["fat_grams", f.fat_grams],
      ["calories", f.calories],
      ["quantity", f.quantity],
    ];
    for (const [name, value] of fields) {
      if (value === undefined) continue;
      assert(
        !isNaN(value),
        `${label}: field ${name} is NaN`,
      );
      assert(
        isFinite(value),
        `${label}: field ${name} is Infinity (value=${value})`,
      );
      assert(
        value >= 0,
        `${label}: field ${name} is negative (value=${value})`,
      );
    }
  }
}

// ============================================================================
// Suite 1 — Empty Pool: no throw, clean return
// ============================================================================

describe("Empty pool — no throw + clean return", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("empty pool returns {foods:[]} without throwing — running / standard targets", async () => {
    // The rule solver guards with `if (foods.length === 0) return {foods:[]}`.
    // This test locks that contract so we catch any regression that adds a
    // throw or tries to index into the empty array.
    const result = generateDuringPhaseRuleBased([], DURING_STANDARD, "running");

    await logs.writeToFile(
      "during-empty-pool-running-standard",
      "Empty pool, running, standard 10-mile targets — must not throw, must return {foods:[]}",
    );

    assertExists(result, "Result must not be null/undefined");
    assertEquals(result.foods, [], "Empty pool must produce empty foods array");
  });

  it("empty pool returns {foods:[]} without throwing — cycling / marathon targets", async () => {
    const result = generateDuringPhaseRuleBased([], DURING_MARATHON, "cycling");

    await logs.writeToFile(
      "during-empty-pool-cycling-marathon",
      "Empty pool, cycling, marathon targets — must not throw",
    );

    assertExists(result, "Result must not be null/undefined");
    assertEquals(result.foods, [], "Empty pool must produce empty foods array");
  });

  it("empty pool returns {foods:[]} without throwing — running / short 5K targets", async () => {
    const result = generateDuringPhaseRuleBased([], DURING_SHORT, "running");

    await logs.writeToFile(
      "during-empty-pool-running-short",
      "Empty pool, running, short 5K targets — must not throw",
    );

    assertExists(result, "Result must not be null/undefined");
    assertEquals(result.foods, [], "Empty pool must produce empty foods array");
  });

  it("empty pool returns {foods:[]} for triathlon activity type", async () => {
    const targets: MacroTargets = { carbs_g: 60, sodium_mg: 600, water_ml: 700 };
    const result = generateDuringPhaseRuleBased([], targets, "triathlon");

    await logs.writeToFile(
      "during-empty-pool-triathlon",
      "Empty pool, triathlon — must not throw",
    );

    assertExists(result, "Result must not be null/undefined");
    assertEquals(result.foods, [], "Empty pool must produce empty foods array");
  });
});

// ============================================================================
// Suite 2 — NaN/Infinity/negative guard on empty and near-empty pools
// ============================================================================

describe("Numeric sanity on empty / near-empty pools", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("empty pool: result.foods is [] — no numeric fields to check (vacuously passes)", async () => {
    // This test documents that the absence of foods means there are no
    // numeric outputs to inspect. If the return type ever adds top-level
    // numeric fields (totals, shortfall_g, etc.) this suite should be
    // extended to assert those too.
    const result = generateDuringPhaseRuleBased([], DURING_STANDARD, "running");

    await logs.writeToFile(
      "during-empty-pool-numeric-vacuous",
      "Empty pool — result.foods=[] so no FoodResult numerics exist",
    );

    assertEquals(result.foods.length, 0);
    // Vacuously satisfied: iterating over empty array asserts nothing.
    assertNumericSanity(result.foods, "empty pool");
  });

  it("single-food pool: numeric outputs are finite and non-negative", async () => {
    // A pool of one food is near-empty — ensure the solver can't produce NaN
    // from arithmetic on a single food's per_serving values.
    const singleFood: Food[] = [
      makeFood({
        id: "solo-gel",
        name: "Solo Gel",
        per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
        preference_score: 80,
        is_indivisible: true,
        product_type: "gel",
        min_servings: 1,
        max_servings: 4,
      }),
    ];
    const result = generateDuringPhaseRuleBased(singleFood, DURING_STANDARD, "running");

    await logs.writeToFile(
      "during-single-food-numeric-sanity",
      "Single-food pool (gel only) — all numeric fields must be finite and non-negative",
    );

    assertNumericSanity(result.foods, "single-food pool");
  });

  it("water-only pool: numeric outputs are finite and non-negative", async () => {
    // Water has carbs=0 and sodium=0, which exercises division-by-zero guards
    // in the carb and sodium scaling paths.
    const waterOnly: Food[] = [
      makeFood({
        id: "water-only",
        name: "Water",
        per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
        preference_score: 50,
        is_liquid: true,
        is_essential: true,
        product_type: "beverage",
        min_servings: 1,
        max_servings: 6,
      }),
    ];
    const result = generateDuringPhaseRuleBased(waterOnly, DURING_STANDARD, "running");

    await logs.writeToFile(
      "during-water-only-numeric-sanity",
      "Water-only pool — carb/sodium=0 per-serving, no division-by-zero should produce NaN",
    );

    assertNumericSanity(result.foods, "water-only pool");
    // Carb-contributing field must not be NaN even if water contributes 0 carbs
    for (const f of result.foods) {
      assert(!isNaN(f.carbs_grams), "carbs_grams must not be NaN on water-only result");
    }
  });

  it("full standard pool: numeric outputs are finite and non-negative for sanity baseline", async () => {
    // Baseline: the full mock catalog must also pass numeric sanity so any
    // future regression in quantify logic is caught here before empty-pool
    // tests are blamed.
    const result = generateDuringPhaseRuleBased(makeDuringFoods(), DURING_MARATHON, "running");

    await logs.writeToFile(
      "during-full-pool-numeric-sanity",
      "Full pool baseline — all numeric fields must be finite and non-negative",
    );

    assert(result.foods.length > 0, "Full pool should produce at least one food");
    assertNumericSanity(result.foods, "full-pool baseline");
  });
});

// ============================================================================
// Suite 3 — knownFailure: empty pool should surface a shortfall or warning
//
// Desired behavior: when the food pool is empty, the solver should surface
// a meaningful signal — either a `shortfalls` array on the result or a
// console.warn message — so the caller (generateDuringPhase) and downstream
// clients can distinguish "no foods = cannot fuel" from "phase succeeded".
//
// Current behavior: the solver returns {foods:[]} silently. No `shortfalls`
// field, no warning. The caller in during-phase.ts also logs an info message
// but does NOT attach a shortfall to the returned LPPhaseResult, so the
// Flutter client cannot distinguish an empty-pool situation from a legitimate
// zero-fuel phase (e.g. swimming).
//
// This is tracked as bug #4 in docs/test/edge-function-test-plan-2026.md.
// ============================================================================

describe("knownFailure — empty pool should emit shortfall/warning (bug #4)", () => {
  beforeEach(setup);
  afterEach(teardown);

  it("empty pool should set shortfalls AND emit a warning log (bug #2 fixed)", async () => {
    // FIXED: generateDuringPhaseRuleBased now emits shortfalls and a warn-level
    // log when the food pool is empty, allowing callers to distinguish
    // "no foods = cannot fuel" from a legitimate zero-fuel phase (e.g. swimming).

    const result = generateDuringPhaseRuleBased([], DURING_MARATHON, "running");

    await logs.writeToFile(
      "during-empty-pool-shortfall-fixed",
      "Empty pool — must emit shortfalls + warning log (bug #2 fixed)",
    );

    // deno-lint-ignore no-explicit-any
    const resultAny = result as any;

    const hasShortfalls =
      Array.isArray(resultAny.shortfalls) && resultAny.shortfalls.length > 0;
    const hasWarnLog = logs.getByLevel("warn").length > 0 || logs.getByLevel("error").length > 0;

    assert(hasShortfalls, "Empty pool must emit a non-empty shortfalls array");
    assert(hasWarnLog, "Empty pool must emit at least one warn/error log entry");
    // Verify shortfall shape: carbs shortfall must be present for marathon targets
    const carbShortfall = resultAny.shortfalls.find(
      // deno-lint-ignore no-explicit-any
      (s: any) => s.macro === "carbs",
    );
    assertExists(carbShortfall, "Carbs shortfall must be present for marathon targets");
    assertEquals(carbShortfall.delivered, 0);
    assertEquals(carbShortfall.target, DURING_MARATHON.carbs_g);
    assertEquals(carbShortfall.unit, "g");
  });

  it("empty pool rule-solver result carries a warnings array for wire propagation (bug #2 fixed)", async () => {
    // FIXED: the rule solver now returns warnings[] on its result when the pool
    // is empty, so during-phase.ts can propagate them into the LPPhaseResult.
    // This verifies the rule-solver output shape; the caller propagation is
    // covered by the integration/E2E path.

    const emptyResult = generateDuringPhaseRuleBased([], DURING_MARATHON, "running");

    await logs.writeToFile(
      "during-empty-pool-wire-warnings-fixed",
      "Empty pool — rule solver result must have warnings[] (bug #2 fixed)",
    );

    // deno-lint-ignore no-explicit-any
    const resultAny = emptyResult as any;

    const hasWarnings =
      Array.isArray(resultAny.warnings) && resultAny.warnings.length > 0;

    assert(hasWarnings, "Rule solver result must carry warnings[] when pool is empty");
    assert(
      resultAny.warnings[0].includes("Empty food pool"),
      `First warning must describe the empty pool condition. Got: ${resultAny.warnings[0]}`,
    );
  });
});
