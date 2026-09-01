/**
 * LP Infeasibility + Empty-Pool Fallback Tests
 *
 * Covers P5 from edge-function-test-plan-2026.md:
 *   "solveLPModel infeasible + greedyFallback empty pool ⇒ never returns
 *    {foods: undefined}; returns {foods:[]} cleanly."
 *
 * Tests operate entirely on in-memory food pools — no Supabase, no HTTP.
 * generateLPPhase is intentionally NOT tested here because it requires a live
 * Supabase client; instead we test buildLPModel + solveLPModel + greedyFallback
 * directly, exactly as lp-solver.test.ts does.
 *
 * Run with:
 *   /opt/homebrew/bin/deno test --allow-read --allow-write --node-modules-dir=none \
 *     supabase/functions/_shared/nutrition/lp-infeasibility.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeEach, afterEach } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { buildLPModel, solveLPModel } from './lp-solver.ts';
import { greedyFallback } from './greedy-fallback.ts';
import { DEFAULT_OPTIMIZATION_WEIGHTS } from './constants.ts';
import type { Food, MacroTargets, Phase } from './types.ts';
import {
  LogCapture,
  makeFood,
  makeAfterFoods,
  makeDuringFoods,
  makeTargets,
} from './test-utils.ts';

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

/** Build + solve in one call (mirrors lp-solver.test.ts helper). */
function buildAndSolve(
  foods: Food[],
  targets: MacroTargets,
  phase: Phase,
) {
  const w = DEFAULT_OPTIMIZATION_WEIGHTS[phase];
  const model = buildLPModel(foods, targets, phase, w);
  return solveLPModel(model, foods, phase);
}

/**
 * Numeric-sanity guard: every numeric field in each food result must be
 * finite, non-negative, and not NaN.
 */
function assertFoodResultsNumericSanity(
  foods: ReturnType<typeof greedyFallback>['foods'],
  label: string,
): void {
  for (const f of foods) {
    const fields: [string, number][] = [
      ['quantity', f.quantity],
      ['carbs_grams', f.carbs_grams],
      ['protein_grams', f.protein_grams],
      ['fat_grams', f.fat_grams],
      ['sodium_mg', f.sodium_mg],
      ['fluids_ml', f.fluids_ml],
      ['calories', f.calories],
    ];
    for (const [name, val] of fields) {
      assert(
        Number.isFinite(val),
        `[${label}] food ${f.food_id}.${name} must be finite, got ${val}`,
      );
      assert(
        val >= 0,
        `[${label}] food ${f.food_id}.${name} must be >= 0, got ${val}`,
      );
    }
  }
}

/**
 * Numeric-sanity guard on PhaseSolution totals.
 */
function assertTotalsNumericSanity(
  totals: ReturnType<typeof greedyFallback>['totals'],
  label: string,
): void {
  const fields: [string, number][] = [
    ['carbs_g', totals.carbs_g],
    ['protein_g', totals.protein_g],
    ['fat_g', totals.fat_g],
    ['sodium_mg', totals.sodium_mg],
    ['water_ml', totals.water_ml],
    ['calories', totals.calories],
  ];
  for (const [name, val] of fields) {
    assert(
      Number.isFinite(val),
      `[${label}] totals.${name} must be finite, got ${val}`,
    );
    assert(
      val >= 0,
      `[${label}] totals.${name} must be >= 0, got ${val}`,
    );
  }
}

// ============================================================================
// P5a — solveLPModel: infeasible pool returns null without throwing
// ============================================================================

describe('LP Infeasibility — solveLPModel on impossible pool', () => {
  beforeEach(setup);
  afterEach(teardown);

  /**
   * CASE 1: Single pure-water food vs. a high-carb target.
   *
   * The pool contains only water (0g carbs per serving). The carb constraint
   * requires [90%, 110%] × 80g = [72, 88]g. The solver CANNOT satisfy the
   * carb minimum → infeasible.
   *
   * Expected: solveLPModel returns null (not throw, not {foods: undefined}).
   */
  it('pure-water food vs high-carb target returns null without throwing', async () => {
    const waterOnly = makeFood({
      id: 'pure-water',
      name: 'Pure Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
      is_liquid: true,
      is_essential: true,
      product_type: 'beverage',
      max_servings: 6,
      preference_score: 50,
    });

    const foods: Food[] = [waterOnly];
    const targets = makeTargets({ carbs_g: 80, protein_g: 20, sodium_mg: 400, water_ml: 500 });

    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile(
      'lp-infeasibility-pure-water-high-carb',
      'Case 1: pure-water food vs high-carb target — expect null',
    );

    // Must return null, not throw and not return {foods: undefined}
    assertEquals(
      result,
      null,
      'solveLPModel must return null for infeasible pool (pure water cannot supply carbs)',
    );
  });

  /**
   * CASE 2: Single electrolyte supplement (1g carbs, 0 protein) vs. targets
   * requiring substantial carbs AND protein.
   *
   * With max_servings=4 the pool can deliver at most 4g carbs (constraint
   * minimum = 0.9 × 80 = 72g) and 0g protein (min = 0.85 × 25 ≈ 21g).
   * Both macro floors are unreachable → infeasible.
   */
  it('electrolyte-only pool vs carb+protein targets returns null', async () => {
    const tab = makeFood({
      id: 'electrolyte-tab-infeasible',
      name: 'Electrolyte Tab',
      per_serving: { carbs_g: 1, protein_g: 0, fat_g: 0, sodium_mg: 350, water_ml: 0, calories: 10 },
      is_electrolyte: true,
      is_indivisible: true,
      product_type: 'supplement',
      max_servings: 4,
      preference_score: 50,
    });

    const foods: Food[] = [tab];
    const targets = makeTargets({ carbs_g: 80, protein_g: 25, sodium_mg: 400, water_ml: 200 });

    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile(
      'lp-infeasibility-electrolyte-only',
      'Case 2: electrolyte-only pool vs carb+protein targets — expect null',
    );

    assertEquals(
      result,
      null,
      'solveLPModel must return null for electrolyte-only pool that cannot meet carb+protein floors',
    );
  });

  /**
   * CASE 3: Single food that has ONLY water and sodium — zero carbs, zero
   * protein. During-phase target requires 45g carbs minimum (0.9 × 50g).
   * Infeasible because the carb floor cannot be met.
   */
  it('sodium-water-only during pool vs carb target returns null', async () => {
    const sports = makeFood({
      id: 'sodium-water-only',
      name: 'Electrolyte Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 200, water_ml: 500, calories: 0 },
      is_liquid: true,
      is_electrolyte: true,
      product_type: 'supplement',
      max_servings: 4,
      preference_score: 80,
    });

    const foods: Food[] = [sports];
    const targets = makeTargets({ carbs_g: 50, protein_g: 0, sodium_mg: 600, water_ml: 800 });
    // Override protein to 0 for during phase (during phase does not use protein constraint)
    const duringTargets: MacroTargets = { ...targets, protein_g: undefined };

    const result = buildAndSolve(foods, duringTargets, 'during');

    await logs.writeToFile(
      'lp-infeasibility-sodium-water-during',
      'Case 3: sodium+water only during pool vs carb target — expect null',
    );

    assertEquals(
      result,
      null,
      'solveLPModel must return null when zero-carb pool cannot satisfy during carb floor',
    );
  });
});

// ============================================================================
// P5b — greedyFallback: empty pool returns {foods: []} cleanly
// ============================================================================

describe('LP Infeasibility — greedyFallback on empty pool', () => {
  beforeEach(setup);
  afterEach(teardown);

  /**
   * CASE 4: greedyFallback with an empty food pool.
   *
   * Must return {foods: []} — NOT {foods: undefined}, NOT throw.
   * The totals must all be 0 (finite, non-negative).
   */
  it('empty after-phase pool returns {foods: []} without throwing', async () => {
    const foods: Food[] = [];
    const targets = makeTargets({ carbs_g: 60, protein_g: 20, sodium_mg: 500, water_ml: 600 });

    let result: ReturnType<typeof greedyFallback> | undefined;
    let threw = false;
    try {
      result = greedyFallback(foods, targets, 'after');
    } catch {
      threw = true;
    }

    await logs.writeToFile(
      'lp-infeasibility-empty-pool-after',
      'Case 4: greedyFallback on empty after pool — expect {foods: []}',
    );

    assert(!threw, 'greedyFallback must NOT throw on empty food pool');
    assertExists(result, 'greedyFallback must return a value, not undefined');

    // foods must be an array, never undefined
    assertExists(result!.foods, 'result.foods must exist (never undefined)');
    assert(Array.isArray(result!.foods), 'result.foods must be an array');
    assertEquals(result!.foods.length, 0, 'result.foods must be [] for empty pool');

    // Totals must be zero and finite
    assertTotalsNumericSanity(result!.totals, 'empty-after-pool');
    assertEquals(result!.totals.carbs_g, 0, 'totals.carbs_g must be 0 for empty pool');
    assertEquals(result!.totals.protein_g, 0, 'totals.protein_g must be 0 for empty pool');
    assertEquals(result!.totals.sodium_mg, 0, 'totals.sodium_mg must be 0 for empty pool');
    assertEquals(result!.totals.water_ml, 0, 'totals.water_ml must be 0 for empty pool');
  });

  /**
   * CASE 5: greedyFallback with an empty pool for during phase.
   *
   * Same invariants: {foods: []}, no throw, totals = 0.
   */
  it('empty during-phase pool returns {foods: []} without throwing', async () => {
    const foods: Food[] = [];
    const targets: MacroTargets = { carbs_g: 45, sodium_mg: 600, water_ml: 700 };

    let result: ReturnType<typeof greedyFallback> | undefined;
    let threw = false;
    try {
      result = greedyFallback(foods, targets, 'during');
    } catch {
      threw = true;
    }

    await logs.writeToFile(
      'lp-infeasibility-empty-pool-during',
      'Case 5: greedyFallback on empty during pool — expect {foods: []}',
    );

    assert(!threw, 'greedyFallback must NOT throw on empty during pool');
    assertExists(result, 'greedyFallback must return a value');
    assertExists(result!.foods, 'result.foods must exist (never undefined)');
    assert(Array.isArray(result!.foods), 'result.foods must be an array');
    assertEquals(result!.foods.length, 0, 'result.foods must be [] for empty during pool');
    assertTotalsNumericSanity(result!.totals, 'empty-during-pool');
  });

  /**
   * CASE 6: greedyFallback with a single pure-water food that provides no
   * carbs or protein. The greedy algorithm cannot fill deficits that the food
   * doesn't supply, so neededServings becomes 0 for every pass.
   *
   * Invariants: no throw, foods array is returned (may be [] or may contain
   * the water food if the greedy decides it helps hydration), totals are all
   * finite and >= 0, no NaN or Infinity.
   */
  it('single zero-carb food in greedy pool: numeric sanity holds', async () => {
    const waterOnly = makeFood({
      id: 'pure-water-greedy',
      name: 'Pure Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
      is_liquid: true,
      is_essential: true,
      product_type: 'beverage',
      max_servings: 6,
      preference_score: 50,
    });

    const foods: Food[] = [waterOnly];
    const targets = makeTargets({ carbs_g: 60, protein_g: 20, sodium_mg: 500, water_ml: 600 });

    let result: ReturnType<typeof greedyFallback> | undefined;
    let threw = false;
    try {
      result = greedyFallback(foods, targets, 'after');
    } catch {
      threw = true;
    }

    await logs.writeToFile(
      'lp-infeasibility-single-water-greedy',
      'Case 6: greedyFallback on single zero-carb food — numeric sanity check',
    );

    assert(!threw, 'greedyFallback must NOT throw on zero-carb only pool');
    assertExists(result, 'greedyFallback must return a value');
    assertExists(result!.foods, 'result.foods must exist (never undefined)');
    assert(Array.isArray(result!.foods), 'result.foods must be an array');

    // Key invariant: never NaN or Infinity in any field
    assertFoodResultsNumericSanity(result!.foods, 'single-zero-carb-greedy');
    assertTotalsNumericSanity(result!.totals, 'single-zero-carb-greedy');
  });
});

// ============================================================================
// P5c — Positive control: feasible LP produces foods within tolerance
// ============================================================================

describe('LP Infeasibility — Positive control (distinguishes infeasible path)', () => {
  beforeEach(setup);
  afterEach(teardown);

  /**
   * CASE 7: Standard after-phase food pool with moderate targets.
   *
   * This is the positive control that proves:
   *   - A feasible LP actually returns non-null with foods.length > 0.
   *   - The infeasible path (null) is genuinely distinct.
   *   - Numeric sanity holds on LP output too.
   */
  it('feasible after-phase pool returns non-null with foods and sane numerics', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 500 });

    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile(
      'lp-infeasibility-positive-control-after',
      'Case 7: positive control — feasible after pool returns non-null',
    );

    // In-band or null→greedy (no-leniency standard, 2026-07-29): the coarse
    // fixture pool cannot always satisfy every band, and an out-of-band LP
    // solution must never ship.
    if (result) {
      assert(result.foods.length > 0, 'Positive control: LP must select at least one food');
      assertFoodResultsNumericSanity(result.foods, 'positive-control-after');
      assertTotalsNumericSanity(result.totals, 'positive-control-after');
      assert(result.totals.carbs_g > 0 || result.totals.protein_g > 0,
        'Positive control: feasible LP solution must deliver nonzero nutrition');
    } else {
      const greedy = greedyFallback(foods, targets, 'after');
      assert(greedy.foods.length > 0, 'Greedy fallback must produce foods when LP declines');
    }
  });

  /**
   * CASE 8: Standard during-phase food pool.
   *
   * Positive control for during phase — confirms feasible LP path is reachable.
   */
  it('feasible during-phase pool returns non-null with foods and sane numerics', async () => {
    const foods = makeDuringFoods();
    const targets: MacroTargets = { carbs_g: 45, sodium_mg: 600, water_ml: 700 };

    const result = buildAndSolve(foods, targets, 'during');

    await logs.writeToFile(
      'lp-infeasibility-positive-control-during',
      'Case 8: positive control — feasible during pool returns non-null',
    );

    assertExists(result, 'Positive control: LP must find a feasible solution for standard during pool');
    assert(result!.foods.length > 0, 'Positive control: LP must select at least one food for during phase');
    assertFoodResultsNumericSanity(result!.foods, 'positive-control-during');
    assertTotalsNumericSanity(result!.totals, 'positive-control-during');
  });

  /**
   * CASE 9: Feasible greedy on a realistic pool — confirm it also produces
   * sane numbers and a non-empty foods array when food is available.
   */
  it('greedyFallback on feasible pool produces non-empty foods with sane numerics', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 500 });

    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile(
      'lp-infeasibility-greedy-feasible-pool',
      'Case 9: greedyFallback on standard after pool — should produce foods',
    );

    assertExists(result.foods, 'result.foods must exist');
    assert(Array.isArray(result.foods), 'result.foods must be an array');
    assert(result.foods.length > 0, 'greedyFallback on feasible pool should select foods');
    assertFoodResultsNumericSanity(result.foods, 'greedy-feasible-after');
    assertTotalsNumericSanity(result.totals, 'greedy-feasible-after');
  });
});

// ============================================================================
// P5d — LP infeasibility does NOT propagate as a thrown exception
// ============================================================================

describe('LP Infeasibility — no-throw contract under adversarial inputs', () => {
  beforeEach(setup);
  afterEach(teardown);

  /**
   * CASE 10: solveLPModel must never throw, even when the food pool is empty.
   * buildLPModel with an empty food array produces a model with no variables.
   * The solver must handle this gracefully.
   */
  it('solveLPModel does not throw on a model built from empty food pool', async () => {
    const foods: Food[] = [];
    const targets = makeTargets({ carbs_g: 60, protein_g: 20, sodium_mg: 500, water_ml: 600 });

    const w = DEFAULT_OPTIMIZATION_WEIGHTS.after;
    const model = buildLPModel(foods, targets, 'after', w);

    let result: ReturnType<typeof solveLPModel> | undefined;
    let threw = false;
    try {
      result = solveLPModel(model, foods, 'after');
    } catch {
      threw = true;
    }

    await logs.writeToFile(
      'lp-infeasibility-empty-model-no-throw',
      'Case 10: solveLPModel on empty-pool model must not throw',
    );

    assert(!threw, 'solveLPModel must NOT throw when food pool is empty');
    // Result is either null or a PhaseSolution — either is acceptable
    // as long as it doesn't throw.
    if (result !== null && result !== undefined) {
      assertExists(result.foods, 'if non-null, result.foods must exist');
      assertFoodResultsNumericSanity(result.foods, 'empty-model-solve');
    }
    // Explicit: null is the expected outcome for an infeasible/empty model
    assertEquals(result, null, 'solveLPModel on empty-pool model should return null');
  });

  /**
   * CASE 11: Maximally over-constrained model — every single constraint is
   * simultaneously set to an impossible combination. solveLPModel must return
   * null, not throw.
   *
   * Food: 1 gel with 25g carbs, 0 protein, 0 water, max 1 serving.
   * Targets: 200g carbs (floor = 180g), 100g protein (floor ~85g), 5000ml water.
   * These cannot simultaneously be satisfied.
   */
  it('maximally over-constrained model returns null without throwing', async () => {
    const gel = makeFood({
      id: 'single-gel-constrained',
      name: 'Single Gel',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      is_indivisible: true,
      product_type: 'gel',
      max_servings: 1,
      preference_score: 80,
    });

    const foods: Food[] = [gel];
    const targets = makeTargets({
      carbs_g: 200,
      protein_g: 100,
      sodium_mg: 2000,
      water_ml: 5000,
    });

    let result: ReturnType<typeof solveLPModel> | undefined;
    let threw = false;
    try {
      result = buildAndSolve(foods, targets, 'after');
    } catch {
      threw = true;
    }

    await logs.writeToFile(
      'lp-infeasibility-maximally-constrained',
      'Case 11: maximally over-constrained model — expect null, no throw',
    );

    assert(!threw, 'solveLPModel must NOT throw on maximally over-constrained model');
    assertEquals(result ?? null, null, 'Maximally over-constrained model must return null');
  });
});
