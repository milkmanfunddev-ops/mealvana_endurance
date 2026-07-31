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

// ============================================================================
// Item 5 (2026-07-04): divisible electrolyte packet — 0.5-serving steps
// ============================================================================
//
// A 150mg "packet" (`is_indivisible: false`) with min_servings 0.5 lets the
// solver land inside a tight before-run sodium band (e.g. Tier-2's 100-200mg)
// that a whole-unit-only 300mg tablet cannot hit without badly overshooting.

const DIVISIBLE_PACKET = makeTemplate({
  id: 'electrolyte-packet',
  name: 'Electrolyte Packet',
  sodium_mg: 150,
  carbs_per_serving: 0,
  fluid_ml: 0,
  min_servings: 0.5,
  max_servings: 3,
  is_indivisible: false,
});

Deno.test(
  'pickElectrolyte: divisible packet steps in 0.5 increments — reaches the exact 1.0-serving match, not just the 0.5 starting point',
  () => {
    // Regression for the step-size fix itself (not just "0.5 is reachable",
    // which is trivially true since min_servings=0.5 is the loop's starting
    // value regardless of step size). A buggy `+= 1` step from a 0.5
    // min_servings tests 0.5, 1.5, 2.5, ... and would NEVER land on exactly
    // 1.0 serving (150mg) — the ideal match for this band's 150mg target.
    // Only a correct `+= 0.5` step reaches 1.0 and scores it as the winner
    // over the 0.5 (75mg, under target) candidate.
    const pick = pickElectrolyte(
      [DIVISIBLE_PACKET],
      /* carbsDelivered */ 0,
      /* proteinDelivered */ 0,
      /* totalSodiumDelivered */ 0,
      /* totalFluidDelivered */ 0,
      /* carbsTarget */ 0,
      /* carbsHigh */ 60,
      /* proteinHigh */ 20,
      /* sodiumLow */ 140,
      /* sodiumHigh */ 160,
      /* sodiumTarget */ 150,
      /* fluidHigh */ 500,
      /* fluidTarget */ 0,
    );

    assert(pick !== null, 'expected the divisible packet to be selectable');
    assertEquals(pick!.name, 'Electrolyte Packet');
    assertEquals(
      pick!.servings,
      1,
      'expected the 1.0-serving exact-target match, only reachable with a 0.5 step',
    );
    assertEquals(pick!.sodium_mg, 150);
  },
);

Deno.test(
  'pickElectrolyte: floor enforcement on a divisible packet overshoots far less than a whole tablet',
  () => {
    // A tight band (sodiumHigh=130) makes even the packet's smallest 0.5-
    // serving step (75mg) exceed the main loop's headroom check (53mg
    // remaining), so this forces the least-overshoot floor-enforcement
    // fallback to run — same mechanism as the BIG_TABLET floor-enforcement
    // test above. The point of comparison: BIG_TABLET (whole-unit-only)
    // overshoots its 200mg high by 177mg (377 total) because 1 whole
    // serving is its smallest step; the divisible packet overshoots this
    // 130mg high by only 22mg (152 total) because 0.5 servings is available.
    const TIGHT_BAND = {
      ...BEFORE_TIER2,
      sodiumLow: 100,
      sodiumHigh: 130,
    };
    const pick = pickElectrolyte(
      [DIVISIBLE_PACKET],
      20,
      0,
      /* totalSodiumDelivered */ 77,
      0,
      TIGHT_BAND.carbsTarget,
      TIGHT_BAND.carbsHigh,
      TIGHT_BAND.proteinHigh,
      TIGHT_BAND.sodiumLow,
      TIGHT_BAND.sodiumHigh,
      TIGHT_BAND.sodiumTarget,
      TIGHT_BAND.fluidHigh,
      TIGHT_BAND.fluidTarget,
    );

    assert(pick !== null, 'floor enforcement should add the packet, not return null');
    assertEquals(pick!.servings, 0.5);
    const total = 77 + pick!.sodium_mg;
    assertEquals(total, 152);
    const overshoot = total - TIGHT_BAND.sodiumHigh;
    assert(
      overshoot < 30,
      `expected a small overshoot from the divisible packet's 0.5 step, got ${overshoot}mg`,
    );
  },
);

// ===========================================================================
// Target-seeking (2026-07-29)
//
// `pickElectrolyte` used to open with `if (totalSodiumDelivered >= sodiumLow)
// return null` — the instant food + drink selection cleared the band FLOOR, no
// electrolyte was ever considered, so sodium parked at the bottom of the range
// while sodium_target sat well above. These tests assert distance-to-target,
// not range membership: landing in-range but further from target than an
// available option is a failure.
// ===========================================================================

Deno.test(
  'pickElectrolyte: keeps closing the gap to TARGET after the floor is already cleared',
  () => {
    // 320mg delivered — already above the 300mg floor, but 130mg short of the
    // 450mg target. A 100mg tab lands 420mg (30mg from target). The old
    // floor gate returned null here and shipped 320mg.
    const SMALL_TAB = makeTemplate({
      id: 'small-tab',
      name: 'Small Salt Tab',
      sodium_mg: 100,
      carbs_per_serving: 0,
      fluid_ml: 0,
      min_servings: 1,
      max_servings: 3,
    });

    const pick = pickElectrolyte(
      [SMALL_TAB],
      /* carbsDelivered */ 20,
      /* proteinDelivered */ 0,
      /* totalSodiumDelivered */ 320,
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

    assert(
      pick !== null,
      'expected an electrolyte: sodium cleared the floor but is 130mg short of target',
    );
    const total = 320 + pick!.sodium_mg;
    assertEquals(
      pick!.servings,
      1,
      `expected the target-closest serving; got ${pick!.servings} (total ${total}mg)`,
    );
    assert(
      Math.abs(total - TARGETS.sodiumTarget) < Math.abs(320 - TARGETS.sodiumTarget),
      `pick must move sodium CLOSER to target: ${total}mg vs baseline 320mg (target ${TARGETS.sodiumTarget}mg)`,
    );
  },
);

Deno.test(
  'pickElectrolyte: adds nothing once sodium is already on target',
  () => {
    const SMALL_TAB = makeTemplate({
      id: 'small-tab',
      name: 'Small Salt Tab',
      sodium_mg: 100,
      carbs_per_serving: 0,
      fluid_ml: 0,
      min_servings: 1,
      max_servings: 3,
    });

    const pick = pickElectrolyte(
      [SMALL_TAB],
      20,
      0,
      /* totalSodiumDelivered */ TARGETS.sodiumTarget,
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

    assertEquals(pick, null, 'on target — nothing to add, and never overshoot');
  },
);

Deno.test(
  'pickElectrolyte: target-seeking must not become ceiling-busting',
  () => {
    // 320mg delivered (in range), only a 300mg tablet available: 620mg would
    // breach sodium_high (600). Removing the floor gate must NOT let a
    // ceiling-breaching pick through, and the floor rescue must stay dormant
    // because we did not start below the floor.
    const pick = pickElectrolyte(
      [BIG_TABLET],
      20,
      0,
      /* totalSodiumDelivered */ 320,
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

    assertEquals(
      pick,
      null,
      'prefer the in-range shortfall over breaching sodium_high',
    );
  },
);
