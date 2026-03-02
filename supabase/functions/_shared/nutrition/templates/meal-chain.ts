/**
 * Meal Chain Selection
 *
 * Selects templates for each sub-phase using a priority chain:
 * 1. full_meal first (most constrained - 16 options)
 * 2. snack second
 * 3. top_up last (least constrained)
 *
 * Conflict avoidance prevents selecting templates that overlap:
 * - Layer 1: base_category (e.g., two "Bagel" templates)
 * - Layer 2: food_name overlap (except staples: banana, honey, maple_syrup)
 */

import { type Template, type SubPhaseType, type SubPhaseTargets } from './types.ts';

// ============================================================================
// Constants
// ============================================================================

/**
 * Staple foods that are allowed to repeat across sub-phases.
 * These are so common in pre-workout nutrition that requiring uniqueness
 * would eliminate too many valid template combinations.
 */
const STAPLE_FOODS = new Set(['banana', 'honey', 'maple_syrup']);

/**
 * Maps sub-phase types to the meal_type values in the templates table.
 */
const SUB_PHASE_TO_MEAL_TYPE: Record<SubPhaseType, string> = {
  meal: 'full_meal',
  snack: 'snack',
  top_up: 'top_up',
};

/**
 * Selection order: most constrained first.
 * full_meal typically has fewer options than snack/top_up.
 */
const SELECTION_ORDER: SubPhaseType[] = ['meal', 'snack', 'top_up'];

// ============================================================================
// Conflict Detection
// ============================================================================

/**
 * Check if two templates conflict.
 *
 * Layer 1: Same base_category (e.g., both are "Toast / Bread")
 * Layer 2: Overlapping food_names (excluding staples)
 */
function hasConflict(
  candidate: Template,
  alreadySelected: Template[],
): boolean {
  for (const selected of alreadySelected) {
    // Layer 1: base_category conflict
    if (candidate.base_category === selected.base_category) {
      return true;
    }

    // Layer 2: food name overlap (excluding staples)
    const candidateFoods = new Set(
      candidate.food_names
        .map((f) => f.toLowerCase())
        .filter((f) => !STAPLE_FOODS.has(f))
    );

    for (const foodName of selected.food_names) {
      if (candidateFoods.has(foodName.toLowerCase()) && !STAPLE_FOODS.has(foodName.toLowerCase())) {
        return true;
      }
    }
  }

  return false;
}

// ============================================================================
// Meal Chain Selection
// ============================================================================

/**
 * Calculate how far from 1.0x a template would need to scale to meet a carb target.
 * Lower values = better fit (template naturally matches the target).
 */
function scalingDistance(template: Template, carbTarget: number): number {
  if (carbTarget <= 0 || template.total_carbs_g <= 0) return 0;
  const neededMultiplier = carbTarget / template.total_carbs_g;
  return Math.abs(neededMultiplier - 1.0);
}

/**
 * Select templates for each active sub-phase using the meal chain algorithm.
 *
 * Templates are ranked by "natural fit" — how close their base carbs are to
 * the sub-phase carb target. A template that needs 1.2x scaling is preferred
 * over one that needs 3.5x scaling (which produces absurd quantities like
 * "5 bananas"). Sodium is used as a secondary tiebreaker.
 *
 * @param availableTemplates - All templates filtered by diet/allergen
 * @param activeSubPhases - Which sub-phases need templates (e.g., ['meal', 'snack', 'top_up'])
 * @param subPhaseTargets - Carb/macro targets per sub-phase (used for fit scoring)
 * @returns Map of sub-phase type to selected template (null if no valid template found)
 */
export function selectTemplateChain(
  availableTemplates: Template[],
  activeSubPhases: SubPhaseType[],
  subPhaseTargets?: Map<SubPhaseType, SubPhaseTargets>,
): Map<SubPhaseType, Template | null> {
  const result = new Map<SubPhaseType, Template | null>();
  const selectedTemplates: Template[] = [];

  // Build lookup: meal_type -> templates
  const templatesByMealType = new Map<string, Template[]>();
  for (const template of availableTemplates) {
    const existing = templatesByMealType.get(template.meal_type) ?? [];
    existing.push(template);
    templatesByMealType.set(template.meal_type, existing);
  }

  // Select in priority order (most constrained first)
  for (const subPhase of SELECTION_ORDER) {
    if (!activeSubPhases.includes(subPhase)) continue;

    const mealType = SUB_PHASE_TO_MEAL_TYPE[subPhase];
    const candidates = templatesByMealType.get(mealType) ?? [];
    const carbTarget = subPhaseTargets?.get(subPhase)?.carbs_g ?? 0;

    console.log(`[MEAL-CHAIN] Selecting for ${subPhase} (meal_type=${mealType}, carbTarget=${carbTarget}g): ${candidates.length} candidates`);

    // Collect all non-conflicting candidates
    const nonConflicting: Template[] = [];
    for (const candidate of candidates) {
      if (!hasConflict(candidate, selectedTemplates)) {
        nonConflicting.push(candidate);
      }
    }

    let selected: Template | null = null;

    if (nonConflicting.length > 0) {
      // Primary: best natural fit (closest to 1.0x scaling needed)
      // Secondary: lowest sodium (tiebreaker when fit is similar)
      nonConflicting.sort((a, b) => {
        const aFit = scalingDistance(a, carbTarget);
        const bFit = scalingDistance(b, carbTarget);

        // If fit differs by more than 0.3x multiplier, prefer the better fit
        if (Math.abs(aFit - bFit) > 0.3) {
          return aFit - bFit;
        }

        // Similar fit: use sodium as tiebreaker
        return a.total_sodium_mg - b.total_sodium_mg;
      });

      selected = nonConflicting[0];
      const neededMult = carbTarget > 0 && selected.total_carbs_g > 0
        ? (carbTarget / selected.total_carbs_g).toFixed(2)
        : '1.00';
      console.log(
        `[MEAL-CHAIN] Selected: ${selected.name} (${selected.base_category}, ` +
        `baseCarbs=${selected.total_carbs_g}g, neededScale=${neededMult}x, ` +
        `sodium=${selected.total_sodium_mg}mg) from ${nonConflicting.length} non-conflicting`
      );
      selectedTemplates.push(selected);
    } else {
      console.log(`[MEAL-CHAIN] No non-conflicting template found for ${subPhase}`);
      // If no conflict-free option exists, pick the best-fit candidate anyway
      if (candidates.length > 0) {
        const sorted = [...candidates].sort((a, b) => {
          const aFit = scalingDistance(a, carbTarget);
          const bFit = scalingDistance(b, carbTarget);
          if (Math.abs(aFit - bFit) > 0.3) return aFit - bFit;
          return a.total_sodium_mg - b.total_sodium_mg;
        });
        selected = sorted[0];
        console.log(`[MEAL-CHAIN] Fallback to best-fit: ${selected.name} (baseCarbs=${selected.total_carbs_g}g, sodium=${selected.total_sodium_mg}mg)`);
        selectedTemplates.push(selected);
      }
    }

    result.set(subPhase, selected);
  }

  return result;
}

/**
 * Select a single template for a given sub-phase, avoiding conflicts
 * with already-selected templates.
 *
 * Useful for food swaps where a single sub-phase template needs replacement.
 */
export function selectAlternativeTemplate(
  availableTemplates: Template[],
  subPhase: SubPhaseType,
  alreadySelected: Template[],
  excludeTemplateIds: string[] = [],
): Template | null {
  const mealType = SUB_PHASE_TO_MEAL_TYPE[subPhase];
  const excludeSet = new Set(excludeTemplateIds);

  const candidates = availableTemplates.filter(
    (t) => t.meal_type === mealType && !excludeSet.has(t.id)
  );

  for (const candidate of candidates) {
    if (!hasConflict(candidate, alreadySelected)) {
      return candidate;
    }
  }

  // Fallback: return first non-excluded candidate
  return candidates[0] ?? null;
}
