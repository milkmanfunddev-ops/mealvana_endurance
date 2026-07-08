/**
 * Shared Zod schema for AI meal-plan import (`parse-meal-plan`).
 *
 * A meal plan (PDF or photographed printout) parses into a flat list of meals.
 * Each meal reuses the per-item / totals shapes from `meal_analysis/schema.ts`
 * so the parsed macros map 1:1 onto the app's `MealComponent` wire format —
 * the same shape the photo and describe flows already emit.
 */

import { z } from 'npm:zod@3';
import { MealItemSchema, MealTotalsSchema } from '../meal_analysis/schema.ts';

// ---------------------------------------------------------------------------
// One meal within the plan
// ---------------------------------------------------------------------------

export const PlanMealSchema = z.object({
  /** Short descriptive title, e.g. "Overnight oats with berries" */
  name: z.string(),
  /**
   * The day this meal belongs to as written in the plan, if any — e.g.
   * "Day 1", "Monday", "Race day". Free-form; the app groups by it for review
   * but does not assign calendar dates.
   */
  day_label: z.string().optional(),
  /** Best-guess slot for grouping in the review UI. */
  suggested_slot: z.enum(['breakfast', 'lunch', 'dinner', 'snack']),
  /** Model's confidence in the parse + macro estimates for this meal. */
  confidence: z.enum(['low', 'medium', 'high']),
  /** Individual food items that make up the meal. */
  items: z.array(MealItemSchema).min(1),
  /** Sum of all item macros — pre-computed by the model. */
  totals: MealTotalsSchema,
  /** Optional per-meal caveat, e.g. "portion not specified; estimated". */
  notes: z.string().optional(),
});

export type PlanMeal = z.infer<typeof PlanMealSchema>;

// ---------------------------------------------------------------------------
// Top-level plan result
// ---------------------------------------------------------------------------

export const MealPlanSchema = z.object({
  /** Plan title if the document has one, e.g. "12-Week Marathon Fuel Plan". */
  plan_title: z.string().optional(),
  /** Every meal found in the document, in reading order. */
  meals: z.array(PlanMealSchema).min(1),
  /** Optional one-line caveat about the overall parse. */
  notes: z.string().optional(),
});

export type MealPlan = z.infer<typeof MealPlanSchema>;
