/**
 * TypeScript interfaces for generate-macros-v4 edge function.
 *
 * Covers:
 * - Database template types (food, drink, electrolyte)
 * - Algorithm state and scoring
 * - Pre-workout selection output
 */

// ============================================================================
// Database Template Types
// ============================================================================

export type TemplateType = 'food' | 'drink' | 'electrolyte';
export type TimeWindow = '< 30 min' | '30-90 min' | '1.5-3 hours';
export type SubPhaseType = 'meal' | 'snack' | 'top_up';

export interface PreWorkoutTemplate {
  id: string;
  name: string;
  base_category: string;
  time_window: TimeWindow;
  digestion_speed: string;
  allergens: string[];
  excluded_diets?: string[];
  serving_unit: string;
  min_servings: number;
  max_servings: number;
  plus_banana: boolean;
  plus_sports_drink: boolean;
  carbs_per_serving: number;
  protein_per_serving: number;
  fat_per_serving: number;
  sodium_mg: number;
  fluid_ml: number;
  template_type: TemplateType;
  is_active: boolean;
  component_food_names: string[];
  component_quantities: Record<string, number>;
}

// ============================================================================
// Algorithm State
// ============================================================================

export interface PlanState {
  used_foods: Set<string>;          // All component food names used across phases
  sports_drink_used: boolean;       // Limits sports drink ADD-ON to one across all phases
  used_categories: Set<string>;
  carbs_delivered: number;
  protein_delivered: number;
  sodium_delivered: number;
  fluid_delivered: number;
  carbs_target: number;
  carbs_low: number;
  carbs_high: number;
  protein_target: number;
  protein_low: number;
  protein_high: number;
  sodium_target: number;
  sodium_low: number;
  sodium_high: number;
  fluid_target: number;
  fluid_low: number;
  fluid_high: number;
}

export interface ScoredFormula {
  template: PreWorkoutTemplate;
  servings: number;
  carbs: number;
  protein: number;
  addOns: AddOn[];
  gap: number;
  sodium: number;
  fluid: number;
}

// ============================================================================
// Add-on Constants
// ============================================================================

export const BANANA_CARBS = 27;
export const BANANA_SODIUM = 1;
export const BANANA_FLUID = 0;
export const SPORTS_DRINK_CARBS = 15;    // per 1 cup (8 oz)
export const SPORTS_DRINK_SODIUM = 100;   // per 1 cup (8 oz)
export const SPORTS_DRINK_FLUID = 240;    // per 1 cup (8 oz)
// Pass 1.5 universal fallback foods (vegan, gluten-free, no common allergens).
// Used to deliver carbs when banana/sports_drink are disliked or already used. (#15)
export const DATES_CARBS = 18;            // per 2 medjool dates
export const DATES_SODIUM = 0;
export const DATES_FLUID = 0;
export const APPLESAUCE_CARBS = 25;       // per 1/2 cup unsweetened pouch
export const APPLESAUCE_SODIUM = 5;
export const APPLESAUCE_FLUID = 0;
export const RAISINS_CARBS = 22;          // per 1/4 cup
export const RAISINS_SODIUM = 5;
export const RAISINS_FLUID = 0;

// ============================================================================
// Algorithm Output Types
// ============================================================================

export interface AddOn {
  type: 'banana' | 'sports_drink' | 'dates' | 'applesauce' | 'raisins';
  carbs_g: number;
  sodium_mg: number;
  fluid_ml: number;
  servings: number;        // 1 for fixed-size add-ons; 0.5, 1, or 2 cups for sports drink
}

export interface TemplateSelection {
  id: string;
  name: string;
  base_category: string;
  serving_unit: string;
  servings: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  component_food_names: string[];
  component_quantities: Record<string, number>;
}

/**
 * Macro target the algorithm could not satisfy because all viable templates
 * or foods were filtered out by user preferences (dislikes/allergens/diet).
 * Surfaced to the UI as a guidance card with curated suggestions. Different
 * from "user just doesn't need much" — only emitted when target > 0 AND
 * delivery is < 90% of target AND the cause is preference-driven filtering.
 *
 * Mirrors the during-phase PhaseShortfall in plan-v3 types.ts so the Flutter
 * widget can render both with one code path.
 */
export interface PreWorkoutShortfall {
  macro: 'carbs' | 'sodium' | 'fluid' | 'protein';
  delivered: number;
  target: number;
  unit: 'g' | 'mg' | 'ml';
  reason: 'all_disliked' | 'no_diet_match' | 'all_templates_filtered';
}

export interface PreWorkoutPhaseResult {
  phase: SubPhaseType;
  primary: TemplateSelection | null;
  stack?: TemplateSelection | null;
  drink?: TemplateSelection | null;
  electrolyte?: TemplateSelection | null;
  add_ons: AddOn[];
  total_carbs_g: number;
  total_protein_g: number;
  total_fat_g: number;
  total_sodium_mg: number;
  total_fluid_ml: number;
  /** Per-macro shortfalls when preferences eliminated all viable options
   * for this phase. Issue #15. */
  shortfalls?: PreWorkoutShortfall[];
  /** Pin honoring telemetry. Populated only when `pinnedTemplateIds` was
   * passed into `selectPreWorkoutFoods`. `used_pin = true` means the primary
   * selection for this phase was driven by a user pin (all preference / diet
   * / scale-clamp filters were bypassed). `fallthrough_reason = 'no_pin_for_scope'`
   * means pins were passed in but none matched this sub_phase's time_window.
   * Field is omitted entirely when no pins were supplied — keeps no-pin
   * behavior byte-identical to pre-pin v3. Formula Kit PR 2 substep 5a. */
  pin_decision?: {
    used_pin: boolean;
    /** True when satisfied by the EPHEMERAL default-formula safety net rather
     * than a real `formula_pins` row. Absent/false for real pins. Formula-first
     * flip, 2026-07-03 (plan Phase 2 #5). */
    ephemeral?: boolean;
    pinned_template_id: string | null;
    /** Template display name when `used_pin = true`, otherwise null. Lets the
     * client render the pinned formula's label in the activity-detail pin
     * banner without an extra round-trip. Formula Kit PR 2 substep 9. */
    pinned_template_name: string | null;
    fallthrough_reason: 'no_pin_for_scope' | null;
    /** Count of in-scope pinned candidates the algorithm saw for this phase
     * after scope-matching. Drives `plan_used_pin` / `plan_pin_fallthrough`
     * analytics. 0 when pins were supplied but none matched scope.
     * Formula Kit PR 2 substep 7. */
    pin_set_size: number;
  };
}

// ============================================================================
// Pre-workout Target Ranges
// ============================================================================

export interface PreWorkoutTargets {
  carbs_g: number;
  carbs_low_g: number;
  carbs_high_g: number;
  protein_g: number;
  protein_low_g: number;
  protein_high_g: number;
  fat_g: number;
  sodium_mg: number;
  sodium_low_mg: number;
  sodium_high_mg: number;
  water_ml: number;
  water_low_ml: number;
  water_high_ml: number;
  meal_type: string;
}

export interface SubPhaseTargets {
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  water_ml: number;
}

// ============================================================================
// Budget Splits
// ============================================================================

export const BUDGET_SPLITS = {
  carbs:   { meal: 0.60, snack: 0.25, top_up: 0.15 },
  protein: { meal: 0.70, snack: 0.25, top_up: 0.05 },
  fat:     { meal: 0.80, snack: 0.15, top_up: 0.05 },
  sodium:  { meal: 0.30, snack: 0.50, top_up: 0.20 },
  water:   { meal: 0.30, snack: 0.40, top_up: 0.30 },
} as const;
