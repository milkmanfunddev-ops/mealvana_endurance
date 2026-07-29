/**
 * Linear Programming Solver for Nutrition Optimization
 *
 * Uses javascript-lp-solver library for optimal food selection
 */

import solver from 'https://esm.sh/javascript-lp-solver@0.4.24?target=deno';
import { roundToIncrement } from '../utils.ts';
import { type Food, type Phase, type MacroTargets, type PhaseSolution, type LPModel, type LPSolution, deriveTimingCategory, shouldPrioritizeMacroTarget } from './types.ts';
import { MACRO_CONSTRAINT_RANGES, PHASE_TIMING_LABELS } from './constants.ts';
import type { MacroWeights } from './constants.ts';
import { correctRoundingDrift } from './lp-solver-rounding.ts';

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

  console.log(
    `[LP-SOLVER] Building model for ${phase} phase | ` +
    `targets: carbs=${targets.carbs_g}g, protein=${targets.protein_g ?? 0}g, ` +
    `sodium=${targets.sodium_mg}mg, water=${targets.water_ml}ml | ` +
    `food pool: ${foods.length} foods, maxFoodItems=${maxFoodItems}, maxServingsCap=${maxServingsCap}`
  );

  const model: LPModel = {
    optimize: 'score',
    opType: 'max',
    constraints: {},
    variables: {},
    ints: {},
    binaries: {},
  };

  const prioritizeCarbTarget = shouldPrioritizeMacroTarget(targets, 'carbs');

  // Phase-specific carb constraints — use V4-provided ranges when available,
  // but prioritize explicit out-of-band/overridden targets.
  if (targets.carbs_g === 0) {
    model.constraints.carbs = { min: 0, max: 5 };
  } else if (prioritizeCarbTarget) {
    const carbBounds = MACRO_CONSTRAINT_RANGES.carbs[phase] ?? { min: 0.9, max: 1.1 };
    model.constraints.carbs = {
      min: targets.carbs_g * carbBounds.min,
      max: targets.carbs_g * carbBounds.max,
    };
    console.log(
      `[LP-SOLVER] Prioritizing carb target (${targets.carbs_g}g) over provided band`,
    );
  } else if (targets.carbs_low_g != null && targets.carbs_high_g != null) {
    model.constraints.carbs = { min: targets.carbs_low_g, max: targets.carbs_high_g };
  } else {
    const carbBounds = MACRO_CONSTRAINT_RANGES.carbs[phase];
    if (carbBounds) {
      model.constraints.carbs = {
        min: targets.carbs_g * carbBounds.min,
        max: targets.carbs_g * carbBounds.max,
      };
    }
  }

  // Protein is intentionally NOT constrained (decided 2026-07-29: protein is
  // not a solver consideration in any phase).

  // Sodium constraints — use V4-provided ranges when available
  if (targets.sodium_mg > 0) {
    if (targets.sodium_low_mg != null && targets.sodium_high_mg != null) {
      model.constraints.sodium = { min: targets.sodium_low_mg, max: targets.sodium_high_mg };
    } else if (constraintOverrides?.sodium) {
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

  // Water constraints — use V4-provided ranges when available
  if (targets.water_ml > 0) {
    if (targets.water_low_ml != null && targets.water_high_ml != null) {
      model.constraints.water = { min: targets.water_low_ml, max: targets.water_high_ml };
    } else {
      const waterBounds = MACRO_CONSTRAINT_RANGES.water[phase];
      if (waterBounds) {
        if ((phase === 'during' && enforceWaterMin) || phase === 'after') {
          const waterMin = phase === 'after'
            ? targets.water_ml * 0.7
            : targets.water_ml * waterBounds.min;
          model.constraints.water = {
            min: waterMin,
            max: targets.water_ml * waterBounds.max,
          };
        } else {
          model.constraints.water = {
            max: targets.water_ml * waterBounds.max,
          };
        }
      }
    }
  }

  // Constraint to limit number of distinct foods
  model.constraints.total_food_items = { max: maxFoodItems };
  if (maxElectrolyteSupplements != null) {
    model.constraints.electrolyte_supplements = { max: maxElectrolyteSupplements };
  }

  // Log all constraint bounds
  const logConstraint = (name: string) => {
    const c = model.constraints[name];
    if (c) {
      console.log(`[LP-SOLVER] Constraint ${name}: [${c.min ?? '-inf'}, ${c.max ?? '+inf'}]`);
    }
  };
  logConstraint('carbs');
  logConstraint('protein');
  logConstraint('sodium');
  logConstraint('water');

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

    // Protein is intentionally NOT scored (decided 2026-07-29: protein is
    // not a solver consideration in any phase).

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

    // Imported user foods are kept available but de-emphasized unless they are
    // explicitly a better contract fit under constraints.
    if (food.is_user_food && (!food.product_type || food.product_type === 'import')) {
      score -= 40;
    }

    // Add random jitter for variety — only for non-user foods so personalization
    // doesn't become unstable between equivalent runs.
    if (options?.randomVariance && food.preference_score < 200 && !food.is_user_food) {
      const jitter = (Math.random() - 0.5) * 0.3 * Math.abs(score);
      score += jitter;
    }

    console.log(
      `[LP-SOLVER] Food ${index}: ${food.name} | pref=${food.preference_score}, score=${score.toFixed(1)} | ` +
      `per_serving: carbs=${food.per_serving.carbs_g}g, protein=${food.per_serving.protein_g}g, ` +
      `sodium=${food.per_serving.sodium_mg}mg, water=${food.per_serving.water_ml}ml | ` +
      `maxServings=${maxServings}`
    );

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

    console.log(`[LP-SOLVER] Solve result: feasible=${solution?.feasible ?? false}`);

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

    // Log selected foods and totals summary
    for (const sf of selectedFoods) {
      console.log(
        `[LP-SOLVER] Selected: ${sf.display_name ?? sf.food_id} x${sf.quantity} → ` +
        `carbs=${sf.carbs_grams.toFixed(1)}g, protein=${sf.protein_grams.toFixed(1)}g, ` +
        `sodium=${sf.sodium_mg}mg, water=${sf.fluids_ml}ml`
      );
    }
    console.log(
      `[LP-SOLVER] Totals: carbs=${totals.carbs_g.toFixed(1)}g, protein=${totals.protein_g.toFixed(1)}g, ` +
      `fat=${totals.fat_g.toFixed(1)}g, sodium=${totals.sodium_mg.toFixed(0)}mg, water=${totals.water_ml.toFixed(0)}ml`
    );

    // Post-rounding correction: adjust servings to bring totals back within constraints
    const { foods: finalFoods, totals: correctedTotals } = correctRoundingDrift(
      selectedFoods,
      foods,
      model,
      totals
    );

    // Final gate: serving rounding (indivisible items are forced up to a whole
    // serving) can push totals past the model's own constraint band even after
    // drift correction. A solution that still violates its constraints beyond
    // a 5% rounding tolerance is not a solution — reject it so the caller
    // falls back to the greedy solver (range standard, 2026-07-29).
    const ROUNDING_TOL = 0.05;
    const violations: string[] = [];
    const checkBand = (
      name: string,
      value: number,
      band?: { min?: number; max?: number },
    ) => {
      if (!band) return;
      if (band.max != null && value > band.max * (1 + ROUNDING_TOL)) {
        violations.push(`${name}=${value.toFixed(1)} > max ${band.max}`);
      }
      if (band.min != null && band.min > 0 && value < band.min * (1 - ROUNDING_TOL)) {
        violations.push(`${name}=${value.toFixed(1)} < min ${band.min}`);
      }
    };
    checkBand('carbs', correctedTotals.carbs_g, model.constraints.carbs);
    checkBand('sodium', correctedTotals.sodium_mg, model.constraints.sodium);
    checkBand('water', correctedTotals.water_ml, model.constraints.water);
    if (violations.length > 0) {
      console.log(
        `[LP-SOLVER] Rejecting rounded solution — violates constraints: ${violations.join('; ')}`,
      );
      return null;
    }

    return {
      foods: finalFoods,
      totals: correctedTotals,
      needsElectrolyte: false,
      needsWater: false,
    };
  } catch (error) {
    console.error('[LP-SOLVER] Error solving model:', error);
    return null;
  }
}
