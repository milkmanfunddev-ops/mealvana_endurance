/**
 * Acceptance Criteria Evaluation
 *
 * Evaluates algorithm results against 10 acceptance criteria:
 * 1. Carb accuracy (FAIL)
 * 2. No banana overload (FAIL)
 * 3. No absurd quantities (FAIL)
 * 4. No food overload (FAIL)
 * 5. No cross-phase food repeat (WARN)
 * 6. Dietary compliance (FAIL)
 * 7. Half-serving precision (FAIL)
 * 8. Phase coverage (FAIL)
 * 9. Sodium accuracy (WARN)
 * 10. Add-on sanity (FAIL)
 */

import {
  type Scenario,
  type AlgorithmResult,
  type CriterionResult,
  type EvaluationResult,
  type Diet,
  type Allergen,
} from './types.ts';
import { FORMULAS } from './data/formulas.ts';
import { getActiveSubPhases } from './macro-targets.ts';

// ============================================================================
// Allergen Mapping
// ============================================================================

/**
 * Collect all formula selections (primary + stacked) from a result.
 */
function allSelections(result: AlgorithmResult): Array<{ sel: import('./types.ts').FormulaSelection; phase: import('./types.ts').SubPhaseType }> {
  const items: Array<{ sel: import('./types.ts').FormulaSelection; phase: import('./types.ts').SubPhaseType }> = [];
  for (const p of result.sub_phases) {
    if (p.formula) items.push({ sel: p.formula, phase: p.phase });
    if (p.second_formula) items.push({ sel: p.second_formula, phase: p.phase });
    if (p.drink) items.push({ sel: p.drink, phase: p.phase });
  }
  return items;
}

function getDietAllergens(diet: Diet): Allergen[] {
  switch (diet) {
    case 'gluten-free': return ['Gluten'];
    case 'dairy-free': return ['Dairy'];
    case 'peanut-free': return ['Peanut'];
    case 'all-free': return ['Gluten', 'Dairy', 'Peanut'];
    default: return [];
  }
}

// ============================================================================
// Individual Criteria
// ============================================================================

function checkCarbAccuracy(scenario: Scenario, result: AlgorithmResult): CriterionResult {
  const target = scenario.targets.total_carbs_g;
  const actual = result.total_carbs_g;

  if (target < 50) {
    // For small targets, use absolute tolerance of +-10g
    const passed = Math.abs(actual - target) <= 10;
    return {
      name: 'carb_accuracy',
      passed,
      severity: 'FAIL',
      detail: `Target: ${target}g, Actual: ${actual}g, Diff: ${(actual - target).toFixed(1)}g (±10g tolerance)`,
    };
  }

  const pctDiff = Math.abs(actual - target) / target;
  const passed = pctDiff <= 0.20;
  return {
    name: 'carb_accuracy',
    passed,
    severity: 'FAIL',
    detail: `Target: ${target}g, Actual: ${actual}g, Diff: ${(pctDiff * 100).toFixed(1)}% (±20% tolerance)`,
  };
}

function checkBananaOverload(result: AlgorithmResult): CriterionResult {
  let bananaCount = 0;
  for (const phase of result.sub_phases) {
    bananaCount += phase.add_ons.filter((a) => a.type === 'banana').length;
  }

  return {
    name: 'banana_overload',
    passed: bananaCount <= 1,
    severity: 'FAIL',
    detail: `Banana add-ons: ${bananaCount} (max 1)`,
  };
}

function checkAbsurdQuantities(result: AlgorithmResult): CriterionResult {
  const issues: string[] = [];
  for (const { sel, phase } of allSelections(result)) {
    const formula = FORMULAS.find((f) => f.id === sel.formula_id);
    const maxAllowed = formula?.max_servings ?? 3.5;
    if (sel.servings > maxAllowed || sel.servings > 4) {
      issues.push(`${sel.formula_name}@${sel.servings} in ${phase} (max: ${maxAllowed})`);
    }
  }

  return {
    name: 'absurd_qty',
    passed: issues.length === 0,
    severity: 'FAIL',
    detail: issues.length > 0 ? `Over 3.5 servings: ${issues.join(', ')}` : 'All servings <= 3.5',
  };
}

function checkFoodOverload(result: AlgorithmResult): CriterionResult {
  const issues: string[] = [];
  for (const { sel } of allSelections(result)) {
    const formula = FORMULAS.find((f) => f.id === sel.formula_id);
    if (formula && sel.servings > formula.max_servings) {
      issues.push(`${sel.formula_name}@${sel.servings} > max ${formula.max_servings}`);
    }
  }

  return {
    name: 'food_overload',
    passed: issues.length === 0,
    severity: 'FAIL',
    detail: issues.length > 0 ? `Exceeds max: ${issues.join(', ')}` : 'All within max_servings',
  };
}

function checkCrossPhaseRepeat(result: AlgorithmResult): CriterionResult {
  // Count how many different phases each category appears in
  const categoryPhases = new Map<string, Set<string>>();
  for (const { sel, phase } of allSelections(result)) {
    const cat = sel.base_category;
    if (!categoryPhases.has(cat)) categoryPhases.set(cat, new Set());
    categoryPhases.get(cat)!.add(phase);
  }

  const categoryCounts = new Map<string, number>();
  for (const [cat, phases] of categoryPhases) {
    categoryCounts.set(cat, phases.size);
  }

  const repeats = Array.from(categoryCounts.entries())
    .filter(([_, count]) => count > 1)
    .map(([cat, count]) => `${cat}(${count}x)`);

  return {
    name: 'cross_phase_repeat',
    passed: repeats.length === 0,
    severity: 'WARN',
    detail: repeats.length > 0 ? `Repeated categories: ${repeats.join(', ')}` : 'No cross-phase repeats',
  };
}

function checkDietaryCompliance(scenario: Scenario, result: AlgorithmResult): CriterionResult {
  const excluded = getDietAllergens(scenario.diet);
  if (excluded.length === 0) {
    return { name: 'dietary', passed: true, severity: 'FAIL', detail: 'No restrictions' };
  }

  const violations: string[] = [];
  for (const { sel } of allSelections(result)) {
    const formula = FORMULAS.find((f) => f.id === sel.formula_id);
    if (!formula) continue;
    for (const allergen of formula.allergens) {
      if (excluded.includes(allergen as Allergen)) {
        violations.push(`${formula.name} contains ${allergen}`);
      }
    }
  }

  return {
    name: 'dietary',
    passed: violations.length === 0,
    severity: 'FAIL',
    detail: violations.length > 0 ? `Violations: ${violations.join(', ')}` : `Compliant with ${scenario.diet}`,
  };
}

function checkHalfServingPrecision(result: AlgorithmResult): CriterionResult {
  const issues: string[] = [];
  for (const { sel } of allSelections(result)) {
    const remainder = sel.servings % 0.5;
    if (Math.abs(remainder) > 0.01 && Math.abs(remainder - 0.5) > 0.01) {
      issues.push(`${sel.formula_name}@${sel.servings}`);
    }
  }

  return {
    name: 'half_serving',
    passed: issues.length === 0,
    severity: 'FAIL',
    detail: issues.length > 0 ? `Not 0.5 increments: ${issues.join(', ')}` : 'All 0.5 increments',
  };
}

function checkPhaseCoverage(scenario: Scenario, result: AlgorithmResult): CriterionResult {
  const expectedPhases = getActiveSubPhases(scenario.hours_before);
  const actualPhases = result.sub_phases.map((p) => p.phase);

  const missing = expectedPhases.filter((p) => !actualPhases.includes(p));
  const extra = actualPhases.filter((p) => !expectedPhases.includes(p));

  const passed = missing.length === 0 && extra.length === 0;
  const details: string[] = [];
  if (missing.length > 0) details.push(`Missing: ${missing.join(', ')}`);
  if (extra.length > 0) details.push(`Extra: ${extra.join(', ')}`);

  return {
    name: 'phase_coverage',
    passed,
    severity: 'FAIL',
    detail: passed ? `Correct ${expectedPhases.length} phases` : details.join('; '),
  };
}

function checkSodiumAccuracy(scenario: Scenario, result: AlgorithmResult): CriterionResult {
  const actual = result.total_sodium_mg;
  const low = scenario.targets.total_sodium_low_mg;
  const high = scenario.targets.total_sodium_high_mg;
  const midpoint = scenario.targets.total_sodium_mg;

  if (midpoint <= 0 && low <= 0) {
    return { name: 'sodium_accuracy', passed: true, severity: 'WARN', detail: 'No sodium target' };
  }

  const passed = actual >= low && actual <= high;

  return {
    name: 'sodium_accuracy',
    passed,
    severity: 'WARN',
    detail: `Range: ${low}-${high}mg, Actual: ${actual}mg${passed ? '' : actual < low ? ' (under floor)' : ' (over ceiling)'}`,
  };
}

function checkHydrationAccuracy(scenario: Scenario, result: AlgorithmResult): CriterionResult {
  const actual = result.total_fluid_ml;
  const low = scenario.targets.total_hydration_low_ml;
  const high = scenario.targets.total_hydration_high_ml;
  const midpoint = scenario.targets.total_hydration_ml;

  if (midpoint <= 0 && low <= 0) {
    return { name: 'hydration_accuracy', passed: true, severity: 'WARN', detail: 'No hydration target' };
  }

  const passed = actual >= low && actual <= high;

  return {
    name: 'hydration_accuracy',
    passed,
    severity: 'WARN',
    detail: `Range: ${low}-${high}ml, Actual: ${actual}ml${passed ? '' : actual < low ? ' (under floor)' : ' (over ceiling)'}`,
  };
}

function checkAddOnSanity(result: AlgorithmResult): CriterionResult {
  let totalBananas = 0;
  let totalDrinks = 0;

  for (const phase of result.sub_phases) {
    totalBananas += phase.add_ons.filter((a) => a.type === 'banana').length;
    totalDrinks += phase.add_ons.filter((a) => a.type === 'sports_drink').length;
  }

  const passed = totalBananas <= 1 && totalDrinks <= 1;

  return {
    name: 'addon_sanity',
    passed,
    severity: 'FAIL',
    detail: `Bananas: ${totalBananas}/1, Sports drinks: ${totalDrinks}/1`,
  };
}

// ============================================================================
// Full Evaluation
// ============================================================================

export function evaluate(scenario: Scenario, result: AlgorithmResult): EvaluationResult {
  const criteria: CriterionResult[] = [
    checkCarbAccuracy(scenario, result),
    checkBananaOverload(result),
    checkAbsurdQuantities(result),
    checkFoodOverload(result),
    checkCrossPhaseRepeat(result),
    checkDietaryCompliance(scenario, result),
    checkHalfServingPrecision(result),
    checkPhaseCoverage(scenario, result),
    checkSodiumAccuracy(scenario, result),
    checkHydrationAccuracy(scenario, result),
    checkAddOnSanity(result),
  ];

  const failCount = criteria.filter((c) => !c.passed && c.severity === 'FAIL').length;
  const warnCount = criteria.filter((c) => !c.passed && c.severity === 'WARN').length;

  return {
    scenario_id: scenario.id,
    algorithm: result.algorithm,
    passed: failCount === 0,
    criteria,
    fail_count: failCount,
    warn_count: warnCount,
  };
}
