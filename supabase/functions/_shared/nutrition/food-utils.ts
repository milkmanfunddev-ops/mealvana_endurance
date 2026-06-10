/**
 * Food utility functions for nutrition planning
 */

import { safe, roundToIncrement } from '../utils.ts';
import type { FoodResult, FoodNutrition } from './types.ts';

/**
 * Build a preference set from an array of food names/IDs
 * Includes both original and lowercase versions for case-insensitive matching
 */
export function buildPreferenceSet(values: string[] | undefined): Set<string> {
  const result = new Set<string>();
  if (!values) return result;

  for (const value of values) {
    if (!value) continue;
    result.add(value);
    result.add(value.toLowerCase());
  }
  return result;
}

/**
 * Check if a food matches a preference set.
 *
 * Matches by id or by exact (case-insensitive) name / display_name ONLY.
 *
 * NOTE: This intentionally does NOT do substring matching. A previous version
 * matched bidirectionally with `includes()` (e.g. preference "protein_shake"
 * would also match "plant_protein_shake_rtd", and a generic token like
 * "electrolyte" would match every electrolyte product). That silently
 * over-excluded foods when used for the disliked set and collapsed the
 * candidate pool. Preference keys are canonical food names/ids, so exact
 * matching is correct.
 */
export function matchesPreference(
  food: { id?: string; name?: string; display_name?: string | null },
  preferenceSet: Set<string>
): boolean {
  if (preferenceSet.size === 0) return false;

  const foodName = food.name?.toLowerCase();
  const displayName = food.display_name?.toLowerCase();

  // Check by ID
  if (food.id && preferenceSet.has(food.id)) return true;

  // Check exact name
  if (food.name && preferenceSet.has(food.name)) return true;

  // Check lowercase name
  if (foodName && preferenceSet.has(foodName)) return true;

  // Check display name
  if (displayName && preferenceSet.has(displayName)) return true;

  return false;
}

/**
 * Deduplicate foods by combining quantities for the same food_id
 */
export function deduplicateFoods(foods: FoodResult[]): FoodResult[] {
  const foodMap = new Map<string, FoodResult>();

  for (const food of foods) {
    const foodId = food.food_id;

    if (foodMap.has(foodId)) {
      const existing = foodMap.get(foodId)!;
      // Combine quantities and recalculate all nutritional values
      const totalQuantity = existing.quantity + food.quantity;
      existing.quantity = roundToIncrement(totalQuantity);
      existing.carbs_grams += food.carbs_grams || 0;
      existing.protein_grams += food.protein_grams || 0;
      existing.fat_grams += food.fat_grams || 0;
      existing.sodium_mg += food.sodium_mg || 0;
      existing.fluids_ml += food.fluids_ml || 0;
      existing.calories += food.calories || 0;
    } else {
      foodMap.set(foodId, { ...food });
    }
  }

  // Return deduplicated foods with rounded values
  return Array.from(foodMap.values()).map((food) => ({
    ...food,
    quantity: roundToIncrement(food.quantity),
    carbs_grams: Math.round((food.carbs_grams || 0) * 10) / 10,
    protein_grams: Math.round((food.protein_grams || 0) * 10) / 10,
    fat_grams: Math.round((food.fat_grams || 0) * 10) / 10,
    sodium_mg: Math.round(food.sodium_mg || 0),
    fluids_ml: Math.round(food.fluids_ml || 0),
    calories: Math.round(food.calories || 0),
  }));
}

/**
 * Calculate totals from a list of food results
 */
export function calculateTotals(foods: FoodResult[]): FoodNutrition {
  return foods.reduce(
    (acc, food) => ({
      carbs_g: acc.carbs_g + (food.carbs_grams || 0),
      protein_g: acc.protein_g + (food.protein_grams || 0),
      fat_g: acc.fat_g + (food.fat_grams || 0),
      sodium_mg: acc.sodium_mg + (food.sodium_mg || 0),
      water_ml: acc.water_ml + (food.fluids_ml || 0),
      calories: acc.calories + (food.calories || 0),
    }),
    {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0,
      calories: 0,
    }
  );
}
