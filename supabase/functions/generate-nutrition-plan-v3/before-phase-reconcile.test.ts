/**
 * Local Unit Tests for Before-Phase Post-Pin Reconciliation
 *
 * Regression for bug 3abe3fdb754c818c93e8fbbd801dae8e (Wiredash 2026-07-28):
 * with Meal and Snack pin-overlaid and a stale Algorithm C top_up, the BEFORE
 * phase landed carbs 55 g below a 66–84 g floor while fluids (16 oz ≈ 473 ml
 * vs 207–296 ml) and sodium (581 mg vs 100–200 mg) blew their ceilings.
 *
 * Run with:
 *   deno test supabase/functions/generate-nutrition-plan-v3/before-phase-reconcile.test.ts
 */

import { assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { reconcileBeforePhaseAfterPins } from './before-phase-reconcile.ts';
import type { FoodResult } from '../_shared/nutrition/types.ts';
import type {
  BeforePhaseResult,
  SubPhaseResult,
} from '../_shared/nutrition/templates/types.ts';
import type { PreWorkoutTargets } from '../generate-macros-v4/types.ts';

function food(overrides: Partial<FoodResult> & { food_id: string }): FoodResult {
  return {
    quantity: 1,
    carbs_grams: 0,
    protein_grams: 0,
    fat_grams: 0,
    sodium_mg: 0,
    fluids_ml: 0,
    calories: 0,
    ...overrides,
  };
}

function subPhase(
  type: 'meal' | 'snack' | 'top_up',
  foods: FoodResult[],
): SubPhaseResult {
  return {
    sub_phase_type: type,
    targets: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 },
    foods,
  };
}

function totals(result: BeforePhaseResult) {
  let carbs = 0, sodium = 0, fluid = 0;
  for (const sub of [result.meal, result.snack, result.top_up]) {
    if (!sub) continue;
    for (const f of sub.foods) {
      carbs += f.carbs_grams;
      sodium += f.sodium_mg;
      fluid += f.fluids_ml;
    }
  }
  return { carbs, sodium, fluid };
}

// The reported case: BEFORE ranges carbs 66–84 g (target 75), sodium
// 100–200 mg (target 150), fluid 207–296 ml (target 250).
const TARGETS: PreWorkoutTargets = {
  carbs_g: 75,
  carbs_low_g: 66,
  carbs_high_g: 84,
  protein_g: 0,
  protein_low_g: 0,
  protein_high_g: 0,
  fat_g: 0,
  sodium_mg: 150,
  sodium_low_mg: 100,
  sodium_high_mg: 200,
  water_ml: 250,
  water_low_ml: 207,
  water_high_ml: 296,
  meal_type: 'meal_snack_topup',
};

function makeReportedScenario(): BeforePhaseResult {
  // Pinned meal: Bagel + Cream Cheese + Almond Butter + cup of water
  const meal = subPhase('meal', [
    food({ food_id: 'bagel', carbs_grams: 38, sodium_mg: 400, fluids_ml: 0 }),
    food({ food_id: 'cream_cheese', carbs_grams: 1, sodium_mg: 90, fluids_ml: 0 }),
    food({ food_id: 'water-meal', fluids_ml: 118, is_drink: true, is_liquid: true }),
  ]);
  // Pinned snack: RXBAR + cup of water
  const snack = subPhase('snack', [
    food({ food_id: 'rxbar', carbs_grams: 16, sodium_mg: 16, fluids_ml: 0 }),
    food({ food_id: 'water-snack', fluids_ml: 118, is_drink: true, is_liquid: true }),
  ]);
  // Stale Algorithm C top_up: 1 cup Water + 0.5 Electrolyte Packet
  const topUp = subPhase('top_up', [
    food({ food_id: 'water-topup', quantity: 1, fluids_ml: 237, is_drink: true, is_liquid: true }),
    food({
      food_id: 'electrolyte-packet',
      quantity: 0.5,
      sodium_mg: 75,
      is_electrolyte: true,
    }),
  ]);
  return { meal, snack, top_up: topUp };
}

describe('reconcileBeforePhaseAfterPins', () => {
  it('no-ops when nothing was pinned', () => {
    const result = makeReportedScenario();
    const before = totals(result);
    reconcileBeforePhaseAfterPins(result, TARGETS, new Set());
    const after = totals(result);
    assert(before.carbs === after.carbs && before.fluid === after.fluid);
  });

  it(
    'reported case: trims stale top_up fluid/sodium and fills the carb floor ' +
      'from the add-on pool (carbs into 66–84, fluid ≤ 296, sodium reduced)',
    () => {
      const result = makeReportedScenario();
      const before = totals(result);
      assert(before.carbs < TARGETS.carbs_low_g, 'precondition: carbs under floor');
      assert(before.fluid > TARGETS.water_high_ml, 'precondition: fluid over ceiling');
      assert(before.sodium > TARGETS.sodium_high_mg, 'precondition: sodium over ceiling');

      reconcileBeforePhaseAfterPins(
        result,
        TARGETS,
        new Set(['meal', 'snack']),
      );
      const after = totals(result);

      // Carbs must land inside the range, driven toward the 75 g target.
      assert(
        after.carbs >= TARGETS.carbs_low_g && after.carbs <= TARGETS.carbs_high_g,
        `carbs must land in [66, 84], got ${after.carbs}`,
      );
      // Fluid must come down to the ceiling or below (the stale top_up cup is
      // trimmable; the pinned cups are honored).
      assert(
        after.fluid <= TARGETS.water_high_ml,
        `fluid must not exceed ceiling 296 ml, got ${after.fluid}`,
      );
      // The non-pinned electrolyte contribution must be trimmed away; the
      // remaining overage lives entirely in the honored pins.
      const topUpSodium = result.top_up!.foods.reduce((s, f) => s + f.sodium_mg, 0);
      assert(
        topUpSodium < 75,
        `stale top_up electrolyte sodium should be trimmed, got ${topUpSodium}`,
      );
      assert(after.sodium < before.sodium, 'total sodium must decrease');
    },
  );

  it('does not touch pinned slots when trimming', () => {
    const result = makeReportedScenario();
    reconcileBeforePhaseAfterPins(result, TARGETS, new Set(['meal', 'snack']));
    const mealFluid = result.meal!.foods.reduce((s, f) => s + f.fluids_ml, 0);
    const snackFluid = result.snack!.foods.reduce((s, f) => s + f.fluids_ml, 0);
    assert(mealFluid === 118 && snackFluid === 118, 'pinned water untouched');
  });

  it('never trims fluid below the range floor', () => {
    // Fluid only slightly above ceiling, floor close beneath current total.
    const result: BeforePhaseResult = {
      meal: subPhase('meal', [
        food({ food_id: 'toast', carbs_grams: 70, sodium_mg: 150 }),
      ]),
      top_up: subPhase('top_up', [
        food({ food_id: 'water-topup', quantity: 1.5, fluids_ml: 320, is_drink: true, is_liquid: true }),
      ]),
    };
    reconcileBeforePhaseAfterPins(result, TARGETS, new Set(['meal']));
    const after = totals(result);
    assert(
      after.fluid >= TARGETS.water_low_ml,
      `fluid must stay at or above floor 207 ml, got ${after.fluid}`,
    );
  });

  it('respects dislikes when picking carb add-ons', () => {
    const result = makeReportedScenario();
    reconcileBeforePhaseAfterPins(
      result,
      TARGETS,
      new Set(['meal', 'snack']),
      new Set(['banana']),
    );
    const addedBanana = result.top_up!.foods.some(
      (f) => f.food_id === 'addon_banana',
    );
    assert(!addedBanana, 'disliked banana must not be added');
    const after = totals(result);
    assert(
      after.carbs >= TARGETS.carbs_low_g,
      `carb floor must still be met via other add-ons, got ${after.carbs}`,
    );
  });
});
