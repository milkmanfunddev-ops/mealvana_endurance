/**
 * Per-Phase Drink Selection
 *
 * Selects an appropriate drink for each sub-phase from the drink pool.
 * Drinks are separate from template foods (templates are food-only).
 *
 * Selection priority:
 * 1. Phase suitability (drink's drink_pool_phases includes this sub-phase)
 * 2. Hydration contribution (prefer drinks with higher fluid_ml)
 * 3. Carb contribution (prefer drinks that help hit carb targets)
 * 4. User preference (prefer liked drinks, avoid disliked)
 *
 * Conflict avoidance:
 * - Don't pick the same drink twice across sub-phases (unless water)
 */

import { type DrinkPoolItem, type SubPhaseType, type FoodResult } from './types.ts';
import type { FoodNutrition } from '../types.ts';

// ============================================================================
// Constants
// ============================================================================

/**
 * Water can be repeated across sub-phases (always available).
 */
const REPEATABLE_DRINKS = new Set(['water']);

/**
 * Default serving size for drinks.
 */
const DEFAULT_DRINK_SERVING_ML = 240; // 1 cup / 8 oz

// ============================================================================
// Drink Selection
// ============================================================================

/**
 * Score a drink for a given sub-phase.
 */
function scoreDrink(
  drink: DrinkPoolItem,
  subPhase: SubPhaseType,
  targetWaterMl: number,
  targetCarbsG: number,
  likedFoods: Set<string>,
  dislikedFoods: Set<string>,
): number {
  let score = 0;

  // Base: fluid contribution (30% weight)
  if (targetWaterMl > 0) {
    const fluidContrib = drink.fluid_ml / targetWaterMl;
    score += Math.min(fluidContrib, 1.0) * 30;
  }

  // Carb contribution for quick-energy phases (20% weight)
  if (subPhase === 'top_up' && drink.carbs_g > 0) {
    score += Math.min(drink.carbs_g / Math.max(targetCarbsG, 1), 1.0) * 20;
  }

  // Electrolyte bonus for later sub-phases (15% weight)
  if (drink.is_electrolyte && (subPhase === 'snack' || subPhase === 'top_up')) {
    score += 15;
  }

  // Caffeine bonus for meal phase only (10% weight)
  if (drink.caffeine_mg && drink.caffeine_mg > 0 && subPhase === 'meal') {
    score += 10;
  }

  // User preference (25% weight)
  const normalizedName = drink.name.toLowerCase();
  if (likedFoods.has(normalizedName)) {
    score += 25;
  } else if (dislikedFoods.has(normalizedName)) {
    score -= 30; // Strong penalty
  }

  return score;
}

/**
 * Select a drink for each active sub-phase from the drink pool.
 *
 * @param drinkPool - Available drinks from template_foods where is_drink_pool = true
 * @param activeSubPhases - Which sub-phases need drinks
 * @param targets - Per-sub-phase targets for scoring
 * @param likedFoods - User's liked food names
 * @param dislikedFoods - User's disliked food names
 * @returns Map of sub-phase type to selected drink (as FoodResult)
 */
export function selectDrinksForPhases(
  drinkPool: DrinkPoolItem[],
  activeSubPhases: SubPhaseType[],
  targets: Map<SubPhaseType, { carbs_g: number; water_ml: number }>,
  likedFoods?: string[],
  dislikedFoods?: string[],
): Map<SubPhaseType, FoodResult | null> {
  const result = new Map<SubPhaseType, FoodResult | null>();
  const usedDrinks = new Set<string>();

  const likedSet = new Set((likedFoods ?? []).map((f) => f.toLowerCase()));
  const dislikedSet = new Set((dislikedFoods ?? []).map((f) => f.toLowerCase()));

  for (const subPhase of activeSubPhases) {
    // Filter drinks available for this phase
    const phaseDrinks = drinkPool.filter((d) =>
      d.drink_pool_phases.includes(subPhase) &&
      (!usedDrinks.has(d.name) || REPEATABLE_DRINKS.has(d.name))
    );

    if (phaseDrinks.length === 0) {
      console.log(`[DRINK-SELECT] No drinks available for ${subPhase}`);
      result.set(subPhase, null);
      continue;
    }

    const phaseTargets = targets.get(subPhase) ?? { carbs_g: 20, water_ml: 200 };

    // Score all available drinks
    const scored = phaseDrinks.map((drink) => ({
      drink,
      score: scoreDrink(
        drink,
        subPhase,
        phaseTargets.water_ml,
        phaseTargets.carbs_g,
        likedSet,
        dislikedSet,
      ),
    }));

    // Sort by score descending
    scored.sort((a, b) => b.score - a.score);

    const selected = scored[0].drink;
    usedDrinks.add(selected.name);

    console.log(
      `[DRINK-SELECT] ${subPhase}: ${selected.display_name} (score: ${scored[0].score.toFixed(1)}, ` +
      `${selected.fluid_ml}ml fluid, ${selected.carbs_g}g carbs)`
    );

    // Convert to FoodResult
    result.set(subPhase, {
      food_id: selected.id,
      quantity: 1,
      carbs_grams: selected.carbs_g,
      protein_grams: selected.protein_g,
      fat_grams: selected.fat_g,
      sodium_mg: selected.sodium_mg,
      fluids_ml: selected.fluid_ml,
      calories: selected.calories,
      display_name: selected.display_name,
      serving_size: selected.serving_size,
      timing: undefined,
      is_drink: true, // flag for client to distinguish drinks from foods
    } as FoodResult & { is_drink: boolean });
  }

  return result;
}
