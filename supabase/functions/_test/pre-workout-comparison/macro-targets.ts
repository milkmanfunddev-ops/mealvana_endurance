/**
 * V3 Macro Target Calculator
 *
 * Ported from generate-macros-v3/index.ts (calculatePreWorkoutMacros).
 * Calculates pre-workout carb/protein/fat/sodium/hydration targets
 * and splits them across sub-phases.
 */

import { type MacroTargets, type SubPhaseType, type SubPhaseTargets } from './types.ts';

// ============================================================================
// Budget Split Percentages (from pre-workout-targets.ts)
// ============================================================================

const BUDGET_SPLITS = {
  carbs:   { meal: 0.60, snack: 0.25, top_up: 0.15 },
  protein: { meal: 0.70, snack: 0.25, top_up: 0.05 },
  fat:     { meal: 0.80, snack: 0.15, top_up: 0.05 },
  sodium:  { meal: 0.30, snack: 0.50, top_up: 0.20 },
  water:   { meal: 0.30, snack: 0.40, top_up: 0.30 },
};

// ============================================================================
// Phase Schedule
// ============================================================================

export function getActiveSubPhases(hoursBefore: number): SubPhaseType[] {
  if (hoursBefore >= 2.5) return ['meal', 'snack', 'top_up'];
  if (hoursBefore >= 1.0) return ['snack', 'top_up'];
  return ['top_up'];
}

// ============================================================================
// Target Splitting
// ============================================================================

function splitTargets(
  totals: { carbs_g: number; protein_g: number; fat_g: number; sodium_mg: number; water_ml: number },
  hoursBefore: number,
): Map<SubPhaseType, SubPhaseTargets> {
  const activePhases = getActiveSubPhases(hoursBefore);
  const result = new Map<SubPhaseType, SubPhaseTargets>();

  for (const phase of activePhases) {
    result.set(phase, { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 });
  }

  const macroMap: Array<{ budget: keyof typeof BUDGET_SPLITS; totalKey: keyof typeof totals; targetKey: keyof SubPhaseTargets }> = [
    { budget: 'carbs',   totalKey: 'carbs_g',   targetKey: 'carbs_g' },
    { budget: 'protein', totalKey: 'protein_g', targetKey: 'protein_g' },
    { budget: 'fat',     totalKey: 'fat_g',     targetKey: 'fat_g' },
    { budget: 'sodium',  totalKey: 'sodium_mg', targetKey: 'sodium_mg' },
    { budget: 'water',   totalKey: 'water_ml',  targetKey: 'water_ml' },
  ];

  for (const { budget, totalKey, targetKey } of macroMap) {
    const splits = BUDGET_SPLITS[budget];
    const totalValue = totals[totalKey];

    let activeSum = 0;
    for (const phase of activePhases) {
      activeSum += splits[phase];
    }

    for (const phase of activePhases) {
      const proportion = splits[phase] / activeSum;
      const target = result.get(phase)!;
      target[targetKey] = Math.round(totalValue * proportion * 10) / 10;
    }
  }

  return result;
}

// ============================================================================
// V3 Pre-Workout Target Calculation
// ============================================================================

/**
 * Calculate pre-workout macro targets using V3 formulas.
 * Uses default moderate environment and medium sweat sodium.
 */
export function calculateMacroTargets(
  weightKg: number,
  hoursBefore: number,
): MacroTargets {
  // V3: carbs = 1 g/kg per hour, capped at 4 g/kg, min 0.5 g/kg
  const carbPerKg = Math.max(0.5, Math.min(hoursBefore, 4.0));
  const totalCarbs = Math.round(weightKg * carbPerKg);

  // Default: medium sweat sodium, moderate environment
  const baseSodium = 450; // medium category
  const envBump = 0; // moderate environment

  const mealSodium = baseSodium + envBump;
  const snackSodium = Math.round((baseSodium + envBump) * 0.5);
  const topUpSodium = envBump + 100;

  let protein: number;
  let fat: number;
  let sodium: number;
  let sodiumLow: number;
  let sodiumHigh: number;
  let hydration: number;
  let hydrationLow: number;
  let hydrationHigh: number;
  let mealType: string;

  if (hoursBefore >= 2.5) {
    protein = Math.round(weightKg * 0.25);
    fat = Math.round(weightKg * 0.4);
    sodium = mealSodium + snackSodium + topUpSodium;
    hydration = Math.round(weightKg * 6.5);
    mealType = 'full_meal';
    // Sodium: normal dietary range from a full pre-race breakfast
    // Research shows 200-500mg from food is adequate; heavy athletes needing
    // 250-330g carbs will naturally accumulate 1500-2000mg from high-carb foods
    sodiumLow = 200;
    sodiumHigh = 2000;
    // Hydration: generous range — minimum 200ml (some food has fluid),
    // ceiling accounts for multi-phase drink servings (min 240ml each)
    hydrationLow = Math.max(200, Math.round(hydration * 0.50));
    hydrationHigh = Math.max(600, Math.round(hydration * 1.50));
  } else if (hoursBefore >= 1.0) {
    protein = Math.round(weightKg * 0.15);
    fat = 5;
    sodium = snackSodium + topUpSodium;
    hydration = Math.round(weightKg * 5.5);
    mealType = 'snack';
    // Sodium: lighter snack foods, less sodium naturally
    sodiumLow = 100;
    sodiumHigh = 1000;
    // Hydration: generous range for snack windows
    hydrationLow = Math.max(150, Math.round(hydration * 0.50));
    hydrationHigh = Math.max(500, Math.round(hydration * 1.50));
  } else {
    protein = 0;
    fat = 0;
    sodium = topUpSodium;
    hydration = 250;
    mealType = 'top_up';
    // Sodium: gels/simple carbs, sodium not critical here
    sodiumLow = 0;
    sodiumHigh = 400;
    // Hydration: wide range for small amounts
    hydrationLow = 0;
    hydrationHigh = 500;
  }

  const totals = {
    carbs_g: totalCarbs,
    protein_g: protein,
    fat_g: fat,
    sodium_mg: sodium,
    water_ml: hydration,
  };

  const phaseTargets = splitTargets(totals, hoursBefore);

  return {
    total_carbs_g: totalCarbs,
    total_protein_g: protein,
    total_fat_g: fat,
    total_sodium_mg: sodium,
    total_sodium_low_mg: sodiumLow,
    total_sodium_high_mg: sodiumHigh,
    total_hydration_ml: hydration,
    total_hydration_low_ml: hydrationLow,
    total_hydration_high_ml: hydrationHigh,
    meal_type: mealType,
    phase_targets: phaseTargets,
  };
}
