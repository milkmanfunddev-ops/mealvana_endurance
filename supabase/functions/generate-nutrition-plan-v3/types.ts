/**
 * Types for generate-nutrition-plan-v3
 */

import type { ActivityType, FoodResult, MacroTargets } from "../_shared/nutrition/index.ts";
import type { PreWorkoutPhaseResult } from "../generate-macros-v4/types.ts";

// ============================================================================
// Plan Input
// ============================================================================

export interface PlanInputV2 {
  device_id: string;
  activity_type: string;
  hours_before: number;
  weight_kg: number;
  pre_run_selections?: PreWorkoutPhaseResult[];
  macro_targets: {
    pre_run: MacroTargets & { protein_g?: number; fat_g?: number };
    during_run: MacroTargets;
    post_run: MacroTargets & { protein_g?: number };
    phases?: {
      during_segments?: Array<{
        segment_order?: number;
        sport?: string;
        duration_minutes?: number;
        carbs_g: number;
        carbs_low_g?: number;
        carbs_high_g?: number;
        sodium_mg: number;
        sodium_low_mg?: number;
        sodium_high_mg?: number;
        water_ml: number;
        water_low_ml?: number;
        water_high_ml?: number;
      }>;
      transitions?: Array<{
        transition_name?: string;
        transition_id?: string;
        carbs_g: number;
        carbs_low_g?: number;
        carbs_high_g?: number;
        sodium_mg: number;
        sodium_low_mg?: number;
        sodium_high_mg?: number;
        water_ml: number;
        water_low_ml?: number;
        water_high_ml?: number;
      }>;
    };
  };
  dietary_preference?: string;
  allergies?: string[];
  liked_foods?: string[];
  disliked_foods?: string[];
  willing_to_try_foods?: string[];
  duration_minutes?: number;
  gut_training_level?: "low" | "moderate" | "high";
  brick_segments?: Array<{
    sport: string;
    duration_minutes: number;
    macro_targets: MacroTargets;
  }>;
  brick_phases?: {
    transitions?: Array<{
      transition_name?: string;
      transition_id?: string;
      carbs_g: number;
      carbs_low_g?: number;
      carbs_high_g?: number;
      sodium_mg: number;
      sodium_low_mg?: number;
      sodium_high_mg?: number;
      water_ml: number;
      water_low_ml?: number;
      water_high_ml?: number;
    }>;
  };
}

// ============================================================================
// Phase Result
// ============================================================================

export interface ByHourTimeSlot {
  hourIndex: number;
  slotIndex: number;
}

export interface ByHourAssignment {
  foodItemId: string;
  timeSlot: ByHourTimeSlot;
  isSipThroughout: boolean;
  adjustedQuantity: number;
  timingCategory: string;
}

export interface ByHourData {
  durationMinutes: number;
  assignments: ByHourAssignment[];
}

export interface TemplateMetadata {
  template_id: string;
  template_number: number;
  template_name: string;
  template_formula: string;
}

export interface LPPhaseResult {
  foods: FoodResult[];
  by_hour_data?: ByHourData | null;
  template_metadata?: TemplateMetadata | null;
}
