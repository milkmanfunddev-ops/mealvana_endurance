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

  // Phase-specific carb constraints — use V4-provided ranges when available
  if (targets.carbs_g === 0) {
    model.constraints.carbs = { min: 0, max: 5 };
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

  // Protein constraints — use V4-provided ranges when available
  if ((phase === 'before' || phase === 'after') && targets.protein_g) {
    if (targets.protein_low_g != null && targets.protein_high_g != null) {
      model.constraints.protein = { min: targets.protein_low_g, max: targets.protein_high_g };
    } else {
      const proteinBounds = MACRO_CONSTRAINT_RANGES.protein[phase];
      if (proteinBounds) {
        model.constraints.protein = {
          min: targets.protein_g * proteinBounds.min,
          max: targets.protein_g * proteinBounds.max,
        };
      }
    }
  }

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
    const macroConstraintNames = ['carbs', 'protein', 'sodium', 'water'] as const;
    const getTotalForConstraint = (name: string): number | null => {
      switch (name) {
        case 'carbs': return totals.carbs_g;
        case 'protein': return totals.protein_g;
        case 'sodium': return totals.sodium_mg;
        case 'water': return totals.water_ml;
        default: return null;
      }
    };
    const getFoodContribution = (food: Food, name: string): number => {
      switch (name) {
        case 'carbs': return food.per_serving.carbs_g;
        case 'protein': return food.per_serving.protein_g;
        case 'sodium': return food.per_serving.sodium_mg;
        case 'water': return food.per_serving.water_ml;
        default: return 0;
      }
    };

    for (let iter = 0; iter < 3; iter++) {
      let adjusted = false;
      for (const cName of macroConstraintNames) {
        const bounds = model.constraints[cName];
        if (!bounds) continue;
        const actual = getTotalForConstraint(cName);
        if (actual == null) continue;

        if (bounds.max != null && actual > bounds.max * 1.01) {
          // Find top contributor for this macro and reduce by 0.5
          let topIdx = -1;
          let topContrib = 0;
          for (let i = 0; i < selectedFoods.length; i++) {
            const sf = selectedFoods[i];
            const foodIdx = foods.findIndex(f => f.id === sf.food_id);
            if (foodIdx < 0) continue;
            const contrib = getFoodContribution(foods[foodIdx], cName) * sf.quantity;
            if (contrib > topContrib && sf.quantity > (foods[foodIdx].is_indivisible ? 1 : 0.5)) {
              topContrib = contrib;
              topIdx = i;
            }
          }
          if (topIdx >= 0) {
            const sf = selectedFoods[topIdx];
            const foodIdx = foods.findIndex(f => f.id === sf.food_id);
            const food = foods[foodIdx];
            const decrement = food.is_indivisible ? 1 : 0.5;
            sf.quantity -= decrement;
            sf.carbs_grams = food.per_serving.carbs_g * sf.quantity;
            sf.protein_grams = food.per_serving.protein_g * sf.quantity;
            sf.fat_grams = food.per_serving.fat_g * sf.quantity;
            sf.sodium_mg = food.per_serving.sodium_mg * sf.quantity;
            sf.fluids_ml = food.per_serving.water_ml * sf.quantity;
            sf.calories = food.per_serving.calories * sf.quantity;
            // Recalculate totals
            totals.carbs_g = selectedFoods.reduce((s, f) => s + f.carbs_grams, 0);
            totals.protein_g = selectedFoods.reduce((s, f) => s + f.protein_grams, 0);
            totals.fat_g = selectedFoods.reduce((s, f) => s + f.fat_grams, 0);
            totals.sodium_mg = selectedFoods.reduce((s, f) => s + f.sodium_mg, 0);
            totals.water_ml = selectedFoods.reduce((s, f) => s + f.fluids_ml, 0);
            adjusted = true;
            console.log(`[LP-SOLVER] POST-ROUNDING FIX: reduced ${sf.display_name ?? sf.food_id} by ${decrement} for ${cName} overshoot`);
          }
        } else if (bounds.min != null && actual < bounds.min * 0.99) {
          // Find top contributor for this macro and increase by 0.5
          let topIdx = -1;
          let topContrib = 0;
          for (let i = 0; i < selectedFoods.length; i++) {
            const sf = selectedFoods[i];
            const foodIdx = foods.findIndex(f => f.id === sf.food_id);
            if (foodIdx < 0) continue;
            const food = foods[foodIdx];
            const contrib = getFoodContribution(food, cName);
            if (contrib > topContrib && sf.quantity < food.max_servings) {
              topContrib = contrib;
              topIdx = i;
            }
          }
          if (topIdx >= 0) {
            const sf = selectedFoods[topIdx];
            const foodIdx = foods.findIndex(f => f.id === sf.food_id);
            const food = foods[foodIdx];
            const increment = food.is_indivisible ? 1 : 0.5;
            sf.quantity += increment;
            sf.carbs_grams = food.per_serving.carbs_g * sf.quantity;
            sf.protein_grams = food.per_serving.protein_g * sf.quantity;
            sf.fat_grams = food.per_serving.fat_g * sf.quantity;
            sf.sodium_mg = food.per_serving.sodium_mg * sf.quantity;
            sf.fluids_ml = food.per_serving.water_ml * sf.quantity;
            sf.calories = food.per_serving.calories * sf.quantity;
            totals.carbs_g = selectedFoods.reduce((s, f) => s + f.carbs_grams, 0);
            totals.protein_g = selectedFoods.reduce((s, f) => s + f.protein_grams, 0);
            totals.fat_g = selectedFoods.reduce((s, f) => s + f.fat_grams, 0);
            totals.sodium_mg = selectedFoods.reduce((s, f) => s + f.sodium_mg, 0);
            totals.water_ml = selectedFoods.reduce((s, f) => s + f.fluids_ml, 0);
            adjusted = true;
            console.log(`[LP-SOLVER] POST-ROUNDING FIX: increased ${sf.display_name ?? sf.food_id} by ${increment} for ${cName} undershoot`);
          }
        }
      }
      if (!adjusted) break;
    }

    // Remove any foods that were reduced to 0 servings
    const finalFoods = selectedFoods.filter(f => f.quantity > 0);

    // Post-rounding validation: check if rounded totals still satisfy LP constraints (5% tolerance)
    const ROUNDING_TOLERANCE = 0.05;
    const roundingIssues: string[] = [];
    for (const [constraintName, bounds] of Object.entries(model.constraints)) {
      if (constraintName.startsWith('select_') || constraintName === 'total_food_items' || constraintName === 'electrolyte_supplements') continue;
      const actualValue = getTotalForConstraint(constraintName);
      if (actualValue == null) continue;

      if (bounds.min != null && actualValue < bounds.min * (1 - ROUNDING_TOLERANCE)) {
        roundingIssues.push(`${constraintName} below min: ${actualValue.toFixed(1)} < ${bounds.min.toFixed(1)} (tolerance: ${(ROUNDING_TOLERANCE * 100).toFixed(0)}%)`);
      }
      if (bounds.max != null && actualValue > bounds.max * (1 + ROUNDING_TOLERANCE)) {
        roundingIssues.push(`${constraintName} above max: ${actualValue.toFixed(1)} > ${bounds.max.toFixed(1)} (tolerance: ${(ROUNDING_TOLERANCE * 100).toFixed(0)}%)`);
      }
    }
    if (roundingIssues.length > 0) {
      console.warn(`[LP-SOLVER] POST-ROUNDING: ${roundingIssues.length} constraint violation(s): ${roundingIssues.join('; ')}`);
    }

    return {
      foods: finalFoods,
      totals,
      needsElectrolyte: false,
      needsWater: false,
    };
  } catch (error) {
    console.error('[LP-SOLVER] Error solving model:', error);
    return null;
  }
}
