/**
 * Report Generation
 *
 * Console and JSON report for algorithm comparison results.
 */

import {
  type Scenario,
  type AlgorithmResult,
  type EvaluationResult,
  type AlgorithmSummary,
  type ComparisonReport,
} from './types.ts';

const ALGO_NAMES: Record<string, string> = {
  A: 'V2 Scaling',
  B: 'Xuan Formulas',
  C: 'Comfort-Capped',
  D: 'Unified Plans',
};

// ============================================================================
// Summary Calculation
// ============================================================================

function buildSummary(algorithm: string, evaluations: EvaluationResult[]): AlgorithmSummary {
  const algoEvals = evaluations.filter((e) => e.algorithm === algorithm);
  const passed = algoEvals.filter((e) => e.passed).length;
  const total = algoEvals.length;

  const failureBreakdown: Record<string, number> = {};
  const warnBreakdown: Record<string, number> = {};

  for (const eval_ of algoEvals) {
    for (const criterion of eval_.criteria) {
      if (!criterion.passed) {
        const bucket = criterion.severity === 'FAIL' ? failureBreakdown : warnBreakdown;
        bucket[criterion.name] = (bucket[criterion.name] ?? 0) + 1;
      }
    }
  }

  return {
    algorithm,
    total_scenarios: total,
    passed,
    failed: total - passed,
    pass_rate: total > 0 ? passed / total : 0,
    failure_breakdown: failureBreakdown,
    warn_breakdown: warnBreakdown,
  };
}

// ============================================================================
// Console Output
// ============================================================================

function printHeader(totalScenarios: number, algoCount: number) {
  console.log('');
  console.log('='.repeat(64));
  console.log('  PRE-WORKOUT ALGORITHM COMPARISON');
  console.log(`  ${totalScenarios} scenarios x ${algoCount} algorithms = ${totalScenarios * algoCount} evaluations`);
  console.log('='.repeat(64));
  console.log('');
}

function printPassRates(summaries: AlgorithmSummary[]) {
  console.log('PASS RATES:');
  for (const s of summaries) {
    const pctStr = (s.pass_rate * 100).toFixed(1);
    const bar = '#'.repeat(Math.round(s.pass_rate * 30));
    const name = `${s.algorithm} (${ALGO_NAMES[s.algorithm] ?? s.algorithm})`;
    console.log(`  ${name.padEnd(22)} ${String(s.passed).padStart(3)}/${s.total_scenarios} (${pctStr.padStart(5)}%) ${bar}`);
  }
  console.log('');
}

function printFailureBreakdown(summaries: AlgorithmSummary[]) {
  console.log('FAILURE BREAKDOWN:');
  for (const s of summaries) {
    const entries = Object.entries(s.failure_breakdown)
      .sort((a, b) => b[1] - a[1])
      .map(([name, count]) => `${name}(${count})`)
      .join(', ');
    console.log(`  ${s.algorithm}: ${entries || '(none)'}`);
  }
  console.log('');

  console.log('WARN BREAKDOWN:');
  for (const s of summaries) {
    const entries = Object.entries(s.warn_breakdown)
      .sort((a, b) => b[1] - a[1])
      .map(([name, count]) => `${name}(${count})`)
      .join(', ');
    console.log(`  ${s.algorithm}: ${entries || '(none)'}`);
  }
  console.log('');
}

function printSampleScenario(
  scenario: Scenario,
  results: Map<string, AlgorithmResult>,
  evaluations: Map<string, EvaluationResult>,
) {
  console.log(`SAMPLE: ${scenario.label} (target: ${scenario.targets.total_carbs_g}g carbs, ${scenario.targets.total_sodium_mg}mg Na, ${scenario.targets.total_hydration_ml}ml H₂O)`);
  for (const [algo, result] of results) {
    const eval_ = evaluations.get(algo);
    const icon = eval_?.passed ? '\u2705' : '\u274C';

    const phases = result.sub_phases.map((p) => {
      const parts: string[] = [];
      if (p.formula) {
        parts.push(`${p.formula.formula_name}@${p.formula.servings}`);
      }
      if (p.second_formula) {
        parts.push(`${p.second_formula.formula_name}@${p.second_formula.servings}`);
      }
      for (const addOn of p.add_ons) {
        parts.push(addOn.type === 'banana' ? '\uD83C\uDF4C' : '\uD83E\uDD64');
      }
      if (p.drink) {
        parts.push(`\uD83D\uDCA7${p.drink.formula_name}@${p.drink.servings}`);
      }
      return parts.join('+') || '(empty)';
    });

    const name = `${algo} (${ALGO_NAMES[algo] ?? algo})`;
    console.log(`  ${name.padEnd(22)} ${phases.join(' -> ')} = ${result.total_carbs_g}g, ${result.total_sodium_mg}mg Na, ${result.total_fluid_ml}ml ${icon}`);
  }
  console.log('');
}

function printVerboseDetails(
  scenarios: Scenario[],
  allResults: Map<string, Map<string, AlgorithmResult>>,
  allEvaluations: EvaluationResult[],
) {
  console.log('-'.repeat(64));
  console.log('DETAILED RESULTS');
  console.log('-'.repeat(64));

  for (const scenario of scenarios) {
    console.log(`\n--- ${scenario.label} (target: ${scenario.targets.total_carbs_g}g carbs) ---`);

    for (const [algo, scenarioResults] of allResults) {
      const result = scenarioResults.get(scenario.id);
      if (!result) continue;

      const eval_ = allEvaluations.find(
        (e) => e.scenario_id === scenario.id && e.algorithm === algo,
      );
      const icon = eval_?.passed ? '\u2705' : '\u274C';

      console.log(`  ${algo} (${ALGO_NAMES[algo]}): ${icon}`);
      for (const phase of result.sub_phases) {
        const parts: string[] = [];
        if (phase.formula) {
          parts.push(`${phase.formula.formula_name}@${phase.formula.servings} (${phase.formula.carbs_g}g)`);
        }
        if (phase.second_formula) {
          parts.push(`${phase.second_formula.formula_name}@${phase.second_formula.servings} (${phase.second_formula.carbs_g}g)`);
        }
        for (const addOn of phase.add_ons) {
          parts.push(`${addOn.type}(${addOn.carbs_g}g)`);
        }
        if (phase.drink) {
          parts.push(`${phase.drink.formula_name}@${phase.drink.servings} (${phase.drink.fluid_ml}ml)`);
        }
        console.log(`    ${phase.phase}: ${parts.join(' + ') || '(empty)'} = ${phase.total_carbs_g}g, ${phase.total_sodium_mg}mg Na, ${phase.total_fluid_ml}ml`);
      }
      console.log(`    TOTAL: ${result.total_carbs_g}g carbs, ${result.total_sodium_mg}mg Na, ${result.total_fluid_ml}ml H₂O`);

      if (eval_ && !eval_.passed) {
        const failures = eval_.criteria.filter((c) => !c.passed);
        for (const f of failures) {
          console.log(`    [${f.severity}] ${f.name}: ${f.detail}`);
        }
      }
    }
  }
}

// ============================================================================
// Public API
// ============================================================================

export function generateReport(
  scenarios: Scenario[],
  allResults: Map<string, Map<string, AlgorithmResult>>,
  evaluations: EvaluationResult[],
  verbose: boolean,
): ComparisonReport {
  // Only include algorithms that were actually run
  const algorithms = ['A', 'B', 'C', 'D'].filter((a) => allResults.has(a));
  const summaries = algorithms.map((a) => buildSummary(a, evaluations));

  // Console output
  printHeader(scenarios.length, algorithms.length);
  printPassRates(summaries);
  printFailureBreakdown(summaries);

  // Show a sample scenario (pick a representative 3-phase one)
  const sampleScenario = scenarios.find(
    (s) => s.hours_before >= 2.5 && s.diet === 'none' && s.weight_kg >= 65 && s.weight_kg <= 80,
  ) ?? scenarios[0];

  const sampleResults = new Map<string, AlgorithmResult>();
  const sampleEvals = new Map<string, EvaluationResult>();

  for (const algo of algorithms) {
    const result = allResults.get(algo)?.get(sampleScenario.id);
    if (result) sampleResults.set(algo, result);
    const eval_ = evaluations.find(
      (e) => e.scenario_id === sampleScenario.id && e.algorithm === algo,
    );
    if (eval_) sampleEvals.set(algo, eval_);
  }

  printSampleScenario(sampleScenario, sampleResults, sampleEvals);

  if (verbose) {
    printVerboseDetails(scenarios, allResults, evaluations);
  }

  // Build JSON report
  return {
    timestamp: new Date().toISOString(),
    total_scenarios: scenarios.length,
    algorithms: summaries,
    evaluations,
  };
}
