/**
 * Baseline macronutrient calculations
 */

import type { Sex } from '../types.ts';

/**
 * Calculate baseline macros before sessions are added
 */
export function baselineMacros(
  weight_kg: number,
  lbm_kg: number | null,
  age: number,
): {
  carb_g: number;
  prot_g: number;
  fat_g: number;
} {
  // Carb baseline: 4.0 g/kg (modified by carb cycling in main pipeline)
  const carb_g = 4.0 * weight_kg;

  // Protein baseline
  let prot_g: number;
  if (lbm_kg !== null) {
    prot_g = 1.8 * lbm_kg;
  } else {
    prot_g = 1.4 * weight_kg;
  }

  // Masters adjustment: age >= 45 → ×1.15
  if (age >= 45) {
    prot_g *= 1.15;
  }

  // Fat baseline (will be overridden by TDEE calculation)
  const fat_g = 1.2 * weight_kg;

  return { carb_g, prot_g, fat_g };
}

/**
 * Calculate protein bump from sessions
 * Returns the maximum bump, not a sum (override pattern)
 */
export function calculateProteinBump(
  sessions: Array<{ sport: string; duration_hr: number }>,
  weight_kg: number,
): number {
  let max_bump = 0;

  for (const session of sessions) {
    if (session.sport === 'strength') {
      max_bump = Math.max(max_bump, 0.3 * weight_kg);
    } else if (session.duration_hr > 1.0) {
      max_bump = Math.max(max_bump, 0.2 * weight_kg);
    }
  }

  return max_bump;
}

/**
 * Clamp macros to safe ranges
 */
export function clampMacros(
  carb_g: number,
  prot_g: number,
  weight_kg: number,
): {
  carb_g: number;
  prot_g: number;
} {
  const carb_clamped = Math.max(
    3.0 * weight_kg,
    Math.min(carb_g, 12.0 * weight_kg),
  );

  const prot_clamped = Math.max(
    1.2 * weight_kg,
    Math.min(prot_g, 2.5 * weight_kg),
  );

  return { carb_g: carb_clamped, prot_g: prot_clamped };
}
