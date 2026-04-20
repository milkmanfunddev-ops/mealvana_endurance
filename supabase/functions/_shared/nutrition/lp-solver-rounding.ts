/**
 * LP Solver Post-Rounding Correction
 *
 * Extracted from lp-solver.ts for maintainability.
 * Handles snapping continuous LP solutions to 0.5 increments and correcting for drift.
 */

import { type Food, type PhaseSolution, type LPModel } from './types.ts';

/**
 * Post-rounding correction: adjust servings to bring totals back within constraints.
 *
 * After rounding servings to 0.5 increments (or whole numbers for indivisible items),
 * the totals may drift outside LP constraint bounds. This function iteratively adjusts
 * servings to bring totals back into compliance.
 */
export function correctRoundingDrift(
  selectedFoods: PhaseSolution['foods'],
  foods: Food[],
  model: LPModel,
  totals: {
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    water_ml: number;
    calories: number;
  },
): { foods: PhaseSolution['foods']; totals: typeof totals; issues: string[] } {
  const macroConstraintNames = ['carbs', 'protein', 'sodium', 'water'] as const;

  const getTotalForConstraint = (name: string): number | null => {
    switch (name) {
      case 'carbs': return totals.carbs_g;
      case 'protein': return totals.protein_g;
      case 'sodium': return totals.sodium_mg;
      case 'water': return totals.water_ml;
      default: return null;
    }
  };

  const getFoodContribution = (food: Food, name: string): number => {
    switch (name) {
      case 'carbs': return food.per_serving.carbs_g;
      case 'protein': return food.per_serving.protein_g;
      case 'sodium': return food.per_serving.sodium_mg;
      case 'water': return food.per_serving.water_ml;
      default: return 0;
    }
  };

  // Iteratively adjust servings to correct constraint violations
  for (let iter = 0; iter < 3; iter++) {
    let adjusted = false;
    for (const cName of macroConstraintNames) {
      const bounds = model.constraints[cName];
      if (!bounds) continue;
      const actual = getTotalForConstraint(cName);
      if (actual == null) continue;

      if (bounds.max != null && actual > bounds.max * 1.01) {
        // Find top contributor for this macro and reduce by 0.5
        let topIdx = -1;
        let topContrib = 0;
        for (let i = 0; i < selectedFoods.length; i++) {
          const sf = selectedFoods[i];
          const foodIdx = foods.findIndex(f => f.id === sf.food_id);
          if (foodIdx < 0) continue;
          const contrib = getFoodContribution(foods[foodIdx], cName) * sf.quantity;
          if (contrib > topContrib && sf.quantity > (foods[foodIdx].is_indivisible ? 1 : 0.5)) {
            topContrib = contrib;
            topIdx = i;
          }
        }
        if (topIdx >= 0) {
          const sf = selectedFoods[topIdx];
          const foodIdx = foods.findIndex(f => f.id === sf.food_id);
          const food = foods[foodIdx];
          const decrement = food.is_indivisible ? 1 : 0.5;
          sf.quantity -= decrement;
          sf.carbs_grams = food.per_serving.carbs_g * sf.quantity;
          sf.protein_grams = food.per_serving.protein_g * sf.quantity;
          sf.fat_grams = food.per_serving.fat_g * sf.quantity;
          sf.sodium_mg = food.per_serving.sodium_mg * sf.quantity;
          sf.fluids_ml = food.per_serving.water_ml * sf.quantity;
          sf.calories = food.per_serving.calories * sf.quantity;
          // Recalculate totals
          totals.carbs_g = selectedFoods.reduce((s, f) => s + f.carbs_grams, 0);
          totals.protein_g = selectedFoods.reduce((s, f) => s + f.protein_grams, 0);
          totals.fat_g = selectedFoods.reduce((s, f) => s + f.fat_grams, 0);
          totals.sodium_mg = selectedFoods.reduce((s, f) => s + f.sodium_mg, 0);
          totals.water_ml = selectedFoods.reduce((s, f) => s + f.fluids_ml, 0);
          adjusted = true;
          console.log(`[LP-SOLVER] POST-ROUNDING FIX: reduced ${sf.display_name ?? sf.food_id} by ${decrement} for ${cName} overshoot`);
        }
      } else if (bounds.min != null && actual < bounds.min * 0.99) {
        // Find top contributor for this macro and increase by 0.5
        let topIdx = -1;
        let topContrib = 0;
        for (let i = 0; i < selectedFoods.length; i++) {
          const sf = selectedFoods[i];
          const foodIdx = foods.findIndex(f => f.id === sf.food_id);
          if (foodIdx < 0) continue;
          const food = foods[foodIdx];
          const contrib = getFoodContribution(food, cName);
          if (contrib > topContrib && sf.quantity < food.max_servings) {
            topContrib = contrib;
            topIdx = i;
          }
        }
        if (topIdx >= 0) {
          const sf = selectedFoods[topIdx];
          const foodIdx = foods.findIndex(f => f.id === sf.food_id);
          const food = foods[foodIdx];
          const increment = food.is_indivisible ? 1 : 0.5;
          sf.quantity += increment;
          sf.carbs_grams = food.per_serving.carbs_g * sf.quantity;
          sf.protein_grams = food.per_serving.protein_g * sf.quantity;
          sf.fat_grams = food.per_serving.fat_g * sf.quantity;
          sf.sodium_mg = food.per_serving.sodium_mg * sf.quantity;
          sf.fluids_ml = food.per_serving.water_ml * sf.quantity;
          sf.calories = food.per_serving.calories * sf.quantity;
          totals.carbs_g = selectedFoods.reduce((s, f) => s + f.carbs_grams, 0);
          totals.protein_g = selectedFoods.reduce((s, f) => s + f.protein_grams, 0);
          totals.fat_g = selectedFoods.reduce((s, f) => s + f.fat_grams, 0);
          totals.sodium_mg = selectedFoods.reduce((s, f) => s + f.sodium_mg, 0);
          totals.water_ml = selectedFoods.reduce((s, f) => s + f.fluids_ml, 0);
          adjusted = true;
          console.log(`[LP-SOLVER] POST-ROUNDING FIX: increased ${sf.display_name ?? sf.food_id} by ${increment} for ${cName} undershoot`);
        }
      }
    }
    if (!adjusted) break;
  }

  // Remove any foods that were reduced to 0 servings
  const finalFoods = selectedFoods.filter(f => f.quantity > 0);

  // Post-rounding validation: check if rounded totals still satisfy LP constraints (5% tolerance)
  const ROUNDING_TOLERANCE = 0.05;
  const roundingIssues: string[] = [];
  for (const [constraintName, bounds] of Object.entries(model.constraints)) {
    if (constraintName.startsWith('select_') || constraintName === 'total_food_items' || constraintName === 'electrolyte_supplements') continue;
    const actualValue = getTotalForConstraint(constraintName);
    if (actualValue == null) continue;

    if (bounds.min != null && actualValue < bounds.min * (1 - ROUNDING_TOLERANCE)) {
      roundingIssues.push(`${constraintName} below min: ${actualValue.toFixed(1)} < ${bounds.min.toFixed(1)} (tolerance: ${(ROUNDING_TOLERANCE * 100).toFixed(0)}%)`);
    }
    if (bounds.max != null && actualValue > bounds.max * (1 + ROUNDING_TOLERANCE)) {
      roundingIssues.push(`${constraintName} above max: ${actualValue.toFixed(1)} > ${bounds.max.toFixed(1)} (tolerance: ${(ROUNDING_TOLERANCE * 100).toFixed(0)}%)`);
    }
  }
  if (roundingIssues.length > 0) {
    console.warn(`[LP-SOLVER] POST-ROUNDING: ${roundingIssues.length} constraint violation(s): ${roundingIssues.join('; ')}`);
  }

  return { foods: finalFoods, totals, issues: roundingIssues };
}
