/**
 * LP Solver Post-Rounding Correction
 *
 * Extracted from lp-solver.ts for maintainability.
 * Handles snapping continuous LP solutions to 0.5 increments and correcting for drift.
 */

import { type Food, type LPModel, type PhaseSolution } from './types.ts';

interface MacroTotals {
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  water_ml: number;
  calories: number;
}

// Constraint names the corrector optimizes against. Protein is intentionally
// absent — it is not a solver consideration in any phase (decided 2026-07-29),
// so buildLPModel never emits a protein constraint.
const MACRO_CONSTRAINT_NAMES = ['carbs', 'sodium', 'water'] as const;

function getTotalForConstraint(totals: MacroTotals, name: string): number | null {
  switch (name) {
    case 'carbs': return totals.carbs_g;
    case 'protein': return totals.protein_g;
    case 'sodium': return totals.sodium_mg;
    case 'water': return totals.water_ml;
    default: return null;
  }
}

/**
 * Total normalized constraint violation for the current totals.
 * 0 means every constrained macro is inside its band.
 */
function bandViolation(model: LPModel, totals: MacroTotals): number {
  let violation = 0;
  for (const cName of MACRO_CONSTRAINT_NAMES) {
    const bounds = model.constraints[cName];
    if (!bounds) continue;
    const actual = getTotalForConstraint(totals, cName);
    if (actual == null) continue;
    const scale = Math.max(bounds.max ?? 0, bounds.min ?? 0, 1);
    if (bounds.max != null && actual > bounds.max) {
      violation += (actual - bounds.max) / scale;
    }
    if (bounds.min != null && bounds.min > 0 && actual < bounds.min) {
      violation += (bounds.min - actual) / scale;
    }
  }
  return violation;
}

function totalsFor(selectedFoods: PhaseSolution['foods']): MacroTotals {
  return {
    carbs_g: selectedFoods.reduce((s, f) => s + f.carbs_grams, 0),
    protein_g: selectedFoods.reduce((s, f) => s + f.protein_grams, 0),
    fat_g: selectedFoods.reduce((s, f) => s + f.fat_grams, 0),
    sodium_mg: selectedFoods.reduce((s, f) => s + f.sodium_mg, 0),
    water_ml: selectedFoods.reduce((s, f) => s + f.fluids_ml, 0),
    calories: selectedFoods.reduce((s, f) => s + f.calories, 0),
  };
}

function applyQuantity(
  sf: PhaseSolution['foods'][number],
  food: Food,
  quantity: number,
): void {
  sf.quantity = quantity;
  sf.carbs_grams = food.per_serving.carbs_g * quantity;
  sf.protein_grams = food.per_serving.protein_g * quantity;
  sf.fat_grams = food.per_serving.fat_g * quantity;
  sf.sodium_mg = food.per_serving.sodium_mg * quantity;
  sf.fluids_ml = food.per_serving.water_ml * quantity;
  sf.calories = food.per_serving.calories * quantity;
}

/**
 * Post-rounding correction: adjust servings to bring totals back within constraints.
 *
 * After rounding servings to 0.5 increments (or whole numbers for indivisible
 * items), the totals may drift outside LP constraint bounds. Greedily applies
 * the single ±one-step serving change that most reduces the total normalized
 * band violation, until every constrained macro is back in band or no move
 * improves things. This replaces the old per-macro top-contributor loop, which
 * could fix a small ceiling breach by removing a whole indivisible serving and
 * land below the floor instead.
 */
export function correctRoundingDrift(
  selectedFoods: PhaseSolution['foods'],
  foods: Food[],
  model: LPModel,
  totals: MacroTotals,
): { foods: PhaseSolution['foods']; totals: MacroTotals; issues: string[] } {
  // Seed zero-quantity entries for pool foods the LP did not select, so the
  // repair search can introduce a food (a quantity-0 entry is dropped from
  // the final result). Keeps the candidate set small: pools are ≤ ~10 foods.
  for (const food of foods) {
    if (!selectedFoods.some((sf) => sf.food_id === food.id)) {
      selectedFoods.push({
        food_id: food.id,
        quantity: 0,
        carbs_grams: 0,
        protein_grams: 0,
        fat_grams: 0,
        sodium_mg: 0,
        fluids_ml: 0,
        calories: 0,
        display_name: food.display_name ?? undefined,
        is_liquid: food.is_liquid ?? false,
        is_electrolyte: food.is_electrolyte ?? false,
        is_drink: food.is_liquid ?? false,
        is_indivisible: food.is_indivisible ?? false,
        product_type: food.product_type,
      });
    }
  }

  const foodByIdx = selectedFoods.map(
    (sf) => foods.find((f) => f.id === sf.food_id) ?? null,
  );

  // Candidate single-step moves for one food (index, new quantity). The pool
  // includes foods the LP left at 0 servings — a repair may need to introduce
  // a food (e.g. swap a whole banana for half a serving of rice).
  const maxFoodItems = model.constraints.total_food_items?.max ??
    Number.POSITIVE_INFINITY;
  const movesFor = (i: number): number[] => {
    const sf = selectedFoods[i];
    const food = foodByIdx[i];
    if (!food) return [];
    const step = food.is_indivisible ? 1 : 0.5;
    const out: number[] = [];
    for (const delta of [-step, step]) {
      const q = sf.quantity + delta;
      if (q < 0 || q > food.max_servings) continue;
      // Introducing a new food must respect the model's item-count cap.
      if (sf.quantity === 0 && q > 0) {
        const nonZero = selectedFoods.filter((f) => f.quantity > 0).length;
        if (nonZero >= maxFoodItems) continue;
      }
      out.push(q);
    }
    return out;
  };

  const violationWith = (
    changes: Array<{ idx: number; quantity: number }>,
  ): number => {
    const originals = changes.map(({ idx }) => selectedFoods[idx].quantity);
    for (const { idx, quantity } of changes) {
      applyQuantity(selectedFoods[idx], foodByIdx[idx]!, quantity);
    }
    const violation = bandViolation(model, totalsFor(selectedFoods));
    changes.forEach(({ idx }, k) => {
      applyQuantity(selectedFoods[idx], foodByIdx[idx]!, originals[k]);
    });
    return violation;
  };

  let currentViolation = bandViolation(model, totals);
  const MAX_MOVES = 12;
  for (let move = 0; move < MAX_MOVES && currentViolation > 1e-9; move++) {
    let best: Array<{ idx: number; quantity: number }> | null = null;
    let bestViolation = currentViolation;

    // Single moves first.
    for (let i = 0; i < selectedFoods.length; i++) {
      if (!foodByIdx[i]) continue;
      for (const q of movesFor(i)) {
        const violation = violationWith([{ idx: i, quantity: q }]);
        if (violation < bestViolation - 1e-9) {
          bestViolation = violation;
          best = [{ idx: i, quantity: q }];
        }
      }
    }

    // Plateau: try coordinated pairs (e.g. remove a whole indivisible serving
    // AND add half a serving of something else) — single steps alone can be
    // trapped between a ceiling breach and a floor breach.
    if (!best) {
      outer:
      for (let i = 0; i < selectedFoods.length; i++) {
        if (!foodByIdx[i]) continue;
        for (const qi of movesFor(i)) {
          for (let j = 0; j < selectedFoods.length; j++) {
            if (j === i || !foodByIdx[j]) continue;
            for (const qj of movesFor(j)) {
              const violation = violationWith([
                { idx: i, quantity: qi },
                { idx: j, quantity: qj },
              ]);
              if (violation < bestViolation - 1e-9) {
                bestViolation = violation;
                best = [
                  { idx: i, quantity: qi },
                  { idx: j, quantity: qj },
                ];
                if (violation <= 1e-9) break outer;
              }
            }
          }
        }
      }
    }

    if (!best) break; // no move improves things

    for (const { idx, quantity } of best) {
      const sf = selectedFoods[idx];
      console.log(
        `[LP-SOLVER] POST-ROUNDING FIX: ${sf.display_name ?? sf.food_id} ` +
          `${sf.quantity} → ${quantity} servings ` +
          `(violation ${currentViolation.toFixed(3)} → ${bestViolation.toFixed(3)})`,
      );
      applyQuantity(sf, foodByIdx[idx]!, quantity);
    }
    currentViolation = bestViolation;
  }

  const finalTotals = totalsFor(selectedFoods);
  totals.carbs_g = finalTotals.carbs_g;
  totals.protein_g = finalTotals.protein_g;
  totals.fat_g = finalTotals.fat_g;
  totals.sodium_mg = finalTotals.sodium_mg;
  totals.water_ml = finalTotals.water_ml;
  totals.calories = finalTotals.calories;

  // Remove any foods that were reduced to 0 servings
  const finalFoods = selectedFoods.filter((f) => f.quantity > 0);

  // Post-rounding validation: check if rounded totals still satisfy LP constraints (5% tolerance)
  const ROUNDING_TOLERANCE = 0.05;
  const roundingIssues: string[] = [];
  for (const [constraintName, bounds] of Object.entries(model.constraints)) {
    if (constraintName.startsWith('select_') || constraintName === 'total_food_items' || constraintName === 'electrolyte_supplements') continue;
    const actualValue = getTotalForConstraint(totals, constraintName);
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

  return { foods: finalFoods, totals, issues: roundingIssues };
}
