/**
 * Pre-Workout Algorithm Comparison — Entry Point
 *
 * Usage:
 *   deno run --allow-read --allow-write _test/pre-workout-comparison/run.ts
 *   deno run --allow-read --allow-write _test/pre-workout-comparison/run.ts --quick
 *   deno run --allow-read --allow-write _test/pre-workout-comparison/run.ts --algo=b
 *   deno run --allow-read --allow-write _test/pre-workout-comparison/run.ts --verbose
 */

import { type Scenario, type AlgorithmResult, type EvaluationResult } from './types.ts';
import { generateScenarios } from './scenarios.ts';
import { runAlgoA } from './algorithms/algo-a-v2-scaling.ts';
import { runAlgoB } from './algorithms/algo-b-xuan.ts';
import { runAlgoC } from './algorithms/algo-c-comfort-cap.ts';
import { runAlgoD } from './algorithms/algo-d-unified-plans.ts';
import { evaluate } from './criteria.ts';
import { generateReport } from './report.ts';

// ============================================================================
// CLI Argument Parsing
// ============================================================================

interface CliArgs {
  quick: boolean;
  algo: string | null; // null = all, 'a'|'b'|'c'|'d' = single
  verbose: boolean;
}

function parseArgs(): CliArgs {
  const args: CliArgs = { quick: false, algo: null, verbose: false };

  for (const arg of Deno.args) {
    if (arg === '--quick') args.quick = true;
    if (arg === '--verbose') args.verbose = true;
    if (arg.startsWith('--algo=')) {
      args.algo = arg.split('=')[1].toLowerCase();
    }
  }

  return args;
}

// ============================================================================
// Algorithm Registry
// ============================================================================

type AlgoFn = (scenario: Scenario) => AlgorithmResult;

const ALGO_REGISTRY: Record<string, AlgoFn> = {
  a: runAlgoA,
  b: runAlgoB,
  c: runAlgoC,
  d: runAlgoD,
};

// ============================================================================
// Main
// ============================================================================

function main() {
  const args = parseArgs();

  // Generate scenarios
  const scenarios = generateScenarios(args.quick);
  console.log(`Generated ${scenarios.length} scenarios (${args.quick ? 'quick' : 'full'} mode)`);

  // Determine which algorithms to run
  const algosToRun = args.algo
    ? { [args.algo]: ALGO_REGISTRY[args.algo] }
    : ALGO_REGISTRY;

  if (args.algo && !ALGO_REGISTRY[args.algo]) {
    console.error(`Unknown algorithm: ${args.algo}. Available: a, b, c, d`);
    Deno.exit(1);
  }

  // Run algorithms and evaluate
  const allResults = new Map<string, Map<string, AlgorithmResult>>();
  const allEvaluations: EvaluationResult[] = [];

  for (const [algoKey, algoFn] of Object.entries(algosToRun)) {
    const algoLabel = algoKey.toUpperCase();
    const scenarioResults = new Map<string, AlgorithmResult>();

    for (const scenario of scenarios) {
      const result = algoFn(scenario);
      scenarioResults.set(scenario.id, result);

      const evaluation = evaluate(scenario, result);
      allEvaluations.push(evaluation);
    }

    allResults.set(algoLabel, scenarioResults);
  }

  // Generate report
  const report = generateReport(scenarios, allResults, allEvaluations, args.verbose);

  // Write JSON report
  const reportPath = new URL('./report-output.json', import.meta.url).pathname;
  try {
    Deno.writeTextFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`\nJSON report written to: ${reportPath}`);
  } catch {
    // If write fails (e.g., permissions), just skip
    console.log('\n(Could not write JSON report file)');
  }
}

main();
