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
  serving_size?: string | null;
  serving_unit?: string | null;
  serving_qualifier?: string | null;
  per_serving: FoodNutrition;
  serving_amount: number | null;
  max_servings: number;
  preference_score: number;
  is_electrolyte: boolean;
  is_liquid: boolean;
  is_essential: boolean;
  is_user_food: boolean;
  is_indivisible: boolean;
  product_type?: string;
}

export type TimingCategory = 'sip_throughout' | 'fuel_drink' | 'quick_consume' | 'slow_consume' | 'electrolyte';

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
  serving_size?: string | null;
  serving_unit?: string | null;
  serving_qualifier?: string | null;
  is_liquid?: boolean;
  is_electrolyte?: boolean;
  is_drink?: boolean;
  is_indivisible?: boolean;
  timing_category?: TimingCategory;
  product_type?: string;
}

/**
 * Derive timing category from food properties.
 * Priority: supplements > liquids (fuel_drink vs sip_throughout) > electrolytes > gels/chews > everything else.
 *
 * fuel_drink: liquids with >5g carbs per serving (e.g. sports drink).
 *   Placed like sip_throughout (distributed at :00) but displayed as fuel with carb badge.
 * sip_throughout: zero/low-carb liquids (e.g. water).
 */
export function deriveTimingCategory(food: Food): TimingCategory {
  // Supplement items are discrete electrolyte events, not sip-throughout drinks.
  if (food.product_type === 'supplement') return 'electrolyte';
  if (food.is_liquid) {
    return food.per_serving.carbs_g > 5 ? 'fuel_drink' : 'sip_throughout';
  }
  if (food.is_electrolyte) return 'electrolyte';
  if (food.product_type === 'gel' || food.product_type === 'chew') return 'quick_consume';
  return 'slow_consume';
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

export type ActivityType = 'running' | 'cycling' | 'swimming' | 'triathlon' | 'duathlon' | 'multisport' | 'brick';
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
