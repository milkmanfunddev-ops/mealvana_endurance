/**
 * Greedy Fallback Algorithm for Nutrition Planning
 *
 * Used when the LP solver fails to find a feasible solution
 */

import { roundToIncrement } from '../utils.ts';
import type { Food, Phase, MacroTargets, PhaseSolution } from './types.ts';

/**
 * Greedy algorithm that selects foods based on preference and macro efficiency
 */
export function greedyFallback(
  foods: Food[],
  targets: MacroTargets,
  phase: Phase
): PhaseSolution {
  console.log(`[GREEDY-FALLBACK] Using greedy approach for ${phase} phase`);

  const selectedFoods: PhaseSolution['foods'] = [];
  const totals = {
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    water_ml: 0,
    calories: 0,
  };

  // Sort foods by preference score and macro efficiency
  const sortedFoods = [...foods].sort((a, b) => {
    // Primary: preference score
    if (a.preference_score !== b.preference_score) {
      return b.preference_score - a.preference_score;
    }

    // Secondary: carb efficiency (carbs per serving)
    const carbsA = a.per_serving.carbs_g;
    const carbsB = b.per_serving.carbs_g;

    if (phase === 'after') {
      // For after-run, also consider protein efficiency
      const proteinA = a.per_serving.protein_g;
      const proteinB = b.per_serving.protein_g;
      return carbsB + proteinB - (carbsA + proteinA);
    }

    return carbsB - carbsA;
  });

  // Greedily select foods to meet targets
  const maxFoods = 3;
  const carbsTarget = targets.carbs_g;
  const proteinTarget = targets.protein_g || 0;
  const sodiumTarget = targets.sodium_mg || 0;
  const waterTarget = targets.water_ml || 0;

  for (const food of sortedFoods) {
    if (selectedFoods.length >= maxFoods) break;

    // Check if adding this food would cause excessive overshoots
    const wouldOvershootSodium =
      sodiumTarget > 0 &&
      totals.sodium_mg + food.per_serving.sodium_mg > sodiumTarget * 1.3;
    const wouldOvershootWater =
      waterTarget > 0 &&
      totals.water_ml + food.per_serving.water_ml > waterTarget * 1.3;

    // Skip foods that would cause major overshoots
    if (wouldOvershootSodium && totals.sodium_mg > sodiumTarget * 0.7) continue;
    if (wouldOvershootWater && totals.water_ml > waterTarget * 0.7) continue;

    // Calculate needed servings based on primary targets
    let neededServings = 0;

    if (phase === 'after' && proteinTarget > 0) {
      // For after-run, prioritize protein then carbs
      const proteinDeficit = Math.max(0, proteinTarget - totals.protein_g);
      const carbsDeficit = Math.max(0, carbsTarget - totals.carbs_g);

      if (proteinDeficit > 0 && food.per_serving.protein_g > 0) {
        neededServings = Math.ceil(proteinDeficit / food.per_serving.protein_g);
      } else if (carbsDeficit > 0 && food.per_serving.carbs_g > 0) {
        neededServings = Math.ceil(carbsDeficit / food.per_serving.carbs_g);
      }
    } else {
      // For before/during, focus on carbs
      const carbsDeficit = Math.max(0, carbsTarget - totals.carbs_g);
      if (carbsDeficit > 0 && food.per_serving.carbs_g > 0) {
        neededServings = Math.ceil(carbsDeficit / food.per_serving.carbs_g);
      }
    }

    // Reduce servings if it would cause major overshoots
    if (neededServings > 0) {
      // Check sodium overshoot potential
      if (sodiumTarget > 0 && food.per_serving.sodium_mg > 0) {
        const maxSodiumServings = Math.floor(
          (sodiumTarget * 1.25 - totals.sodium_mg) / food.per_serving.sodium_mg
        );
        neededServings = Math.min(neededServings, Math.max(1, maxSodiumServings));
      }

      // Check water overshoot potential
      if (waterTarget > 0 && food.per_serving.water_ml > 0) {
        const maxWaterServings = Math.floor(
          (waterTarget * 1.2 - totals.water_ml) / food.per_serving.water_ml
        );
        neededServings = Math.min(neededServings, Math.max(1, maxWaterServings));
      }
    }

    // Cap servings at reasonable amounts
    neededServings = Math.min(neededServings, 3);
    neededServings = roundToIncrement(neededServings);

    if (neededServings > 0) {
      selectedFoods.push({
        food_id: food.id,
        quantity: neededServings,
        carbs_grams: food.per_serving.carbs_g * neededServings,
        protein_grams: food.per_serving.protein_g * neededServings,
        fat_grams: food.per_serving.fat_g * neededServings,
        sodium_mg: food.per_serving.sodium_mg * neededServings,
        fluids_ml: food.per_serving.water_ml * neededServings,
        calories: food.per_serving.calories * neededServings,
        display_name: food.display_name ?? undefined,
        display_name_plural: food.display_name_plural ?? undefined,
        description: food.description ?? undefined,
        image_address: food.image_address ?? undefined,
      });

      totals.carbs_g += food.per_serving.carbs_g * neededServings;
      totals.protein_g += food.per_serving.protein_g * neededServings;
      totals.fat_g += food.per_serving.fat_g * neededServings;
      totals.sodium_mg += food.per_serving.sodium_mg * neededServings;
      totals.water_ml += food.per_serving.water_ml * neededServings;

      // Stop if we've met our carb target
      if (totals.carbs_g >= carbsTarget * 0.9) break;
    }
  }

  return {
    foods: selectedFoods,
    totals,
    needsElectrolyte: false,
    needsWater: false,
  };
}
