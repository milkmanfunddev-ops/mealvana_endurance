/**
 * Test Scenario Generation
 *
 * Generates ~120 scenarios by combining:
 * - 4 weights: 50kg, 65kg, 80kg, 95kg
 * - 5 hours_before: 0.25h, 0.75h, 1.5h, 2.5h, 3.5h
 * - 4 diets + 2 edge cases
 */

import { type Scenario, type Diet } from './types.ts';
import { calculateMacroTargets } from './macro-targets.ts';

const WEIGHTS = [50, 65, 80, 95];
const HOURS_BEFORE = [0.25, 0.75, 1.5, 2.5, 3.5];
const DIETS: Diet[] = ['none', 'gluten-free', 'dairy-free', 'peanut-free'];

function dietLabel(diet: Diet): string {
  if (diet === 'none') return 'no restrictions';
  return diet;
}

/**
 * Generate all standard combination scenarios.
 */
function generateCombinations(): Scenario[] {
  const scenarios: Scenario[] = [];

  for (const weight of WEIGHTS) {
    for (const hours of HOURS_BEFORE) {
      for (const diet of DIETS) {
        const targets = calculateMacroTargets(weight, hours);
        scenarios.push({
          id: `${weight}kg_${hours}h_${diet}`,
          label: `${weight}kg, ${hours}h before, ${dietLabel(diet)}`,
          weight_kg: weight,
          hours_before: hours,
          diet,
          targets,
        });
      }
    }
  }

  return scenarios;
}

/**
 * Generate targeted edge-case scenarios.
 */
function generateEdgeCases(): Scenario[] {
  const edgeCases: Array<{ weight: number; hours: number; diet: Diet; label: string }> = [
    // Very light athlete + long window
    { weight: 50, hours: 3.5, diet: 'none', label: 'Light athlete, long window (175g target)' },
    // Very heavy athlete + short window
    { weight: 95, hours: 0.75, diet: 'none', label: 'Heavy athlete, short window (71g in <1h)' },
    // All allergens combined
    { weight: 70, hours: 2.5, diet: 'all-free' as Diet, label: 'All restrictions (very limited pool)' },
    { weight: 70, hours: 1.5, diet: 'all-free' as Diet, label: 'All restrictions, snack window' },
    { weight: 70, hours: 0.5, diet: 'all-free' as Diet, label: 'All restrictions, topoff only' },
    // Exact boundary at 1.0h
    { weight: 65, hours: 1.0, diet: 'none', label: 'Exactly 1h boundary (snack+topup)' },
    // Exact boundary at 2.5h
    { weight: 65, hours: 2.5, diet: 'none', label: 'Exactly 2.5h boundary (3-phase)' },
    // Heavy athlete, all restrictions, long window
    { weight: 95, hours: 3.5, diet: 'all-free' as Diet, label: 'Heavy + all restrictions + long window' },
    // Light athlete, short window, gluten-free
    { weight: 50, hours: 0.25, diet: 'gluten-free', label: 'Light athlete, <30min, gluten-free' },
    // Moderate athlete, moderate window
    { weight: 70, hours: 2.0, diet: 'none', label: '70kg, 2h before (snack+topup region)' },
    { weight: 70, hours: 3.0, diet: 'none', label: '70kg, 3h before (full meal)' },
    // Heavy athlete, dairy+peanut free (common combo)
    { weight: 85, hours: 2.5, diet: 'dairy-free', label: '85kg, 2.5h, dairy-free' },
    { weight: 85, hours: 2.5, diet: 'peanut-free', label: '85kg, 2.5h, peanut-free' },
    // Additional scenarios to approach ~120 total
    // Very large carb budgets (95kg at 3.5h = 333g!)
    { weight: 95, hours: 3.5, diet: 'none', label: 'Heavy athlete, huge carb budget (333g)' },
    { weight: 95, hours: 3.5, diet: 'gluten-free', label: 'Heavy, huge budget, gluten-free' },
    // Minimum targets
    { weight: 50, hours: 0.25, diet: 'none', label: 'Lightest athlete, minimal window (25g)' },
    { weight: 50, hours: 0.25, diet: 'all-free' as Diet, label: 'Lightest, minimal, all restricted' },
    // Mid-range athletes at various windows
    { weight: 75, hours: 1.0, diet: 'none', label: '75kg, exactly 1h' },
    { weight: 75, hours: 2.0, diet: 'none', label: '75kg, 2h snack window' },
    { weight: 75, hours: 3.0, diet: 'none', label: '75kg, 3h full meal' },
    { weight: 75, hours: 1.0, diet: 'gluten-free', label: '75kg, 1h, gluten-free' },
    { weight: 75, hours: 2.0, diet: 'dairy-free', label: '75kg, 2h, dairy-free' },
    { weight: 75, hours: 3.0, diet: 'peanut-free', label: '75kg, 3h, peanut-free' },
    // Extreme restriction combos
    { weight: 80, hours: 3.0, diet: 'all-free' as Diet, label: '80kg, 3h, all restricted' },
    { weight: 60, hours: 2.5, diet: 'all-free' as Diet, label: '60kg, 2.5h, all restricted' },
    // Near-boundary times
    { weight: 70, hours: 0.9, diet: 'none', label: '70kg, 0.9h (just under snack boundary)' },
    { weight: 70, hours: 2.4, diet: 'none', label: '70kg, 2.4h (just under meal boundary)' },
    { weight: 70, hours: 2.6, diet: 'none', label: '70kg, 2.6h (just over meal boundary)' },
    // Athletes with common diet combos at different windows
    { weight: 65, hours: 1.5, diet: 'peanut-free', label: '65kg, 1.5h, peanut-free' },
    { weight: 80, hours: 0.75, diet: 'dairy-free', label: '80kg, 0.75h, dairy-free' },
    { weight: 50, hours: 3.5, diet: 'dairy-free', label: '50kg, 3.5h, dairy-free' },
    { weight: 95, hours: 1.5, diet: 'all-free' as Diet, label: '95kg, 1.5h, all restricted' },
  ];

  return edgeCases.map((ec) => {
    const targets = calculateMacroTargets(ec.weight, ec.hours);
    return {
      id: `edge_${ec.weight}kg_${ec.hours}h_${ec.diet}`,
      label: ec.label,
      weight_kg: ec.weight,
      hours_before: ec.hours,
      diet: ec.diet,
      targets,
    };
  });
}

/**
 * Generate all test scenarios.
 * Returns ~93 from combinations + ~13 edge cases = ~106 total.
 * Some edge cases may duplicate combos (that's fine, they're labeled differently).
 */
export function generateScenarios(quick = false): Scenario[] {
  if (quick) {
    // Quick mode: 2 weights x 3 hours x 2 diets = 12 + 8 edge cases = 20
    const quickWeights = [65, 80];
    const quickHours = [0.5, 1.5, 3.0];
    const quickDiets: Diet[] = ['none', 'gluten-free'];
    const scenarios: Scenario[] = [];

    for (const weight of quickWeights) {
      for (const hours of quickHours) {
        for (const diet of quickDiets) {
          const targets = calculateMacroTargets(weight, hours);
          scenarios.push({
            id: `${weight}kg_${hours}h_${diet}`,
            label: `${weight}kg, ${hours}h before, ${dietLabel(diet)}`,
            weight_kg: weight,
            hours_before: hours,
            diet,
            targets,
          });
        }
      }
    }

    return [...scenarios, ...generateEdgeCases().slice(0, 8)];
  }

  return [...generateCombinations(), ...generateEdgeCases()];
}
