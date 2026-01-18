/**
 * TypeScript types for nutrition planning
 */

// ============================================================================
// Food Types
// ============================================================================

export interface FoodNutrition {
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  water_ml: number;
  calories: number;
}

export interface Food {
  id: string;
  name: string;
  display_name: string | null;
  display_name_plural: string | null;
  description: string | null;
  image_address: string | null;
  per_serving: FoodNutrition;
  serving_amount: number | null;
  max_servings: number;
  preference_score: number;
  is_electrolyte: boolean;
  is_essential: boolean;
  is_user_food: boolean;
}

export interface FoodResult {
  food_id: string;
  quantity: number;
  carbs_grams: number;
  protein_grams: number;
  fat_grams: number;
  sodium_mg: number;
  fluids_ml: number;
  calories: number;
  timing?: string;
  display_name?: string;
  display_name_plural?: string;
  description?: string;
  image_address?: string;
}

// ============================================================================
// Target Types
// ============================================================================

export interface MacroTargets {
  carbs_g: number;
  protein_g?: number;
  sodium_mg: number;
  water_ml: number;
}

export interface PhaseTargets {
  pre_run: MacroTargets;
  during_run: MacroTargets;
  post_run: MacroTargets;
}

// ============================================================================
// Solution Types
// ============================================================================

export interface PhaseSolution {
  foods: FoodResult[];
  totals: FoodNutrition;
  needsElectrolyte?: boolean;
  needsWater?: boolean;
}

export interface PhaseResult {
  items: FoodResult[];
  totals: FoodNutrition;
}

export interface NutritionPlanResult {
  success: boolean;
  plan_id: string;
  detailed_message: string;
  plan: {
    before: FoodResult[];
    during: FoodResult[];
    after: FoodResult[];
  };
  macro_targets: PhaseTargets & { activity_type: ActivityType };
}

// ============================================================================
// Activity Types
// ============================================================================

export type ActivityType = 'running' | 'cycling' | 'swimming' | 'triathlon' | 'duathlon' | 'multisport';
export type Phase = 'before' | 'during' | 'after';
export type PreferenceCategory = 'liked' | 'willing' | 'essential' | 'neutral';

// ============================================================================
// Request Types
// ============================================================================

export interface GenerateNutritionPlanRequest {
  device_id: string;
  macro_targets: PhaseTargets;
  liked_foods?: string[];
  willing_to_try_foods?: string[];
  disliked_foods?: string[];
  activity_type?: ActivityType;
}

// ============================================================================
// LP Solver Types
// ============================================================================

export interface LPModel {
  optimize: string;
  opType: 'max' | 'min';
  constraints: Record<string, { min?: number; max?: number }>;
  variables: Record<string, Record<string, number>>;
  ints?: Record<string, number>;
  binaries?: Record<string, number>;
}

export interface LPSolution {
  feasible: boolean;
  [key: string]: number | boolean;
}
