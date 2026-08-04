/**
 * Shared Zod schema and TypeScript types for Mealvana AI meal analysis results.
 *
 * Used by both `analyze-meal-photo` and `describe-meal` edge functions so the
 * output shape is identical regardless of input modality.
 */

import { z } from 'npm:zod@3';

// ---------------------------------------------------------------------------
// Per-item schema
// ---------------------------------------------------------------------------

export const MealItemSchema = z.object({
  /** Common food name, e.g. "grilled chicken breast" */
  name: z.string(),
  /** Human-readable portion, e.g. "1 cup", "3 oz", "1 medium" */
  portion: z.string(),
  /** Estimated kilocalories (integer) */
  calories: z.number().int().nonnegative(),
  /** Carbohydrates in grams */
  carb_g: z.number().nonnegative(),
  /** Protein in grams */
  protein_g: z.number().nonnegative(),
  /** Fat in grams */
  fat_g: z.number().nonnegative(),
  /** Sodium in milligrams */
  sodium_mg: z.number().nonnegative(),
});

export type MealItem = z.infer<typeof MealItemSchema>;

// ---------------------------------------------------------------------------
// Totals schema — mirrors per-item macro fields (no portion string)
// ---------------------------------------------------------------------------

export const MealTotalsSchema = z.object({
  calories: z.number().int().nonnegative(),
  carb_g: z.number().nonnegative(),
  protein_g: z.number().nonnegative(),
  fat_g: z.number().nonnegative(),
  sodium_mg: z.number().nonnegative(),
});

export type MealTotals = z.infer<typeof MealTotalsSchema>;

// ---------------------------------------------------------------------------
// Top-level analysis result schema
// ---------------------------------------------------------------------------

export const MealAnalysisSchema = z.object({
  /** Short descriptive title, e.g. "Grilled chicken with rice and salad" */
  name: z.string(),
  /**
   * Best-guess meal slot for an endurance athlete's typical eating pattern.
   * The app may override this based on the time of day.
   */
  suggested_slot: z.enum(['breakfast', 'lunch', 'dinner', 'snack']),
  /** Model's self-reported confidence in the identification and estimates */
  confidence: z.enum(['low', 'medium', 'high']),
  /** Individual dishes identified in the meal. A single meal should not need
   * more than 12 separately logged dishes; this also bounds structured output. */
  items: z.array(MealItemSchema).min(1).max(12),
  /** Sum of all item macros — pre-computed by the model for convenience */
  totals: MealTotalsSchema,
  /**
   * Optional one-line caveat visible to the user, e.g.
   * "Sauce portion estimated; could add 50–100 kcal"
   */
  notes: z.string().optional(),
});

export type MealAnalysis = z.infer<typeof MealAnalysisSchema>;
