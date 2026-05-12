/**
 * Regression tests for the #22 follow-up: pickElectrolyte should use the
 * same delta-based headroom check as pickDrink, so a zero-delta electrolyte
 * candidate (e.g. a zero-carb sodium tablet when state is already over
 * carbs_high) stays selectable on its sodium criteria.
 *
 * Run with:
 *   deno test --no-check --allow-env --allow-net \
 *     supabase/functions/generate-macros-v4/pre-workout-pickelectrolyte.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { pickElectrolyte } from './pre-workout.ts';
import type { PreWorkoutTemplate } from './types.ts';

function makeTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'Electrolyte',
    time_window: '0-30 min',
    digestion_speed: 'fast',
    allergens: [],
    serving_unit: 'capsule',
    min_servings: 1,
    max_servings: 2,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 0,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 200,
    fluid_ml: 0,
    template_type: 'electrolyte',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

// Pure sodium delivery, zero carbs/fluid — the realistic shape.
const SODIUM_CAPSULE = makeTemplate({
  id: 'sodium-capsule',
  name: 'Sodium Capsule',
  sodium_mg: 200,
  carbs_per_serving: 0,
  fluid_ml: 0,
});

// A chew with a small carb load — used to exercise the carbs_high path.
const SALT_CHEW = makeTemplate({
  id: 'salt-chew',
  name: 'Salt Chew',
  sodium_mg: 100,
  carbs_per_serving: 5,
  fluid_ml: 0,
});

const TARGETS = {
  carbsHigh: 80,
  proteinHigh: 20,
  sodiumLow: 300,
  sodiumHigh: 600,
  sodiumTarget: 450,
  fluidHigh: 500,
  fluidTarget: 300,
};

Deno.test(
  'pickElectrolyte: zero-carb candidate selectable when state is already over carbs_high (#22 follow-up)',
  () => {
    // 90g carbs delivered > 80g carbs_high. A zero-carb sodium capsule adds 0g
    // carbs, so it should still be selectable to close the sodium gap.
    const pick = pickElectrolyte(
      [SODIUM_CAPSULE],
      /* carbsDelivered */ 90,
      /* proteinDelivered */ 0,
      /* totalSodiumDelivered */ 100,
      /* totalFluidDelivered */ 0,
      /* carbsTarget */ 60,
      TARGETS.carbsHigh,
      TARGETS.proteinHigh,
      TARGETS.sodiumLow,
      TARGETS.sodiumHigh,
      TARGETS.sodiumTarget,
      TARGETS.fluidHigh,
      TARGETS.fluidTarget,
    );

    assert(pick !== null, 'pickElectrolyte returned null even though candidate adds 0 carbs');
    assertEquals(pick!.name, 'Sodium Capsule');
  },
);

Deno.test(
  'pickElectrolyte: carb-adding candidate rejected when state is already over carbs_high',
  () => {
    // 90g carbs delivered > 80g carbs_high. Salt chew adds 5g carbs → should reject.
    const pick = pickElectrolyte(
      [SALT_CHEW],
      /* carbsDelivered */ 90,
      0,
      100,
      0,
      60,
      TARGETS.carbsHigh,
      TARGETS.proteinHigh,
      TARGETS.sodiumLow,
      TARGETS.sodiumHigh,
      TARGETS.sodiumTarget,
      TARGETS.fluidHigh,
      TARGETS.fluidTarget,
    );

    assertEquals(pick, null, 'expected salt chew to be rejected when its carbs would breach the cap');
  },
);

Deno.test(
  'pickElectrolyte: no-regression — normal sodium-low scenario still picks capsule',
  () => {
    // 100 mg delivered (well under low cap of 300), plenty of headroom.
    const pick = pickElectrolyte(
      [SODIUM_CAPSULE],
      /* carbsDelivered */ 30,
      0,
      /* totalSodiumDelivered */ 100,
      0,
      60,
      TARGETS.carbsHigh,
      TARGETS.proteinHigh,
      TARGETS.sodiumLow,
      TARGETS.sodiumHigh,
      TARGETS.sodiumTarget,
      TARGETS.fluidHigh,
      TARGETS.fluidTarget,
    );

    assert(pick !== null);
    assertEquals(pick!.name, 'Sodium Capsule');
  },
);
