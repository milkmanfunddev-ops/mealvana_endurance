/**
 * Tests for generate-nutrition-plan-v2 Edge Function
 *
 * Tests template selection, scaling, drink selection, and LP integration.
 */

import { assertEquals, assert, assertExists } from 'https://deno.land/std@0.224.0/assert/mod.ts';

// Template modules under test
import { getActiveSubPhases, splitPreWorkoutTargets, getSubPhaseTimingLabel } from '../_shared/nutrition/templates/pre-workout-targets.ts';
import { filterTemplatesByDiet, filterDrinksByDiet, scoreTemplatesByPreference } from '../_shared/nutrition/templates/diet-filter.ts';
import { scaleTemplate, formatQuantity } from '../_shared/nutrition/templates/scaling.ts';
import { selectTemplateChain, selectAlternativeTemplate } from '../_shared/nutrition/templates/meal-chain.ts';
import { selectDrinksForPhases } from '../_shared/nutrition/templates/drink-selection.ts';

import type { Template, TemplateFoodItem, DrinkPoolItem, SubPhaseType } from '../_shared/nutrition/templates/types.ts';

// ============================================================================
// Test Fixtures
// ============================================================================

function makeTemplate(overrides: Partial<Template> = {}): Template {
  return {
    id: 'test-template-1',
    name: 'Test Toast + PB',
    slug: 'test-toast-pb',
    phase: 'before',
    timing_window: '3-4 hours',
    timing_min_minutes: 180,
    timing_max_minutes: 240,
    meal_type: 'full_meal',
    base_category: 'Toast / Bread',
    digestion_speed: 'medium',
    allergens: ['gluten', 'peanuts'],
    excluded_diets: ['paleo', 'keto'],
    notes: null,
    foods: [
      makeFoodItem({ food_name: 'white_bread', carbs_g: 13, default_servings: 2 }),
      makeFoodItem({ food_name: 'peanut_butter', carbs_g: 3, protein_g: 4, fat_g: 8, default_servings: 1.5 }),
      makeFoodItem({ food_name: 'banana', carbs_g: 27, default_servings: 1 }),
    ],
    food_names: ['white_bread', 'peanut_butter', 'banana'],
    total_carbs_g: 56.5,
    total_protein_g: 10,
    total_fat_g: 14,
    total_sodium_mg: 300,
    total_fluid_ml: 50,
    total_calories: 350,
    validation_status: 'validated',
    is_active: true,
    sort_order: 1,
    ...overrides,
  };
}

function makeFoodItem(overrides: Partial<TemplateFoodItem> = {}): TemplateFoodItem {
  return {
    food_id: 'food-' + Math.random().toString(36).slice(2, 8),
    food_name: 'test_food',
    display_name: 'Test Food',
    serving_size: '1 slice',
    default_servings: 1,
    min_servings: 0.5,
    max_servings: 4,
    carbs_g: 15,
    protein_g: 2,
    fat_g: 1,
    sodium_mg: 100,
    fluid_ml: 10,
    calories: 70,
    ...overrides,
  };
}

function makeDrink(overrides: Partial<DrinkPoolItem> = {}): DrinkPoolItem {
  return {
    id: 'drink-' + Math.random().toString(36).slice(2, 8),
    name: 'water',
    display_name: 'Water',
    serving_size: '1 cup (240ml)',
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    fluid_ml: 240,
    calories: 0,
    caffeine_mg: null,
    is_electrolyte: false,
    drink_pool_phases: ['meal', 'snack', 'top_up'],
    ...overrides,
  };
}

// ============================================================================
// Pre-Workout Targets Tests
// ============================================================================

Deno.test('getActiveSubPhases - 3+ hours returns all three phases', () => {
  assertEquals(getActiveSubPhases(3.5), ['meal', 'snack', 'top_up']);
  assertEquals(getActiveSubPhases(4.0), ['meal', 'snack', 'top_up']);
  assertEquals(getActiveSubPhases(2.5), ['meal', 'snack', 'top_up']);
});

Deno.test('getActiveSubPhases - 1-2.5 hours returns snack + top_up', () => {
  assertEquals(getActiveSubPhases(2.0), ['snack', 'top_up']);
  assertEquals(getActiveSubPhases(1.5), ['snack', 'top_up']);
  assertEquals(getActiveSubPhases(1.0), ['snack', 'top_up']);
});

Deno.test('getActiveSubPhases - <1 hour returns top_up only', () => {
  assertEquals(getActiveSubPhases(0.5), ['top_up']);
  assertEquals(getActiveSubPhases(0.0), ['top_up']);
});

Deno.test('splitPreWorkoutTargets - 3 phases sum to total', () => {
  const total = { carbs_g: 100, protein_g: 20, fat_g: 10, sodium_mg: 500, water_ml: 800 };
  const result = splitPreWorkoutTargets(total, 3.0);

  assertEquals(result.size, 3);

  let sumCarbs = 0;
  let sumProtein = 0;
  for (const [, targets] of result) {
    sumCarbs += targets.carbs_g;
    sumProtein += targets.protein_g;
  }

  // Should approximately sum to total (allowing rounding)
  assert(Math.abs(sumCarbs - 100) < 1, `Carbs sum ${sumCarbs} != 100`);
  assert(Math.abs(sumProtein - 20) < 1, `Protein sum ${sumProtein} != 20`);
});

Deno.test('splitPreWorkoutTargets - 2 phases redistribute meal budget', () => {
  const total = { carbs_g: 60, protein_g: 10, fat_g: 5, sodium_mg: 300, water_ml: 500 };
  const result = splitPreWorkoutTargets(total, 1.5); // snack + top_up

  assertEquals(result.size, 2);
  assert(result.has('snack'));
  assert(result.has('top_up'));
  assert(!result.has('meal'));

  // Snack should get more carbs than top_up
  assert(result.get('snack')!.carbs_g > result.get('top_up')!.carbs_g);
});

// ============================================================================
// Diet Filter Tests
// ============================================================================

Deno.test('filterTemplatesByDiet - excludes paleo templates for paleo diet', () => {
  const templates = [
    makeTemplate({ excluded_diets: ['paleo', 'keto'] }),
    makeTemplate({ id: '2', excluded_diets: [] }),
  ];

  const filtered = filterTemplatesByDiet(templates, 'paleo');
  assertEquals(filtered.length, 1);
  assertEquals(filtered[0].id, '2');
});

Deno.test('filterTemplatesByDiet - excludes by allergen overlap', () => {
  const templates = [
    makeTemplate({ allergens: ['gluten', 'peanuts'] }),
    makeTemplate({ id: '2', allergens: ['dairy'] }),
    makeTemplate({ id: '3', allergens: [] }),
  ];

  const filtered = filterTemplatesByDiet(templates, undefined, ['gluten']);
  assertEquals(filtered.length, 2);
});

Deno.test('filterTemplatesByDiet - no filters returns all', () => {
  const templates = [makeTemplate(), makeTemplate({ id: '2' })];
  const filtered = filterTemplatesByDiet(templates);
  assertEquals(filtered.length, 2);
});

Deno.test('scoreTemplatesByPreference - liked foods boost score', () => {
  const templates = [
    makeTemplate({ id: '1', food_names: ['oatmeal', 'banana'] }),
    makeTemplate({ id: '2', food_names: ['white_bread', 'jam'] }),
  ];

  const scored = scoreTemplatesByPreference(templates, ['oatmeal', 'banana']);
  assertEquals(scored[0].id, '1'); // Should be ranked first
});

Deno.test('scoreTemplatesByPreference - excludes all-disliked templates', () => {
  const templates = [
    makeTemplate({ id: '1', food_names: ['oatmeal', 'banana'] }),
    makeTemplate({ id: '2', food_names: ['liver', 'sardines'] }),
  ];

  const scored = scoreTemplatesByPreference(templates, [], ['liver', 'sardines']);
  assertEquals(scored.length, 1);
  assertEquals(scored[0].id, '1');
});

// ============================================================================
// Scaling Tests
// ============================================================================

Deno.test('scaleTemplate - scales to meet carb target', () => {
  const foods = [
    makeFoodItem({ carbs_g: 20, default_servings: 1, min_servings: 0.5, max_servings: 4 }),
    makeFoodItem({ carbs_g: 10, default_servings: 1, min_servings: 0.5, max_servings: 4 }),
  ];

  const targets = { carbs_g: 60, protein_g: 0, fat_g: 0, sodium_mg: 200, water_ml: 300 };
  const result = scaleTemplate(foods, targets);

  // Default is 30g carbs (20+10). Target is 60g. Expect ~2x multiplier.
  assert(result.total_carbs >= 45, `Carbs ${result.total_carbs} should be >= 45`);
  assert(result.total_carbs <= 75, `Carbs ${result.total_carbs} should be <= 75`);
});

Deno.test('scaleTemplate - respects min/max servings', () => {
  const foods = [
    makeFoodItem({ default_servings: 1, min_servings: 1, max_servings: 2 }),
  ];

  const targets = { carbs_g: 200, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 };
  const result = scaleTemplate(foods, targets);

  // Even with huge target, max_servings = 2 should limit the scaling
  assert(result.foods[0].quantity <= 2, `Quantity ${result.foods[0].quantity} should be <= 2`);
});

Deno.test('scaleTemplate - subtracts drink carbs from target', () => {
  const foods = [
    makeFoodItem({ carbs_g: 20, default_servings: 1, min_servings: 0.25, max_servings: 4 }),
  ];

  const targets = { carbs_g: 40, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 };

  // Without drink: expect ~2x (40g target / 20g per serving)
  const withoutDrink = scaleTemplate(foods, targets, 0);

  // With 20g drink carbs: expect ~1x (40g - 20g drink = 20g food target / 20g per serving)
  const withDrink = scaleTemplate(foods, targets, 20);

  assert(withoutDrink.multiplier > withDrink.multiplier,
    `Without drink multiplier (${withoutDrink.multiplier}) should be > with drink (${withDrink.multiplier})`);
});

Deno.test('formatQuantity - formats friendly fractions', () => {
  assertEquals(formatQuantity(0.5), '1/2');
  assertEquals(formatQuantity(1), '1');
  assertEquals(formatQuantity(1.5), '1 1/2');
  assertEquals(formatQuantity(2), '2');
  assertEquals(formatQuantity(0.33), '0.3'); // No longer uses 1/3 fractions
});

// ============================================================================
// Meal Chain Tests
// ============================================================================

Deno.test('selectTemplateChain - selects non-conflicting templates', () => {
  const templates = [
    makeTemplate({ id: '1', meal_type: 'full_meal', base_category: 'Toast / Bread', food_names: ['white_bread', 'peanut_butter'] }),
    makeTemplate({ id: '2', meal_type: 'snack', base_category: 'Bagel', food_names: ['bagel', 'cream_cheese'] }),
    makeTemplate({ id: '3', meal_type: 'top_up', base_category: 'Fruit', food_names: ['banana', 'honey'] }),
  ];

  const chain = selectTemplateChain(templates, ['meal', 'snack', 'top_up']);

  assertEquals(chain.size, 3);
  assertExists(chain.get('meal'));
  assertExists(chain.get('snack'));
  assertExists(chain.get('top_up'));
});

Deno.test('selectTemplateChain - avoids same base_category', () => {
  const templates = [
    makeTemplate({ id: '1', meal_type: 'full_meal', base_category: 'Toast / Bread' }),
    makeTemplate({ id: '2', meal_type: 'snack', base_category: 'Toast / Bread' }), // same category
    makeTemplate({ id: '3', meal_type: 'snack', base_category: 'Granola' }), // different
    makeTemplate({ id: '4', meal_type: 'top_up', base_category: 'Fruit' }),
  ];

  const chain = selectTemplateChain(templates, ['meal', 'snack', 'top_up']);

  // Snack should be the Granola one, not Toast/Bread
  assertEquals(chain.get('snack')?.id, '3');
});

Deno.test('selectTemplateChain - avoids food name overlap except staples', () => {
  const templates = [
    makeTemplate({ id: '1', meal_type: 'full_meal', base_category: 'Toast', food_names: ['white_bread', 'jam'] }),
    makeTemplate({ id: '2', meal_type: 'snack', base_category: 'Granola', food_names: ['granola', 'jam'] }), // overlap: jam
    makeTemplate({ id: '3', meal_type: 'snack', base_category: 'Yogurt', food_names: ['yogurt', 'banana'] }), // banana is staple
    makeTemplate({ id: '4', meal_type: 'top_up', base_category: 'Fruit' }),
  ];

  const chain = selectTemplateChain(templates, ['meal', 'snack', 'top_up']);

  // Snack should be Yogurt (banana is staple, allowed to repeat), not Granola (jam conflicts)
  assertEquals(chain.get('snack')?.id, '3');
});

// ============================================================================
// Drink Selection Tests
// ============================================================================

Deno.test('selectDrinksForPhases - selects phase-appropriate drinks', () => {
  const drinks = [
    makeDrink({ name: 'coffee', drink_pool_phases: ['meal', 'snack'], caffeine_mg: 95 }),
    makeDrink({ name: 'sports_drink', drink_pool_phases: ['snack', 'top_up'], carbs_g: 14, fluid_ml: 240, is_electrolyte: true }),
    makeDrink({ name: 'water', drink_pool_phases: ['meal', 'snack', 'top_up'], fluid_ml: 240 }),
  ];

  const targets = new Map<SubPhaseType, { carbs_g: number; water_ml: number }>([
    ['meal', { carbs_g: 60, water_ml: 300 }],
    ['snack', { carbs_g: 25, water_ml: 200 }],
    ['top_up', { carbs_g: 15, water_ml: 200 }],
  ]);

  const selected = selectDrinksForPhases(drinks, ['meal', 'snack', 'top_up'], targets);

  assertEquals(selected.size, 3);

  // Every sub-phase should have a drink
  for (const [phase, drink] of selected) {
    assertExists(drink, `${phase} should have a drink`);
  }
});

Deno.test('selectDrinksForPhases - avoids repeating drinks except water', () => {
  const drinks = [
    makeDrink({ name: 'orange_juice', drink_pool_phases: ['meal', 'snack'], carbs_g: 26, fluid_ml: 240 }),
    makeDrink({ name: 'water', drink_pool_phases: ['meal', 'snack', 'top_up'], fluid_ml: 240 }),
  ];

  const targets = new Map<SubPhaseType, { carbs_g: number; water_ml: number }>([
    ['meal', { carbs_g: 60, water_ml: 300 }],
    ['snack', { carbs_g: 25, water_ml: 200 }],
  ]);

  const selected = selectDrinksForPhases(drinks, ['meal', 'snack'], targets);

  // OJ should be selected for meal (higher score), water for snack (OJ already used)
  const mealDrink = selected.get('meal');
  const snackDrink = selected.get('snack');

  assertExists(mealDrink);
  assertExists(snackDrink);

  // They shouldn't be the same drink (unless water)
  if (mealDrink.food_id === snackDrink.food_id) {
    // Only acceptable if it's water
    assertEquals(mealDrink.display_name, 'Water');
  }
});

// ============================================================================
// Integration Tests (would require Supabase client)
// ============================================================================

// These tests require actual database access and should be run
// with SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables

Deno.test({
  name: 'Integration: full plan generation',
  ignore: !Deno.env.get('SUPABASE_URL'), // Skip if no Supabase connection
  async fn() {
    const response = await fetch(
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/generate-nutrition-plan-v2`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_ANON_KEY')}`,
        },
        body: JSON.stringify({
          device_id: 'test-device-id',
          activity_type: 'running',
          hours_before: 3.0,
          weight_kg: 70,
          macro_targets: {
            pre_run: { carbs_g: 100, protein_g: 20, sodium_mg: 500, water_ml: 800 },
            during_run: { carbs_g: 60, sodium_mg: 500, water_ml: 600 },
            post_run: { carbs_g: 80, protein_g: 30, sodium_mg: 400, water_ml: 500 },
          },
        }),
      },
    );

    const data = await response.json();
    assertEquals(data.success, true);
    assertExists(data.plan.before);
    assertExists(data.plan.during);
    assertExists(data.plan.after);

    // Before should have sub-phases
    const before = data.plan.before;
    assertExists(before.meal, 'Should have meal sub-phase for 3h window');
    assertExists(before.snack, 'Should have snack sub-phase');
    assertExists(before.top_up, 'Should have top_up sub-phase');

    // Each sub-phase should have foods
    assert(before.meal.foods.length > 0, 'Meal should have foods');
    assert(before.snack.foods.length > 0, 'Snack should have foods');
    assert(before.top_up.foods.length > 0, 'Top-up should have foods');
  },
});
