/**
 * Regression tests for #15: when an athlete dislikes the standard Pass 1.5
 * fallbacks (banana, sports drink, sports drink mix) AND the top-up-only
 * window leaves no other phase to redistribute to, the algorithm must still
 * deliver carbs by trying the universal fallback chain (dates → applesauce →
 * raisins) before giving up.
 *
 * Run with:
 *   deno test --no-check --allow-env --allow-net --allow-read \
 *     supabase/functions/generate-macros-v4/pre-workout-fallback-foods.test.ts
 */

import { assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { selectPreWorkoutFoods } from './pre-workout.ts';
import type { PreWorkoutTemplate, PreWorkoutTargets } from './types.ts';

function makeTopUpTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'Quick Grab',
    time_window: '0-30 min',
    digestion_speed: 'fast',
    allergens: [],
    serving_unit: 'piece',
    min_servings: 1,
    max_servings: 2,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 25,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 40,
    fluid_ml: 0,
    template_type: 'food',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

const GEL = makeTopUpTemplate({
  id: 'gel',
  name: 'Energy Gel',
  component_food_names: ['energy_gel'],
});

const CHEWS = makeTopUpTemplate({
  id: 'chews',
  name: 'Energy Chews',
  component_food_names: ['energy_chews'],
});

const PICKY_TOPUP_TARGETS: PreWorkoutTargets = {
  carbs_g: 30,
  carbs_low_g: 25,
  carbs_high_g: 40,
  protein_g: 0,
  protein_low_g: 0,
  protein_high_g: 10,
  fat_g: 0,
  sodium_mg: 100,
  sodium_low_mg: 0,
  sodium_high_mg: 400,
  water_ml: 250,
  water_low_ml: 0,
  water_high_ml: 500,
  meal_type: 'top_up',
};

Deno.test(
  '#15: picky athlete (dislikes gels/chews/banana/sports drink) gets dates fallback in top-up-only window',
  () => {
    const results = selectPreWorkoutFoods(
      PICKY_TOPUP_TARGETS,
      /* hoursBefore */ 0.5,
      /* diet */ 'none',
      /* foodTemplates */ [GEL, CHEWS],
      /* drinkTemplates */ [],
      /* electrolyteTemplates */ [],
      /* likedFoods */ [],
      /* dislikedFoods */ ['energy_gel', 'energy_chews', 'banana', 'sports_drink', 'sports_drink_mix'],
      /* allergies */ [],
    );

    const totalCarbs = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
    assert(
      totalCarbs >= PICKY_TOPUP_TARGETS.carbs_low_g,
      `expected carbs >= ${PICKY_TOPUP_TARGETS.carbs_low_g}g (carbs_low), got ${totalCarbs}g`,
    );

    const addOnTypes = results.flatMap((p) => p.add_ons.map((a) => a.type));
    const usedFallback = addOnTypes.some((t) => t === 'dates' || t === 'applesauce' || t === 'raisins');
    assert(
      usedFallback,
      `expected dates/applesauce/raisins fallback to fire, got add-ons: ${JSON.stringify(addOnTypes)}`,
    );
  },
);

Deno.test(
  '#15: when dates ALSO disliked, applesauce or raisins closes the gap',
  () => {
    const results = selectPreWorkoutFoods(
      PICKY_TOPUP_TARGETS,
      0.5,
      'none',
      [GEL, CHEWS],
      [],
      [],
      [],
      ['energy_gel', 'energy_chews', 'banana', 'sports_drink', 'sports_drink_mix', 'dates'],
      [],
    );

    const totalCarbs = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
    assert(
      totalCarbs >= PICKY_TOPUP_TARGETS.carbs_low_g,
      `expected carbs >= ${PICKY_TOPUP_TARGETS.carbs_low_g}g, got ${totalCarbs}g`,
    );

    const addOnTypes = results.flatMap((p) => p.add_ons.map((a) => a.type));
    assert(
      !addOnTypes.includes('dates'),
      `dates should be filtered out when disliked, got: ${JSON.stringify(addOnTypes)}`,
    );
    assert(
      addOnTypes.includes('applesauce') || addOnTypes.includes('raisins'),
      `expected applesauce or raisins to fire when dates disliked, got: ${JSON.stringify(addOnTypes)}`,
    );
  },
);

Deno.test(
  '#15: no-regression — when banana is available, fallback chain does NOT fire',
  () => {
    const results = selectPreWorkoutFoods(
      PICKY_TOPUP_TARGETS,
      0.5,
      'none',
      [GEL, CHEWS],
      [],
      [],
      [],
      /* dislikedFoods */ ['energy_gel', 'energy_chews'],
      [],
    );

    const totalCarbs = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
    assert(
      totalCarbs >= PICKY_TOPUP_TARGETS.carbs_low_g,
      `expected carbs >= ${PICKY_TOPUP_TARGETS.carbs_low_g}g, got ${totalCarbs}g`,
    );

    const addOnTypes = results.flatMap((p) => p.add_ons.map((a) => a.type));
    assert(
      addOnTypes.includes('banana'),
      `expected banana to be used preferentially over fallbacks, got: ${JSON.stringify(addOnTypes)}`,
    );
  },
);
