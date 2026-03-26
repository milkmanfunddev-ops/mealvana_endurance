/**
 * Dynamic NEAT and iterative TEF calculations (Iteration 3)
 */

import type { Lifestyle, SessionInput } from '../types.ts';

export type VolumeTier =
  | 'recreational'
  | 'moderate'
  | 'serious'
  | 'high_volume'
  | 'professional';

export type DayType = 'double' | 'training' | 'rest_after_hard' | 'rest';

/**
 * Infer volume tier from typical weekly training hours
 */
export function inferVolumeTier(
  typical_weekly_hours: number | null | undefined,
): { tier: VolumeTier; base_neat: number } {
  // Default to moderate if not provided
  if (
    typical_weekly_hours === null ||
    typical_weekly_hours === undefined
  ) {
    return { tier: 'moderate', base_neat: 0.25 };
  }

  if (typical_weekly_hours < 5) {
    return { tier: 'recreational', base_neat: 0.30 };
  } else if (typical_weekly_hours < 8) {
    return { tier: 'moderate', base_neat: 0.25 };
  } else if (typical_weekly_hours < 12) {
    return { tier: 'serious', base_neat: 0.20 };
  } else if (typical_weekly_hours < 18) {
    return { tier: 'high_volume', base_neat: 0.17 };
  } else {
    return { tier: 'professional', base_neat: 0.13 };
  }
}

/**
 * Get day modifier based on today's sessions and yesterday's TSS
 * Evaluation order: DOUBLE → TRAINING → REST_AFTER_HARD → REST
 */
export function getDayModifier(
  sessions: SessionInput[],
  yesterday_tss: number | null | undefined,
): { day_type: DayType; modifier: number } {
  // 2+ sessions
  if (sessions.length >= 2) {
    return { day_type: 'double', modifier: 1.15 };
  }

  // 1 session with duration >= 0.75 hr
  if (sessions.length === 1 && sessions[0].duration_hr >= 0.75) {
    return { day_type: 'training', modifier: 1.10 };
  }

  // Rest day after hard session (TSS >= 150)
  if (
    sessions.length === 0 &&
    yesterday_tss !== null &&
    yesterday_tss !== undefined &&
    yesterday_tss >= 150
  ) {
    return { day_type: 'rest_after_hard', modifier: 0.90 };
  }

  // Default: rest
  return { day_type: 'rest', modifier: 1.00 };
}

/**
 * Calculate NEAT from RMR and modifiers
 */
export function calculateNEAT(
  rmr: number,
  base_neat: number,
  day_modifier: number,
  lifestyle: Lifestyle | undefined,
): number {
  const LIFESTYLE_MOD: Record<Lifestyle, number> = {
    desk: 0.90,
    mixed: 1.00,
    active: 1.15,
    very_active: 1.25,
  };

  const lifestyle_mod = lifestyle ? LIFESTYLE_MOD[lifestyle] : 1.00;

  const neat_factor = base_neat * day_modifier * lifestyle_mod;
  return rmr * neat_factor;
}

/**
 * Calculate TDEE with iterative TEF convergence
 * Solves circular dependency: TDEE → fat → intake → TEF → TDEE
 */
export function calculateTDEE(
  rmr: number,
  neat: number,
  session_kcal: number,
  carb_g: number,
  prot_g: number,
  weight_kg: number,
): {
  tdee: number;
  fat_g: number;
  tef: number;
} {
  const fat_floor = 0.8 * weight_kg;
  let tef = 0;
  const max_passes = 5;

  for (let pass = 1; pass <= max_passes; pass++) {
    const prev_tef = tef;

    // Calculate TDEE with current TEF
    const tdee = rmr + neat + tef + session_kcal;

    // Calculate fat from TDEE
    const fat_from_tdee = (tdee - carb_g * 4 - prot_g * 4) / 9;
    const fat = Math.max(fat_from_tdee, fat_floor);

    // Calculate intake and new TEF
    const intake = carb_g * 4 + prot_g * 4 + fat * 9;
    const new_tef = intake * 0.10;

    // Check convergence
    const delta = Math.abs(new_tef - prev_tef);
    tef = new_tef;

    if (delta < 10) {
      // Converged - calculate final values
      const final_tdee = rmr + neat + tef + session_kcal;
      const final_fat = Math.max(
        (final_tdee - carb_g * 4 - prot_g * 4) / 9,
        fat_floor,
      );

      return {
        tdee: Math.round(final_tdee),
        fat_g: Math.round(final_fat),
        tef: Math.round(tef),
      };
    }
  }

  // Should converge before max_passes, but return final result anyway
  const final_tdee = rmr + neat + tef + session_kcal;
  const final_fat = Math.max(
    (final_tdee - carb_g * 4 - prot_g * 4) / 9,
    fat_floor,
  );

  return {
    tdee: Math.round(final_tdee),
    fat_g: Math.round(final_fat),
    tef: Math.round(tef),
  };
}
