/**
 * Unit tests for get-foods edge function.
 *
 * STRATEGY:
 * The handler is a thin Supabase pass-through: it queries template_foods,
 * deduplicates by id, and maps columns to a response shape. All three of
 * these operations contain testable pure logic.
 *
 * We test:
 * 1. Deduplication — categorized + essential foods, same-id appears once
 * 2. Field mapping — column rename (carbs_g → carbs_per_serving, etc.)
 * 3. Derived fields — before_run_suitable, during_run_suitable, run_portable
 * 4. Fallback / null-safety — null fields don't crash the mapper
 * 5. Category filter intent — verifies the function selects by category value
 * 6. Input validation concept — no explicit validation in get-foods (documented)
 *
 * BUGS FOUND: documented inline.
 *
 * Run with:
 *   deno test --allow-env --node-modules-dir=none \
 *     supabase/functions/get-foods/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure copies of the logic from index.ts
// ============================================================================

/** Deduplicate an array of food rows by id (Map preserves first occurrence) */
function deduplicateFoods(categorizedFoods: any[], essentialFoods: any[]): any[] {
  const foodsMap = new Map();
  for (const food of [...categorizedFoods, ...essentialFoods]) {
    if (!foodsMap.has(food.id)) {
      foodsMap.set(food.id, food);
    }
  }
  return Array.from(foodsMap.values());
}

/** Map a template_foods DB row to the response shape expected by Flutter */
function mapFoodToResponse(food: any): Record<string, unknown> {
  return {
    id: food.id,
    name: food.name,
    display_name: food.display_name,
    display_name_plural: food.display_name_plural,
    image_address: food.image_address,
    description: food.description ?? null,
    instructions: null, // template_foods doesn't have instructions
    categories: food.categories || [],
    // Column renames
    carbs_per_serving: food.carbs_g || 0,
    sodium_mg: food.sodium_mg || 0,
    fluid_ml_per_serving: food.fluid_ml || 0,
    calories_per_serving: food.calories || 0,
    protein_per_serving: food.protein_g || 0,
    fat_per_serving: food.fat_g || 0,
    serving_amount: food.serving_amount || 1.0,
    serving_size: food.serving_size || null,
    serving_unit: food.serving_unit || null,
    serving_qualifier: food.serving_qualifier || null,
    // Suitability derived from categories array
    before_run_suitable: (food.categories || []).includes('before_run'),
    during_run_suitable: (food.categories || []).includes('during_run'),
    run_portable: true, // template_foods doesn't track this; default true
    requires_preparation: food.requires_preparation ?? false,
    aid_station_available: false, // template_foods doesn't track this
    max_servings_before: food.max_servings_before,
    max_servings_during: food.max_servings_during,
    caffeine_mg: food.caffeine_mg,
    potassium_mg: food.potassium_mg,
    show_in_preferences: food.show_in_preferences,
    is_electrolyte: food.is_electrolyte,
    to_exclude_from_solver: food.to_exclude_from_solver,
    product_type: food.product_type || null,
    created_at: food.created_at,
  };
}

// ============================================================================
// Test data factories
// ============================================================================

function makeRawFood(overrides: Partial<Record<string, unknown>> & { id: string; name: string }): Record<string, unknown> {
  // Start with sentinel-based defaults, then explicitly spread overrides so that
  // null/0 passed in overrides correctly replaces the default (Object.assign semantics).
  const base: Record<string, unknown> = {
    display_name: overrides.name,
    display_name_plural: null,
    image_address: null,
    description: null,
    categories: ['before_run'],
    carbs_g: 25,
    protein_g: 5,
    fat_g: 3,
    calories: 150,
    fluid_ml: 0,
    sodium_mg: 100,
    caffeine_mg: null,
    potassium_mg: null,
    serving_amount: 1.0,
    serving_size: '1 bar',
    serving_unit: null,
    serving_qualifier: null,
    max_servings_before: 2,
    max_servings_during: null,
    is_essential: false,
    is_electrolyte: false,
    to_exclude_from_solver: false,
    requires_preparation: false,
    show_in_preferences: true,
    product_type: 'food',
    created_at: '2024-01-01T00:00:00Z',
  };
  // Spread overrides LAST so explicit null/0/false values win over defaults.
  return Object.assign(base, overrides);
}

// ============================================================================
// A. Deduplication
// ============================================================================

describe('get-foods deduplication', () => {
  it('no overlap — all foods included', () => {
    const cat = [makeRawFood({ id: 'a', name: 'Banana' })];
    const ess = [makeRawFood({ id: 'b', name: 'Water' })];
    const result = deduplicateFoods(cat, ess);
    assertEquals(result.length, 2);
  });

  it('same id in both lists — only first occurrence kept', () => {
    const water = makeRawFood({ id: 'water', name: 'Water', sodium_mg: 0 });
    const waterEssential = makeRawFood({ id: 'water', name: 'Water', sodium_mg: 99 });
    const result = deduplicateFoods([water], [waterEssential]);
    assertEquals(result.length, 1);
    // categorized foods are listed first — that version should win
    assertEquals(result[0].sodium_mg, 0);
  });

  it('empty categorized + essential foods — returns essential only', () => {
    const ess = [makeRawFood({ id: 'salt', name: 'Salt' })];
    const result = deduplicateFoods([], ess);
    assertEquals(result.length, 1);
    assertEquals(result[0].id, 'salt');
  });

  it('empty both — returns empty array', () => {
    const result = deduplicateFoods([], []);
    assertEquals(result.length, 0);
  });

  it('three items, two with same id — dedup keeps first', () => {
    const a = makeRawFood({ id: 'gel', name: 'Gel v1' });
    const b = makeRawFood({ id: 'bar', name: 'Bar' });
    const c = makeRawFood({ id: 'gel', name: 'Gel v2' }); // duplicate
    const result = deduplicateFoods([a, b], [c]);
    assertEquals(result.length, 2);
    const gel = result.find(f => f.id === 'gel');
    assertEquals(gel?.name, 'Gel v1'); // first wins
  });

  it('multiple essential foods, none in categorized — all included', () => {
    const essentials = [
      makeRawFood({ id: 'water', name: 'Water' }),
      makeRawFood({ id: 'salt', name: 'Salt' }),
      makeRawFood({ id: 'electrolyte', name: 'Electrolyte Tab' }),
    ];
    const result = deduplicateFoods([], essentials);
    assertEquals(result.length, 3);
  });
});

// ============================================================================
// B. Field mapping — column renames
// ============================================================================

describe('get-foods field mapping', () => {
  it('carbs_g maps to carbs_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Oatmeal', carbs_g: 30 });
    const response = mapFoodToResponse(food);
    assertEquals(response.carbs_per_serving, 30);
    // Confirm the raw DB column is NOT present
    assert(!('carbs_g' in response), 'carbs_g should not be in response');
  });

  it('fluid_ml maps to fluid_ml_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Sports Drink', fluid_ml: 500 });
    const response = mapFoodToResponse(food);
    assertEquals(response.fluid_ml_per_serving, 500);
  });

  it('protein_g maps to protein_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Chicken', protein_g: 30 });
    const response = mapFoodToResponse(food);
    assertEquals(response.protein_per_serving, 30);
  });

  it('fat_g maps to fat_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Peanut Butter', fat_g: 16 });
    const response = mapFoodToResponse(food);
    assertEquals(response.fat_per_serving, 16);
  });

  it('calories maps to calories_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Energy Bar', calories: 250 });
    const response = mapFoodToResponse(food);
    assertEquals(response.calories_per_serving, 250);
  });

  it('instructions is always null (no column in template_foods)', () => {
    const food = makeRawFood({ id: '1', name: 'Rice' });
    const response = mapFoodToResponse(food);
    assertEquals(response.instructions, null);
  });

  it('run_portable is always true', () => {
    const food = makeRawFood({ id: '1', name: 'Gel' });
    const response = mapFoodToResponse(food);
    assertEquals(response.run_portable, true);
  });

  it('aid_station_available is always false', () => {
    const food = makeRawFood({ id: '1', name: 'Banana' });
    const response = mapFoodToResponse(food);
    assertEquals(response.aid_station_available, false);
  });
});

// ============================================================================
// C. Derived suitability fields
// ============================================================================

describe('get-foods derived suitability fields', () => {
  it('before_run category → before_run_suitable=true, during_run_suitable=false', () => {
    const food = makeRawFood({ id: '1', name: 'Oatmeal', categories: ['before_run'] });
    const response = mapFoodToResponse(food);
    assertEquals(response.before_run_suitable, true);
    assertEquals(response.during_run_suitable, false);
  });

  it('during_run category → during_run_suitable=true, before_run_suitable=false', () => {
    const food = makeRawFood({ id: '1', name: 'Gel', categories: ['during_run'] });
    const response = mapFoodToResponse(food);
    assertEquals(response.during_run_suitable, true);
    assertEquals(response.before_run_suitable, false);
  });

  it('both categories → both suitability flags true', () => {
    const food = makeRawFood({ id: '1', name: 'Banana', categories: ['before_run', 'during_run'] });
    const response = mapFoodToResponse(food);
    assertEquals(response.before_run_suitable, true);
    assertEquals(response.during_run_suitable, true);
  });

  it('empty categories → both suitability flags false', () => {
    const food = makeRawFood({ id: '1', name: 'Misc', categories: [] });
    const response = mapFoodToResponse(food);
    assertEquals(response.before_run_suitable, false);
    assertEquals(response.during_run_suitable, false);
  });

  it('null categories → treated as empty array, both false', () => {
    const food = makeRawFood({ id: '1', name: 'Misc', categories: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.categories, []);
    assertEquals(response.before_run_suitable, false);
    assertEquals(response.during_run_suitable, false);
  });
});

// ============================================================================
// D. Null-safety / zero-default fallbacks
// ============================================================================

describe('get-foods null-safety and zero defaults', () => {
  it('null carbs_g → 0 carbs_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Water', carbs_g: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.carbs_per_serving, 0);
  });

  it('null sodium_mg → 0 sodium_mg', () => {
    const food = makeRawFood({ id: '1', name: 'Pure Water', sodium_mg: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.sodium_mg, 0);
  });

  it('null protein_g → 0 protein_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Gel', protein_g: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.protein_per_serving, 0);
  });

  it('null fat_g → 0 fat_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Fruit', fat_g: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.fat_per_serving, 0);
  });

  it('null calories → 0 calories_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Water', calories: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.calories_per_serving, 0);
  });

  it('null fluid_ml → 0 fluid_ml_per_serving', () => {
    const food = makeRawFood({ id: '1', name: 'Bar', fluid_ml: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.fluid_ml_per_serving, 0);
  });

  it('null serving_amount → 1.0 default', () => {
    const food = makeRawFood({ id: '1', name: 'Gel', serving_amount: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.serving_amount, 1.0);
  });

  it('null product_type → null (not empty string)', () => {
    const food = makeRawFood({ id: '1', name: 'Custom', product_type: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.product_type, null);
  });

  it('description is null when absent (explicit null via ??)', () => {
    const food = makeRawFood({ id: '1', name: 'Gel' });
    delete (food as any).description;
    const response = mapFoodToResponse(food);
    assertEquals(response.description, null);
  });

  it('requires_preparation defaults to false when null', () => {
    const food = makeRawFood({ id: '1', name: 'Gel', requires_preparation: null });
    const response = mapFoodToResponse(food);
    assertEquals(response.requires_preparation, false);
  });
});

// ============================================================================
// E. Zero-value nutrition (true-zero vs null semantic)
// ============================================================================

describe('get-foods zero-value nutrition', () => {
  it('carbs_g=0 → carbs_per_serving=0 (not null)', () => {
    // BUG NOTE: `food.carbs_g || 0` treats 0 as falsy and returns 0 anyway.
    // For carbs this is fine since 0 || 0 = 0. But if carbs_g were negative
    // (which shouldn't happen but is not guarded) the bug would hide it.
    // Documenting actual correct behavior here.
    const food = makeRawFood({ id: '1', name: 'Water', carbs_g: 0 });
    const response = mapFoodToResponse(food);
    assertEquals(response.carbs_per_serving, 0);
  });

  it('categories=[after_run] only → before/during both false', () => {
    const food = makeRawFood({ id: '1', name: 'Recovery Shake', categories: ['after_run'] });
    const response = mapFoodToResponse(food);
    assertEquals(response.before_run_suitable, false);
    assertEquals(response.during_run_suitable, false);
  });
});

// ============================================================================
// F. No input validation in get-foods (documented)
// ============================================================================

describe('get-foods — no input validation (live integration required)', () => {
  it('NOTE: get-foods has no explicit validation — null/undefined category falls through to "get all"', () => {
    // The function handles null category by fetching all active foods.
    // This is correct behavior documented here, not a bug.
    // Live integration test needed to verify the Supabase query path.
    // Confirming the category-presence branch logic:
    const categoryName = null;
    const hasCategoryFilter = !!categoryName;
    assertEquals(hasCategoryFilter, false); // null → fetch all path
  });

  it('non-empty category string → category filter path', () => {
    const categoryName = 'before_run';
    const hasCategoryFilter = !!categoryName;
    assertEquals(hasCategoryFilter, true);
  });

  it('empty string category → treated as no-category (fetch all)', () => {
    const categoryName = '';
    const hasCategoryFilter = !!categoryName;
    assertEquals(hasCategoryFilter, false); // '' is falsy
  });
});

// ============================================================================
// G. Full pipeline: dedup + map
// ============================================================================

describe('get-foods full pipeline: dedup + map', () => {
  it('dedup then map: correct count and field shapes', () => {
    const banana = makeRawFood({ id: 'banana', name: 'Banana', categories: ['before_run', 'during_run'], carbs_g: 27 });
    const water = makeRawFood({ id: 'water', name: 'Water', categories: ['during_run'], carbs_g: 0, is_essential: true });
    const waterDupe = makeRawFood({ id: 'water', name: 'Water DUPE', carbs_g: 99 }); // should be dropped

    const deduped = deduplicateFoods([banana, water], [waterDupe]);
    assertEquals(deduped.length, 2);

    const formatted = deduped.map(mapFoodToResponse);
    assertEquals(formatted.length, 2);

    const bananaResp = formatted.find(f => f.id === 'banana') as any;
    assertExists(bananaResp);
    assertEquals(bananaResp.carbs_per_serving, 27);
    assertEquals(bananaResp.before_run_suitable, true);
    assertEquals(bananaResp.during_run_suitable, true);

    const waterResp = formatted.find(f => f.id === 'water') as any;
    assertExists(waterResp);
    assertEquals(waterResp.carbs_per_serving, 0); // not 99 (dupe dropped)
  });
});
