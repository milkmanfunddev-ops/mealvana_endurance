/**
 * Types for the template-based nutrition planning system
 */

import { type FoodResult, type MacroTargets } from '../types.ts';

// ============================================================================
// Template Types (from Supabase)
// ============================================================================

export interface TemplateFoodItem {
  food_id: string;
  food_name: string;
  display_name: string;
  serving_size: string;
  default_servings: number;
  min_servings: number;
  max_servings: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  calories: number;
  is_liquid?: boolean; // true for milk, OJ — fluid counts toward hydration targets
}

export interface Template {
  id: string;
  name: string;
  slug: string;
  phase: string;
  timing_window: string;
  timing_min_minutes: number;
  timing_max_minutes: number;
  meal_type: string; // 'full_meal' | 'snack' | 'top_up'
  base_category: string;
  digestion_speed: string;
  allergens: string[];
  excluded_diets: string[];
  notes: string | null;
  foods: TemplateFoodItem[];
  food_names: string[];
  total_carbs_g: number;
  total_protein_g: number;
  total_fat_g: number;
  total_sodium_mg: number;
  total_fluid_ml: number;
  total_calories: number;
  validation_status: string;
  is_active: boolean;
  sort_order: number;
  has_liquid_base?: boolean; // true for smoothie+milk, cereal+milk — skip drink assignment
}

export interface DrinkPoolItem {
  id: string;
  name: string;
  display_name: string;
  serving_size: string;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  calories: number;
  caffeine_mg: number | null;
  is_electrolyte: boolean;
  drink_pool_phases: string[];
}

// ============================================================================
// Sub-Phase Types
// ============================================================================

export type SubPhaseType = 'meal' | 'snack' | 'top_up';

export interface SubPhaseTargets {
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  water_ml: number;
}

export interface ScaledFood {
  food_id: string;
  food_name: string;
  display_name: string;
  serving_size: string;
  quantity: number;
  original_servings: number;
  scale_multiplier: number;
  carbs_grams: number;
  protein_grams: number;
  fat_grams: number;
  sodium_mg: number;
  fluids_ml: number;
  calories: number;
}

/**
 * A macro target the algorithm could not fully satisfy because viable foods
 * were filtered out by the user's preferences (dislikes, allergens, diet).
 * Surfaced to the UI as a guidance card with curated suggestions. Mirrors
 * the same shape used by during-phase (PhaseShortfall in plan-v3 types) so
 * the Flutter widget can render both with one code path. Issue #14 / #15.
 */
export interface SubPhaseShortfall {
  macro: 'carbs' | 'sodium' | 'fluid' | 'protein' | 'caffeine';
  delivered: number;
  target: number;
  unit: 'g' | 'mg' | 'ml';
  reason: 'all_disliked' | 'no_diet_match' | 'all_templates_filtered';
}

export interface SubPhaseResult {
  sub_phase_type: SubPhaseType;
  targets: SubPhaseTargets;
  foods: FoodResult[];
  template_id?: string;
  template_name?: string;
  drink?: FoodResult;
  /** Per-macro shortfalls when preferences eliminated viable options for
   * this sub-phase. Empty/absent on a clean fit. */
  shortfalls?: SubPhaseShortfall[];
  /** Pin honoring telemetry. Populated only when pins were supplied to the
   * algorithm. Mirrors PreWorkoutPhaseResult.pin_decision; carried into the
   * SubPhaseResult so the response surfaces it per phase. Formula Kit PR 2
   * substep 5b. */
  pin_decision?: {
    used_pin: boolean;
    pinned_template_id: string | null;
    fallthrough_reason: 'no_pin_for_scope' | null;
  };
}

// ============================================================================
// Plan V2 Output Types
// ============================================================================

export interface BeforePhaseResult {
  meal?: SubPhaseResult;
  snack?: SubPhaseResult;
  top_up?: SubPhaseResult;
}

export interface NutritionPlanV2Result {
  success: boolean;
  plan_id: string;
  plan: {
    before: BeforePhaseResult;
    during: FoodResult[];
    during_segments?: Record<string, FoodResult[]>;
    transitions?: Record<string, FoodResult[]>;
    after: FoodResult[];
  };
  macro_targets: Record<string, unknown>;
}

// ============================================================================
// Scaling Types
// ============================================================================

export interface ScalingResult {
  multiplier: number;
  foods: ScaledFood[];
  total_carbs: number;
  total_protein: number;
  total_fat: number;
  total_sodium: number;
  total_fluid: number;
  total_calories: number;
  score: number;
}

export interface FriendlyFraction {
  value: number;
  display: string;
}
