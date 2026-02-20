/**
 * Pre-Workout Target Splitting
 *
 * Splits total pre-workout macro targets across sub-phases (meal, snack, top_up)
 * based on hours before activity. Budget percentages are research-based:
 * - Meal: bulk of protein/fat (slower digestion), moderate carbs
 * - Snack: moderate carbs, some sodium/fluids
 * - Top-up: quick carbs, final hydration push
 */

import { type SubPhaseType, type SubPhaseTargets } from './types.ts';

// ============================================================================
// Budget Split Percentages
// ============================================================================

/**
 * How to distribute macros across sub-phases.
 * Each array is [meal%, snack%, top_up%] summing to 1.0
 */
const BUDGET_SPLITS = {
  carbs:    { meal: 0.60, snack: 0.25, top_up: 0.15 },
  protein:  { meal: 0.70, snack: 0.25, top_up: 0.05 },
  fat:      { meal: 0.80, snack: 0.15, top_up: 0.05 },
  sodium:   { meal: 0.30, snack: 0.50, top_up: 0.20 },
  water:    { meal: 0.30, snack: 0.40, top_up: 0.30 },
};

// ============================================================================
// Phase Schedule
// ============================================================================

/**
 * Determine which sub-phases are present based on hours before activity.
 *
 * >= 2.5h: meal + snack + top_up (3-4h window = full prep)
 * >= 1.0h: snack + top_up (1-2h window)
 * < 1.0h:  top_up only (quick top-off)
 */
export function getActiveSubPhases(hoursBefore: number): SubPhaseType[] {
  if (hoursBefore >= 2.5) {
    return ['meal', 'snack', 'top_up'];
  }
  if (hoursBefore >= 1.0) {
    return ['snack', 'top_up'];
  }
  return ['top_up'];
}

// ============================================================================
// Target Splitting
// ============================================================================

/**
 * Split total pre-workout targets across active sub-phases.
 *
 * When fewer sub-phases are active, budgets are redistributed proportionally.
 * For example, if only snack + top_up are active, the meal budget is redistributed
 * to snack and top_up proportionally.
 */
export function splitPreWorkoutTargets(
  totalTargets: {
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    water_ml: number;
  },
  hoursBefore: number,
): Map<SubPhaseType, SubPhaseTargets> {
  const activePhases = getActiveSubPhases(hoursBefore);
  const result = new Map<SubPhaseType, SubPhaseTargets>();

  for (const phase of activePhases) {
    result.set(phase, {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0,
    });
  }

  // For each macro, redistribute budget across active phases
  const macros: (keyof typeof BUDGET_SPLITS)[] = ['carbs', 'protein', 'fat', 'sodium', 'water'];
  const macroKeys: Record<string, keyof SubPhaseTargets> = {
    carbs: 'carbs_g',
    protein: 'protein_g',
    fat: 'fat_g',
    sodium: 'sodium_mg',
    water: 'water_ml',
  };
  const totalKeys: Record<string, keyof typeof totalTargets> = {
    carbs: 'carbs_g',
    protein: 'protein_g',
    fat: 'fat_g',
    sodium: 'sodium_mg',
    water: 'water_ml',
  };

  for (const macro of macros) {
    const splits = BUDGET_SPLITS[macro];
    const totalValue = totalTargets[totalKeys[macro]];

    // Sum of budgets for active phases only
    let activeSum = 0;
    for (const phase of activePhases) {
      activeSum += splits[phase];
    }

    // Redistribute proportionally
    for (const phase of activePhases) {
      const proportion = splits[phase] / activeSum;
      const target = result.get(phase)!;
      (target as Record<string, number>)[macroKeys[macro]] = Math.round(totalValue * proportion * 10) / 10;
    }
  }

  return result;
}

/**
 * Get timing label for a sub-phase based on hours_before.
 */
export function getSubPhaseTimingLabel(
  subPhase: SubPhaseType,
  hoursBefore: number,
): string {
  if (subPhase === 'meal') {
    return `${hoursBefore >= 3 ? '3-4' : '2-3'} hours before`;
  }
  if (subPhase === 'snack') {
    return hoursBefore >= 2.5 ? '1-2 hours before' : '45-60 min before';
  }
  return '15-30 min before';
}
