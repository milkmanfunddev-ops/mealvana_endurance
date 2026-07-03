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
    time_window: '< 30 min',
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

// A tablet whose single serving overshoots a low before-run sodium_high.
const BIG_TABLET = makeTemplate({
  id: 'big-tablet',
  name: 'Big Salt Tablet',
  sodium_mg: 300,
  carbs_per_serving: 0,
  fluid_ml: 0,
  min_servings: 1,
  max_servings: 2,
});

// Tier-2 before-run hydration overlay targets (100 low / 200 high / 150 target)
// — the production range where the 77mg bug occurred.
const BEFORE_TIER2 = {
  carbsTarget: 30,
  carbsHigh: 60,
  proteinHigh: 20,
  sodiumLow: 100,
  sodiumHigh: 200,
  sodiumTarget: 150,
  fluidHigh: 500,
  fluidTarget: 250,
};

Deno.test(
  'pickElectrolyte: floor enforcement — adds an overshooting serving rather than stranding sodium below the floor',
  () => {
    // 77mg delivered, only a 300mg tablet available. 1 serving → 377mg, which
    // overshoots sodium_high (200) so the headroom gate rejects it. Before the
    // fix this stranded sodium at 77mg (< 100 floor); now floor enforcement
    // adds the tablet so sodium clears the floor.
    const pick = pickElectrolyte(
      [BIG_TABLET],
      /* carbsDelivered */ 20,
      /* proteinDelivered */ 0,
      /* totalSodiumDelivered */ 77,
      /* totalFluidDelivered */ 0,
      BEFORE_TIER2.carbsTarget,
      BEFORE_TIER2.carbsHigh,
      BEFORE_TIER2.proteinHigh,
      BEFORE_TIER2.sodiumLow,
      BEFORE_TIER2.sodiumHigh,
      BEFORE_TIER2.sodiumTarget,
      BEFORE_TIER2.fluidHigh,
      BEFORE_TIER2.fluidTarget,
    );

    assert(pick !== null, 'floor enforcement should add an electrolyte, not return null');
    assertEquals(pick!.name, 'Big Salt Tablet');
    // Least-overshoot serving = 1 (not 2), and the delivered floor is cleared.
    assertEquals(pick!.servings, 1);
    assert(
      77 + pick!.sodium_mg >= BEFORE_TIER2.sodiumLow,
      `expected total sodium >= ${BEFORE_TIER2.sodiumLow}, got ${77 + pick!.sodium_mg}`,
    );
  },
);

Deno.test(
  'pickElectrolyte: floor enforcement picks the least-overshoot serving among options',
  () => {
    // Two tablets both overshoot high (200): 120mg and 300mg on top of 77mg
    // gives 197 (< low? no, 197 >= 100 and <= 200 — that would pass the normal
    // path). Use 150mg and 300mg so 77+150=227 and 77+300=377 both overshoot;
    // the 150mg (227, least overshoot) must win.
    const MID = makeTemplate({
      id: 'mid-tablet',
      name: 'Mid Salt Tablet',
      sodium_mg: 150,
      carbs_per_serving: 0,
      fluid_ml: 0,
      min_servings: 1,
      max_servings: 1,
    });
    const pick = pickElectrolyte(
      [BIG_TABLET, MID],
      20,
      0,
      /* totalSodiumDelivered */ 77,
      0,
      BEFORE_TIER2.carbsTarget,
      BEFORE_TIER2.carbsHigh,
      BEFORE_TIER2.proteinHigh,
      BEFORE_TIER2.sodiumLow,
      BEFORE_TIER2.sodiumHigh,
      BEFORE_TIER2.sodiumTarget,
      BEFORE_TIER2.fluidHigh,
      BEFORE_TIER2.fluidTarget,
    );
    assert(pick !== null);
    assertEquals(pick!.name, 'Mid Salt Tablet');
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
