/**
 * Algorithm D: Unified Cross-Phase Plans
 *
 * Pre-generated curated meal+snack+topoff combinations:
 * - Programmatically generate valid formula combinations for each plan type
 * - 3-phase plans (meal + snack + topoff) for >=2.5h windows
 * - 2-phase plans (snack + topoff) for 1-2.5h windows
 * - 1-phase plans (topoff only) for <1h windows
 * - Each plan pre-validated for food diversity (no repeating categories)
 * - Selection: score each plan by combined base carbs vs total target
 * - Scaling: each sub-phase formula scales independently within min/max
 */

import {
  type Formula,
  type Scenario,
  type AlgorithmResult,
  type SubPhaseResult,
  type SubPhaseType,
  type AddOn,
  BANANA_CARBS,
  SPORTS_DRINK_CARBS,
} from '../types.ts';
import { FORMULAS } from '../data/formulas.ts';
import {
  getEligibleFormulas,
  clampAndSnap,
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
// Plan Types
// ============================================================================

interface UnifiedPlan {
  meal?: Formula;
  snack?: Formula;
  topoff: Formula;
  base_carbs_total: number;
  categories: Set<string>;
}

// ============================================================================
// Plan Generation
// ============================================================================

/**
 * Generate all valid 3-phase plans (meal + snack + topoff).
 * Rules:
 * - No duplicate base_category across phases
 * - Each formula must be from its correct time window
 */
function generate3PhasePlans(
  mealFormulas: Formula[],
  snackFormulas: Formula[],
  topoffFormulas: Formula[],
): UnifiedPlan[] {
  const plans: UnifiedPlan[] = [];

  for (const meal of mealFormulas) {
    for (const snack of snackFormulas) {
      // Skip if same category
      if (meal.base_category === snack.base_category) continue;

      for (const topoff of topoffFormulas) {
        // Skip if topoff shares category with meal or snack
        if (topoff.base_category === meal.base_category) continue;
        if (topoff.base_category === snack.base_category) continue;

        // Calculate base carbs at comfortable (min) servings
        const mealCarbs = meal.carbs_per_serving * meal.min_servings;
        const snackCarbs = snack.carbs_per_serving * snack.min_servings;
        const topoffCarbs = topoff.carbs_per_serving * topoff.min_servings;

        plans.push({
          meal,
          snack,
          topoff,
          base_carbs_total: mealCarbs + snackCarbs + topoffCarbs,
          categories: new Set([meal.base_category, snack.base_category, topoff.base_category]),
        });
      }
    }
  }

  return plans;
}

/**
 * Generate all valid 2-phase plans (snack + topoff).
 */
function generate2PhasePlans(
  snackFormulas: Formula[],
  topoffFormulas: Formula[],
): UnifiedPlan[] {
  const plans: UnifiedPlan[] = [];

  for (const snack of snackFormulas) {
    for (const topoff of topoffFormulas) {
      if (topoff.base_category === snack.base_category) continue;

      const snackCarbs = snack.carbs_per_serving * snack.min_servings;
      const topoffCarbs = topoff.carbs_per_serving * topoff.min_servings;

      plans.push({
        snack,
        topoff,
        base_carbs_total: snackCarbs + topoffCarbs,
        categories: new Set([snack.base_category, topoff.base_category]),
      });
    }
  }

  return plans;
}

/**
 * Generate 1-phase plans (topoff only).
 */
function generate1PhasePlans(topoffFormulas: Formula[]): UnifiedPlan[] {
  return topoffFormulas.map((topoff) => ({
    topoff,
    base_carbs_total: topoff.carbs_per_serving * topoff.min_servings,
    categories: new Set([topoff.base_category]),
  }));
}

// ============================================================================
// Plan Selection & Scaling
// ============================================================================

/**
 * Score a plan: how close its max comfortable carbs can get to target.
 * Uses comfortable servings (60% of max) for scoring.
 */
function scorePlan(plan: UnifiedPlan, totalCarbTarget: number): number {
  let maxComfortable = 0;

  if (plan.meal) {
    const servings = Math.round(plan.meal.max_servings * 0.6 * 2) / 2;
    maxComfortable += plan.meal.carbs_per_serving * Math.max(plan.meal.min_servings, servings);
  }
  if (plan.snack) {
    const servings = Math.round(plan.snack.max_servings * 0.6 * 2) / 2;
    maxComfortable += plan.snack.carbs_per_serving * Math.max(plan.snack.min_servings, servings);
  }
  {
    const servings = Math.round(plan.topoff.max_servings * 0.6 * 2) / 2;
    maxComfortable += plan.topoff.carbs_per_serving * Math.max(plan.topoff.min_servings, servings);
  }

  return Math.abs(maxComfortable - totalCarbTarget);
}

/**
 * Scale a single formula within a plan to meet its sub-phase carb target.
 * Uses Xuan's comfortable approach: start at comfortable, scale up if needed.
 */
function scaleFormulaInPlan(
  formula: Formula,
  carbTarget: number,
  bananaUsed: boolean,
  sportsDrinkUsed: boolean,
): { servings: number; addOns: AddOn[] } {
  // Start at comfortable servings
  const comfortable = Math.round(formula.max_servings * 0.6 * 2) / 2;
  let servings = clampAndSnap(comfortable, formula);

  let carbs = formulaCarbs(formula, servings);
  const addOns: AddOn[] = [];

  // Scale up in 0.5 increments if gap is large
  while (carbTarget - carbs > 15 && servings + 0.5 <= formula.max_servings) {
    servings += 0.5;
    carbs = formulaCarbs(formula, servings);
  }

  servings = clampAndSnap(servings, formula);
  carbs = formulaCarbs(formula, servings);

  // Add-ons to fill remaining gap (only if it brings us closer to target)
  let gap = carbTarget - carbs;
  if (gap > 10 && formula.plus_banana && !bananaUsed) {
    const withBanana = Math.abs(carbTarget - (carbs + BANANA_CARBS));
    if (withBanana < Math.abs(gap)) {
      carbs += BANANA_CARBS;
      addOns.push(makeBananaAddOn());
      gap = carbTarget - carbs;
    }
  }
  if (gap > 10 && formula.plus_sports_drink && !sportsDrinkUsed) {
    const withDrink = Math.abs(carbTarget - (carbs + SPORTS_DRINK_CARBS));
    if (withDrink < Math.abs(gap)) {
      carbs += SPORTS_DRINK_CARBS;
      addOns.push(makeSportsDrinkAddOn());
      gap = carbTarget - carbs;
    }
  }

  return { servings, addOns };
}

// ============================================================================
// Entry Point
// ============================================================================

export function runAlgoD(scenario: Scenario): AlgorithmResult {
  const phases = getActiveSubPhases(scenario.hours_before);
  const diet = scenario.diet;

  // Get eligible formulas per phase
  const mealFormulas = phases.includes('meal')
    ? getEligibleFormulas(FORMULAS, 'meal', diet)
    : [];
  const snackFormulas = phases.includes('snack')
    ? getEligibleFormulas(FORMULAS, 'snack', diet)
    : [];
  const topoffFormulas = getEligibleFormulas(FORMULAS, 'top_up', diet);

  // Generate valid plans based on number of phases
  let plans: UnifiedPlan[];
  if (phases.length === 3) {
    plans = generate3PhasePlans(mealFormulas, snackFormulas, topoffFormulas);
  } else if (phases.length === 2) {
    plans = generate2PhasePlans(snackFormulas, topoffFormulas);
  } else {
    plans = generate1PhasePlans(topoffFormulas);
  }

  // If no valid plans, return empty result
  if (plans.length === 0) {
    const emptyPhases = phases.map((p) => buildSubPhaseResult(p, null, []));
    return assembleResult('D', emptyPhases);
  }

  // Score and select best plan
  const totalCarbTarget = scenario.targets.total_carbs_g;
  plans.sort((a, b) => scorePlan(a, totalCarbTarget) - scorePlan(b, totalCarbTarget));
  const bestPlan = plans[0];

  // Scale each sub-phase independently
  const subPhaseResults: SubPhaseResult[] = [];
  let bananaUsed = false;
  let sportsDrinkUsed = false;

  for (const phase of phases) {
    const formula = phase === 'meal' ? bestPlan.meal
      : phase === 'snack' ? bestPlan.snack
      : bestPlan.topoff;

    if (!formula) {
      subPhaseResults.push(buildSubPhaseResult(phase, null, []));
      continue;
    }

    const phaseTargets = scenario.targets.phase_targets.get(phase);
    const carbTarget = phaseTargets?.carbs_g ?? 0;

    const { servings, addOns } = scaleFormulaInPlan(
      formula,
      carbTarget,
      bananaUsed,
      sportsDrinkUsed,
    );

    // Update cross-phase state
    for (const addOn of addOns) {
      if (addOn.type === 'banana') bananaUsed = true;
      if (addOn.type === 'sports_drink') sportsDrinkUsed = true;
    }

    const formulaSel = makeSelection(formula, servings);
    subPhaseResults.push(buildSubPhaseResult(phase, formulaSel, addOns));
  }

  return assembleResult('D', subPhaseResults);
}
