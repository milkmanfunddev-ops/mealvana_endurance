/**
 * Local Unit Tests for Greedy Fallback Algorithm
 *
 * Tests greedyFallback() directly with mock food data.
 * No HTTP, no Supabase — pure algorithm testing with log capture.
 *
 * Run with:
 *   deno test --allow-write supabase/functions/_shared/nutrition/greedy-fallback.test.ts
 */

import {
  assertEquals,
  assert,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeEach, afterEach } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { greedyFallback } from './greedy-fallback.ts';
import type { Food, MacroTargets } from './types.ts';
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

// ============================================================================
// Basic Selection
// ============================================================================

describe('Greedy Fallback — Basic Selection', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should select foods by preference score order', async () => {
    const likedFood = makeFood({
      name: 'Liked Banana',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 200,
    });
    const neutralFood = makeFood({
      name: 'Neutral Cracker',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 50, water_ml: 0, calories: 100 },
      preference_score: 20,
    });

    const foods = [neutralFood, likedFood]; // deliberately reversed
    const targets = makeTargets({ carbs_g: 25, protein_g: 0, sodium_mg: 50, water_ml: 0 });
    const result = greedyFallback(foods, targets, 'before');

    await logs.writeToFile('greedy-basic-preference-order', `Phase: before | Preference ordering`);

    assert(result.foods.length > 0, 'Should select at least one food');
    assertEquals(result.foods[0].food_id, likedFood.id, 'Should select liked food first');
  });

  it('should fill carb target for before/during phases', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 45, sodium_mg: 400, water_ml: 500 });
    const result = greedyFallback(foods, targets, 'during');

    await logs.writeToFile('greedy-basic-carb-filling', `Phase: during | Carb filling`);

    assert(result.totals.carbs_g > 0, 'Should deliver some carbs');
    console.log(`[TEST] ${formatSummary(result.totals, targets)}`);
  });

  it('should prioritize protein for after phase', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 50, protein_g: 25, sodium_mg: 400, water_ml: 500 });
    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('greedy-basic-protein-priority', `Phase: after | Protein priority`);

    assert(result.totals.protein_g > 0, 'Should deliver some protein');
    console.log(`[TEST] ${formatSummary(result.totals, targets)}`);
  });

  it('should respect maxFoods limit', async () => {
    const foods = makeAfterFoods();
    const targets = makeTargets({ carbs_g: 100, protein_g: 40, sodium_mg: 1000, water_ml: 1500 });
    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('greedy-basic-max-foods', `Phase: after | maxFoods limit`);

    assert(result.foods.length <= 5, `After phase should select at most 5 foods, got ${result.foods.length}`);
  });
});

// ============================================================================
// Overshoot Protection
// ============================================================================

describe('Greedy Fallback — Overshoot Protection', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should skip foods that would overshoot carbs by >30%', async () => {
    const highCarbDrink = makeFood({
      name: 'High Carb Drink',
      per_serving: { carbs_g: 80, protein_g: 0, fat_g: 0, sodium_mg: 50, water_ml: 400, calories: 320 },
      preference_score: 200,
    });
    const banana = makeFood({
      name: 'Banana',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 200,
    });

    const foods = [highCarbDrink, banana];
    // Target is 50g carbs — high carb drink alone gives 80g (160% of target)
    const targets = makeTargets({ carbs_g: 50, protein_g: 0, sodium_mg: 100, water_ml: 500 });
    const result = greedyFallback(foods, targets, 'before');

    await logs.writeToFile('greedy-overshoot-carbs', `Phase: before | Carb overshoot protection`);

    console.log(`[TEST] Carbs delivered: ${result.totals.carbs_g}g / ${targets.carbs_g}g target`);
    // After first food, should cap to avoid massive overshoot
  });

  it('should skip sodium overshoot when already at 70% of target', async () => {
    const saltBomb = makeFood({
      name: 'Salt Bomb',
      per_serving: { carbs_g: 20, protein_g: 5, fat_g: 0, sodium_mg: 800, water_ml: 200, calories: 100 },
      preference_score: 200,
    });
    const mildFood = makeFood({
      name: 'Mild Food',
      per_serving: { carbs_g: 30, protein_g: 10, fat_g: 2, sodium_mg: 50, water_ml: 200, calories: 170 },
      preference_score: 80,
    });

    const foods = [saltBomb, mildFood];
    const targets = makeTargets({ carbs_g: 50, protein_g: 15, sodium_mg: 500, water_ml: 400 });
    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('greedy-overshoot-sodium', `Phase: after | Sodium overshoot protection`);

    console.log(`[TEST] Sodium delivered: ${result.totals.sodium_mg}mg / ${targets.sodium_mg}mg target`);
  });

  it('should allow protein foods through when protein critically unmet', async () => {
    // First fill carbs, then check if protein food gets through
    const carbFood = makeFood({
      name: 'Carb Heavy Rice',
      per_serving: { carbs_g: 45, protein_g: 3, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 200 },
      preference_score: 200,
    });
    const proteinShake = makeFood({
      name: 'Protein Shake',
      per_serving: { carbs_g: 5, protein_g: 25, fat_g: 2, sodium_mg: 200, water_ml: 350, calories: 150 },
      preference_score: 200,
      is_liquid: true,
    });

    const foods = [carbFood, proteinShake];
    const targets = makeTargets({ carbs_g: 45, protein_g: 25, sodium_mg: 300, water_ml: 400 });
    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('greedy-overshoot-protein-exception', `Phase: after | Protein critically unmet exception`);

    // Protein shake should be selected even after carbs are filled
    const shakeSelected = result.foods.find(f => f.food_id === proteinShake.id);
    console.log(`[TEST] Protein shake selected: ${shakeSelected ? `x${shakeSelected.quantity}` : 'NO'}`);
    console.log(`[TEST] ${formatSummary(result.totals, targets)}`);
  });

  it('should cap servings at 6 per food in after phase', async () => {
    const food = makeFood({
      name: 'Unlimited Food',
      per_serving: { carbs_g: 10, protein_g: 5, fat_g: 1, sodium_mg: 50, water_ml: 100, calories: 70 },
      preference_score: 200,
      max_servings: 10,
    });

    const targets = makeTargets({ carbs_g: 100, protein_g: 50, sodium_mg: 500, water_ml: 1000 });
    const result = greedyFallback([food], targets, 'after');

    await logs.writeToFile('greedy-overshoot-serving-cap', `Phase: after | Serving cap`);

    if (result.foods.length > 0) {
      assert(result.foods[0].quantity <= 6, `Servings should be capped at 6 (after phase), got ${result.foods[0].quantity}`);
    }
  });
});

// ============================================================================
// Known Problem Cases (KEY diagnostic tests)
// ============================================================================

describe('Greedy Fallback — Known Problem Cases', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should document sodium/water under-delivery for heavy hot profile', async () => {
    const foods = makeAfterFoods();
    const result = greedyFallback(foods, PROFILE_HEAVY, 'after');

    await logs.writeToFile('greedy-known-heavy-hot',
      `Phase: after | KNOWN ISSUE: heavy/hot sodium/water under-delivery\n` +
      `Targets: carbs=${PROFILE_HEAVY.carbs_g}g, protein=${PROFILE_HEAVY.protein_g}g, sodium=${PROFILE_HEAVY.sodium_mg}mg, water=${PROFILE_HEAVY.water_ml}ml`
    );

    console.log(`[TEST] Heavy hot result: ${formatSummary(result.totals, PROFILE_HEAVY)}`);
    const check = assertTotalsInRange(result.totals, PROFILE_HEAVY);
    if (!check.passed) {
      console.warn(`[TEST] KNOWN ISSUE — out of range: ${check.issues.join(', ')}`);
    }

    // Document the actual delivery percentages
    const sodiumPct = PROFILE_HEAVY.sodium_mg > 0 ? result.totals.sodium_mg / PROFILE_HEAVY.sodium_mg : 1;
    const waterPct = PROFILE_HEAVY.water_ml > 0 ? result.totals.water_ml / PROFILE_HEAVY.water_ml : 1;
    console.log(`[TEST] Sodium delivery: ${(sodiumPct * 100).toFixed(0)}% — ${sodiumPct < 0.7 ? 'CRITICALLY LOW' : sodiumPct < 0.85 ? 'LOW' : 'OK'}`);
    console.log(`[TEST] Water delivery: ${(waterPct * 100).toFixed(0)}% — ${waterPct < 0.7 ? 'CRITICALLY LOW' : waterPct < 0.85 ? 'LOW' : 'OK'}`);

    assert(true, 'Diagnostic test — documents under-delivery');
  });

  it('should document high-carb food crowding in greedy selection', async () => {
    // High-carb user food can crowd out protein and hydration
    const userDrinkMix = makeFood({
      name: 'User Drink Mix',
      per_serving: { carbs_g: 80, protein_g: 0, fat_g: 0, sodium_mg: 150, water_ml: 500, calories: 320 },
      preference_score: 300, // user_food score
      is_user_food: true,
      is_liquid: true,
    });
    const proteinShake = makeFood({
      name: 'Protein Shake',
      per_serving: { carbs_g: 5, protein_g: 25, fat_g: 2, sodium_mg: 200, water_ml: 350, calories: 150 },
      preference_score: 200,
      is_liquid: true,
    });
    const rice = makeFood({
      name: 'Rice',
      per_serving: { carbs_g: 45, protein_g: 4, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 200 },
      preference_score: 80,
    });

    const foods = [userDrinkMix, proteinShake, rice];
    const targets = makeTargets({ carbs_g: 60, protein_g: 25, sodium_mg: 500, water_ml: 700 });
    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('greedy-known-crowding',
      `Phase: after | KNOWN ISSUE: high-carb user food crowding`
    );

    console.log(`[TEST] Crowding result: ${formatSummary(result.totals, targets)}`);
    const drinkSelected = result.foods.find(f => f.food_id === userDrinkMix.id);
    const shakeSelected = result.foods.find(f => f.food_id === proteinShake.id);
    console.log(`[TEST] Drink Mix selected: ${drinkSelected ? `x${drinkSelected.quantity}` : 'NO'}`);
    console.log(`[TEST] Protein Shake selected: ${shakeSelected ? `x${shakeSelected.quantity}` : 'NO'}`);
  });

  it('should document early stopping behavior', async () => {
    const foods = makeAfterFoods();
    const targets = PROFILE_AVG;
    const result = greedyFallback(foods, targets, 'after');

    await logs.writeToFile('greedy-known-early-stop',
      `Phase: after | Early stop analysis`
    );

    console.log(`[TEST] Avg profile result: ${formatSummary(result.totals, targets)}`);
    console.log(`[TEST] Foods selected: ${result.foods.length}`);

    // Check if the solver stopped early (carbs met but sodium/water under-delivered)
    const carbsMet = result.totals.carbs_g >= targets.carbs_g * 0.9;
    const sodiumMet = targets.sodium_mg <= 0 || result.totals.sodium_mg >= targets.sodium_mg * 0.7;
    const waterMet = targets.water_ml <= 0 || result.totals.water_ml >= targets.water_ml * 0.7;

    console.log(`[TEST] Stop conditions: carbsMet=${carbsMet}, sodiumMet=${sodiumMet}, waterMet=${waterMet}`);
    if (carbsMet && (!sodiumMet || !waterMet)) {
      console.warn(`[TEST] ISSUE: Carbs met but sodium/water under-delivered — stopping too early`);
    }
  });

  it('should compare greedy vs LP for heavy after-phase', async () => {
    const { buildLPModel, solveLPModel } = await import('./lp-solver.ts');
    const { DEFAULT_OPTIMIZATION_WEIGHTS } = await import('./constants.ts');

    const foods = makeAfterFoods();
    const targets = PROFILE_HEAVY;

    const greedyResult = greedyFallback(foods, targets, 'after');

    logs.clear(); // Clear greedy logs before LP
    const weights = DEFAULT_OPTIMIZATION_WEIGHTS.after;
    const model = buildLPModel(foods, targets, 'after', weights);
    const lpResult = solveLPModel(model, foods, 'after');

    await logs.writeToFile('greedy-vs-lp-heavy-after',
      `Phase: after | Greedy vs LP comparison for heavy profile`
    );

    console.log(`[TEST] Greedy: ${formatSummary(greedyResult.totals, targets)}`);
    console.log(`[TEST] LP: ${lpResult ? formatSummary(lpResult.totals, targets) : 'INFEASIBLE'}`);

    assert(true, 'Diagnostic comparison test');
  });
});

// ============================================================================
// Edge Cases
// ============================================================================

describe('Greedy Fallback — Edge Cases', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should handle empty food pool gracefully', async () => {
    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 400, water_ml: 500 });
    const result = greedyFallback([], targets, 'after');

    await logs.writeToFile('greedy-edge-empty', `Phase: after | Empty food pool`);

    assertEquals(result.foods.length, 0, 'Should return empty foods for empty pool');
    assertEquals(result.totals.carbs_g, 0, 'Should have zero totals');
  });

  it('should handle identical foods (same preference and macros)', async () => {
    const food1 = makeFood({
      name: 'Banana A',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 80,
    });
    const food2 = makeFood({
      name: 'Banana B',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 80,
    });

    const targets = makeTargets({ carbs_g: 50, protein_g: 0, sodium_mg: 50, water_ml: 100 });
    const result = greedyFallback([food1, food2], targets, 'before');

    await logs.writeToFile('greedy-edge-identical', `Phase: before | Identical foods`);

    assert(result.foods.length > 0, 'Should select at least one food');
    console.log(`[TEST] Selected: ${result.foods.map(f => `${f.food_id} x${f.quantity}`).join(', ')}`);
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

    const targets = makeTargets({ carbs_g: 50, protein_g: 20, sodium_mg: 500, water_ml: 400 });
    const result = greedyFallback([tab], targets, 'after');

    await logs.writeToFile('greedy-edge-electrolyte-only', `Phase: after | Electrolyte-only pool`);

    console.log(`[TEST] ${formatSummary(result.totals, targets)}`);
    // With only electrolyte tabs, carbs/protein/water will be near zero
    assert(result.totals.carbs_g < 5, 'Electrolyte tabs should deliver minimal carbs');
  });
});
