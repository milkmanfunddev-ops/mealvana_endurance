/**
 * Regression tests for bug 3ace3fdb — "Top-Off slot generates completely empty
 * when the pre-workout window is long enough to schedule a Full Meal".
 *
 * Reported case: a 12 mi / 1h48m run with a 2-hour pre-workout window activated
 * all three sub-phases. Meal and Snack populated; Top-Off rendered as a header
 * row with no food, no water and no electrolyte beneath it. The same plan at a
 * 90-minute window filled Top-Off correctly.
 *
 * Mechanism: meal+snack consume the whole carb budget at template serving
 * granularity, the cross-phase carb ceiling guard then skips top_up entirely,
 * Pass 1.5 is a no-op (carbs are already above carbs_low_g so there is no gap),
 * and Passes 2/3 find no drink or electrolyte that fits under fluid_high.
 *
 * The invariant these tests lock: a rendered top_up slot always carries
 * something, and at minimum MIN_TOP_UP_FLUID_ML of water.
 *
 * Run with:
 *   deno test --allow-env --allow-read \
 *     supabase/functions/generate-macros-v4/pre-workout-topoff-floor.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
  getActiveSubPhases,
} from './pre-workout.ts';
import { MIN_TOP_UP_FLUID_ML } from './types.ts';
import type { PreWorkoutTemplate, PreWorkoutPhaseResult } from './types.ts';

// ============================================================================
// Fixtures
// ============================================================================

function makeTemplate(
  overrides: Partial<PreWorkoutTemplate> & { id: string; name: string },
): PreWorkoutTemplate {
  return {
    base_category: 'grain',
    time_window: '1.5-3 hours',
    digestion_speed: 'medium',
    allergens: [],
    serving_unit: 'serving',
    min_servings: 1,
    max_servings: 4,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 30,
    protein_per_serving: 5,
    fat_per_serving: 3,
    sodium_mg: 100,
    fluid_ml: 0,
    template_type: 'food',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

// A deliberately carb-dense meal: at its minimum serving it already eats most
// of the budget, which is what starves the later phases.
const BIG_MEAL = makeTemplate({
  id: 'big-meal',
  name: 'Big Pancake Stack',
  base_category: 'grain',
  time_window: '1.5-3 hours',
  carbs_per_serving: 80,
  protein_per_serving: 12,
  fat_per_serving: 8,
  sodium_mg: 400,
  fluid_ml: 300,
  min_servings: 1,
  max_servings: 2,
  component_food_names: ['pancakes'],
  component_quantities: { pancakes: 1 },
});

const BAR_SNACK = makeTemplate({
  id: 'rx-bar',
  name: 'RXBAR Blueberry',
  base_category: 'bar',
  time_window: '30-90 min',
  carbs_per_serving: 24,
  protein_per_serving: 12,
  fat_per_serving: 9,
  sodium_mg: 150,
  fluid_ml: 240,
  min_servings: 1,
  max_servings: 2,
  component_food_names: ['rx_bar'],
  component_quantities: { rx_bar: 1 },
});

// The smallest top-off food available is still large enough to breach the carb
// ceiling once BIG_MEAL + BAR_SNACK have run — this is the exact condition that
// makes the ceiling guard skip the phase.
const BIG_CHEWS = makeTemplate({
  id: 'chews',
  name: 'Energy Chews',
  base_category: 'chew',
  time_window: '< 30 min',
  digestion_speed: 'fast',
  carbs_per_serving: 40,
  protein_per_serving: 0,
  fat_per_serving: 0,
  sodium_mg: 60,
  fluid_ml: 0,
  min_servings: 1,
  max_servings: 2,
  component_food_names: ['energy_chews'],
  component_quantities: { energy_chews: 1 },
});

const WATER = makeTemplate({
  id: 'water',
  name: 'Water',
  base_category: 'water',
  time_window: '< 30 min',
  template_type: 'drink',
  carbs_per_serving: 0,
  protein_per_serving: 0,
  fat_per_serving: 0,
  sodium_mg: 0,
  fluid_ml: 240,
  min_servings: 0.5,
  max_servings: 4,
  component_food_names: ['water'],
  component_quantities: { water: 1 },
});

const NUUN = makeTemplate({
  id: 'nuun',
  name: 'Nuun Tab',
  base_category: 'electrolyte',
  time_window: '< 30 min',
  template_type: 'electrolyte',
  carbs_per_serving: 2,
  protein_per_serving: 0,
  fat_per_serving: 0,
  sodium_mg: 300,
  fluid_ml: 0,
  min_servings: 1,
  max_servings: 2,
  component_food_names: ['nuun'],
  component_quantities: { nuun: 1 },
});

const STARVING_FOODS = [BIG_MEAL, BAR_SNACK, BIG_CHEWS];

// ============================================================================
// Helpers
// ============================================================================

function topUpOf(
  results: PreWorkoutPhaseResult[],
  label = '',
): PreWorkoutPhaseResult {
  const phase = results.find((p) => p.phase === 'top_up');
  assert(phase, `expected a top_up phase in the results ${label}`);
  return phase;
}

function isEmptySlot(phase: PreWorkoutPhaseResult): boolean {
  return (
    phase.primary === null &&
    !phase.stack &&
    phase.add_ons.length === 0 &&
    !phase.drink &&
    !phase.electrolyte
  );
}

// ============================================================================
// Tests
// ============================================================================

describe('bug 3ace3fdb — top-off is never empty', () => {
  it('reproduces the reported 2-hour window and still fills Top-Off', () => {
    // The reported athlete profile: 12 mi run, 1h48m, at a 2-hour pre-window.
    const targets = calculatePreWorkoutTargets(70, 2.0, false, 'medium', 'moderate');

    // Precondition: this window really does schedule all three tiers, which is
    // what distinguishes this bug from the working 90-minute case.
    assertEquals(getActiveSubPhases(2.0), ['meal', 'snack', 'top_up']);

    const results = selectPreWorkoutFoods(
      targets,
      2.0,
      'none',
      STARVING_FOODS,
      [WATER],
      [NUUN],
    );

    const topUp = topUpOf(results);
    assert(
      !isEmptySlot(topUp),
      'Top-Off shipped empty — the exact defect in bug 3ace3fdb',
    );
    assert(
      topUp.total_fluid_ml >= MIN_TOP_UP_FLUID_ML,
      `Top-Off carried ${topUp.total_fluid_ml}ml of fluid, below the ` +
        `${MIN_TOP_UP_FLUID_ML}ml floor ("should at least have a half a cup of water")`,
    );
  });

  it('falls back to water specifically when the carb ceiling starves the slot', () => {
    const targets = calculatePreWorkoutTargets(70, 2.0, false, 'medium', 'moderate');
    const results = selectPreWorkoutFoods(
      targets,
      2.0,
      'none',
      STARVING_FOODS,
      [WATER],
      [NUUN],
    );

    const topUp = topUpOf(results);
    // When no food could fit, the floor is the thing that rescues the slot —
    // and it must be recognisable water, not a zero-fluid placeholder.
    if (topUp.primary === null && topUp.add_ons.length === 0) {
      assert(topUp.drink, 'starved Top-Off should still carry a drink');
      assertEquals(topUp.drink.base_category, 'water');
      assert(topUp.drink.fluid_ml >= MIN_TOP_UP_FLUID_ML);
    }
  });

  it('synthesizes the floor when no drink template is eligible at all', () => {
    const targets = calculatePreWorkoutTargets(70, 2.0, false, 'medium', 'moderate');
    const results = selectPreWorkoutFoods(
      targets,
      2.0,
      'none',
      STARVING_FOODS,
      [], // no drinks in the catalog
      [],
    );

    const topUp = topUpOf(results);
    assert(!isEmptySlot(topUp), 'Top-Off shipped empty with no drink catalog');
    assert(topUp.total_fluid_ml >= MIN_TOP_UP_FLUID_ML);
  });

  it('holds across a matrix of long-window athlete profiles', () => {
    const weights = [50, 70, 90, 110];
    const hours = [1.5, 2.0, 2.5, 3.0];
    const sweats = ['low', 'medium', 'high'];
    const envs = ['moderate', 'hot'];

    for (const weight of weights) {
      for (const hoursBefore of hours) {
        for (const sweat of sweats) {
          for (const env of envs) {
          const targets = calculatePreWorkoutTargets(
            weight,
            hoursBefore,
            false,
            sweat,
            env,
          );
          const results = selectPreWorkoutFoods(
            targets,
            hoursBefore,
            'none',
            STARVING_FOODS,
            [WATER],
            [NUUN],
          );

          const label =
            `${weight}kg / ${hoursBefore}h before / ${sweat} sweat / ${env}`;
          const topUp = topUpOf(results, label);

          // The invariant: the slot is never empty.
          assert(!isEmptySlot(topUp), `Top-Off empty for ${label}`);

          // The fluid floor is scoped to the case it rescues. A Top-Off that
          // landed real food is already non-empty and is left alone — making
          // every Top-Off carry water regardless is part of the 60/30/10
          // distribution rework, not this fix.
          const hasFood =
            topUp.primary !== null ||
            topUp.stack !== undefined && topUp.stack !== null ||
            topUp.add_ons.length > 0;
          if (!hasFood) {
            assert(
              topUp.total_fluid_ml >= MIN_TOP_UP_FLUID_ML,
              `foodless Top-Off carried ${topUp.total_fluid_ml}ml, below the ` +
                `${MIN_TOP_UP_FLUID_ML}ml floor for ${label}`,
            );
          }
          }
        }
      }
    }
  });

  it('does not disturb a plan whose Top-Off already has food', () => {
    // A small, fast top-off food that comfortably fits under the ceiling: the
    // floor must not fire, and must not staple extra water onto a good plan.
    const SMALL_DATES = makeTemplate({
      id: 'dates',
      name: 'Medjool Dates',
      base_category: 'fruit',
      time_window: '< 30 min',
      digestion_speed: 'fast',
      carbs_per_serving: 12,
      protein_per_serving: 0,
      fat_per_serving: 0,
      sodium_mg: 0,
      fluid_ml: 0,
      min_servings: 0.5,
      max_servings: 2,
      component_food_names: ['medjool_dates'],
      component_quantities: { medjool_dates: 1 },
    });

    const targets = calculatePreWorkoutTargets(70, 2.0, false, 'medium', 'moderate');
    const results = selectPreWorkoutFoods(
      targets,
      2.0,
      'none',
      [BIG_MEAL, BAR_SNACK, SMALL_DATES],
      [WATER],
      [NUUN],
    );

    const topUp = topUpOf(results);
    assert(!isEmptySlot(topUp));
    assert(
      topUp.primary !== null || topUp.add_ons.length > 0,
      'Top-Off should have selected real food when a small template fits',
    );
  });
});
