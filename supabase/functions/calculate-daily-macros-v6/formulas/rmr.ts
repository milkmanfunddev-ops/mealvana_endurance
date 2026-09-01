/**
 * RMR (Resting Metabolic Rate) calculation
 *
 * Uses Cunningham equation when body fat % is known (more accurate for athletes),
 * otherwise falls back to Mifflin-St Jeor equation.
 */

import type { Sex } from '../types.ts';

/**
 * Calculate RMR using Cunningham equation (LBM-based)
 * Formula: RMR = 500 + 22 × LBM_kg
 */
function cunninghamRMR(lbm_kg: number): number {
  return 500 + 22 * lbm_kg;
}

/**
 * Calculate RMR using Mifflin-St Jeor equation
 * Formula: RMR = 10 × weight_kg + 6.25 × height_cm - 5 × age + (5 if MALE, -161 if FEMALE)
 */
function mifflinStJeorRMR(
  weight_kg: number,
  height_cm: number,
  age: number,
  sex: Sex,
): number {
  const sexOffset = sex === 'male' ? 5 : -161;
  return 10 * weight_kg + 6.25 * height_cm - 5 * age + sexOffset;
}

/**
 * Calculate RMR with automatic method selection
 * Prioritizes Cunningham when body fat % is available
 */
export function calculateRMR(
  weight_kg: number,
  height_cm: number,
  age: number,
  sex: Sex,
  body_fat_pct?: number | null,
): number {
  if (body_fat_pct !== null && body_fat_pct !== undefined) {
    const lbm_kg = weight_kg * (1 - body_fat_pct / 100);
    return cunninghamRMR(lbm_kg);
  }

  return mifflinStJeorRMR(weight_kg, height_cm, age, sex);
}
