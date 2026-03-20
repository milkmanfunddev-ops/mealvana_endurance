/**
 * Local Unit Tests for Before-Phase Template Filtering
 *
 * Tests getEligibleTemplates() directly with mock template data.
 * Documents known filtering bugs (vegan/vegetarian, drink/electrolyte bypass).
 *
 * Run with:
 *   deno test --allow-write supabase/functions/generate-nutrition-plan-v3/before-phase-filtering.test.ts
 */

import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeEach, afterEach } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { getEligibleTemplates } from '../generate-macros-v4/pre-workout.ts';
import type { PreWorkoutTemplate } from '../generate-macros-v4/types.ts';
import { LogCapture } from '../_shared/nutrition/test-utils.ts';

// ============================================================================
// Test Setup
// ============================================================================

let logs: LogCapture;

function setup() {
  logs = new LogCapture();
  logs.start();
}

function teardown() {
  logs.stop();
  logs.clear();
}

// ============================================================================
// Mock Template Factory
// ============================================================================

let _templateCounter = 0;

function makeTemplate(overrides: Partial<PreWorkoutTemplate> & { name: string }): PreWorkoutTemplate {
  _templateCounter++;
  return {
    id: overrides.id ?? `tmpl-${_templateCounter}`,
    name: overrides.name,
    base_category: overrides.base_category ?? 'grain',
    time_window: overrides.time_window ?? '1.5-3 hours',
    digestion_speed: overrides.digestion_speed ?? 'medium',
    allergens: overrides.allergens ?? [],
    serving_unit: overrides.serving_unit ?? 'serving',
    min_servings: overrides.min_servings ?? 1,
    max_servings: overrides.max_servings ?? 3,
    plus_banana: overrides.plus_banana ?? false,
    plus_sports_drink: overrides.plus_sports_drink ?? false,
    carbs_per_serving: overrides.carbs_per_serving ?? 30,
    protein_per_serving: overrides.protein_per_serving ?? 5,
    fat_per_serving: overrides.fat_per_serving ?? 2,
    sodium_mg: overrides.sodium_mg ?? 100,
    fluid_ml: overrides.fluid_ml ?? 0,
    template_type: overrides.template_type ?? 'food',
    is_active: overrides.is_active ?? true,
    component_food_names: overrides.component_food_names ?? [],
    component_quantities: overrides.component_quantities ?? {},
  };
}

// ============================================================================
// Mock Template Catalogs
// ============================================================================

function makeMealTemplates(): PreWorkoutTemplate[] {
  return [
    makeTemplate({
      name: 'Oatmeal with Banana',
      time_window: '1.5-3 hours',
      allergens: ['Gluten'],
      component_food_names: ['oatmeal', 'banana'],
      carbs_per_serving: 45,
      protein_per_serving: 8,
    }),
    makeTemplate({
      name: 'Toast with PB',
      time_window: '1.5-3 hours',
      allergens: ['Gluten', 'Peanut'],
      component_food_names: ['toast', 'peanut_butter'],
      carbs_per_serving: 35,
      protein_per_serving: 10,
    }),
    makeTemplate({
      name: 'Greek Yogurt Bowl',
      time_window: '1.5-3 hours',
      allergens: ['Dairy'],
      component_food_names: ['greek_yogurt', 'granola', 'honey'],
      carbs_per_serving: 40,
      protein_per_serving: 15,
    }),
    makeTemplate({
      name: 'Rice Cakes with Jam',
      time_window: '1.5-3 hours',
      allergens: [],
      component_food_names: ['rice_cake', 'jam'],
      carbs_per_serving: 30,
      protein_per_serving: 2,
    }),
    makeTemplate({
      name: 'Banana',
      time_window: '1.5-3 hours',
      allergens: [],
      component_food_names: ['banana'],
      carbs_per_serving: 27,
      protein_per_serving: 1,
    }),
    makeTemplate({
      name: 'Egg on Toast',
      time_window: '1.5-3 hours',
      allergens: ['Gluten', 'Eggs'],
      component_food_names: ['egg', 'toast'],
      carbs_per_serving: 25,
      protein_per_serving: 12,
    }),
  ];
}

function makeDrinkTemplates(): PreWorkoutTemplate[] {
  return [
    makeTemplate({
      name: 'Sports Drink',
      time_window: '1.5-3 hours',
      allergens: [],
      template_type: 'drink',
      component_food_names: ['sports_drink'],
      carbs_per_serving: 15,
      fluid_ml: 240,
    }),
    makeTemplate({
      name: 'Chocolate Milk',
      time_window: '1.5-3 hours',
      allergens: ['Dairy'],
      template_type: 'drink',
      component_food_names: ['chocolate_milk'],
      carbs_per_serving: 26,
      protein_per_serving: 8,
      fluid_ml: 240,
    }),
  ];
}

function makeElectrolyteTemplates(): PreWorkoutTemplate[] {
  return [
    makeTemplate({
      name: 'Electrolyte Tablet',
      time_window: '1.5-3 hours',
      allergens: [],
      template_type: 'electrolyte',
      component_food_names: ['electrolyte_tablet'],
      carbs_per_serving: 1,
      sodium_mg: 350,
    }),
  ];
}

// ============================================================================
// Allergen Filtering
// ============================================================================

describe('Before Phase Filtering — Allergen Filtering', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should exclude gluten-containing templates for gluten allergy', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'none', [], ['Gluten']);

    await logs.writeToFile('before-allergen-gluten', `Allergen: Gluten`);

    const names = result.map(t => t.name);
    console.log(`[TEST] Remaining after gluten filter: ${names.join(', ')}`);

    assert(!names.includes('Oatmeal with Banana'), 'Oatmeal should be excluded (contains Gluten)');
    assert(!names.includes('Toast with PB'), 'Toast should be excluded (contains Gluten)');
    assert(!names.includes('Egg on Toast'), 'Egg on Toast should be excluded (contains Gluten)');
    assert(names.includes('Rice Cakes with Jam'), 'Rice Cakes should remain (no Gluten)');
    assert(names.includes('Banana'), 'Banana should remain (no allergens)');
  });

  it('should handle multiple allergens with stacking', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'none', [], ['Gluten', 'Dairy']);

    await logs.writeToFile('before-allergen-multi', `Allergens: Gluten + Dairy`);

    const names = result.map(t => t.name);
    console.log(`[TEST] Remaining after Gluten+Dairy filter: ${names.join(', ')}`);

    assert(!names.includes('Oatmeal with Banana'), 'Oatmeal excluded (Gluten)');
    assert(!names.includes('Greek Yogurt Bowl'), 'Yogurt excluded (Dairy)');
    assert(names.includes('Rice Cakes with Jam'), 'Rice Cakes should remain');
    assert(names.includes('Banana'), 'Banana should remain');
  });

  it('should handle case-insensitive allergen matching', async () => {
    const templates = makeMealTemplates();
    // Pass lowercase allergens — templates have capitalized allergens
    const result = getEligibleTemplates(templates, 'meal', 'none', [], ['gluten']);

    await logs.writeToFile('before-allergen-case', `Allergen: gluten (lowercase)`);

    const names = result.map(t => t.name);
    console.log(`[TEST] Case-insensitive filter result: ${names.join(', ')}`);

    // Case-insensitive matching should work
    assert(!names.includes('Oatmeal with Banana'), 'Should exclude Oatmeal even with lowercase allergen');
  });

  it('should handle peanut+tree nut allergen stacking', async () => {
    const templates = [
      ...makeMealTemplates(),
      makeTemplate({
        name: 'Almond Butter Toast',
        time_window: '1.5-3 hours',
        allergens: ['Gluten', 'Tree Nuts'],
        component_food_names: ['toast', 'almond_butter'],
      }),
    ];
    const result = getEligibleTemplates(templates, 'meal', 'none', [], ['Peanut', 'Tree Nuts']);

    await logs.writeToFile('before-allergen-nuts', `Allergens: Peanut + Tree Nuts`);

    const names = result.map(t => t.name);
    console.log(`[TEST] After nut exclusion: ${names.join(', ')}`);

    assert(!names.includes('Toast with PB'), 'PB toast excluded (Peanut)');
    assert(!names.includes('Almond Butter Toast'), 'Almond toast excluded (Tree Nuts)');
  });
});

// ============================================================================
// Diet Filtering Bugs (documents known issues)
// ============================================================================

describe('Before Phase Filtering — Diet Filtering', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should filter gluten-free diet correctly', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'gluten-free', [], []);

    await logs.writeToFile('before-diet-gluten-free', `Diet: gluten-free`);

    const names = result.map(t => t.name);
    console.log(`[TEST] Gluten-free diet result: ${names.join(', ')}`);

    assert(!names.includes('Oatmeal with Banana'), 'Oatmeal excluded for gluten-free diet');
    assert(!names.includes('Toast with PB'), 'Toast excluded for gluten-free diet');
  });

  it('should filter dairy-free diet correctly', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'dairy-free', [], []);

    await logs.writeToFile('before-diet-dairy-free', `Diet: dairy-free`);

    const names = result.map(t => t.name);
    console.log(`[TEST] Dairy-free diet result: ${names.join(', ')}`);

    assert(!names.includes('Greek Yogurt Bowl'), 'Yogurt excluded for dairy-free diet');
    assert(names.includes('Oatmeal with Banana'), 'Oatmeal should remain for dairy-free');
  });

  it('should document that vegan diet is NOT handled by diet filter', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'vegan', [], []);

    await logs.writeToFile('before-diet-vegan-bug',
      `Diet: vegan | KNOWN BUG: vegan not in hardcoded diet map`
    );

    const names = result.map(t => t.name);
    console.log(`[TEST] Vegan diet result: ${names.join(', ')}`);

    // BUG: vegan is not handled — the diet map only has gluten-free, dairy-free, peanut-free, all-free
    // So all templates pass through, including dairy (Yogurt) and eggs
    const hasYogurt = names.includes('Greek Yogurt Bowl');
    const hasEgg = names.includes('Egg on Toast');
    console.log(`[TEST] KNOWN BUG: Yogurt included for vegan diet: ${hasYogurt}`);
    console.log(`[TEST] KNOWN BUG: Egg on Toast included for vegan diet: ${hasEgg}`);

    // Document the bug — don't assert failure, just document
    if (hasYogurt || hasEgg) {
      console.warn(`[TEST] BUG CONFIRMED: vegan diet does not filter dairy/egg templates`);
    }
  });

  it('should document that vegetarian diet is NOT handled by diet filter', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'vegetarian', [], []);

    await logs.writeToFile('before-diet-vegetarian-bug',
      `Diet: vegetarian | KNOWN BUG: vegetarian not in hardcoded diet map`
    );

    const names = result.map(t => t.name);
    console.log(`[TEST] Vegetarian diet result: ${names.join(', ')}`);

    // Vegetarian is also not in the diet map
    // This is less critical than vegan since vegetarian typically allows dairy/eggs
    // But it means NO filtering happens at all
    assertEquals(names.length, makeMealTemplates().filter(t => t.time_window === '1.5-3 hours').length,
      'Vegetarian should pass all templates through (no filtering)'
    );
  });
});

// ============================================================================
// Dislike Filtering
// ============================================================================

describe('Before Phase Filtering — Dislike Filtering', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should exclude templates with disliked component foods', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'none', ['oatmeal'], []);

    await logs.writeToFile('before-dislike-component', `Disliked: oatmeal`);

    const names = result.map(t => t.name);
    console.log(`[TEST] After dislike filter (oatmeal): ${names.join(', ')}`);

    assert(!names.includes('Oatmeal with Banana'), 'Oatmeal template excluded (contains disliked oatmeal)');
    assert(names.includes('Banana'), 'Banana should remain');
  });

  it('should exclude templates at template level for disliked foods', async () => {
    const templates = makeMealTemplates();
    const result = getEligibleTemplates(templates, 'meal', 'none', ['peanut_butter'], []);

    await logs.writeToFile('before-dislike-template', `Disliked: peanut_butter`);

    const names = result.map(t => t.name);
    console.log(`[TEST] After dislike filter (peanut_butter): ${names.join(', ')}`);

    assert(!names.includes('Toast with PB'), 'Toast with PB excluded (contains disliked peanut_butter)');
  });
});

// ============================================================================
// Drink/Electrolyte Bypass (documents known gap)
// ============================================================================

describe('Before Phase Filtering — Drink/Electrolyte Gap', () => {
  beforeEach(setup);
  afterEach(teardown);

  it('should document that drink templates bypass allergen filtering', async () => {
    const allTemplates = [...makeMealTemplates(), ...makeDrinkTemplates()];
    const result = getEligibleTemplates(allTemplates, 'meal', 'none', [], ['Dairy']);

    await logs.writeToFile('before-drink-bypass',
      `KNOWN GAP: drink templates may bypass allergen filtering`
    );

    const names = result.map(t => t.name);
    console.log(`[TEST] After Dairy allergen filter: ${names.join(', ')}`);

    // Chocolate Milk drink template has Dairy allergen — should be excluded
    const hasChocMilk = names.includes('Chocolate Milk');
    console.log(`[TEST] Chocolate Milk (drink, Dairy allergen) included: ${hasChocMilk}`);

    // Note: getEligibleTemplates DOES filter drink templates by allergens
    // The "bypass" issue is that drinks/electrolytes are selected SEPARATELY
    // in selectPreWorkoutFoods via pickDrink/pickElectrolyte, which may
    // not apply the same filtering
    if (!hasChocMilk) {
      console.log(`[TEST] getEligibleTemplates correctly filters drinks by allergens`);
    }
  });

  it('should document that electrolyte templates bypass dislike filtering', async () => {
    const allTemplates = [...makeMealTemplates(), ...makeElectrolyteTemplates()];
    const result = getEligibleTemplates(allTemplates, 'meal', 'none', ['electrolyte_tablet'], []);

    await logs.writeToFile('before-electrolyte-bypass',
      `Electrolyte template dislike filtering check`
    );

    const names = result.map(t => t.name);
    console.log(`[TEST] After dislike filter (electrolyte_tablet): ${names.join(', ')}`);

    const hasElectrolyte = names.includes('Electrolyte Tablet');
    console.log(`[TEST] Electrolyte Tablet (disliked component) included: ${hasElectrolyte}`);

    // getEligibleTemplates filters by component_food_names, which should
    // catch electrolyte_tablet. But the separate pickElectrolyte flow
    // in selectPreWorkoutFoods may not apply dislike filtering.
    if (!hasElectrolyte) {
      console.log(`[TEST] getEligibleTemplates correctly filters electrolytes by dislikes`);
    }
  });
});
