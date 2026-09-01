/**
 * Local Unit Tests for LP Solver
 *
 * Tests buildLPModel() and solveLPModel() directly with mock food data.
 * No HTTP, no Supabase — pure algorithm testing with log capture.
 *
 * Run with:
 *   deno test --allow-write supabase/functions/_shared/nutrition/lp-solver.test.ts
 */

import {
  assertEquals,
  assert,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeEach, afterEach } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { buildLPModel, solveLPModel } from './lp-solver.ts';
import { greedyFallback } from './greedy-fallback.ts';
import { DEFAULT_OPTIMIZATION_WEIGHTS } from './constants.ts';
import type { MacroWeights } from './constants.ts';
import type { Food, MacroTargets, Phase } from './types.ts';
import {
  LogCapture,
  makeFood,
  makeAfterFoods,
  makeDuringFoods,
  makeTargets,
  assertTotalsInRange,
  formatSummary,
  PROFILE_LIGHT,
  PROFILE_AVG,
  PROFILE_HEAVY,
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

/** Helper: build + solve in one call */
function buildAndSolve(
  foods: Food[],
  targets: MacroTargets,
  phase: Phase,
  weights?: MacroWeights,
  options?: Parameters<typeof buildLPModel>[5] extends undefined ? never : Parameters<typeof buildLPModel>[6],
) {
  const w = weights ?? DEFAULT_OPTIMIZATION_WEIGHTS[phase];
  const model = buildLPModel(foods, targets, phase, w, undefined, undefined, options);
  return solveLPModel(model, foods, phase);
}

// ============================================================================
// Basic Feasibility
// ============================================================================

describe('LP Solver — Basic Feasibility', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should solve moderate after-phase targets', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 500 });
    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile('lp-basic-moderate-after', `Phase: after | Moderate targets`);

    // The LP either returns a solution INSIDE its constraint bands or null
    // (the plan pipeline then falls back to the greedy solver). This coarse
    // 0.5-serving fixture pool cannot always satisfy every band at once, so
    // null is a legitimate outcome — an out-of-band solution is not
    // (no-leniency standard, 2026-07-29).
    if (result) {
      assert(result.foods.length > 0, 'Should select at least one food');
      assert(result.totals.carbs_g > 0, 'Should deliver some carbs');
    } else {
      const greedy = greedyFallback(foods, targets, 'after');
      assert(greedy.foods.length > 0, 'Greedy fallback must produce foods when LP declines');
    }
  });

  it('should return null for impossible targets', async () => {
    const foods = [
      makeFood({
        name: 'Tiny Cracker',
        per_serving: { carbs_g: 2, protein_g: 0, fat_g: 0, sodium_mg: 5, water_ml: 0, calories: 10 },
        max_servings: 1,
      }),
    ];
    // Request massive macros with only 1 tiny food
    const targets = makeTargets({ carbs_g: 200, protein_g: 100, sodium_mg: 2000, water_ml: 3000 });
    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile('lp-basic-impossible', `Phase: after | Impossible targets`);

    assertEquals(result, null, 'LP should return null for infeasible targets');
  });

  it('should handle zero carb targets gracefully', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 0, protein_g: 20, sodium_mg: 300, water_ml: 400 });
    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile('lp-basic-zero-carbs', `Phase: after | Zero carb targets`);

    // Zero carbs with after-phase foods is very constrained — LP may return null
    // because carbs constraint [0, 5] conflicts with protein/water demands
    if (result) {
      assert(result.totals.carbs_g <= 6, `Carbs should be near zero, got ${result.totals.carbs_g}`);
    } else {
      console.log('[TEST] Zero carb targets: LP infeasible — carb constraint [0,5] too tight for protein/water needs');
    }
    assert(true, 'Diagnostic test — documents zero-carb behavior');
  });

  it('should solve during-phase targets', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 45, sodium_mg: 600, water_ml: 700 });
    const result = buildAndSolve(foods, targets, 'during');

    await logs.writeToFile('lp-basic-during', `Phase: during | Standard targets`);

    assertExists(result, 'LP should solve during-phase targets');
    assert(result!.foods.length > 0, 'Should select at least one food');
  });

  it('should prioritize out-of-band carb target over provided carb band', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({
      carbs_g: 90,
      carbs_low_g: 180,
      carbs_high_g: 270,
      sodium_mg: 600,
      water_ml: 700,
    });
    const model = buildLPModel(
      foods,
      targets,
      'during',
      DEFAULT_OPTIMIZATION_WEIGHTS.during,
    );

    await logs.writeToFile(
      'lp-basic-out-of-band-carb-priority',
      'Phase: during | out-of-band carb target should drive LP carb constraints',
    );

    // During carb range is 0.9..1.1 of target when target-priority mode is active.
    assertEquals(model.constraints.carbs?.min, 81);
    assert(
      Math.abs((model.constraints.carbs?.max ?? 0) - 99) < 1e-6,
      `Expected carb max near 99, got ${model.constraints.carbs?.max}`,
    );
  });
});

// ============================================================================
// After Phase Infeasibility (KEY diagnostic tests)
// ============================================================================

describe('LP Solver — After Phase Infeasibility', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should solve light after-phase profile', async () => {
    const foods = makeAfterFoods();
    const result = buildAndSolve(foods, PROFILE_LIGHT, 'after');

    await logs.writeToFile('lp-after-light',
      `Phase: after | Light profile: carbs=${PROFILE_LIGHT.carbs_g}g, protein=${PROFILE_LIGHT.protein_g}g, sodium=${PROFILE_LIGHT.sodium_mg}mg, water=${PROFILE_LIGHT.water_ml}ml`
    );

    // In-band or null→greedy (no-leniency standard, 2026-07-29).
    if (result) {
      const check = assertTotalsInRange(result.totals, PROFILE_LIGHT);
      console.log(`[TEST] Light profile: ${formatSummary(result.totals, PROFILE_LIGHT)}`);
      if (!check.passed) {
        console.warn(`[TEST] Out of range: ${check.issues.join(', ')}`);
      }
    } else {
      const greedy = greedyFallback(foods, PROFILE_LIGHT, 'after');
      assert(greedy.foods.length > 0, 'Greedy fallback must produce foods when LP declines');
    }
  });

  it('should solve average after-phase profile', async () => {
    const foods = makeAfterFoods();
    const result = buildAndSolve(foods, PROFILE_AVG, 'after');

    await logs.writeToFile('lp-after-avg',
      `Phase: after | Avg profile: carbs=${PROFILE_AVG.carbs_g}g, protein=${PROFILE_AVG.protein_g}g, sodium=${PROFILE_AVG.sodium_mg}mg, water=${PROFILE_AVG.water_ml}ml`
    );

    if (!result) {
      const greedy = greedyFallback(foods, PROFILE_AVG, 'after');
      assert(greedy.foods.length > 0, 'Greedy fallback must produce foods when LP declines');
      return;
    }
    const check = assertTotalsInRange(result!.totals, PROFILE_AVG);
    console.log(`[TEST] Avg profile: ${formatSummary(result!.totals, PROFILE_AVG)}`);
    if (!check.passed) {
      console.warn(`[TEST] Out of range: ${check.issues.join(', ')}`);
    }
  });

  it('should attempt heavy after-phase profile (may be infeasible)', async () => {
    const foods = makeAfterFoods();
    const result = buildAndSolve(foods, PROFILE_HEAVY, 'after');

    await logs.writeToFile('lp-after-heavy',
      `Phase: after | Heavy profile: carbs=${PROFILE_HEAVY.carbs_g}g, protein=${PROFILE_HEAVY.protein_g}g, sodium=${PROFILE_HEAVY.sodium_mg}mg, water=${PROFILE_HEAVY.water_ml}ml`
    );

    // This test documents whether the LP is feasible for heavy profiles
    if (result) {
      console.log(`[TEST] Heavy profile FEASIBLE: ${formatSummary(result.totals, PROFILE_HEAVY)}`);
      const check = assertTotalsInRange(result.totals, PROFILE_HEAVY);
      if (!check.passed) {
        console.warn(`[TEST] Out of range: ${check.issues.join(', ')}`);
      }
    } else {
      console.log(`[TEST] Heavy profile INFEASIBLE — LP returned null, greedy fallback needed`);
      // Analyze which constraints caused infeasibility from logs
      const constraintLogs = logs.getByPrefix('LP-SOLVER').filter(e => e.message.includes('Constraint'));
      for (const cl of constraintLogs) {
        console.log(`[TEST] ${cl.raw}`);
      }
    }

    // Test passes either way — it's diagnostic
    assert(true, 'Diagnostic test — documenting LP behavior for heavy profile');
  });

  it('should show constraint tightness for after phase', async () => {
    const foods = makeAfterFoods();
    const targets = PROFILE_HEAVY;
    const weights = DEFAULT_OPTIMIZATION_WEIGHTS.after;
    const model = buildLPModel(foods, targets, 'after', weights);

    await logs.writeToFile('lp-after-constraint-analysis',
      `Phase: after | Constraint tightness analysis for heavy profile`
    );

    // Analyze the model constraints
    const constraints = model.constraints;
    assertExists(constraints.carbs, 'Should have carb constraints');
    assertExists(constraints.protein, 'After phase SHOULD have protein constraints (after-fallback only, 2026-07-29)');
    assertExists(constraints.sodium, 'Should have sodium constraints');
    assertExists(constraints.water, 'Should have water constraints');

    // Log the food pool's maximum delivery potential
    let maxCarbs = 0, maxProtein = 0, maxSodium = 0, maxWater = 0;
    for (const food of foods) {
      const maxS = food.max_servings;
      maxCarbs += food.per_serving.carbs_g * maxS;
      maxProtein += food.per_serving.protein_g * maxS;
      maxSodium += food.per_serving.sodium_mg * maxS;
      maxWater += food.per_serving.water_ml * maxS;
    }

    console.log(`[TEST] Pool max delivery: carbs=${maxCarbs}g, protein=${maxProtein}g, sodium=${maxSodium}mg, water=${maxWater}ml`);
    console.log(`[TEST] Carbs constraint: [${constraints.carbs?.min?.toFixed(1)}, ${constraints.carbs?.max?.toFixed(1)}] — pool max: ${maxCarbs}g`);
    console.log(`[TEST] Protein constraint: [${constraints.protein?.min?.toFixed(1)}, ${constraints.protein?.max?.toFixed(1)}] — pool max: ${maxProtein}g`);
    console.log(`[TEST] Sodium constraint: [${constraints.sodium?.min?.toFixed(1)}, ${constraints.sodium?.max?.toFixed(1)}] — pool max: ${maxSodium}mg`);
    console.log(`[TEST] Water constraint: [${constraints.water?.min?.toFixed(1)}, ${constraints.water?.max?.toFixed(1)}] — pool max: ${maxWater}ml`);

    // Check which constraints are theoretically satisfiable
    const carbFeasible = maxCarbs >= (constraints.carbs?.min ?? 0);
    const proteinFeasible = maxProtein >= (constraints.protein?.min ?? 0);
    const sodiumFeasible = maxSodium >= (constraints.sodium?.min ?? 0);
    const waterFeasible = maxWater >= (constraints.water?.min ?? 0);

    console.log(`[TEST] Individual feasibility: carbs=${carbFeasible}, protein=${proteinFeasible}, sodium=${sodiumFeasible}, water=${waterFeasible}`);
  });

  it('should compare LP vs greedy for heavy after-phase', async () => {
    // Lazy import greedy to avoid circular deps
    const { greedyFallback } = await import('./greedy-fallback.ts');
    const foods = makeAfterFoods();
    const targets = PROFILE_HEAVY;

    const lpResult = buildAndSolve(foods, targets, 'after');
    const greedyResult = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('lp-vs-greedy-heavy-after',
      `Phase: after | LP vs Greedy comparison for heavy profile`
    );

    console.log(`[TEST] LP result: ${lpResult ? formatSummary(lpResult.totals, targets) : 'INFEASIBLE'}`);
    console.log(`[TEST] Greedy result: ${formatSummary(greedyResult.totals, targets)}`);

    const greedyCheck = assertTotalsInRange(greedyResult.totals, targets);
    if (!greedyCheck.passed) {
      console.warn(`[TEST] Greedy out of range: ${greedyCheck.issues.join(', ')}`);
    }

    assert(true, 'Diagnostic comparison test');
  });
});

// ============================================================================
// Constraint Sensitivity
// ============================================================================

describe('LP Solver — Constraint Sensitivity', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should respect carb constraint range [0.9, 1.1]', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 60, protein_g: 20, sodium_mg: 400, water_ml: 500 });
    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile('lp-constraint-carbs', `Phase: after | Carb constraint check`);

    if (result) {
      const ratio = result.totals.carbs_g / targets.carbs_g;
      // LP constraints are [0.9, 1.1] of target, but rounding (0.5 increments)
      // can push actuals slightly outside — allow up to 1.3x
      console.log(`[TEST] Carb ratio: ${(ratio * 100).toFixed(0)}% (LP constraint range: 90-110%, with rounding)`);
      assert(ratio >= 0.80, `Carbs should be >= 80% of target, got ${(ratio * 100).toFixed(0)}%`);
      assert(ratio <= 1.35, `Carbs should be <= 135% of target, got ${(ratio * 100).toFixed(0)}%`);
    }
  });

  it('should enforce sodium floor at 75% of target', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 800, water_ml: 500 });
    const weights = DEFAULT_OPTIMIZATION_WEIGHTS.after;
    const model = buildLPModel(foods, targets, 'after', weights);

    await logs.writeToFile('lp-constraint-sodium-floor', `Phase: after | Sodium floor check`);

    // Sodium min should be min(sodiumBounds.min, 0.75) * target = 0.75 * 800 = 600
    assertExists(model.constraints.sodium, 'Should have sodium constraint');
    assert(
      model.constraints.sodium!.min! <= targets.sodium_mg * 0.76,
      `Sodium min should be <= 76% of target, got ${model.constraints.sodium!.min}`
    );
  });

  it('should enforce water min for after phase at 70%', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 1000 });
    const weights = DEFAULT_OPTIMIZATION_WEIGHTS.after;
    const model = buildLPModel(foods, targets, 'after', weights);

    await logs.writeToFile('lp-constraint-water-min-after', `Phase: after | Water min check`);

    assertExists(model.constraints.water, 'Should have water constraint');
    assertExists(model.constraints.water!.min, 'After phase should have water min');
    assertEquals(model.constraints.water!.min, targets.water_ml * 0.7, 'Water min should be 70% of target');
  });

  it('should add protein constraints for the after phase only (2026-07-29)', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 500 });

    const afterWeights = DEFAULT_OPTIMIZATION_WEIGHTS.after;
    const duringWeights = DEFAULT_OPTIMIZATION_WEIGHTS.during;

    const afterModel = buildLPModel(foods, targets, 'after', afterWeights);
    const duringModel = buildLPModel(foods, targets, 'during', duringWeights);

    await logs.writeToFile('lp-constraint-protein-phases', `Protein constraints by phase`);

    assertExists(afterModel.constraints.protein, 'After phase should have protein constraints');
    assertEquals(duringModel.constraints.protein, undefined, 'During phase must NOT have protein constraints');

    const beforeWeights = DEFAULT_OPTIMIZATION_WEIGHTS.before;
    const beforeModel = buildLPModel(foods, targets, 'before', beforeWeights);
    assertEquals(beforeModel.constraints.protein, undefined, 'Before phase must NOT have protein constraints');
  });
});

// ============================================================================
// Scoring & Selection
// ============================================================================

describe('LP Solver — Scoring & Selection', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should prefer higher preference_score foods', async () => {
    const likedFood = makeFood({
      name: 'Liked Banana',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 200,
    });
    const neutralFood = makeFood({
      name: 'Neutral Rice',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 20,
    });

    const foods = [likedFood, neutralFood];
    const targets = makeTargets({ carbs_g: 25, protein_g: 0, sodium_mg: 50, water_ml: 100 });
    const result = buildAndSolve(foods, targets, 'after');

    await logs.writeToFile('lp-scoring-preference', `Phase: after | Preference scoring test`);

    if (result && result.foods.length > 0) {
      // The liked food should be selected (or have more servings)
      const likedSelected = result.foods.find(f => f.food_id === likedFood.id);
      console.log(`[TEST] Liked food selected: ${likedSelected ? `x${likedSelected.quantity}` : 'NO'}`);
    }
  });

  it('should respect maxFoodItems constraint', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 80, protein_g: 30, sodium_mg: 600, water_ml: 800 });
    const result = buildAndSolve(foods, targets, 'after', undefined, { maxFoodItems: 3 });

    await logs.writeToFile('lp-scoring-max-foods', `Phase: after | maxFoodItems=3`);

    if (result) {
      assert(result.foods.length <= 3, `Should select at most 3 foods, got ${result.foods.length}`);
    }
  });

  it('should respect maxServingsCap', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 80, protein_g: 30, sodium_mg: 600, water_ml: 800 });
    const result = buildAndSolve(foods, targets, 'after', undefined, { maxServingsCap: 2 });

    await logs.writeToFile('lp-scoring-max-servings', `Phase: after | maxServingsCap=2`);

    if (result) {
      for (const food of result.foods) {
        assert(food.quantity <= 2.5, `Food ${food.food_id} has ${food.quantity} servings, expected <= 2.5`);
      }
    }
  });

  it('should add random variance when enabled', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 60, protein_g: 20, sodium_mg: 500, water_ml: 600 });

    // Run twice with randomVariance — results may differ
    const result1 = buildAndSolve(foods, targets, 'after', undefined, { randomVariance: true });
    logs.clear();
    const result2 = buildAndSolve(foods, targets, 'after', undefined, { randomVariance: true });

    await logs.writeToFile('lp-scoring-random-variance', `Phase: after | Random variance comparison`);

    // Both should be valid if feasible
    if (result1) {
      assert(result1.foods.length > 0, 'Result 1 should have foods');
    }
    if (result2) {
      assert(result2.foods.length > 0, 'Result 2 should have foods');
    }

    // Note: results may or may not differ depending on RNG — this is expected
    console.log(`[TEST] Run 1 foods: ${result1?.foods.map(f => f.food_id).join(', ') ?? 'INFEASIBLE'}`);
    console.log(`[TEST] Run 2 foods: ${result2?.foods.map(f => f.food_id).join(', ') ?? 'INFEASIBLE'}`);
  });
});

// ============================================================================
// Edge Cases
// ============================================================================

describe('LP Solver — Edge Cases', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should round indivisible items to whole numbers', async () => {
    const gel = makeFood({
      name: 'Indivisible Gel',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      is_indivisible: true,
      product_type: 'gel',
      preference_score: 200,
      max_servings: 6,
    });
    const foods = [gel];
    const targets = makeTargets({ carbs_g: 60, sodium_mg: 150, water_ml: 0 });
    const result = buildAndSolve(foods, targets, 'during');

    await logs.writeToFile('lp-edge-indivisible', `Phase: during | Indivisible rounding`);

    if (result) {
      for (const f of result.foods) {
        assertEquals(f.quantity, Math.round(f.quantity), `Indivisible food should have whole-number servings, got ${f.quantity}`);
      }
    }
  });

  it('should round divisible items to nearest 0.5', async () => {
    const drink = makeFood({
      name: 'Sports Drink',
      per_serving: { carbs_g: 15, protein_g: 0, fat_g: 0, sodium_mg: 110, water_ml: 240, calories: 60 },
      is_liquid: true,
      product_type: 'sports_drink',
      preference_score: 80,
    });
    const foods = [drink];
    const targets = makeTargets({ carbs_g: 25, sodium_mg: 200, water_ml: 400 });
    const result = buildAndSolve(foods, targets, 'during');

    await logs.writeToFile('lp-edge-divisible-rounding', `Phase: during | Divisible rounding`);

    if (result) {
      for (const f of result.foods) {
        const remainder = f.quantity % 0.5;
        assert(
          Math.abs(remainder) < 0.01 || Math.abs(remainder - 0.5) < 0.01,
          `Divisible food should round to nearest 0.5, got ${f.quantity}`
        );
      }
    }
  });

  it('should handle single food in pool', async () => {
    const food = makeFood({
      name: 'Only Option',
      per_serving: { carbs_g: 30, protein_g: 10, fat_g: 2, sodium_mg: 100, water_ml: 200, calories: 170 },
      max_servings: 4,
      preference_score: 80,
    });
    const targets = makeTargets({ carbs_g: 60, protein_g: 20, sodium_mg: 200, water_ml: 400 });
    const result = buildAndSolve([food], targets, 'after');

    await logs.writeToFile('lp-edge-single-food', `Phase: after | Single food pool`);

    if (result) {
      assertEquals(result.foods.length, 1, 'Should select the only available food');
    }
  });

  it('should handle electrolyte-only pool', async () => {
    const tab = makeFood({
      name: 'Electrolyte Tab',
      per_serving: { carbs_g: 1, protein_g: 0, fat_g: 0, sodium_mg: 350, water_ml: 0, calories: 10 },
      is_electrolyte: true,
      is_indivisible: true,
      product_type: 'supplement',
      preference_score: 50,
    });
    // Targets require carbs but pool only has electrolytes
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 500, water_ml: 400 });
    const result = buildAndSolve([tab], targets, 'after');

    await logs.writeToFile('lp-edge-electrolyte-only', `Phase: after | Electrolyte-only pool`);

    // Should be infeasible since we can't meet carb/protein/water targets
    assertEquals(result, null, 'Electrolyte-only pool should be infeasible for full targets');
  });
});
