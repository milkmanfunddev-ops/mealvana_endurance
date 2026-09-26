/**
 * Turning the model's answer into the app's answer (ai-cost ticket 08, mp-473).
 *
 * Two rules live here, shared by `describe-meal` and `analyze-meal-photo`:
 *
 *  1. The totals are ours. Whatever the model reported is dropped and the
 *     items are added up, so the number at the bottom of the review screen
 *     always equals the rows above it.
 *  2. A photo or a sentence that is not food returns one answer and no macros.
 *
 * And the meal type follows the clock when the app sent one (mp-672,
 * slot_from_time.ts): the model's guess only breaks a tie near a boundary.
 */

import {
  type MealAnalysis,
  type MealAnalysisRequest,
  type MealItem,
  type MealTotals,
} from './schema.ts';
import { slotForMeal } from './slot_from_time.ts';

/** Grams and milligrams to one decimal; a float sum otherwise reads 45.300000000000004. */
function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

/**
 * The sum of every item's macros. Calories and sodium are whole numbers, the
 * macros keep one decimal.
 */
export function sumTotals(items: readonly MealItem[]): MealTotals {
  let calories = 0, carb = 0, protein = 0, fat = 0, sodium = 0;
  for (const item of items) {
    calories += item.calories;
    carb += item.carb_g;
    protein += item.protein_g;
    fat += item.fat_g;
    sodium += item.sodium_mg;
  }
  return {
    calories: Math.round(calories),
    carb_g: round1(carb),
    protein_g: round1(protein),
    fat_g: round1(fat),
    sodium_mg: Math.round(sodium),
  };
}

/** A meal, or the one-line "that is not food" answer. */
export type FinalizedAnalysis =
  | { notFood: true }
  | { notFood: false; analysis: MealAnalysis };

/**
 * Apply both rules to what the model returned.
 *
 * A model answer flagged `not_food`, or one with no items at all, is the
 * not-food answer: the caller sends the code and the app reads its line from
 * the content system. Anything else is a meal with totals we computed.
 */
export function finalizeAnalysis(
  requested: MealAnalysisRequest,
  { eatenAt }: { eatenAt?: unknown } = {},
): FinalizedAnalysis {
  if (requested.not_food === true || requested.items.length === 0) {
    return { notFood: true };
  }
  return {
    notFood: false,
    analysis: {
      name: requested.name,
      // The eaten-at wall clock decides; without one, the model's guess, else snack (mp-525).
      suggested_slot: slotForMeal(eatenAt, requested.suggested_slot),
      confidence: requested.confidence ?? 'medium',
      items: requested.items,
      // The model's own `totals` never reach the app.
      totals: sumTotals(requested.items),
      ...(requested.notes ? { notes: requested.notes } : {}),
    },
  };
}

/** The body a not-food answer returns: a code, never prose (the app's line is content-managed). */
export const NOT_FOOD_BODY = { error: 'not_food' } as const;

/** HTTP status for the not-food answer. Unchanged from before, so older app builds still map it. */
export const NOT_FOOD_STATUS = 422;
