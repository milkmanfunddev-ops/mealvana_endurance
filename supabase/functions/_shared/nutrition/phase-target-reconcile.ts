/**
 * Post-solve hydration/sodium reconciliation.
 *
 * The LP solver is a *feasibility* engine, not a target-seeking one: its
 * constraints are `[min, max]` bands and its objective is a linear preference
 * score, so `javascript-lp-solver` maximizes at a vertex of the feasible
 * polytope. Nothing in the objective pulls the answer toward the midpoint of a
 * band, which means an LP "success" routinely parks fluid and sodium on a
 * range EDGE and calls it done.
 *
 * Reworking the objective into a goal program (piecewise-linear
 * distance-to-target with per-macro slack variables) would be the textbook
 * fix, but it destabilizes a solver the whole after-phase depends on. Instead
 * this module follows the pattern the codebase already uses for exactly this
 * problem — `during-gap-fill.ts` (carbs) and `before-phase-reconcile.ts`
 * (before phase) — and runs a closing top-up pass over the same food pool.
 *
 * Policy: aim at the TARGET, pass iff inside the range. A serving is only
 * added when it strictly reduces `|actual - target|` AND stays under every
 * band ceiling. Where item granularity makes the target unreachable, the
 * closest under-ceiling option wins and the residual gap is left honest
 * rather than papered over with an overshoot.
 */

import type { Food, FoodResult, MacroTargets } from "./types.ts";
import { calculateTotals } from "./food-utils.ts";
import { buildFoodResult, getServingCandidates } from "./during-utils.ts";

/** Cap on distinct NEW items this pass may introduce, matching
 * `during-gap-fill.ts`'s MAX_NEW_ITEMS — a top-up must not turn a tidy
 * recovery snack into a grab bag. Topping up an item already in the plan does
 * not count against this. */
const MAX_NEW_ITEMS = 2;

export interface ReconcileOutcome {
  foods: FoodResult[];
  addedSodium: number;
  addedFluid: number;
  applied: boolean;
}

function ceilingFor(
  high: number | undefined,
  target: number,
  fallbackMultiplier: number,
): number {
  if (high !== undefined && high !== null) return high;
  return target > 0 ? target * fallbackMultiplier : Number.POSITIVE_INFINITY;
}

/**
 * Top a solved phase up toward its sodium and fluid targets.
 *
 * @param currentFoods the solver's output (never removed or replaced — pins
 *   and curated selections stay honored; this pass only adds).
 * @param pool the same food pool the solver drew from.
 */
export function reconcilePhaseHydrationAndSodium(
  currentFoods: FoodResult[],
  pool: Food[],
  targets: MacroTargets,
): ReconcileOutcome {
  const sodiumTarget = targets.sodium_mg ?? 0;
  const fluidTarget = targets.water_ml ?? 0;

  if (
    (sodiumTarget <= 0 && fluidTarget <= 0) || pool.length === 0
  ) {
    return {
      foods: currentFoods,
      addedSodium: 0,
      addedFluid: 0,
      applied: false,
    };
  }

  const carbTarget = targets.carbs_g ?? 0;
  const proteinTarget = targets.protein_g ?? 0;
  const sodiumUpper = ceilingFor(targets.sodium_high_mg, sodiumTarget, 1.1);
  const fluidUpper = ceilingFor(targets.water_high_ml, fluidTarget, 1.1);
  const carbUpper = ceilingFor(targets.carbs_high_g, carbTarget, 1.1);
  const proteinUpper = ceilingFor(targets.protein_high_g, proteinTarget, 1.2);

  const foods = currentFoods.map((f) => ({ ...f }));
  const inPlanIds = new Set(foods.map((f) => f.food_id));

  let totals = calculateTotals(foods);
  const startSodium = totals.sodium_mg;
  const startFluid = totals.water_ml;

  /** Normalized distance-to-target across the two macros this pass owns.
   * Undershoot and overshoot both count, so a candidate that vaults past the
   * target scores worse than one that lands just under it. */
  const distance = (sodium: number, fluid: number): number => {
    const sodiumErr = sodiumTarget > 0
      ? Math.abs(sodium - sodiumTarget) / sodiumTarget
      : 0;
    const fluidErr = fluidTarget > 0
      ? Math.abs(fluid - fluidTarget) / fluidTarget
      : 0;
    return sodiumErr + fluidErr;
  };

  // Only foods that can actually move sodium or fluid are worth considering.
  const candidates = pool.filter((f) =>
    (sodiumTarget > 0 && f.per_serving.sodium_mg > 0) ||
    (fluidTarget > 0 && f.per_serving.water_ml > 0)
  );
  if (candidates.length === 0) {
    return {
      foods: currentFoods,
      addedSodium: 0,
      addedFluid: 0,
      applied: false,
    };
  }

  let newItemsAdded = 0;
  // Bounded outer loop: each iteration commits at most one (food, servings)
  // step that strictly reduces the distance to target, so it terminates.
  const MAX_STEPS = 6;

  for (let step = 0; step < MAX_STEPS; step++) {
    const currentDistance = distance(totals.sodium_mg, totals.water_ml);
    if (currentDistance <= 1e-9) break;

    let best:
      | { food: Food; servings: number; distance: number; isNew: boolean }
      | null = null;

    for (const food of candidates) {
      const isNew = !inPlanIds.has(food.id);
      if (isNew && newItemsAdded >= MAX_NEW_ITEMS) continue;

      const existing = foods.find((f) => f.food_id === food.id);
      const alreadyUsed = existing?.quantity ?? 0;
      const headroomServings = food.max_servings - alreadyUsed;
      if (headroomServings <= 0) continue;

      for (const servings of getServingCandidates(food)) {
        if (servings > headroomServings + 1e-9) continue;

        const sodium = totals.sodium_mg +
          food.per_serving.sodium_mg * servings;
        const fluid = totals.water_ml + food.per_serving.water_ml * servings;
        const carbs = totals.carbs_g + food.per_serving.carbs_g * servings;
        const protein = totals.protein_g +
          food.per_serving.protein_g * servings;

        // Never cross a band ceiling. This is what keeps "aim at target" from
        // degenerating into "overshoot the target".
        if (sodium > sodiumUpper + 1e-6) continue;
        if (fluid > fluidUpper + 1e-6) continue;
        if (carbs > carbUpper + 1e-6) continue;
        if (protein > proteinUpper + 1e-6) continue;

        const d = distance(sodium, fluid);
        // Strict improvement only — no "close enough", no range-membership.
        if (d >= currentDistance - 1e-9) continue;
        if (!best || d < best.distance) {
          best = { food, servings, distance: d, isNew };
        }
      }
    }

    if (!best) break;

    const existing = foods.find((f) => f.food_id === best.food.id);
    if (existing) {
      Object.assign(
        existing,
        buildFoodResult(best.food, existing.quantity + best.servings),
      );
    } else {
      foods.push(buildFoodResult(best.food, best.servings));
      inPlanIds.add(best.food.id);
      newItemsAdded++;
    }
    totals = calculateTotals(foods);
  }

  const addedSodium = totals.sodium_mg - startSodium;
  const addedFluid = totals.water_ml - startFluid;
  const applied = addedSodium > 0 || addedFluid > 0;

  if (applied) {
    console.log(
      `[TARGET-RECONCILE] +${addedSodium.toFixed(0)}mg sodium, ` +
        `+${addedFluid.toFixed(0)}ml fluid → ` +
        `sodium=${totals.sodium_mg.toFixed(0)}/${sodiumTarget}mg, ` +
        `fluid=${totals.water_ml.toFixed(0)}/${fluidTarget}ml`,
    );
  }

  return {
    foods: applied ? foods : currentFoods,
    addedSodium,
    addedFluid,
    applied,
  };
}
