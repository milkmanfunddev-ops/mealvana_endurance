/**
 * Target-seeking regression tests (2026-07-29).
 *
 * Policy under test (Lee, 2026-07-29): "aim at the TARGET, not the range.
 * If we miss, it is OK to be in the range." Every assertion here is therefore
 * about DISTANCE TO TARGET, never about range membership — a plan that merely
 * clears the band floor is a FAILURE for these cases, because a strictly
 * closer-to-target option existed in the pool.
 *
 * Covers:
 *   - greedy-fallback.ts        stop condition + before/during deficit cascade
 *   - during-utils.ts           fillElectrolytes second-pass gate
 *   - phase-target-reconcile.ts post-LP sodium/fluid reconciliation
 *
 * Run with:
 *   deno test --no-check --allow-env --allow-net \
 *     supabase/functions/_shared/nutrition/target-seeking.test.ts
 */

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import { greedyFallback } from './greedy-fallback.ts';
import { fillElectrolytes } from './during-utils.ts';
import { reconcilePhaseHydrationAndSodium } from './phase-target-reconcile.ts';
import { makeFood, makeTargets } from './test-utils.ts';
import type { FoodResult } from './types.ts';

function sum(foods: FoodResult[]) {
  return foods.reduce(
    (acc, f) => ({
      carbs_g: acc.carbs_g + f.carbs_grams,
      protein_g: acc.protein_g + f.protein_grams,
      sodium_mg: acc.sodium_mg + f.sodium_mg,
      water_ml: acc.water_ml + f.fluids_ml,
    }),
    { carbs_g: 0, protein_g: 0, sodium_mg: 0, water_ml: 0 },
  );
}

// ===========================================================================
// greedy-fallback.ts — 3.2a / 3.8
// ===========================================================================

Deno.test(
  'greedyFallback during: fills fluid to TARGET, not 70% of it',
  () => {
    // The old stop condition broke out of the loop the moment water reached
    // 70% of target (and sized servings from the carb deficit alone), so a
    // 700ml/1000ml plan was declared "met". Water is available in 250ml units
    // here, so landing exactly on target is possible and anything less is a
    // satisficing failure.
    const foods = [
      makeFood({
        id: 'gel',
        name: 'Carb Gel',
        preference_score: 200,
        per_serving: {
          carbs_g: 25,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 50,
          water_ml: 0,
          calories: 100,
        },
        max_servings: 4,
      }),
      // Two hydration sources: the per-food serving cap for during is 3, a
      // deliberate item-realism limit ("don't prescribe 4 of one bottle"), so
      // reaching 1000ml legitimately requires drawing on both. The bug under
      // test is the STOP CONDITION, not that cap.
      makeFood({
        id: 'bottle',
        name: 'Bottle',
        preference_score: 100,
        is_liquid: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 250,
          calories: 0,
        },
        max_servings: 4,
      }),
      makeFood({
        id: 'flask',
        name: 'Soft Flask',
        preference_score: 100,
        is_liquid: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 250,
          calories: 0,
        },
        max_servings: 4,
      }),
    ];
    const targets = makeTargets({
      carbs_g: 50,
      protein_g: 0,
      sodium_mg: 300,
      water_ml: 1000,
    });

    const result = greedyFallback(foods, targets, 'during');
    const totals = sum(result.foods);

    assertEquals(
      totals.water_ml,
      1000,
      `fluid should land ON the 1000ml target, got ${totals.water_ml}ml`,
    );
    // And the target it was already chasing must not regress.
    assert(
      totals.carbs_g >= 50,
      `carbs should reach the 50g target, got ${totals.carbs_g}g`,
    );
  },
);

Deno.test(
  'greedyFallback during: does not stop carbs at 90% when the target is reachable',
  () => {
    // Deliberately tuned to land the first food on EXACTLY 90% of target:
    // Gel A is 15g and the per-food serving cap for during is 3 → 45g, which
    // is 90% of the 50g target. The old `carbs >= target * 0.9` stop broke out
    // right there. A 5g chew that closes the last gram is next in the pool, so
    // 50g is reachable and 45g is a satisficing failure.
    const foods = [
      makeFood({
        id: 'gel-a',
        name: 'Gel A',
        preference_score: 200,
        per_serving: {
          carbs_g: 15,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 0,
          calories: 60,
        },
        max_servings: 4,
      }),
      makeFood({
        id: 'chew',
        name: 'Carb Chew',
        preference_score: 100,
        per_serving: {
          carbs_g: 5,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 0,
          calories: 20,
        },
        max_servings: 4,
      }),
    ];
    const targets = makeTargets({
      carbs_g: 50,
      protein_g: 0,
      sodium_mg: 0,
      water_ml: 0,
    });

    const totals = sum(greedyFallback(foods, targets, 'during').foods);
    assertEquals(totals.carbs_g, 50, 'carbs must reach target, not 90% of it');
  },
);

Deno.test(
  'greedyFallback during: never crosses the band ceiling while chasing target',
  () => {
    // Only a 400ml bottle exists against a 1000ml target with a 1100ml
    // ceiling. 2 bottles = 800ml (under target, in range); 3 = 1200ml, over
    // the ceiling. Aim at target, but the ceiling wins: expect 800ml and an
    // honest shortfall, NOT 1200ml.
    const foods = [
      makeFood({
        id: 'bottle',
        name: 'Big Bottle',
        preference_score: 200,
        is_liquid: true,
        is_indivisible: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 400,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 4,
      }),
    ];
    const targets = {
      ...makeTargets({
        carbs_g: 0,
        protein_g: 0,
        sodium_mg: 0,
        water_ml: 1000,
      }),
      water_high_ml: 1100,
    };

    const totals = sum(greedyFallback(foods, targets, 'during').foods);
    assert(
      totals.water_ml <= 1100,
      `must not breach the 1100ml ceiling, got ${totals.water_ml}ml`,
    );
    assertEquals(
      totals.water_ml,
      800,
      'closest under-ceiling option to target is 800ml',
    );
  },
);

// ===========================================================================
// during-utils.ts fillElectrolytes — 3.6b
// ===========================================================================

const ELECTROLYTE_BOUNDS = {
  sodiumTarget: 600,
  sodiumLower: 400,
  sodiumUpper: 800,
  fluidTarget: 500,
  fluidUpper: 700,
  carbTarget: 60,
  carbUpper: 70,
};

Deno.test(
  'fillElectrolytes: second pass fires when the first pick clears the FLOOR but misses the TARGET',
  () => {
    // First pick can only deliver 450mg (clears the 400mg floor, 150mg short
    // of the 600mg target). A second, different source offers exactly 150mg.
    // The old `sodiumAssigned < sodiumLower` gate skipped the retry entirely.
    const pool = [
      makeFood({
        id: 'tab-450',
        name: 'Salt Tab 450',
        is_electrolyte: true,
        is_indivisible: true,
        preference_score: 200,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 450,
          water_ml: 0,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 1,
      }),
      makeFood({
        id: 'tab-150',
        name: 'Salt Tab 150',
        is_electrolyte: true,
        is_indivisible: true,
        preference_score: 50,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 150,
          water_ml: 0,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 1,
      }),
    ];

    const foods: FoodResult[] = [];
    const out = fillElectrolytes(pool, foods, 0, 0, 0, ELECTROLYTE_BOUNDS, null);

    assertEquals(
      out.sodiumAssigned,
      600,
      `sodium should reach the 600mg target, got ${out.sodiumAssigned}mg ` +
        '(a first pick that only clears the floor must not end the fill)',
    );
    assertEquals(foods.length, 2, 'both electrolyte sources should be used');
  },
);

Deno.test(
  'fillElectrolytes: does not overshoot the ceiling to reach target',
  () => {
    // Only a 500mg tab exists. 1 tab = 500mg (in range, 100mg short of the
    // 600mg target); 2 tabs = 1000mg, past the 800mg ceiling. Prefer the
    // in-range option and take the honest shortfall.
    const pool = [
      makeFood({
        id: 'tab-500',
        name: 'Salt Tab 500',
        is_electrolyte: true,
        is_indivisible: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 500,
          water_ml: 0,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 2,
      }),
    ];

    const foods: FoodResult[] = [];
    const out = fillElectrolytes(pool, foods, 0, 0, 0, ELECTROLYTE_BOUNDS, null);

    assertEquals(out.sodiumAssigned, 500, 'closest option under the ceiling');
    assert(
      out.sodiumAssigned <= ELECTROLYTE_BOUNDS.sodiumUpper,
      'must never breach sodium_high',
    );
  },
);

Deno.test(
  'fillElectrolytes: adds nothing when sodium is already at target',
  () => {
    const pool = [
      makeFood({
        id: 'tab-200',
        name: 'Salt Tab 200',
        is_electrolyte: true,
        is_indivisible: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 200,
          water_ml: 0,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 1,
      }),
    ];

    const foods: FoodResult[] = [];
    const out = fillElectrolytes(
      pool,
      foods,
      /* currentSodium */ 600,
      0,
      0,
      ELECTROLYTE_BOUNDS,
      null,
    );

    assertEquals(out.sodiumAssigned, 600, 'already on target — add nothing');
    assertEquals(foods.length, 0);
  },
);

// ===========================================================================
// phase-target-reconcile.ts — 3.3 (post-LP)
// ===========================================================================

Deno.test(
  'reconcilePhaseHydrationAndSodium: pulls an LP range-edge result back to target',
  () => {
    // Simulates an LP solution that parked fluid on the low band edge
    // (600ml against a 1000ml target, 800ml floor) — feasible, but not the
    // target. 200ml water units are in the pool, so target is reachable.
    const solved: FoodResult[] = [
      {
        food_id: 'recovery-shake',
        quantity: 1,
        carbs_grams: 40,
        protein_grams: 20,
        fat_grams: 2,
        sodium_mg: 200,
        fluids_ml: 600,
        calories: 300,
      } as FoodResult,
    ];
    const pool = [
      makeFood({
        id: 'water',
        name: 'Water',
        is_liquid: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 200,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 6,
      }),
    ];
    const targets = {
      ...makeTargets({
        carbs_g: 40,
        protein_g: 20,
        sodium_mg: 200,
        water_ml: 1000,
      }),
      carbs_high_g: 50,
      protein_high_g: 25,
      sodium_high_mg: 300,
      water_high_ml: 1200,
    };

    const out = reconcilePhaseHydrationAndSodium(solved, pool, targets);
    const totals = sum(out.foods);

    assert(out.applied, 'reconciliation should have applied');
    assertEquals(
      totals.water_ml,
      1000,
      `fluid should be pulled to the 1000ml target, got ${totals.water_ml}ml`,
    );
    // Sodium was already on target — must be left alone.
    assertEquals(totals.sodium_mg, 200, 'on-target sodium must not be touched');
  },
);

Deno.test(
  'reconcilePhaseHydrationAndSodium: is a no-op when already on target',
  () => {
    const solved: FoodResult[] = [
      {
        food_id: 'shake',
        quantity: 1,
        carbs_grams: 40,
        protein_grams: 20,
        fat_grams: 0,
        sodium_mg: 500,
        fluids_ml: 1000,
        calories: 300,
      } as FoodResult,
    ];
    const pool = [
      makeFood({
        id: 'water',
        name: 'Water',
        is_liquid: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 200,
          calories: 0,
        },
      }),
    ];
    const targets = {
      ...makeTargets({
        carbs_g: 40,
        protein_g: 20,
        sodium_mg: 500,
        water_ml: 1000,
      }),
      water_high_ml: 1200,
      sodium_high_mg: 600,
    };

    const out = reconcilePhaseHydrationAndSodium(solved, pool, targets);
    assertEquals(out.applied, false, 'nothing to do when already on target');
    assertEquals(out.foods.length, 1);
  },
);

Deno.test(
  'reconcilePhaseHydrationAndSodium: never breaches the fluid ceiling',
  () => {
    // 700ml short of target but only 500ml bottles available and a 1200ml
    // ceiling: one bottle (1100ml) is closer to target than two (1600ml,
    // over ceiling and rejected). Expect exactly one added bottle.
    const solved: FoodResult[] = [
      {
        food_id: 'shake',
        quantity: 1,
        carbs_grams: 40,
        protein_grams: 20,
        fat_grams: 0,
        sodium_mg: 500,
        fluids_ml: 600,
        calories: 300,
      } as FoodResult,
    ];
    const pool = [
      makeFood({
        id: 'bottle',
        name: 'Bottle',
        is_liquid: true,
        is_indivisible: true,
        per_serving: {
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          water_ml: 500,
          calories: 0,
        },
        min_servings: 1,
        max_servings: 4,
      }),
    ];
    const targets = {
      ...makeTargets({
        carbs_g: 40,
        protein_g: 20,
        sodium_mg: 500,
        water_ml: 1300,
      }),
      water_high_ml: 1200,
      sodium_high_mg: 600,
      carbs_high_g: 50,
      protein_high_g: 25,
    };

    const totals = sum(
      reconcilePhaseHydrationAndSodium(solved, pool, targets).foods,
    );
    assertEquals(totals.water_ml, 1100, 'closest option under the ceiling');
    assert(totals.water_ml <= 1200, 'must never breach water_high_ml');
  },
);
