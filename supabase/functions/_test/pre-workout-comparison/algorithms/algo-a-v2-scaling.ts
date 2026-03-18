/**
 * Algorithm A: V2-Style Proportional Scaling
 *
 * Adapts V2's grid-search approach to work with formulas:
 * - Grid search multiplier 0.25x-4.0x on each formula's servings
 * - Weighted scoring: carbs 80%, sodium 20%
 * - Independent selection per sub-phase (best formula per phase)
 * - Snaps servings to 0.5 increments
 * - No add-on system — pure scaling only
 */

import {
  type Formula,
  type Scenario,
  type AlgorithmResult,
  type SubPhaseResult,
  type SubPhaseType,
} from '../types.ts';
import { FORMULAS } from '../data/formulas.ts';
import {
  getEligibleFormulas,
  snapToHalf,
  formulaCarbs,
  formulaSodium,
  makeSelection,
  buildSubPhaseResult,
  assembleResult,
} from './shared.ts';
import { getActiveSubPhases } from '../macro-targets.ts';

// ============================================================================
// Scoring & Search
// ============================================================================

/**
 * Score a formula at a given multiplier against targets.
 * Weighted: carbs 60% + sodium 40%.
 * Penalizes carb overshoot >20%.
 */
function scoreFormula(
  formula: Formula,
  servings: number,
  carbTarget: number,
  sodiumTarget: number,
): number {
  const carbs = formulaCarbs(formula, servings);
  const sodium = formulaSodium(formula, servings);

  const carbScore = carbTarget > 0
    ? Math.max(0, Math.min(1, 1 - Math.abs(carbs - carbTarget) / carbTarget))
    : 1;

  const sodiumScore = sodiumTarget > 0
    ? Math.max(0, Math.min(1, 1 - Math.abs(sodium - sodiumTarget) / sodiumTarget))
    : 1;

  // Penalize carb overshoot >20%
  const penalty = carbs > carbTarget * 1.2 ? -0.15 : 0;

  return 0.8 * carbScore + 0.2 * sodiumScore + penalty;
}

/**
 * Find the best serving count for a formula against targets.
 * Tests all valid 0.5-increment serving counts within min/max.
 */
function findBestServings(
  formula: Formula,
  carbTarget: number,
  sodiumTarget: number,
): { servings: number; score: number } {
  let bestServings = formula.min_servings;
  let bestScore = -Infinity;

  // Iterate through all valid serving counts in 0.5 increments
  for (let s = formula.min_servings; s <= formula.max_servings; s += 0.5) {
    const servings = snapToHalf(s);
    const score = scoreFormula(formula, servings, carbTarget, sodiumTarget);
    if (score > bestScore) {
      bestScore = score;
      bestServings = servings;
    }
  }

  return { servings: bestServings, score: bestScore };
}

/**
 * Select the best formula for a sub-phase using grid search.
 */
function selectBestFormula(
  eligible: Formula[],
  carbTarget: number,
  sodiumTarget: number,
): { formula: Formula; servings: number } | null {
  if (eligible.length === 0) return null;

  let bestFormula: Formula | null = null;
  let bestServings = 1;
  let bestScore = -Infinity;

  for (const formula of eligible) {
    const { servings, score } = findBestServings(formula, carbTarget, sodiumTarget);
    if (score > bestScore) {
      bestScore = score;
      bestFormula = formula;
      bestServings = servings;
    }
  }

  if (!bestFormula) return null;
  return { formula: bestFormula, servings: bestServings };
}

// ============================================================================
// Entry Point
// ============================================================================

export function runAlgoA(scenario: Scenario): AlgorithmResult {
  const phases = getActiveSubPhases(scenario.hours_before);
  const subPhaseResults: SubPhaseResult[] = [];

  for (const phase of phases) {
    const phaseTargets = scenario.targets.phase_targets.get(phase);
    const carbTarget = phaseTargets?.carbs_g ?? 0;
    const sodiumTarget = phaseTargets?.sodium_mg ?? 0;

    const eligible = getEligibleFormulas(FORMULAS, phase, scenario.diet);
    const selection = selectBestFormula(eligible, carbTarget, sodiumTarget);

    if (!selection) {
      subPhaseResults.push(buildSubPhaseResult(phase, null, []));
      continue;
    }

    const formulaSel = makeSelection(selection.formula, selection.servings);
    subPhaseResults.push(buildSubPhaseResult(phase, formulaSel, []));
  }

  return assembleResult('A', subPhaseResults);
}
