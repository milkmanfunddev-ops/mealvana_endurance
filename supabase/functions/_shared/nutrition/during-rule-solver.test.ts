/**
 * Local Unit Tests for During-Phase Rule-Based Solver
 *
 * Tests generateDuringPhaseRuleBased() directly with mock food data.
 * No HTTP, no Supabase — pure algorithm testing with log capture.
 *
 * Run with:
 *   deno test --allow-write supabase/functions/_shared/nutrition/during-rule-solver.test.ts
 */

import {
  assertEquals,
  assert,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeEach, afterEach } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { generateDuringPhaseRuleBased } from './during-rule-solver.ts';
import type { Food, MacroTargets } from './types.ts';
import {
  LogCapture,
  makeFood,
  makeDuringFoods,
  makeTargets,
  DURING_STANDARD,
  DURING_MARATHON,
  DURING_SHORT,
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

/** Sum up totals from FoodResult array */
function sumTotals(foods: Array<{ carbs_grams: number; sodium_mg: number; fluids_ml: number; protein_grams: number }>) {
  return foods.reduce(
    (acc, f) => ({
      carbs_g: acc.carbs_g + f.carbs_grams,
      sodium_mg: acc.sodium_mg + f.sodium_mg,
      water_ml: acc.water_ml + f.fluids_ml,
      protein_g: acc.protein_g + f.protein_grams,
    }),
    { carbs_g: 0, sodium_mg: 0, water_ml: 0, protein_g: 0 }
  );
}

// ============================================================================
// Running Scenarios
// ============================================================================

describe('During Rule Solver — Running Scenarios', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should handle standard 10-mile run', async () => {
    const foods = makeDuringFoods();
    const result = generateDuringPhaseRuleBased(foods, DURING_STANDARD, 'running');

    await logs.writeToFile('during-running-standard',
      `Sport: running | Standard 10-mile targets: carbs=${DURING_STANDARD.carbs_g}g, sodium=${DURING_STANDARD.sodium_mg}mg, fluid=${DURING_STANDARD.water_ml}ml`
    );

    assert(result.foods.length > 0, 'Should select at least one food');
    const totals = sumTotals(result.foods);
    console.log(`[TEST] Standard run: carbs=${totals.carbs_g.toFixed(0)}g, sodium=${totals.sodium_mg}mg, fluid=${totals.water_ml}ml`);
  });

  it('should handle short 5K with low carb target', async () => {
    const foods = makeDuringFoods();
    const result = generateDuringPhaseRuleBased(foods, DURING_SHORT, 'running');

    await logs.writeToFile('during-running-short',
      `Sport: running | Short 5K targets: carbs=${DURING_SHORT.carbs_g}g, sodium=${DURING_SHORT.sodium_mg}mg, fluid=${DURING_SHORT.water_ml}ml`
    );

    // With carb target < 15, should skip primary carb entirely
    const totals = sumTotals(result.foods);
    console.log(`[TEST] Short 5K: ${result.foods.length} foods, carbs=${totals.carbs_g.toFixed(0)}g`);
    // Primary carb should be skipped for very low targets
    const hasPrimaryCarb = result.foods.some(f => f.product_type === 'gel' || f.product_type === 'chew' || f.product_type === 'drink_mix');
    console.log(`[TEST] Primary carb selected: ${hasPrimaryCarb}`);
  });

  it('should handle marathon with high carb targets', async () => {
    const foods = makeDuringFoods();
    const result = generateDuringPhaseRuleBased(foods, DURING_MARATHON, 'running');

    await logs.writeToFile('during-running-marathon',
      `Sport: running | Marathon targets: carbs=${DURING_MARATHON.carbs_g}g, sodium=${DURING_MARATHON.sodium_mg}mg, fluid=${DURING_MARATHON.water_ml}ml`
    );

    assert(result.foods.length > 0, 'Should select foods for marathon');
    const totals = sumTotals(result.foods);
    console.log(`[TEST] Marathon: carbs=${totals.carbs_g.toFixed(0)}g/${DURING_MARATHON.carbs_g}g, sodium=${totals.sodium_mg}mg/${DURING_MARATHON.sodium_mg}mg`);
  });

  it('should not select bike solids for running', async () => {
    const foods = makeDuringFoods();
    const result = generateDuringPhaseRuleBased(foods, DURING_STANDARD, 'running');

    await logs.writeToFile('during-running-no-bike-solids', `Sport: running | No bike solids check`);

    const hasBikeSolid = result.foods.some(f => f.product_type === 'bar');
    assertEquals(hasBikeSolid, false, 'Running should NOT select bar/waffle bike solids');
  });

  it('should cap carbs near target when target is below provided band', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({
      carbs_g: 90,
      carbs_low_g: 180,
      carbs_high_g: 270,
      sodium_mg: 800,
      water_ml: 900,
    });
    const result = generateDuringPhaseRuleBased(foods, targets, 'running');

    await logs.writeToFile(
      'during-running-out-of-band-carb-priority',
      'Sport: running | out-of-band carb target should be prioritized over stale band',
    );

    const totals = sumTotals(result.foods);
    assert(
      totals.carbs_g <= 100,
      `Expected carbs to stay near 90g target (<=100g), got ${totals.carbs_g.toFixed(1)}g`,
    );
  });
});

// ============================================================================
// Cycling Scenarios
// ============================================================================

describe('During Rule Solver — Cycling Scenarios', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should include bike solids for cycling', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 70, sodium_mg: 800, water_ml: 900 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'cycling');

    await logs.writeToFile('during-cycling-bike-solids',
      `Sport: cycling | Bike solids should be included`
    );

    assert(result.foods.length > 0, 'Should select foods for cycling');
    const totals = sumTotals(result.foods);
    console.log(`[TEST] Cycling: ${result.foods.length} foods, carbs=${totals.carbs_g.toFixed(0)}g`);
    // Bike solids may or may not be selected depending on carb gap after primary + sports drink
  });

  it('should handle combined carb sources for cycling', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 90, sodium_mg: 1000, water_ml: 1200 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'cycling');

    await logs.writeToFile('during-cycling-combined-carbs',
      `Sport: cycling | High carb targets requiring multiple sources`
    );

    const totals = sumTotals(result.foods);
    console.log(`[TEST] Combined carbs cycling: carbs=${totals.carbs_g.toFixed(0)}g/${targets.carbs_g}g`);
    console.log(`[TEST] Foods: ${result.foods.map(f => `${f.display_name ?? f.food_id} x${f.quantity}`).join(', ')}`);
  });

  it('should handle heavy sodium scaling for cycling', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 80, sodium_mg: 1500, water_ml: 1500 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'cycling');

    await logs.writeToFile('during-cycling-heavy-sodium',
      `Sport: cycling | Heavy sodium scaling`
    );

    const totals = sumTotals(result.foods);
    const sodiumPct = targets.sodium_mg > 0 ? (totals.sodium_mg / targets.sodium_mg * 100).toFixed(0) : 'n/a';
    console.log(`[TEST] Heavy cycling sodium: ${totals.sodium_mg}mg/${targets.sodium_mg}mg (${sodiumPct}%)`);
  });
});

// ============================================================================
// Sodium/Hydration Scaling (KEY diagnostic tests)
// ============================================================================

describe('During Rule Solver — Sodium/Hydration Scaling', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should handle low sodium target (light sweater)', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 30, sodium_mg: 200, water_ml: 400 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'running');

    await logs.writeToFile('during-sodium-low',
      `Sport: running | Low sodium target: ${targets.sodium_mg}mg`
    );

    const totals = sumTotals(result.foods);
    console.log(`[TEST] Low sodium: ${totals.sodium_mg}mg/${targets.sodium_mg}mg`);
    // Low sodium may skip electrolyte entirely
    const hasElectrolyte = result.foods.some(f => f.product_type === 'supplement');
    console.log(`[TEST] Electrolyte selected: ${hasElectrolyte}`);
  });

  it('should handle high sodium target (heavy sweater)', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 60, sodium_mg: 1400, water_ml: 1000 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'running');

    await logs.writeToFile('during-sodium-high',
      `Sport: running | High sodium target: ${targets.sodium_mg}mg`
    );

    const totals = sumTotals(result.foods);
    const sodiumPct = (totals.sodium_mg / targets.sodium_mg * 100).toFixed(0);
    console.log(`[TEST] High sodium: ${totals.sodium_mg}mg/${targets.sodium_mg}mg (${sodiumPct}%)`);

    // Document whether we can hit high sodium targets
    if (totals.sodium_mg < targets.sodium_mg * 0.7) {
      console.warn(`[TEST] KNOWN ISSUE: sodium under-delivery at ${sodiumPct}% — electrolyte scaling ceiling`);
    }
  });

  it('should fill fluid gap with water', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 40, sodium_mg: 500, water_ml: 1000 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'running');

    await logs.writeToFile('during-fluid-filling',
      `Sport: running | Fluid filling test: ${targets.water_ml}ml target`
    );

    const totals = sumTotals(result.foods);
    const fluidPct = (totals.water_ml / targets.water_ml * 100).toFixed(0);
    console.log(`[TEST] Fluid delivery: ${totals.water_ml}ml/${targets.water_ml}ml (${fluidPct}%)`);

    const hasWater = result.foods.some(f => f.product_type === 'beverage');
    console.log(`[TEST] Water selected: ${hasWater}`);
  });

  it('should handle extreme hot condition targets', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 70, sodium_mg: 2000, water_ml: 2000 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'running');

    await logs.writeToFile('during-sodium-extreme-hot',
      `Sport: running | EXTREME HOT targets: sodium=${targets.sodium_mg}mg, fluid=${targets.water_ml}ml`
    );

    const totals = sumTotals(result.foods);
    console.log(`[TEST] Extreme hot: sodium=${totals.sodium_mg}mg/${targets.sodium_mg}mg, fluid=${totals.water_ml}ml/${targets.water_ml}ml`);
    console.log(`[TEST] Foods: ${result.foods.map(f => `${f.display_name ?? f.food_id} x${f.quantity}`).join(', ')}`);

    // Document the ceiling
    const sodiumPct = (totals.sodium_mg / targets.sodium_mg * 100).toFixed(0);
    const fluidPct = (totals.water_ml / targets.water_ml * 100).toFixed(0);
    console.log(`[TEST] Delivery: sodium=${sodiumPct}%, fluid=${fluidPct}%`);
  });

  it('should handle heavy cyclist targets', async () => {
    const foods = makeDuringFoods();
    const targets = makeTargets({ carbs_g: 100, sodium_mg: 1800, water_ml: 1500 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'cycling');

    await logs.writeToFile('during-heavy-cyclist',
      `Sport: cycling | Heavy cyclist targets`
    );

    const totals = sumTotals(result.foods);
    console.log(`[TEST] Heavy cyclist: carbs=${totals.carbs_g.toFixed(0)}g/${targets.carbs_g}g, sodium=${totals.sodium_mg}mg/${targets.sodium_mg}mg, fluid=${totals.water_ml}ml/${targets.water_ml}ml`);
  });
});

// ============================================================================
// Preference & Variety
// ============================================================================

describe('During Rule Solver — Preference & Variety', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should prefer liked foods', async () => {
    const likedGel = makeFood({
      id: 'liked-gel',
      name: 'Liked Gel',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      preference_score: 200,
      is_indivisible: true,
      product_type: 'gel',
      min_servings: 1,
      max_servings: 6,
    });
    const willingGel = makeFood({
      id: 'willing-gel',
      name: 'Willing Gel',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      preference_score: 80,
      is_indivisible: true,
      product_type: 'gel',
      min_servings: 1,
      max_servings: 6,
    });
    const water = makeFood({
      id: 'water',
      name: 'Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
      preference_score: 50,
      is_liquid: true,
      is_essential: true,
      product_type: 'beverage',
    });

    const foods = [likedGel, willingGel, water];
    const targets = makeTargets({ carbs_g: 45, sodium_mg: 400, water_ml: 500 });
    const result = generateDuringPhaseRuleBased(foods, targets, 'running');

    await logs.writeToFile('during-preference-liked', `Sport: running | Liked preference test`);

    // The liked gel should be selected as primary carb
    const likedSelected = result.foods.find(f => f.food_id === 'liked-gel');
    const willingSelected = result.foods.find(f => f.food_id === 'willing-gel');
    console.log(`[TEST] Liked gel selected: ${likedSelected ? `x${likedSelected.quantity}` : 'NO'}`);
    console.log(`[TEST] Willing gel selected: ${willingSelected ? `x${willingSelected.quantity}` : 'NO'}`);
  });

  it('should produce variety across multiple runs (random selection)', async () => {
    const foods = makeDuringFoods();
    const targets = DURING_STANDARD;

    // Run 5 times and collect primary carb selections
    const primaryCarbs = new Set<string>();
    for (let i = 0; i < 5; i++) {
      logs.clear();
      const result = generateDuringPhaseRuleBased(foods, targets, 'running');
      for (const f of result.foods) {
        if (f.product_type === 'gel' || f.product_type === 'chew' || f.product_type === 'drink_mix') {
          primaryCarbs.add(f.food_id);
        }
      }
    }

    await logs.writeToFile('during-variety-random', `Sport: running | Random variety across 5 runs`);

    console.log(`[TEST] Primary carbs selected across 5 runs: ${[...primaryCarbs].join(', ')}`);
    // Note: variety depends on whether foods have equal preference scores
    // With our mock data, Energy Gel has score 200 (liked) so it will likely be picked every time
  });

  it('should produce variety when preferences are equal', async () => {
    // All gels have the same preference — random selection should kick in
    const gel1 = makeFood({
      id: 'gel-a',
      name: 'Gel A',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      preference_score: 80,
      is_indivisible: true,
      product_type: 'gel',
      min_servings: 1,
      max_servings: 6,
    });
    const gel2 = makeFood({
      id: 'gel-b',
      name: 'Gel B',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      preference_score: 80,
      is_indivisible: true,
      product_type: 'gel',
      min_servings: 1,
      max_servings: 6,
    });
    const water = makeFood({
      id: 'water',
      name: 'Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
      preference_score: 50,
      is_liquid: true,
      product_type: 'beverage',
    });

    const foods = [gel1, gel2, water];
    const targets = makeTargets({ carbs_g: 25, sodium_mg: 100, water_ml: 400 });

    const selections = new Set<string>();
    for (let i = 0; i < 10; i++) {
      logs.clear();
      const result = generateDuringPhaseRuleBased(foods, targets, 'running');
      for (const f of result.foods) {
        if (f.product_type === 'gel') {
          selections.add(f.food_id);
        }
      }
    }

    await logs.writeToFile('during-variety-equal-prefs', `Sport: running | Equal preference variety over 10 runs`);

    console.log(`[TEST] Unique gels selected across 10 runs: ${[...selections].join(', ')}`);
    // With crypto.getRandomValues() and equal scores, we should see both
    // (though not guaranteed in small sample)
  });
});
