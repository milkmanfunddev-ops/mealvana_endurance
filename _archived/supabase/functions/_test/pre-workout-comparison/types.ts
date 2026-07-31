/**
 * Shared types for pre-workout algorithm comparison test suite.
 */

// ============================================================================
// Formula Types
// ============================================================================

export type TimeWindow = '< 30 min' | '30-90 min' | '1.5-3 hours';
export type DigestionSpeed = 'Fast' | 'Medium';
export type Allergen = 'Gluten' | 'Dairy' | 'Peanut';
export type Diet = 'none' | 'gluten-free' | 'dairy-free' | 'peanut-free' | 'all-free';

export interface Formula {
  id: string;
  name: string;
  base_category: string;
  time_window: TimeWindow;
  digestion_speed: DigestionSpeed;
  allergens: Allergen[];
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
}

// ============================================================================
// Scenario Types
// ============================================================================

export interface Scenario {
  id: string;
  label: string;
  weight_kg: number;
  hours_before: number;
  diet: Diet;
  targets: MacroTargets;
}

export interface MacroTargets {
  total_carbs_g: number;
  total_protein_g: number;
  total_fat_g: number;
  total_sodium_mg: number;
  total_sodium_low_mg: number;
  total_sodium_high_mg: number;
  total_hydration_ml: number;
  total_hydration_low_ml: number;
  total_hydration_high_ml: number;
  meal_type: string;
  phase_targets: Map<SubPhaseType, SubPhaseTargets>;
}

export type SubPhaseType = 'meal' | 'snack' | 'top_up';

export interface SubPhaseTargets {
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  water_ml: number;
}

// ============================================================================
// Algorithm Output Types
// ============================================================================

export interface FormulaSelection {
  formula_name: string;
  formula_id: string;
  base_category: string;
  servings: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
}

export interface AddOn {
  type: 'banana' | 'sports_drink';
  carbs_g: number;
  sodium_mg: number;
  fluid_ml: number;
}

export interface SubPhaseResult {
  phase: SubPhaseType;
  formula: FormulaSelection | null;
  second_formula?: FormulaSelection | null;
  drink?: FormulaSelection | null;
  add_ons: AddOn[];
  total_carbs_g: number;
  total_sodium_mg: number;
  total_fluid_ml: number;
}

export interface AlgorithmResult {
  algorithm: string;
  sub_phases: SubPhaseResult[];
  total_carbs_g: number;
  total_protein_g: number;
  total_fat_g: number;
  total_sodium_mg: number;
  total_fluid_ml: number;
}

// ============================================================================
// Evaluation Types
// ============================================================================

export type CriterionSeverity = 'FAIL' | 'WARN';

export interface CriterionResult {
  name: string;
  passed: boolean;
  severity: CriterionSeverity;
  detail: string;
}

export interface EvaluationResult {
  scenario_id: string;
  algorithm: string;
  passed: boolean;
  criteria: CriterionResult[];
  fail_count: number;
  warn_count: number;
}

// ============================================================================
// Report Types
// ============================================================================

export interface AlgorithmSummary {
  algorithm: string;
  total_scenarios: number;
  passed: number;
  failed: number;
  pass_rate: number;
  failure_breakdown: Record<string, number>;
  warn_breakdown: Record<string, number>;
}

export interface ComparisonReport {
  timestamp: string;
  total_scenarios: number;
  algorithms: AlgorithmSummary[];
  evaluations: EvaluationResult[];
}

// ============================================================================
// Add-on Constants
// ============================================================================

export const BANANA_CARBS = 27;
export const BANANA_SODIUM = 1; // negligible
export const BANANA_FLUID = 0;
export const SPORTS_DRINK_CARBS = 17;
export const SPORTS_DRINK_SODIUM = 230;
export const SPORTS_DRINK_FLUID = 240; // ~8oz
