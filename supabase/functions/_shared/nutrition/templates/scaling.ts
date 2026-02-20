/**
 * Proportional Scaling Algorithm
 *
 * Grid-search proportional scaling with friendly fraction snapping.
 * All items in a template get the same multiplier (0.25x to 4.0x),
 * then each item's quantity is snapped to a friendly fraction based
 * on its unit type.
 *
 * Score: carbs 60% + hydration 20% + sodium 20%
 *
 * Only fluid from is_liquid foods (milk, OJ) counts toward hydration scoring.
 * Non-liquid food fluid (banana 88ml, grapes 122ml) is ignored for scoring.
 */

import { type TemplateFoodItem, type ScaledFood, type ScalingResult, type SubPhaseTargets } from './types.ts';

// ============================================================================
// Friendly Fractions
// ============================================================================

/**
 * Friendly fractions for different serving unit types.
 * These are the "nice" quantities users see (e.g., 0.5, 1, 1.5, 2).
 */
const FRIENDLY_FRACTIONS = [
  0.25, 0.33, 0.5, 0.67, 0.75, 1.0,
  1.25, 1.33, 1.5, 1.67, 1.75, 2.0,
  2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0,
];

/**
 * Snap a value to the nearest friendly fraction.
 */
function snapToFriendly(value: number): number {
  if (value <= 0) return 0;

  let closest = FRIENDLY_FRACTIONS[0];
  let minDist = Math.abs(value - closest);

  for (const frac of FRIENDLY_FRACTIONS) {
    const dist = Math.abs(value - frac);
    if (dist < minDist) {
      minDist = dist;
      closest = frac;
    }
  }

  return closest;
}

/**
 * Format a quantity as a display string with friendly fractions.
 */
export function formatQuantity(value: number): string {
  if (value === 0) return '0';
  if (value === 0.25) return '1/4';
  if (value === 0.33) return '1/3';
  if (value === 0.5) return '1/2';
  if (value === 0.67) return '2/3';
  if (value === 0.75) return '3/4';
  if (Number.isInteger(value)) return value.toString();

  const whole = Math.floor(value);
  const frac = value - whole;

  if (Math.abs(frac - 0.25) < 0.05) return `${whole} 1/4`;
  if (Math.abs(frac - 0.33) < 0.05) return `${whole} 1/3`;
  if (Math.abs(frac - 0.5) < 0.05) return `${whole} 1/2`;
  if (Math.abs(frac - 0.67) < 0.05) return `${whole} 2/3`;
  if (Math.abs(frac - 0.75) < 0.05) return `${whole} 3/4`;

  return value.toFixed(1);
}

// ============================================================================
// Grid Search Scaling
// ============================================================================

/**
 * Multiplier grid: 0.25 to 4.0 in 0.05 increments
 */
function generateMultiplierGrid(): number[] {
  const grid: number[] = [];
  for (let m = 0.25; m <= 4.0; m += 0.05) {
    grid.push(Math.round(m * 100) / 100);
  }
  return grid;
}

const MULTIPLIER_GRID = generateMultiplierGrid();

/**
 * Score a scaling result against targets.
 *
 * Weighted scoring:
 * - Carbs: 60% weight (primary macro for endurance — most important)
 * - Hydration: 20% weight (drink provides most of the fluid)
 * - Sodium: 20% weight (important but shouldn't block carb scaling)
 *
 * Each component is scored as 1 - |actual - target| / target,
 * clamped to [0, 1] so that no single component can go deeply negative
 * and overwhelm the others.
 */
function scoreScaling(
  totalCarbs: number,
  totalFluid: number,
  totalSodium: number,
  targets: SubPhaseTargets,
): number {
  const rawCarbScore = targets.carbs_g > 0
    ? 1 - Math.abs(totalCarbs - targets.carbs_g) / targets.carbs_g
    : 1;

  const rawFluidScore = targets.water_ml > 0
    ? 1 - Math.abs(totalFluid - targets.water_ml) / targets.water_ml
    : 1;

  const rawSodiumScore = targets.sodium_mg > 0
    ? 1 - Math.abs(totalSodium - targets.sodium_mg) / targets.sodium_mg
    : 1;

  // Clamp to [0, 1] to prevent any single macro from going deeply negative
  // and overriding carb optimization (e.g., high-sodium tortilla at 2x would
  // produce sodiumScore = -2.5 without clamping, killing the entire result)
  const carbScore = Math.max(0, Math.min(1, rawCarbScore));
  const fluidScore = Math.max(0, Math.min(1, rawFluidScore));
  const sodiumScore = Math.max(0, Math.min(1, rawSodiumScore));

  // Mild penalty for significant carb overshoot (>20% over target)
  const carbPenalty = totalCarbs > targets.carbs_g * 1.2 ? -0.15 : 0;

  return (
    0.6 * carbScore +
    0.2 * fluidScore +
    0.2 * sodiumScore +
    carbPenalty
  );
}

/**
 * Scale template foods proportionally to meet targets.
 *
 * All foods get the same multiplier applied to their default_servings.
 * Each result is snapped to friendly fractions and checked against
 * min/max serving constraints.
 *
 * Returns the best-scoring result from the grid search.
 */
export function scaleTemplate(
  foods: TemplateFoodItem[],
  targets: SubPhaseTargets,
  drinkCarbsToSubtract: number = 0,
  drinkFluidsToSubtract: number = 0,
  drinkSodiumToSubtract: number = 0,
): ScalingResult {
  // Adjust targets to account for drink contribution
  const adjustedCarbTarget = Math.max(0, targets.carbs_g - drinkCarbsToSubtract);
  const adjustedFluidTarget = Math.max(0, targets.water_ml - drinkFluidsToSubtract);
  const adjustedSodiumTarget = Math.max(0, targets.sodium_mg - drinkSodiumToSubtract);

  let bestResult: ScalingResult | null = null;

  for (const multiplier of MULTIPLIER_GRID) {
    const scaledFoods: ScaledFood[] = [];
    let totalCarbs = 0;
    let totalProtein = 0;
    let totalFat = 0;
    let totalSodium = 0;
    let totalFluid = 0;
    let totalCalories = 0;
    let valid = true;

    for (const food of foods) {
      const rawServings = food.default_servings * multiplier;
      const snapped = snapToFriendly(rawServings);
      const isLiquid = food.is_liquid === true;

      // Check against min/max constraints
      if (snapped < food.min_servings || snapped > food.max_servings) {
        // Clamp to bounds
        const clamped = Math.max(food.min_servings, Math.min(food.max_servings, snapped));
        if (clamped !== snapped) {
          // Re-snap after clamping (if clamped value differs significantly)
          const finalServings = snapToFriendly(clamped);

          const carbsContrib = food.carbs_g * finalServings;
          const proteinContrib = food.protein_g * finalServings;
          const fatContrib = food.fat_g * finalServings;
          const sodiumContrib = food.sodium_mg * finalServings;
          const fluidContrib = food.fluid_ml * finalServings;
          const caloriesContrib = food.calories * finalServings;

          scaledFoods.push({
            food_id: food.food_id,
            food_name: food.food_name,
            display_name: food.display_name,
            serving_size: food.serving_size,
            quantity: finalServings,
            original_servings: food.default_servings,
            scale_multiplier: multiplier,
            carbs_grams: Math.round(carbsContrib * 10) / 10,
            protein_grams: Math.round(proteinContrib * 10) / 10,
            fat_grams: Math.round(fatContrib * 10) / 10,
            sodium_mg: Math.round(sodiumContrib * 10) / 10,
            fluids_ml: Math.round(fluidContrib * 10) / 10,
            calories: Math.round(caloriesContrib),
          });

          totalCarbs += carbsContrib;
          totalProtein += proteinContrib;
          totalFat += fatContrib;
          totalSodium += sodiumContrib;
          // Only count fluid from liquid foods (milk, OJ) toward hydration scoring
          if (isLiquid) totalFluid += fluidContrib;
          totalCalories += caloriesContrib;
          continue;
        }
      }

      const carbsContrib = food.carbs_g * snapped;
      const proteinContrib = food.protein_g * snapped;
      const fatContrib = food.fat_g * snapped;
      const sodiumContrib = food.sodium_mg * snapped;
      const fluidContrib = food.fluid_ml * snapped;
      const caloriesContrib = food.calories * snapped;

      scaledFoods.push({
        food_id: food.food_id,
        food_name: food.food_name,
        display_name: food.display_name,
        serving_size: food.serving_size,
        quantity: snapped,
        original_servings: food.default_servings,
        scale_multiplier: multiplier,
        carbs_grams: Math.round(carbsContrib * 10) / 10,
        protein_grams: Math.round(proteinContrib * 10) / 10,
        fat_grams: Math.round(fatContrib * 10) / 10,
        sodium_mg: Math.round(sodiumContrib * 10) / 10,
        fluids_ml: Math.round(fluidContrib * 10) / 10,
        calories: Math.round(caloriesContrib),
      });

      totalCarbs += carbsContrib;
      totalProtein += proteinContrib;
      totalFat += fatContrib;
      totalSodium += sodiumContrib;
      // Only count fluid from liquid foods (milk, OJ) toward hydration scoring
      if (isLiquid) totalFluid += fluidContrib;
      totalCalories += caloriesContrib;
    }

    if (!valid) continue;

    // Use adjusted targets for scoring (subtract drink contributions)
    const adjustedTargets: SubPhaseTargets = {
      ...targets,
      carbs_g: adjustedCarbTarget,
      water_ml: adjustedFluidTarget,
      sodium_mg: adjustedSodiumTarget,
    };

    const score = scoreScaling(totalCarbs, totalFluid, totalSodium, adjustedTargets);

    if (!bestResult || score > bestResult.score) {
      bestResult = {
        multiplier,
        foods: scaledFoods,
        total_carbs: Math.round(totalCarbs * 10) / 10,
        total_protein: Math.round(totalProtein * 10) / 10,
        total_fat: Math.round(totalFat * 10) / 10,
        total_sodium: Math.round(totalSodium * 10) / 10,
        total_fluid: Math.round(totalFluid * 10) / 10,
        total_calories: Math.round(totalCalories),
        score,
      };
    }
  }

  // Fallback: return default servings if grid search fails
  if (!bestResult) {
    const defaultFoods = foods.map((food) => ({
      food_id: food.food_id,
      food_name: food.food_name,
      display_name: food.display_name,
      serving_size: food.serving_size,
      quantity: food.default_servings,
      original_servings: food.default_servings,
      scale_multiplier: 1.0,
      carbs_grams: Math.round(food.carbs_g * food.default_servings * 10) / 10,
      protein_grams: Math.round(food.protein_g * food.default_servings * 10) / 10,
      fat_grams: Math.round(food.fat_g * food.default_servings * 10) / 10,
      sodium_mg: Math.round(food.sodium_mg * food.default_servings * 10) / 10,
      fluids_ml: Math.round(food.fluid_ml * food.default_servings * 10) / 10,
      calories: Math.round(food.calories * food.default_servings),
    }));

    // Only count fluid from liquid foods (milk, OJ) in fallback
    const fallbackLiquidFluid = foods.reduce((s, food) =>
      food.is_liquid === true ? s + Math.round(food.fluid_ml * food.default_servings * 10) / 10 : s, 0);

    bestResult = {
      multiplier: 1.0,
      foods: defaultFoods,
      total_carbs: defaultFoods.reduce((s, f) => s + f.carbs_grams, 0),
      total_protein: defaultFoods.reduce((s, f) => s + f.protein_grams, 0),
      total_fat: defaultFoods.reduce((s, f) => s + f.fat_grams, 0),
      total_sodium: defaultFoods.reduce((s, f) => s + f.sodium_mg, 0),
      total_fluid: fallbackLiquidFluid,
      total_calories: defaultFoods.reduce((s, f) => s + f.calories, 0),
      score: 0,
    };
  }

  return bestResult;
}
