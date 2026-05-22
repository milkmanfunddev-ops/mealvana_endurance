/**
 * Integration Tests for Liked-Food Bonus (#24)
 *
 * Validates that scoreFormula's 15% effective-gap reduction actually fires when
 * a user's liked-food list contains display-formatted strings (e.g.
 * "Oatmeal (½ cup dry)") that match a template's snake_case component
 * (e.g. "oatmeal").
 *
 * The unit tests in pre-workout-constants.test.ts prove that normalizeToken
 * produces the right canonical token. These tests prove the resulting bonus
 * actually reaches scoreFormula's output.
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/pre-workout-liked-bonus.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { scoreFormula } from './pre-workout-scoring.ts';
import type { PreWorkoutTemplate, PlanState } from './types.ts';

// ============================================================================
// Test Fixtures
// ============================================================================

function makeTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
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

function makeState(): PlanState {
  return {
    used_foods: new Set(),
    sports_drink_used: false,
    used_categories: new Set(),
    carbs_delivered: 0,
    protein_delivered: 0,
    sodium_delivered: 0,
    fluid_delivered: 0,
    carbs_target: 60,
    carbs_low: 50,
    carbs_high: 80,
    protein_target: 10,
    protein_low: 5,
    protein_high: 20,
    sodium_target: 200,
    sodium_low: 150,
    sodium_high: 400,
    fluid_target: 300,
    fluid_low: 200,
    fluid_high: 500,
  };
}

// A template the user "likes" — single oatmeal component.
// max_servings=2 ensures servings get clamped against carbTarget=90 so there
// is a real gap for the 15% bonus to discount (gap = 90 - 60 = 30).
const OATMEAL_TEMPLATE = makeTemplate({
  id: 'oatmeal',
  name: 'Oatmeal',
  component_food_names: ['oatmeal'],
  max_servings: 2,
});

// ============================================================================
// The bug surface: parens-format liked food should fire the 15% bonus
// ============================================================================

Deno.test('liked-food bonus fires when liked food is display-formatted "Oatmeal (½ cup dry)"', () => {
  const state = makeState();
  // carbTarget=90, max_servings=2, carbs_per_serving=30 → 2 servings × 30 = 60
  // delivered, gap = 90 − 60 = 30 (Math.abs already in scoreFormula).
  const adjustedTarget = 90;

  const withLike = scoreFormula(
    OATMEAL_TEMPLATE,
    adjustedTarget,
    state,
    /* dislikedSet */ new Set(),
    /* likedFoods */ ['Oatmeal (½ cup dry)'],
  );
  const withoutLike = scoreFormula(
    OATMEAL_TEMPLATE,
    adjustedTarget,
    state,
    new Set(),
    [],
  );

  // 15% bonus = effectiveGap × 0.85, so the with-like gap must be smaller.
  assert(
    withLike.gap < withoutLike.gap,
    `expected liked-food bonus to reduce gap; got with=${withLike.gap}, without=${withoutLike.gap}`,
  );

  // And it should be exactly 0.85× of the without-like gap.
  assertEquals(
    Math.round(withLike.gap * 100) / 100,
    Math.round(withoutLike.gap * 0.85 * 100) / 100,
  );
});

Deno.test('liked-food bonus fires for snake_case liked foods (no regression)', () => {
  const state = makeState();
  const adjustedTarget = 90;

  const withLike = scoreFormula(
    OATMEAL_TEMPLATE,
    adjustedTarget,
    state,
    new Set(),
    ['oatmeal'],
  );
  const withoutLike = scoreFormula(
    OATMEAL_TEMPLATE,
    adjustedTarget,
    state,
    new Set(),
    [],
  );

  assert(withLike.gap < withoutLike.gap);
});

Deno.test('liked-food bonus does NOT fire when no template component matches', () => {
  const state = makeState();
  const adjustedTarget = 90;

  const withUnrelatedLike = scoreFormula(
    OATMEAL_TEMPLATE,
    adjustedTarget,
    state,
    new Set(),
    ['Bagel (large)'], // user likes bagels, but template has only oatmeal
  );
  const withoutLike = scoreFormula(
    OATMEAL_TEMPLATE,
    adjustedTarget,
    state,
    new Set(),
    [],
  );

  assertEquals(withUnrelatedLike.gap, withoutLike.gap);
});

Deno.test('liked-food bonus fires when at least one component matches a multi-component template', () => {
  const state = makeState();
  const adjustedTarget = 90;

  const oatmealRaisins = makeTemplate({
    id: 'oatmeal-raisins',
    name: 'Oatmeal + Raisins',
    component_food_names: ['oatmeal', 'raisins'],
    max_servings: 2,
  });

  const withLike = scoreFormula(
    oatmealRaisins,
    adjustedTarget,
    state,
    new Set(),
    ['Oatmeal (½ cup dry)'], // matches one of two components
  );
  const withoutLike = scoreFormula(
    oatmealRaisins,
    adjustedTarget,
    state,
    new Set(),
    [],
  );

  assert(withLike.gap < withoutLike.gap);
});
