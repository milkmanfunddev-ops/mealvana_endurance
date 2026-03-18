/**
 * Algorithm B: Xuan's Comfortable Servings
 *
 * Direct port of Xuan's pre-workout algorithm approach:
 * - Comfortable servings at 60% of max_servings
 * - Add-on gap filling: banana (+27g) or sports drink (+17g)
 * - Scale-up only if gap > 30g or > 25% of target
 * - Cross-tier add-on tracking (max 1 banana per plan)
 * - Simulation-based formula selection (predict delivery before choosing)
 * - Category diversity (used_categories prevents repeats)
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
  SPORTS_DRINK_CARBS,
} from '../types.ts';
import { FORMULAS } from '../data/formulas.ts';
import {
  getEligibleFormulas,
  clampAndSnap,
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

const COMFORTABLE_RATIO = 0.6;   // 60% of max servings
const SCALE_UP_GAP_ABS = 30;     // Scale up if gap > 30g
const SCALE_UP_GAP_PCT = 0.25;   // Scale up if gap > 25% of target

// ============================================================================
// Core Algorithm
// ============================================================================

interface PlanState {
  banana_used: boolean;
  sports_drink_used: boolean;
  used_categories: Set<string>;
}

/**
 * Calculate comfortable servings for a formula.
 */
function comfortableServings(formula: Formula): number {
  const comfortable = formula.max_servings * COMFORTABLE_RATIO;
  return clampAndSnap(comfortable, formula);
}

/**
 * Simulate what a formula delivers at comfortable servings + possible add-ons.
 */
function simulateDelivery(
  formula: Formula,
  carbTarget: number,
  state: PlanState,
): { servings: number; carbs: number; addOns: AddOn[]; score: number } {
  const servings = comfortableServings(formula);
  let carbs = formulaCarbs(formula, servings);
  const addOns: AddOn[] = [];

  const gap = carbTarget - carbs;

  // Try add-ons to fill the gap (only if closer to target)
  if (gap > 10 && formula.plus_banana && !state.banana_used) {
    if (Math.abs(carbTarget - (carbs + BANANA_CARBS)) < Math.abs(gap)) {
      carbs += BANANA_CARBS;
      addOns.push(makeBananaAddOn());
    }
  }

  const gapAfterBanana = carbTarget - carbs;
  if (gapAfterBanana > 10 && formula.plus_sports_drink && !state.sports_drink_used) {
    if (Math.abs(carbTarget - (carbs + SPORTS_DRINK_CARBS)) < Math.abs(gapAfterBanana)) {
      carbs += SPORTS_DRINK_CARBS;
      addOns.push(makeSportsDrinkAddOn());
    }
  }

  // Score: how close to target (lower is better)
  const finalGap = Math.abs(carbTarget - carbs);
  const score = finalGap;

  return { servings, carbs, addOns, score };
}

/**
 * Try scaling up a formula if gap is too large.
 */
function tryScaleUp(
  formula: Formula,
  carbTarget: number,
  baseServings: number,
): number {
  const baseCarbs = formulaCarbs(formula, baseServings);
  const gap = carbTarget - baseCarbs;

  // Only scale up if gap is significant
  if (gap <= SCALE_UP_GAP_ABS && (carbTarget <= 0 || gap / carbTarget <= SCALE_UP_GAP_PCT)) {
    return baseServings;
  }

  // Try incrementing by 0.5 until gap closes or max reached
  let servings = baseServings;
  while (servings < formula.max_servings) {
    const next = servings + 0.5;
    if (next > formula.max_servings) break;
    const nextCarbs = formulaCarbs(formula, next);
    if (nextCarbs >= carbTarget * 0.9) {
      return next;
    }
    servings = next;
  }

  return clampAndSnap(servings, formula);
}

/**
 * Select the best formula for a sub-phase.
 */
function selectFormula(
  eligible: Formula[],
  carbTarget: number,
  state: PlanState,
): { formula: Formula; servings: number; addOns: AddOn[] } | null {
  if (eligible.length === 0) return null;

  // Filter out used categories
  let candidates = eligible.filter((f) => !state.used_categories.has(f.base_category));
  // Fallback to all if filtering removes everything
  if (candidates.length === 0) candidates = eligible;

  // Simulate each candidate and pick the best
  let bestResult: {
    formula: Formula;
    servings: number;
    carbs: number;
    addOns: AddOn[];
    score: number;
  } | null = null;

  for (const formula of candidates) {
    const sim = simulateDelivery(formula, carbTarget, state);
    if (!bestResult || sim.score < bestResult.score) {
      bestResult = { formula, ...sim };
    }
  }

  if (!bestResult) return null;

  // Try scale-up if still short after add-ons
  const gapAfterAddOns = carbTarget - bestResult.carbs;
  if (gapAfterAddOns > SCALE_UP_GAP_ABS ||
      (carbTarget > 0 && gapAfterAddOns / carbTarget > SCALE_UP_GAP_PCT)) {
    const scaledServings = tryScaleUp(bestResult.formula, carbTarget, bestResult.servings);
    if (scaledServings !== bestResult.servings) {
      bestResult.servings = scaledServings;
      bestResult.carbs = formulaCarbs(bestResult.formula, scaledServings);

      // Recalculate add-ons with new serving level
      bestResult.addOns = [];
      const newGap = carbTarget - bestResult.carbs;
      if (newGap > 10 && bestResult.formula.plus_banana && !state.banana_used) {
        if (Math.abs(carbTarget - (bestResult.carbs + BANANA_CARBS)) < Math.abs(newGap)) {
          bestResult.carbs += BANANA_CARBS;
          bestResult.addOns.push(makeBananaAddOn());
        }
      }
      const gapAfterBanana = carbTarget - bestResult.carbs;
      if (gapAfterBanana > 10 && bestResult.formula.plus_sports_drink && !state.sports_drink_used) {
        if (Math.abs(carbTarget - (bestResult.carbs + SPORTS_DRINK_CARBS)) < Math.abs(gapAfterBanana)) {
          bestResult.carbs += SPORTS_DRINK_CARBS;
          bestResult.addOns.push(makeSportsDrinkAddOn());
        }
      }
    }
  }

  return {
    formula: bestResult.formula,
    servings: bestResult.servings,
    addOns: bestResult.addOns,
  };
}

// ============================================================================
// Entry Point
// ============================================================================

export function runAlgoB(scenario: Scenario): AlgorithmResult {
  const phases = getActiveSubPhases(scenario.hours_before);
  const state: PlanState = { banana_used: false, sports_drink_used: false, used_categories: new Set() };
  const subPhaseResults: SubPhaseResult[] = [];

  for (const phase of phases) {
    const phaseTargets = scenario.targets.phase_targets.get(phase);
    const carbTarget = phaseTargets?.carbs_g ?? 0;

    const eligible = getEligibleFormulas(FORMULAS, phase, scenario.diet);
    const selection = selectFormula(eligible, carbTarget, state);

    if (!selection) {
      // No eligible formula — empty phase
      subPhaseResults.push(buildSubPhaseResult(phase, null, []));
      continue;
    }

    // Update cross-phase state
    state.used_categories.add(selection.formula.base_category);
    for (const addOn of selection.addOns) {
      if (addOn.type === 'banana') state.banana_used = true;
      if (addOn.type === 'sports_drink') state.sports_drink_used = true;
    }

    const formulaSel = makeSelection(selection.formula, selection.servings);
    subPhaseResults.push(buildSubPhaseResult(phase, formulaSel, selection.addOns));
  }

  return assembleResult('B', subPhaseResults);
}
