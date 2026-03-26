/**
 * Safety checks and overrides (Iteration 4)
 */

import type { Sex, SessionInput, TrainingPhase } from '../types.ts';

export type EAStatus = 'OK' | 'SOFT_WARNING' | 'HARD_WARNING' | 'BLOCK';

/**
 * Derive FFM (Fat-Free Mass) from body fat % or estimate
 */
export function deriveFFM(
  weight_kg: number,
  sex: Sex,
  body_fat_pct: number | null | undefined,
): number {
  if (body_fat_pct !== null && body_fat_pct !== undefined) {
    return weight_kg * (1 - body_fat_pct / 100);
  }

  // Estimate based on sex
  return sex === 'male' ? weight_kg * 0.85 : weight_kg * 0.78;
}

/**
 * Check Energy Availability
 * EA = (intake - session_kcal) / ffm_kg
 */
export function checkEnergyAvailability(
  intake_kcal: number,
  session_kcal: number,
  ffm_kg: number,
): {
  ea: number;
  status: EAStatus;
} {
  const ea = (intake_kcal - session_kcal) / ffm_kg;

  let status: EAStatus;
  if (ea >= 45) {
    status = 'OK';
  } else if (ea >= 30) {
    status = 'SOFT_WARNING';
  } else if (ea >= 20) {
    status = 'HARD_WARNING';
  } else {
    status = 'BLOCK';
  }

  return { ea, status };
}

/**
 * EA override: force intake to EA = 30 when EA is 20-30
 * Split deficit 60% carb / 40% fat
 */
export function eaOverride(
  carb: number,
  prot: number,
  fat: number,
  session_kcal: number,
  ffm_kg: number,
  weight_kg: number,
): {
  carb: number;
  prot: number;
  fat: number;
  adjusted: boolean;
} | { block: true } {
  const intake = carb * 4 + prot * 4 + fat * 9;
  const ea = (intake - session_kcal) / ffm_kg;

  // EA >= 30: no adjustment needed
  if (ea >= 30) {
    return { carb, prot, fat, adjusted: false };
  }

  // EA < 20: block plan generation
  if (ea < 20) {
    return { block: true };
  }

  // EA 20-30: force to EA = 30
  const min_intake = 30 * ffm_kg + session_kcal;
  const deficit = min_intake - intake;

  // Split deficit 60% carb / 40% fat
  const new_carb = carb + (deficit * 0.6) / 4;
  const new_fat = fat + (deficit * 0.4) / 9;

  // Respect carb ceiling
  const carb_ceiling = 12.0 * weight_kg;
  if (new_carb > carb_ceiling) {
    // Can't add more carb, add all deficit to fat
    const final_carb = carb_ceiling;
    const remaining_deficit = min_intake - (final_carb * 4 + prot * 4 + fat * 9);
    const final_fat = fat + remaining_deficit / 9;

    return {
      carb: Math.round(final_carb),
      prot: Math.round(prot),
      fat: Math.round(final_fat),
      adjusted: true,
    };
  }

  return {
    carb: Math.round(new_carb),
    prot: Math.round(prot),
    fat: Math.round(new_fat),
    adjusted: true,
  };
}

/**
 * Multi-session carb compounding
 * Each subsequent endurance session gets 1.1^n multiplier
 * Strength sessions not compounded
 */
export function multiSessionCarbCompound(
  sessions: SessionInput[],
  weight_kg: number,
  carbDemandFn: (if_: number, duration: number, weight: number) => number,
  zoneToIFFn: (conv: number, tempo: number, allout: number) => number,
): {
  session_carb: number;
  prot_bump: number;
} {
  let total_carb = 0;
  let endurance_index = 0;
  let max_prot_bump = 0;

  for (const session of sessions) {
    const intensity_factor = zoneToIFFn(
      session.pct_conversational,
      session.pct_tempo,
      session.pct_allout,
    );

    const base_carb = carbDemandFn(
      intensity_factor,
      session.duration_hr,
      weight_kg,
    );

    if (
      session.sport === 'running' ||
      session.sport === 'cycling' ||
      session.sport === 'swimming'
    ) {
      // Endurance session: apply compounding
      const compound_factor = Math.pow(1.1, endurance_index);
      total_carb += base_carb * compound_factor;
      endurance_index += 1;
    } else {
      // Strength: no compounding
      total_carb += base_carb;
    }

    // Protein bump: max override
    if (session.sport === 'strength') {
      max_prot_bump = Math.max(max_prot_bump, 0.3 * weight_kg);
    } else if (session.duration_hr > 1.0) {
      max_prot_bump = Math.max(max_prot_bump, 0.2 * weight_kg);
    }
  }

  // Respect carb ceiling
  const carb_ceiling = 12.0 * weight_kg;
  total_carb = Math.min(total_carb, carb_ceiling);

  return {
    session_carb: Math.round(total_carb),
    prot_bump: Math.round(max_prot_bump),
  };
}

/**
 * Carb cycling adjustment
 * On qualifying easy days, reduce carb baseline to 3.0 g/kg
 */
export function carbCycleAdjust(
  session_if: number,
  session_duration_hr: number,
  opt_in: boolean | undefined,
  phase: TrainingPhase | undefined,
  baseline_carb: number,
  weight_kg: number,
): number {
  // Not opted in
  if (!opt_in) {
    return baseline_carb;
  }

  // Disabled in PEAK or RACE_WEEK
  if (phase === 'peak' || phase === 'race_week') {
    return baseline_carb;
  }

  // IF too high
  if (session_if > 0.80) {
    return baseline_carb;
  }

  // Duration too long (>1.25hr = 75 minutes)
  if (session_duration_hr > 1.25) {
    return baseline_carb;
  }

  // All conditions met: train low
  return 3.0 * weight_kg;
}
