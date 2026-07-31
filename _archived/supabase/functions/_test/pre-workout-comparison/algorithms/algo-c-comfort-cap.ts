/**
 * Algorithm C: Simple Direct Calculation
 *
 * Straightforward formula-based pre-workout planning:
 * 1. Calculate ideal servings directly (target / carbs_per_serving)
 * 2. Clamp to min/max, snap to 0.5
 * 3. Fill remaining gap with add-ons (banana/sports drink) — sodium-aware ordering
 * 4. If single formula still >20% short, stack a second formula
 * 5. Among formulas within 15% of best carb gap, pick by sodium/fluid alignment
 * 6. Track categories + add-ons across phases (no repeats)
 * 7. After food selection, add a standalone drink to top-up for hydration/sodium
 */

import {
  type Formula,
  type Scenario,
  type AlgorithmResult,
  type SubPhaseResult,
  type SubPhaseType,
  type AddOn,
  type FormulaSelection,
  BANANA_CARBS,
  BANANA_SODIUM,
  BANANA_FLUID,
  SPORTS_DRINK_CARBS,
  SPORTS_DRINK_SODIUM,
  SPORTS_DRINK_FLUID,
} from '../types.ts';
import { FORMULAS, DRINK_FORMULAS } from '../data/formulas.ts';
import {
  getEligibleFormulas,
  snapToHalf,
  formulaCarbs,
  makeSelection,
  makeBananaAddOn,
  makeSportsDrinkAddOn,
  buildSubPhaseResult,
  assembleResult,
} from './shared.ts';
import { getActiveSubPhases } from '../macro-targets.ts';

// ============================================================================
// Constants
// ============================================================================

const ADDON_GAP_THRESHOLD = 10;  // Only add banana/drink if gap > 10g
const STACK_THRESHOLD = 0.20;    // Stack second formula if >20% short
const DIVERSITY_BAND = 0.15;     // Pick among formulas within 15% of best carb gap
const DIVERSITY_FLOOR = 8;       // Minimum absolute carb gap to include in diversity band

// ============================================================================
// Core Logic
// ============================================================================

interface PlanState {
  banana_used: boolean;
  sports_drink_used: boolean;
  used_categories: Set<string>;
  sodium_delivered: number;
  fluid_delivered: number;
  sodium_target: number;
  fluid_target: number;
}

interface ScoredFormula {
  formula: Formula;
  servings: number;
  carbs: number;
  addOns: AddOn[];
  gap: number;
  sodium: number;
  fluid: number;
}

/**
 * For a single formula, calculate ideal servings and add-ons.
 * Add-on ordering is sodium-aware: prefer sports drink when sodium is needed,
 * banana when sodium is already sufficient.
 */
function scoreFormula(
  formula: Formula,
  carbTarget: number,
  state: PlanState,
): ScoredFormula {
  // Step 1: Calculate ideal servings directly
  const ideal = carbTarget / formula.carbs_per_serving;
  const clamped = Math.max(formula.min_servings, Math.min(formula.max_servings, ideal));
  const servings = snapToHalf(clamped);

  let carbs = formulaCarbs(formula, servings);
  let sodium = formula.sodium_mg * servings;
  let fluid = formula.fluid_ml * servings;
  const addOns: AddOn[] = [];

  // Step 2: Fill gap with add-ons — sodium-aware ordering
  let gap = carbTarget - carbs;

  const bananaEligible = formula.plus_banana && !state.banana_used;
  const drinkEligible = formula.plus_sports_drink && !state.sports_drink_used;

  // Determine add-on order: prefer sports drink first if we need sodium
  const sodiumRemaining = state.sodium_target - (state.sodium_delivered + sodium);
  const preferDrinkFirst = sodiumRemaining > 100;

  const addOnOrder = preferDrinkFirst
    ? [{ type: 'sports_drink' as const, eligible: drinkEligible }, { type: 'banana' as const, eligible: bananaEligible }]
    : [{ type: 'banana' as const, eligible: bananaEligible }, { type: 'sports_drink' as const, eligible: drinkEligible }];

  for (const addOn of addOnOrder) {
    if (gap <= ADDON_GAP_THRESHOLD || !addOn.eligible) continue;

    if (addOn.type === 'banana') {
      const withBanana = Math.abs(carbTarget - (carbs + BANANA_CARBS));
      if (withBanana < Math.abs(gap)) {
        carbs += BANANA_CARBS;
        sodium += BANANA_SODIUM;
        fluid += BANANA_FLUID;
        addOns.push(makeBananaAddOn());
        gap = carbTarget - carbs;
      }
    } else {
      // Skip sports drink if sodium is already significantly over target,
      // UNLESS adding it would significantly improve carb accuracy (>5g and >15% of target)
      const wouldOvershoot = (state.sodium_delivered + sodium + SPORTS_DRINK_SODIUM) > state.sodium_target * 1.4;
      const withDrink = Math.abs(carbTarget - (carbs + SPORTS_DRINK_CARBS));
      const carbImprovement = Math.abs(gap) - withDrink;
      const carbsNeedHelp = carbImprovement > 5 && carbTarget > 0 && Math.abs(gap) / carbTarget > 0.15;
      if (wouldOvershoot && !preferDrinkFirst && !carbsNeedHelp) continue;

      if (withDrink < Math.abs(gap)) {
        carbs += SPORTS_DRINK_CARBS;
        sodium += SPORTS_DRINK_SODIUM;
        fluid += SPORTS_DRINK_FLUID;
        addOns.push(makeSportsDrinkAddOn());
        gap = carbTarget - carbs;
      }
    }
  }

  return { formula, servings, carbs, addOns, gap: Math.abs(gap), sodium, fluid };
}

/**
 * Pick from the carb-close pool using sodium/fluid alignment as tiebreaker.
 * Uses a wider diversity band (15% + 8g floor) so sodium/fluid tiebreaker
 * has more candidates to choose from without sacrificing carb accuracy.
 */
function pickBestFormula(
  scored: ScoredFormula[],
  state: PlanState,
  carbTarget: number,
): ScoredFormula {
  if (scored.length === 0) throw new Error('No candidates');
  if (scored.length === 1) return scored[0];

  // Sort by carb gap (best first)
  scored.sort((a, b) => a.gap - b.gap);
  const bestGap = scored[0].gap;

  // Find all formulas within the diversity band (wider floor for sodium/fluid flexibility)
  const threshold = bestGap + (bestGap * DIVERSITY_BAND) + DIVERSITY_FLOOR;
  const pool = scored.filter((s) => s.gap <= threshold);

  if (pool.length === 1) return pool[0];

  // Score each by sodium+fluid proximity to targets
  let bestScore = Infinity;
  let bestPick = pool[0];

  for (const candidate of pool) {
    const resultSodium = state.sodium_delivered + candidate.sodium;
    const resultFluid = state.fluid_delivered + candidate.fluid;

    // Normalized distance from targets (penalize overshoot 1.5x)
    let sodiumErr = 0;
    if (state.sodium_target > 0) {
      const diff = resultSodium - state.sodium_target;
      sodiumErr = Math.abs(diff) / state.sodium_target * (diff > 0 ? 1.5 : 1.0);
    }

    let fluidErr = 0;
    if (state.fluid_target > 0) {
      const diff = resultFluid - state.fluid_target;
      fluidErr = Math.abs(diff) / state.fluid_target * (diff > 0 ? 1.5 : 1.0);
    }

    // Include normalized carb gap so we don't pick much-worse carbs for marginal sodium gains
    const carbErr = carbTarget > 0 ? candidate.gap / carbTarget : 0;
    const score = carbErr + sodiumErr + fluidErr;

    if (score < bestScore) {
      bestScore = score;
      bestPick = candidate;
    }
  }

  return bestPick;
}

/**
 * Try to stack a second formula to fill a large remaining gap.
 * Among equally-close candidates, prefer lower sodium when sodium is over target.
 */
function tryStack(
  remainingGap: number,
  eligible: Formula[],
  state: PlanState,
  usedCategory: string,
  usedFormulaId: string,
): { formula: Formula; servings: number } | null {
  // Prefer different category, but allow same category (different formula) as fallback
  let candidates = eligible.filter((f) => f.base_category !== usedCategory && f.id !== usedFormulaId);
  if (candidates.length === 0) {
    candidates = eligible.filter((f) => f.id !== usedFormulaId);
  }
  if (candidates.length === 0) return null;

  const sodiumOver = state.sodium_delivered > state.sodium_target;

  let best: { formula: Formula; servings: number; gap: number; sodium: number } | null = null;

  for (const formula of candidates) {
    const ideal = remainingGap / formula.carbs_per_serving;
    const clamped = Math.max(formula.min_servings, Math.min(formula.max_servings, ideal));
    const servings = snapToHalf(clamped);
    const carbs = formulaCarbs(formula, servings);
    const gap = Math.abs(remainingGap - carbs);
    const sodium = formula.sodium_mg * servings;

    if (!best || gap < best.gap) {
      best = { formula, servings, gap, sodium };
    } else if (Math.abs(gap - best.gap) < 3 && sodiumOver && sodium < best.sodium) {
      // Carb gap is similar — prefer lower sodium when already over target
      best = { formula, servings, gap, sodium };
    }
  }

  return best ? { formula: best.formula, servings: best.servings } : null;
}

// ============================================================================
// Drink Selection
// ============================================================================

/**
 * Score how close a sodium+fluid result is to the targets.
 * Lower is better. Penalizes overshooting 1.5x more than undershooting.
 */
function scoreDrinkOption(
  resultSodium: number,
  resultFluid: number,
  sodiumTarget: number,
  fluidTarget: number,
): number {
  let sodiumError = 0;
  if (sodiumTarget > 0) {
    const diff = resultSodium - sodiumTarget;
    sodiumError = Math.abs(diff) / sodiumTarget * (diff > 0 ? 1.5 : 1.0);
  }

  let fluidError = 0;
  if (fluidTarget > 0) {
    const diff = resultFluid - fluidTarget;
    fluidError = Math.abs(diff) / fluidTarget * (diff > 0 ? 1.5 : 1.0);
  }

  return sodiumError + fluidError;
}

/**
 * Pick the best standalone drink for the top-up phase.
 * Scores every (drink × servings) combination against both sodium and fluid targets.
 * "No drink" is also a valid option if food already covers the targets.
 */
function pickDrink(
  totalSodiumDelivered: number,
  totalFluidDelivered: number,
  sodiumTarget: number,
  fluidTarget: number,
): FormulaSelection | null {
  // Score the "no drink" option as baseline
  let bestScore = scoreDrinkOption(totalSodiumDelivered, totalFluidDelivered, sodiumTarget, fluidTarget);
  let bestPick: { formula: Formula; servings: number } | null = null;

  for (const formula of DRINK_FORMULAS) {
    // Try every valid 0.5-step serving from min to max
    for (let srv = formula.min_servings; srv <= formula.max_servings; srv += 0.5) {
      const servings = snapToHalf(srv);
      const resultSodium = totalSodiumDelivered + formula.sodium_mg * servings;
      const resultFluid = totalFluidDelivered + formula.fluid_ml * servings;

      const score = scoreDrinkOption(resultSodium, resultFluid, sodiumTarget, fluidTarget);

      if (score < bestScore) {
        bestScore = score;
        bestPick = { formula, servings };
      }
    }
  }

  if (!bestPick) return null; // No drink is better than any drink option
  return makeSelection(bestPick.formula, bestPick.servings);
}

// ============================================================================
// Entry Point
// ============================================================================

export function runAlgoC(scenario: Scenario): AlgorithmResult {
  const phases = getActiveSubPhases(scenario.hours_before);
  const state: PlanState = {
    banana_used: false,
    sports_drink_used: false,
    used_categories: new Set(),
    sodium_delivered: 0,
    fluid_delivered: 0,
    sodium_target: scenario.targets.total_sodium_mg,
    fluid_target: scenario.targets.total_hydration_ml,
  };
  const subPhaseResults: SubPhaseResult[] = [];

  for (const phase of phases) {
    const phaseTargets = scenario.targets.phase_targets.get(phase);
    const carbTarget = phaseTargets?.carbs_g ?? 0;

    const eligible = getEligibleFormulas(FORMULAS, phase, scenario.diet);

    // Filter to unused categories (fallback to all if none left)
    let candidates = eligible.filter((f) => !state.used_categories.has(f.base_category));
    if (candidates.length === 0) candidates = eligible;

    if (candidates.length === 0) {
      subPhaseResults.push(buildSubPhaseResult(phase, null, []));
      continue;
    }

    // Score every candidate (sodium-aware add-on ordering)
    const scored = candidates.map((f) => scoreFormula(f, carbTarget, state));

    // Pick by combined carb + sodium/fluid score
    const pick = pickBestFormula(scored, state, carbTarget);

    // Check if we need to stack a second formula
    const deliveredCarbs = formulaCarbs(pick.formula, pick.servings)
      + pick.addOns.reduce((s, a) => s + a.carbs_g, 0);
    const remainingGap = carbTarget - deliveredCarbs;
    const pctShort = carbTarget > 0 ? remainingGap / carbTarget : 0;

    let secondFormula: FormulaSelection | null = null;

    if (pctShort > STACK_THRESHOLD && remainingGap > 20) {
      const stack = tryStack(remainingGap, eligible, state, pick.formula.base_category, pick.formula.id);
      if (stack) {
        secondFormula = makeSelection(stack.formula, stack.servings);
        state.used_categories.add(stack.formula.base_category);
      }
    }

    // Update cross-phase state
    state.used_categories.add(pick.formula.base_category);
    for (const addOn of pick.addOns) {
      if (addOn.type === 'banana') state.banana_used = true;
      if (addOn.type === 'sports_drink') state.sports_drink_used = true;
    }

    // Build result (with optional stacked formula)
    const primarySel = makeSelection(pick.formula, pick.servings);

    if (secondFormula) {
      const totalCarbs = primarySel.carbs_g + secondFormula.carbs_g
        + pick.addOns.reduce((s, a) => s + a.carbs_g, 0);
      const totalSodium = primarySel.sodium_mg + secondFormula.sodium_mg
        + pick.addOns.reduce((s, a) => s + a.sodium_mg, 0);
      const totalFluid = primarySel.fluid_ml + secondFormula.fluid_ml
        + pick.addOns.reduce((s, a) => s + a.fluid_ml, 0);

      subPhaseResults.push({
        phase,
        formula: primarySel,
        second_formula: secondFormula,
        add_ons: pick.addOns,
        total_carbs_g: Math.round(totalCarbs * 10) / 10,
        total_sodium_mg: Math.round(totalSodium * 10) / 10,
        total_fluid_ml: Math.round(totalFluid * 10) / 10,
      });

      state.sodium_delivered += totalSodium;
      state.fluid_delivered += totalFluid;
    } else {
      const phaseResult = buildSubPhaseResult(phase, primarySel, pick.addOns);
      subPhaseResults.push(phaseResult);

      state.sodium_delivered += phaseResult.total_sodium_mg;
      state.fluid_delivered += phaseResult.total_fluid_ml;
    }
  }

  // ── Pass 2: Add standalone drink to top-up phase ──────────────────────
  const topUpIdx = subPhaseResults.findIndex((p) => p.phase === 'top_up');
  if (topUpIdx >= 0) {
    const drink = pickDrink(
      state.sodium_delivered,
      state.fluid_delivered,
      state.sodium_target,
      state.fluid_target,
    );
    if (drink) {
      const phase = subPhaseResults[topUpIdx];
      phase.drink = drink;
      phase.total_carbs_g = Math.round((phase.total_carbs_g + drink.carbs_g) * 10) / 10;
      phase.total_sodium_mg = Math.round((phase.total_sodium_mg + drink.sodium_mg) * 10) / 10;
      phase.total_fluid_ml = Math.round((phase.total_fluid_ml + drink.fluid_ml) * 10) / 10;
    }
  }

  return assembleResult('C', subPhaseResults);
}
