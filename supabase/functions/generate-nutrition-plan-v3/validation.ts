/**
 * Validation functions for nutrition plan V3 phase results.
 */

import {
  calculateTotals,
  type FoodResult,
  MACRO_CONSTRAINT_RANGES,
  type MacroTargets,
  type Phase,
} from "../_shared/nutrition/index.ts";

export interface PhaseValidationResult {
  ok: boolean;
  issues: string[];
}

export function resolveMacroBounds(
  target: number,
  low: number | undefined,
  high: number | undefined,
  phaseRange: { min: number; max: number } | undefined,
): { min: number; max: number } {
  if (target <= 0) {
    return { min: 0, max: 0 };
  }
  if (low != null && high != null) {
    return { min: low, max: high };
  }
  if (phaseRange) {
    return {
      min: target * phaseRange.min,
      max: target * phaseRange.max,
    };
  }
  return { min: target * 0.9, max: target * 1.1 };
}

export function validatePhaseResultAgainstTargets(
  foods: FoodResult[],
  targets: MacroTargets,
  phase: Phase,
): PhaseValidationResult {
  const totals = calculateTotals(foods);
  const issues: string[] = [];
  const ranges = {
    carbs: MACRO_CONSTRAINT_RANGES.carbs[phase],
    protein: MACRO_CONSTRAINT_RANGES.protein[phase],
    sodium: MACRO_CONSTRAINT_RANGES.sodium[phase],
    water: MACRO_CONSTRAINT_RANGES.water[phase],
  };

  const carbBounds = resolveMacroBounds(
    targets.carbs_g,
    targets.carbs_low_g,
    targets.carbs_high_g,
    ranges.carbs,
  );
  if (totals.carbs_g < carbBounds.min || totals.carbs_g > carbBounds.max) {
    issues.push(
      `carbs=${totals.carbs_g.toFixed(1)} not in [${
        carbBounds.min.toFixed(1)
      }, ${carbBounds.max.toFixed(1)}]`,
    );
  }

  if (
    targets.sodium_mg > 0 || targets.sodium_low_mg != null ||
    targets.sodium_high_mg != null
  ) {
    const sodiumBounds = resolveMacroBounds(
      targets.sodium_mg,
      targets.sodium_low_mg,
      targets.sodium_high_mg,
      ranges.sodium,
    );
    if (
      totals.sodium_mg < sodiumBounds.min || totals.sodium_mg > sodiumBounds.max
    ) {
      issues.push(
        `sodium=${totals.sodium_mg.toFixed(0)} not in [${
          sodiumBounds.min.toFixed(0)
        }, ${sodiumBounds.max.toFixed(0)}]`,
      );
    }
  }

  if (
    targets.water_ml > 0 || targets.water_low_ml != null ||
    targets.water_high_ml != null
  ) {
    const waterBounds = resolveMacroBounds(
      targets.water_ml,
      targets.water_low_ml,
      targets.water_high_ml,
      ranges.water,
    );
    if (
      totals.water_ml < waterBounds.min || totals.water_ml > waterBounds.max
    ) {
      issues.push(
        `water=${totals.water_ml.toFixed(0)} not in [${
          waterBounds.min.toFixed(0)
        }, ${waterBounds.max.toFixed(0)}]`,
      );
    }
  }

  if (
    (phase === "before" || phase === "after") && (targets.protein_g ?? 0) > 0
  ) {
    const proteinBounds = resolveMacroBounds(
      targets.protein_g ?? 0,
      targets.protein_low_g,
      targets.protein_high_g,
      ranges.protein,
    );
    if (
      totals.protein_g < proteinBounds.min ||
      totals.protein_g > proteinBounds.max
    ) {
      issues.push(
        `protein=${totals.protein_g.toFixed(1)} not in [${
          proteinBounds.min.toFixed(1)
        }, ${proteinBounds.max.toFixed(1)}]`,
      );
    }
  }

  return { ok: issues.length === 0, issues };
}

export function flattenBeforeFoods(
  beforeResult: Record<string, { foods?: FoodResult[] }>,
): FoodResult[] {
  const foods: FoodResult[] = [];
  for (const key of ["meal", "snack", "top_up"]) {
    const sub = beforeResult[key];
    if (sub?.foods?.length) {
      foods.push(...sub.foods);
    }
  }
  return foods;
}
