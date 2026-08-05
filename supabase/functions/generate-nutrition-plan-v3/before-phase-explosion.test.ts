/**
 * Local Unit Tests for Before-Phase Component Explosion
 *
 * Regression for bug 3abe3fdb754c81ff879bdd1e5e28c0aa (Wiredash 2026-07-28):
 * food-type pre_workout_templates rows were never seeded with a parent-level
 * fluid_ml (DEFAULT 0), so normalizeExplosionMacros scaled every exploded
 * component's real fluid (milk 220 ml, cooked oatmeal 200 ml) to zero.
 *
 * Run with:
 *   deno test supabase/functions/generate-nutrition-plan-v3/before-phase-explosion.test.ts
 */

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { selectionToFoodResults } from './before-phase-explosion.ts';
import type { TemplateSelection } from '../generate-macros-v4/types.ts';
import type { TemplateFoodRow } from './before-phase-db.ts';

function makeTemplateFood(
  overrides: Partial<TemplateFoodRow> & { name: string },
): TemplateFoodRow {
  return {
    display_name: overrides.name,
    display_name_plural: null,
    serving_size: null,
    serving_unit: null,
    serving_amount: null,
    serving_qualifier: null,
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    fluid_ml: 0,
    is_liquid: false,
    is_electrolyte: false,
    product_type: null,
    ...overrides,
  };
}

describe('selectionToFoodResults — fluid preservation', () => {
  it(
    'keeps component fluid when the parent template declares fluid_ml = 0 ' +
      '(food-type composite, e.g. banana + blueberries + milk)',
    () => {
      // Parent row mirrors an unseeded food-type template: fluid_ml = 0.
      const selection: TemplateSelection = {
        id: 'tmpl-smoothie',
        name: 'Smoothie',
        base_category: 'snack',
        serving_unit: 'serving',
        servings: 1,
        carbs_g: 24,
        protein_g: 5,
        fat_g: 2,
        sodium_mg: 50,
        fluid_ml: 0,
        component_food_names: ['banana', 'blueberries', 'milk'],
        component_quantities: { banana: 0.5, blueberries: 0.5, milk: 0.5 },
      } as TemplateSelection;

      const templateFoods = new Map<string, TemplateFoodRow>([
        ['banana', makeTemplateFood({ name: 'banana', carbs_g: 27, fluid_ml: 88 })],
        ['blueberries', makeTemplateFood({ name: 'blueberries', carbs_g: 10.7, fluid_ml: 62 })],
        ['milk', makeTemplateFood({ name: 'milk', carbs_g: 12, fluid_ml: 220, is_liquid: true })],
      ]);

      const results = selectionToFoodResults(
        selection,
        'pre_workout_snack',
        false,
        false,
        templateFoods,
      );

      assertEquals(results.length, 3);
      const totalFluid = results.reduce((sum, r) => sum + r.fluids_ml, 0);
      // 0.5 × (88 + 62 + 220) = 185 ml of real component fluid must survive.
      assert(
        Math.abs(totalFluid - 185) < 1,
        `component fluid must not be zeroed: expected ~185 ml, got ${totalFluid} ml`,
      );
      for (const r of results) {
        assert(
          r.fluids_ml > 0,
          `${r.display_name} should retain its component fluid, got ${r.fluids_ml}`,
        );
      }
    },
  );

  it('still normalizes component fluid to the parent total when the parent declares one (drink rows)', () => {
    const selection: TemplateSelection = {
      id: 'tmpl-water',
      name: 'Water',
      base_category: 'top_up',
      serving_unit: 'cup',
      servings: 1,
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      fluid_ml: 240,
      component_food_names: ['water'],
      component_quantities: { water: 1 },
    } as TemplateSelection;

    const templateFoods = new Map<string, TemplateFoodRow>([
      ['water', makeTemplateFood({ name: 'water', fluid_ml: 237, is_liquid: true })],
    ]);

    const results = selectionToFoodResults(
      selection,
      'top_up',
      true,
      false,
      templateFoods,
    );

    assertEquals(results.length, 1);
    // Parent declares 240 ml; the component's 237 ml is normalized up to it.
    assertEquals(results[0].fluids_ml, 240);
  });
});

describe('selectionToFoodResults — unresolved components', () => {
  // Regression for the "1 banana meal = 108 g carbs" bug (2026-08-05):
  // "Rice + Banana" referenced component 'white_rice_cooked' while the
  // template_foods row is named 'white_rice'. The lookup miss skipped the
  // rice, then normalizeExplosionMacros scaled the surviving banana up to
  // the whole selection's macros — a "1.5 Bananas" row secretly carrying
  // 108 g carbs, so one +/- stepper tap jumped carbs by a hidden meal.
  it(
    'falls back to a single whole-template row when any component fails ' +
      'lookup, instead of inflating the survivors',
    () => {
      const selection: TemplateSelection = {
        id: 'tmpl-rice-banana',
        name: 'Rice + Banana',
        base_category: 'White Rice',
        serving_unit: '1 plate',
        servings: 1.5,
        carbs_g: 108, // 1.5 × (45 + 27) × per-serving parent macros
        protein_g: 8.3,
        fat_g: 0.8,
        sodium_mg: 8,
        fluid_ml: 132,
        component_food_names: ['white_rice_cooked', 'banana'], // rice dangles
        component_quantities: { white_rice_cooked: 1, banana: 1 },
      } as TemplateSelection;

      const templateFoods = new Map<string, TemplateFoodRow>([
        // Note: named 'white_rice', so 'white_rice_cooked' misses.
        ['white_rice', makeTemplateFood({ name: 'white_rice', carbs_g: 45 })],
        ['banana', makeTemplateFood({ name: 'banana', carbs_g: 27, fluid_ml: 88 })],
      ]);

      const results = selectionToFoodResults(
        selection,
        'pre_workout_meal',
        false,
        false,
        templateFoods,
      );

      // One honest whole-template row, not an inflated lone banana.
      assertEquals(results.length, 1);
      assertEquals(results[0].display_name, 'Rice + Banana');
      assertEquals(results[0].quantity, 1.5);
      assertEquals(results[0].carbs_grams, 108);
    },
  );

  it('still explodes normally when every component resolves', () => {
    const selection: TemplateSelection = {
      id: 'tmpl-rice-banana',
      name: 'Rice + Banana',
      base_category: 'White Rice',
      serving_unit: '1 plate',
      servings: 1.5,
      carbs_g: 108,
      protein_g: 8.3,
      fat_g: 0.8,
      sodium_mg: 8,
      fluid_ml: 132,
      component_food_names: ['white_rice', 'banana'],
      component_quantities: { white_rice: 1, banana: 1 },
    } as TemplateSelection;

    const templateFoods = new Map<string, TemplateFoodRow>([
      ['white_rice', makeTemplateFood({ name: 'white_rice', carbs_g: 45 })],
      ['banana', makeTemplateFood({ name: 'banana', carbs_g: 27, fluid_ml: 88 })],
    ]);

    const results = selectionToFoodResults(
      selection,
      'pre_workout_meal',
      false,
      false,
      templateFoods,
    );

    assertEquals(results.length, 2);
    const totalCarbs = results.reduce((s, r) => s + r.carbs_grams, 0);
    // Components sum to the selection contract; each keeps its own share
    // (1.5 servings: rice 67.5 g, banana 40.5 g).
    assert(
      Math.abs(totalCarbs - 108) < 0.2,
      `exploded carbs should sum to 108, got ${totalCarbs}`,
    );
    const banana = results.find((r) => r.display_name === 'banana');
    assert(banana !== undefined);
    assert(
      Math.abs(banana!.carbs_grams - 40.5) < 0.2,
      `banana should carry only its own carbs (~40.5 g), got ${banana!.carbs_grams}`,
    );
  });
});
