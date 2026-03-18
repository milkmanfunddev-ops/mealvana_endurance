/**
 * Shared Algorithm Utilities
 *
 * Common functions used across all four algorithms:
 * - Friendly fraction snapping
 * - Formula filtering by time window and diet
 * - Carb budget splitting
 * - Add-on helpers
 */

import {
  type Formula,
  type SubPhaseType,
  type SubPhaseTargets,
  type FormulaSelection,
  type AddOn,
  type SubPhaseResult,
  type AlgorithmResult,
  BANANA_CARBS,
  BANANA_SODIUM,
  BANANA_FLUID,
  SPORTS_DRINK_CARBS,
  SPORTS_DRINK_SODIUM,
  SPORTS_DRINK_FLUID,
} from '../types.ts';
import { filterFormulasByDiet } from '../data/formulas.ts';

// ============================================================================
// Friendly Fractions
// ============================================================================

const FRIENDLY_FRACTIONS = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0];

/**
 * Snap a value to the nearest 0.5 increment.
 */
export function snapToHalf(value: number): number {
  return Math.round(value * 2) / 2;
}

/**
 * Snap to the nearest friendly fraction (from the predefined list).
 */
export function snapToFriendly(value: number): number {
  if (value <= 0) return 0;

  let closest = FRIENDLY_FRACTIONS[0];
  let minDist = Math.abs(value - closest);

  for (const frac of FRIENDLY_FRACTIONS) {
    const dist = Math.abs(value - frac);
    if (dist < minDist) {
      minDist = dist;
      closest = frac;
    }
  }

  return closest;
}

/**
 * Clamp servings to formula's min/max range, then snap to 0.5.
 */
export function clampAndSnap(servings: number, formula: Formula): number {
  const clamped = Math.max(formula.min_servings, Math.min(formula.max_servings, servings));
  return snapToHalf(clamped);
}

// ============================================================================
// Formula Filtering
// ============================================================================

/**
 * Get time window for a sub-phase.
 */
export function getTimeWindowForPhase(phase: SubPhaseType): string {
  switch (phase) {
    case 'meal': return '1.5-3 hours';
    case 'snack': return '30-90 min';
    case 'top_up': return '< 30 min';
  }
}

/**
 * Get eligible formulas for a sub-phase, filtered by diet.
 */
export function getEligibleFormulas(
  allFormulas: Formula[],
  phase: SubPhaseType,
  diet: string,
): Formula[] {
  const timeWindow = getTimeWindowForPhase(phase);
  const filtered = allFormulas.filter((f) => f.time_window === timeWindow);
  return filterFormulasByDiet(filtered, diet);
}

// ============================================================================
// Scoring Helpers
// ============================================================================

/**
 * Calculate carbs delivered by a formula at given servings.
 */
export function formulaCarbs(formula: Formula, servings: number): number {
  return formula.carbs_per_serving * servings;
}

/**
 * Calculate sodium delivered by a formula at given servings.
 */
export function formulaSodium(formula: Formula, servings: number): number {
  return formula.sodium_mg * servings;
}

/**
 * Calculate fluid delivered by a formula at given servings.
 */
export function formulaFluid(formula: Formula, servings: number): number {
  return formula.fluid_ml * servings;
}

/**
 * Create a FormulaSelection from a formula and servings.
 */
export function makeSelection(formula: Formula, servings: number): FormulaSelection {
  return {
    formula_name: formula.name,
    formula_id: formula.id,
    base_category: formula.base_category,
    servings,
    carbs_g: Math.round(formula.carbs_per_serving * servings * 10) / 10,
    protein_g: Math.round(formula.protein_per_serving * servings * 10) / 10,
    fat_g: Math.round(formula.fat_per_serving * servings * 10) / 10,
    sodium_mg: Math.round(formula.sodium_mg * servings * 10) / 10,
    fluid_ml: Math.round(formula.fluid_ml * servings * 10) / 10,
  };
}

/**
 * Create a banana add-on.
 */
export function makeBananaAddOn(): AddOn {
  return { type: 'banana', carbs_g: BANANA_CARBS, sodium_mg: BANANA_SODIUM, fluid_ml: BANANA_FLUID };
}

/**
 * Create a sports drink add-on.
 */
export function makeSportsDrinkAddOn(): AddOn {
  return { type: 'sports_drink', carbs_g: SPORTS_DRINK_CARBS, sodium_mg: SPORTS_DRINK_SODIUM, fluid_ml: SPORTS_DRINK_FLUID };
}

// ============================================================================
// Result Assembly
// ============================================================================

/**
 * Build a SubPhaseResult from selections and add-ons.
 */
export function buildSubPhaseResult(
  phase: SubPhaseType,
  formula: FormulaSelection | null,
  addOns: AddOn[],
  drink?: FormulaSelection | null,
): SubPhaseResult {
  const formulaCarbs = formula?.carbs_g ?? 0;
  const formulaSodium = formula?.sodium_mg ?? 0;
  const formulaFluid = formula?.fluid_ml ?? 0;
  const addOnCarbs = addOns.reduce((s, a) => s + a.carbs_g, 0);
  const addOnSodium = addOns.reduce((s, a) => s + a.sodium_mg, 0);
  const addOnFluid = addOns.reduce((s, a) => s + a.fluid_ml, 0);
  const drinkCarbs = drink?.carbs_g ?? 0;
  const drinkSodium = drink?.sodium_mg ?? 0;
  const drinkFluid = drink?.fluid_ml ?? 0;

  return {
    phase,
    formula,
    drink: drink ?? undefined,
    add_ons: addOns,
    total_carbs_g: Math.round((formulaCarbs + addOnCarbs + drinkCarbs) * 10) / 10,
    total_sodium_mg: Math.round((formulaSodium + addOnSodium + drinkSodium) * 10) / 10,
    total_fluid_ml: Math.round((formulaFluid + addOnFluid + drinkFluid) * 10) / 10,
  };
}

/**
 * Assemble a full AlgorithmResult from sub-phase results.
 */
export function assembleResult(algorithm: string, subPhases: SubPhaseResult[]): AlgorithmResult {
  return {
    algorithm,
    sub_phases: subPhases,
    total_carbs_g: Math.round(subPhases.reduce((s, p) => s + p.total_carbs_g, 0) * 10) / 10,
    total_protein_g: Math.round(
      subPhases.reduce((s, p) =>
        s + (p.formula?.protein_g ?? 0) + (p.second_formula?.protein_g ?? 0) + (p.drink?.protein_g ?? 0), 0) * 10
    ) / 10,
    total_fat_g: Math.round(
      subPhases.reduce((s, p) =>
        s + (p.formula?.fat_g ?? 0) + (p.second_formula?.fat_g ?? 0) + (p.drink?.fat_g ?? 0), 0) * 10
    ) / 10,
    total_sodium_mg: Math.round(subPhases.reduce((s, p) => s + p.total_sodium_mg, 0) * 10) / 10,
    total_fluid_ml: Math.round(subPhases.reduce((s, p) => s + p.total_fluid_ml, 0) * 10) / 10,
  };
}
