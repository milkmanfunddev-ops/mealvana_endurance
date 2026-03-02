/**
 * Linear Programming Solver for Nutrition Optimization
 *
 * Uses javascript-lp-solver library for optimal food selection
 */

import solver from 'https://esm.sh/javascript-lp-solver@0.4.24?target=deno';
import { roundToIncrement } from '../utils.ts';
import { type Food, type Phase, type MacroTargets, type PhaseSolution, type LPModel, type LPSolution, deriveTimingCategory } from './types.ts';
import { MACRO_CONSTRAINT_RANGES, PHASE_TIMING_LABELS } from './constants.ts';
import type { MacroWeights } from './constants.ts';

/**
 * Build a Linear Programming model for food optimization
 */
export function buildLPModel(
  foods: Food[],
  targets: MacroTargets,
  phase: Phase,
  weights: MacroWeights,
  weightOverrides?: Partial<MacroWeights>,
  constraintOverrides?: { sodium?: { min: number; max: number } },
  options?: {
    maxFoodItems?: number;
    maxServingsCap?: number;
    selectionPenalty?: number;
    maxElectrolyteSupplements?: number;
    enforceWaterMin?: boolean;
    randomVariance?: boolean;
  },
): LPModel {
  const effectiveWeights = { ...weights, ...(weightOverrides ?? {}) };
  const maxFoodItems = options?.maxFoodItems ?? (phase === 'during' ? 6 : 4);
  const maxServingsCap = options?.maxServingsCap ?? 4;
  const selectionPenalty = options?.selectionPenalty ?? 0.1;
  const maxElectrolyteSupplements = options?.maxElectrolyteSupplements;
  const enforceWaterMin = options?.enforceWaterMin ?? false;

  const model: LPModel = {
    optimize: 'score',
    opType: 'max',
    constraints: {},
    variables: {},
    ints: {},
    binaries: {},
  };

  // Phase-specific carb constraints
  const carbBounds = MACRO_CONSTRAINT_RANGES.carbs[phase];
  if (carbBounds) {
    // Handle zero carb targets (e.g., swimming during phase)
    if (targets.carbs_g === 0) {
      model.constraints.carbs = { min: 0, max: 5 };
    } else {
      model.constraints.carbs = {
        min: targets.carbs_g * carbBounds.min,
        max: targets.carbs_g * carbBounds.max,
      };
    }
  }

  // Add protein constraints for before and after phases
  if ((phase === 'before' || phase === 'after') && targets.protein_g) {
    const proteinBounds = MACRO_CONSTRAINT_RANGES.protein[phase];
    if (proteinBounds) {
      model.constraints.protein = {
        min: targets.protein_g * proteinBounds.min,
        max: targets.protein_g * proteinBounds.max,
      };
    }
  }

  // Balanced sodium constraints
  if (targets.sodium_mg > 0) {
    if (constraintOverrides?.sodium) {
      // Use overridden sodium constraints (e.g., relaxed for two-pass during phase)
      model.constraints.sodium = {
        min: targets.sodium_mg * constraintOverrides.sodium.min,
        max: targets.sodium_mg * constraintOverrides.sodium.max,
      };
    } else {
      const sodiumBounds = MACRO_CONSTRAINT_RANGES.sodium[phase];
      if (sodiumBounds) {
        model.constraints.sodium = {
          min: targets.sodium_mg * Math.min(sodiumBounds.min, 0.75),
          max: targets.sodium_mg * sodiumBounds.max,
        };
      }
    }
  }

  // Phase-specific water constraints
  if (targets.water_ml > 0) {
    const waterBounds = MACRO_CONSTRAINT_RANGES.water[phase];
    if (waterBounds) {
      if (phase === 'during' && enforceWaterMin) {
        model.constraints.water = {
          min: targets.water_ml * waterBounds.min,
          max: targets.water_ml * waterBounds.max,
        };
      } else {
        model.constraints.water = {
          max: targets.water_ml * waterBounds.max,
        };
      }
    }
  }

  // Constraint to limit number of distinct foods
  model.constraints.total_food_items = { max: maxFoodItems };
  if (maxElectrolyteSupplements != null) {
    model.constraints.electrolyte_supplements = { max: maxElectrolyteSupplements };
  }

  // Add variables for each food
  foods.forEach((food, index) => {
    const varName = `food_${index}`;
    const selectionConstraint = `select_${index}`;
    const selectionVarName = `choose_${index}`;
    const maxServings = Math.max(0.5, Math.min(food.max_servings ?? 4, maxServingsCap));

    // Calculate score based on preference and macro contribution
    let score = food.preference_score;

    // Add weighted macro contributions
    score += weights.carbs * food.per_serving.carbs_g;

    // Add protein scoring for before and after phases
    if ((phase === 'before' || phase === 'after') && weights.protein) {
      score += weights.protein * food.per_serving.protein_g;
    }

    // Add sodium consideration (uses effectiveWeights to allow per-phase overrides)
    if (effectiveWeights.sodium) {
      const sodiumScore = Math.max(
        0,
        effectiveWeights.sodium * (200 - Math.abs(food.per_serving.sodium_mg - 200))
      );
      score += sodiumScore;
    }

    // Penalize high water content foods in pre-run
    if (phase === 'before' && food.per_serving.water_ml > 300) {
      score -= 3;
    }

    // Add random jitter for variety — non-liked foods get ±15% score perturbation
    if (options?.randomVariance && food.preference_score < 200) {
      const jitter = (Math.random() - 0.5) * 0.3 * Math.abs(score);
      score += jitter;
    }

    const variable: Record<string, number> = {
      score,
      carbs: food.per_serving.carbs_g,
      protein: food.per_serving.protein_g,
      sodium: food.per_serving.sodium_mg,
      water: food.per_serving.water_ml,
      [selectionConstraint]: 1,
    };

    model.variables[varName] = variable;

    // Link servings to binary selection variable
    model.constraints[selectionConstraint] = { max: 0 };
    const selectionVariable: Record<string, number> = {
      score: -selectionPenalty,
      [selectionConstraint]: -maxServings,
      total_food_items: 1,
    };
    const isElectrolyteSupplement =
      food.is_electrolyte === true && food.product_type === 'supplement';
    if (maxElectrolyteSupplements != null && isElectrolyteSupplement) {
      selectionVariable.electrolyte_supplements = 1;
    }
    model.variables[selectionVarName] = selectionVariable;
    model.binaries![selectionVarName] = 1;
  });

  return model;
}

/**
 * Solve the LP model and extract food selections
 */
export function solveLPModel(
  model: LPModel,
  foods: Food[],
  phase: Phase
): PhaseSolution | null {
  try {
    const solution = solver.Solve(model) as LPSolution;

    if (!solution || !solution.feasible) {
      console.log('[LP-SOLVER] No feasible solution found');
      return null;
    }

    // Extract selected foods and quantities
    const selectedFoods: PhaseSolution['foods'] = [];
    const totals = {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0,
      calories: 0,
    };

    foods.forEach((food, index) => {
      const varName = `food_${index}`;
      const servings = (solution[varName] as number) || 0;

      if (servings > 0) {
        // Indivisible items (tablets, gel packets) round to whole numbers;
        // everything else rounds to nearest 0.5
        const roundedServings = food.is_indivisible
          ? Math.max(1, Math.round(servings))
          : roundToIncrement(servings);
        if (roundedServings <= 0) return;

        selectedFoods.push({
          food_id: food.id,
          quantity: roundedServings,
          carbs_grams: food.per_serving.carbs_g * roundedServings,
          protein_grams: food.per_serving.protein_g * roundedServings,
          fat_grams: food.per_serving.fat_g * roundedServings,
          sodium_mg: food.per_serving.sodium_mg * roundedServings,
          fluids_ml: food.per_serving.water_ml * roundedServings,
          calories: food.per_serving.calories * roundedServings,
          timing: PHASE_TIMING_LABELS[phase],
          display_name: food.display_name ?? undefined,
          display_name_plural: food.display_name_plural ?? undefined,
          description: food.description ?? undefined,
          image_address: food.image_address ?? undefined,
          is_liquid: food.is_liquid ?? false,
          is_electrolyte: food.is_electrolyte ?? false,
          is_drink: food.is_liquid ?? false,
          is_indivisible: food.is_indivisible ?? false,
          timing_category: deriveTimingCategory(food),
          product_type: food.product_type,
        });

        totals.carbs_g += food.per_serving.carbs_g * roundedServings;
        totals.protein_g += food.per_serving.protein_g * roundedServings;
        totals.fat_g += food.per_serving.fat_g * roundedServings;
        totals.sodium_mg += food.per_serving.sodium_mg * roundedServings;
        totals.water_ml += food.per_serving.water_ml * roundedServings;
      }
    });

    return {
      foods: selectedFoods,
      totals,
      needsElectrolyte: false,
      needsWater: false,
    };
  } catch (error) {
    console.error('[LP-SOLVER] Error solving model:', error);
    return null;
  }
}
