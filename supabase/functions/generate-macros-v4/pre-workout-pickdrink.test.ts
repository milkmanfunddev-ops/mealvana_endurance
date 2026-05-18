/**
 * Regression tests for #22: pickDrink must allow zero-sodium drinks (water)
 * even when state is already over sodium_high.
 *
 * The bug: the hard cap check was `resultSodium > sodiumHigh`, where
 * resultSodium = totalSodiumDelivered + template.sodium_mg × servings. For
 * water (sodium_mg = 0) this collapses to `totalSodiumDelivered > sodiumHigh`,
 * meaning whenever state arrived at pickDrink with sodium already over the
 * cap (which happens when Pass 1 over-loads sodium and the safePool fallback
 * fires), every drink — including water — was rejected. Users got plans
 * with no fluid recommendation at all.
 *
 * The fix: compare the drink's sodium *contribution* against remaining
 * sodium headroom (clamped at zero), so zero-sodium drinks always pass
 * the cap. Drinks that add positive sodium are still rejected when there's
 * no headroom — that's the correct behavior.
 *
 * Run with:
 *   deno test --no-check --allow-env --allow-net \
 *     supabase/functions/generate-macros-v4/pre-workout-pickdrink.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { pickDrink } from './pre-workout.ts';
import type { PreWorkoutTemplate } from './types.ts';

// ============================================================================
// Fixtures
// ============================================================================

function makeTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'Hydration',
    time_window: '< 30 min',
    digestion_speed: 'fast',
    allergens: [],
    serving_unit: 'cup',
    min_servings: 1,
    max_servings: 2,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 0,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 0,
    fluid_ml: 240,
    template_type: 'drink',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

const WATER = makeTemplate({
  id: 'water',
  name: 'Water',
  sodium_mg: 0,
  fluid_ml: 240,
});

const SPORTS_DRINK = makeTemplate({
  id: 'sports-drink',
  name: 'Sports Drink',
  sodium_mg: 200,
  fluid_ml: 240,
});

// Standard pre-workout target band — 105 lb athlete on a longer ride.
const TARGETS = {
  proteinHigh: 20,
  sodiumTarget: 450,
  fluidTarget: 300,
  sodiumHigh: 600,
  fluidHigh: 500,
  carbsHigh: 80,
};

// ============================================================================
// The #22 bug surface: state over sodium_high must still allow water
// ============================================================================

Deno.test('pickDrink returns water when state is OVER sodium_high (#22)', () => {
  // 800 mg delivered > 600 mg sodium_high. Pre-fix, this rejected every drink
  // including water because resultSodium = 800 + 0 = 800 > 600.
  const drink = pickDrink(
    [WATER, SPORTS_DRINK],
    /* proteinDelivered */ 0,
    /* totalSodiumDelivered */ 800,
    /* totalFluidDelivered */ 0,
    TARGETS.proteinHigh,
    TARGETS.sodiumTarget,
    TARGETS.fluidTarget,
    TARGETS.sodiumHigh,
    TARGETS.fluidHigh,
    /* carbsDelivered */ 0,
    TARGETS.carbsHigh,
  );

  assert(drink !== null, 'pickDrink returned null when state was over sodium_high — bug not fixed');
  assertEquals(drink!.name, 'Water', 'expected zero-sodium water to win when state is sodium-saturated');
});

Deno.test('pickDrink rejects sodium-adding drinks when state is OVER sodium_high (#22)', () => {
  // Only a sodium-adding drink available — should return null, not a
  // sports drink that would push sodium further over the cap.
  const drink = pickDrink(
    [SPORTS_DRINK],
    0,
    /* totalSodiumDelivered */ 800,
    0,
    TARGETS.proteinHigh,
    TARGETS.sodiumTarget,
    TARGETS.fluidTarget,
    TARGETS.sodiumHigh,
    TARGETS.fluidHigh,
    0,
    TARGETS.carbsHigh,
  );

  assertEquals(drink, null, 'expected sports drink to be rejected when no sodium headroom remains');
});

Deno.test('pickDrink returns water when state is AT sodium_high (boundary case)', () => {
  // 600 mg delivered = 600 mg cap. Headroom = 0, water adds 0 sodium → passes.
  const drink = pickDrink(
    [WATER, SPORTS_DRINK],
    0,
    /* totalSodiumDelivered */ 600,
    0,
    TARGETS.proteinHigh,
    TARGETS.sodiumTarget,
    TARGETS.fluidTarget,
    TARGETS.sodiumHigh,
    TARGETS.fluidHigh,
    0,
    TARGETS.carbsHigh,
  );

  assert(drink !== null);
  assertEquals(drink!.name, 'Water', 'water should be selected when sodium is exactly at cap');
});

// ============================================================================
// No-regression cases: normal sodium-budget paths still work
// ============================================================================

Deno.test('pickDrink picks sports drink when sodium room remains and gap is large', () => {
  // 100 mg delivered, gap of 350 mg to target. Sports drink (200 mg) closes
  // more of the gap than water (0 mg) and there's plenty of headroom (500 mg
  // remaining before sodium_high). Sports drink should win on score.
  const drink = pickDrink(
    [WATER, SPORTS_DRINK],
    0,
    /* totalSodiumDelivered */ 100,
    0,
    TARGETS.proteinHigh,
    TARGETS.sodiumTarget,
    TARGETS.fluidTarget,
    TARGETS.sodiumHigh,
    TARGETS.fluidHigh,
    0,
    TARGETS.carbsHigh,
  );

  assert(drink !== null);
  assertEquals(drink!.name, 'Sports Drink', 'sports drink should close the larger sodium gap');
});

Deno.test('pickDrink rejects sports drink when its contribution would breach cap', () => {
  // 500 mg delivered, 600 mg cap. Sports drink at 1 serving = 200 mg pushes
  // total to 700 (over by 100). Should be rejected; water selected instead.
  const drink = pickDrink(
    [WATER, SPORTS_DRINK],
    0,
    /* totalSodiumDelivered */ 500,
    0,
    TARGETS.proteinHigh,
    TARGETS.sodiumTarget,
    TARGETS.fluidTarget,
    TARGETS.sodiumHigh,
    TARGETS.fluidHigh,
    0,
    TARGETS.carbsHigh,
  );

  assert(drink !== null);
  assertEquals(drink!.name, 'Water', 'sports drink should be rejected when its sodium would breach the cap');
});
