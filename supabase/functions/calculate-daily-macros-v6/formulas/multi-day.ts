/**
 * Multi-day context adjustments: recovery debt, pre-load, weekly load, phase modifiers
 */

import type { TrainingPhase } from '../types.ts';

/**
 * Calculate recovery debt from yesterday's hard session
 * TSS >= 150 triggers recovery. Linear decay from 18h to 36h.
 * Max: +1.25 g/kg carb, +0.1 g/kg protein
 */
export function recoveryDebt(
  yesterday_tss: number | null | undefined,
  hours_since: number | null | undefined,
  weight_kg: number,
): {
  carb_add: number;
  prot_add: number;
} {
  if (
    yesterday_tss === null ||
    yesterday_tss === undefined ||
    hours_since === null ||
    hours_since === undefined
  ) {
    return { carb_add: 0, prot_add: 0 };
  }

  // Only trigger if TSS >= 150
  if (yesterday_tss < 150) {
    return { carb_add: 0, prot_add: 0 };
  }

  // Decay factor: 1.0 at 18h or less, linearly to 0.0 at 36h
  let decay_factor: number;
  if (hours_since <= 18) {
    decay_factor = 1.0;
  } else if (hours_since >= 36) {
    decay_factor = 0.0;
  } else {
    // Linear decay from 18h to 36h
    decay_factor = 1.0 - (hours_since - 18) / (36 - 18);
  }

  const carb_add = 1.25 * weight_kg * decay_factor;
  const prot_add = 0.1 * weight_kg * decay_factor;

  return { carb_add, prot_add };
}

/**
 * Pre-load override for tomorrow's race or high TSS
 * Race or very high TSS → 9.0 g/kg carb
 * Moderate high TSS → current + 1.5 g/kg
 */
export function preLoadOverride(
  tomorrow_tss: number | null | undefined,
  tomorrow_duration_hr: number | null | undefined,
  tomorrow_is_race: boolean | undefined,
  current_carb: number,
  weight_kg: number,
): number {
  // Default to non-race if not specified
  const is_race = tomorrow_is_race ?? false;

  // Race day → 9.0 g/kg
  if (is_race) {
    return Math.max(current_carb, 9.0 * weight_kg);
  }

  // Very high TSS (>200) → 9.0 g/kg
  if (tomorrow_tss !== null && tomorrow_tss !== undefined && tomorrow_tss > 200) {
    return Math.max(current_carb, 9.0 * weight_kg);
  }

  // Moderately high: TSS > 120 OR duration > 1.5hr
  const moderate_trigger =
    (tomorrow_tss !== null && tomorrow_tss !== undefined && tomorrow_tss > 120) ||
    (tomorrow_duration_hr !== null &&
      tomorrow_duration_hr !== undefined &&
      tomorrow_duration_hr > 1.5);

  if (moderate_trigger) {
    return current_carb + 1.5 * weight_kg;
  }

  // No pre-load
  return current_carb;
}

/**
 * Weekly load adjustment based on this week's volume vs typical
 */
export function weeklyLoadAdjust(
  ratio: number | null | undefined,
  weight_kg: number,
): {
  carb_add: number;
  prot_add: number;
} {
  if (ratio === null || ratio === undefined) {
    return { carb_add: 0, prot_add: 0 };
  }

  // 5 buckets
  if (ratio < 0.7) {
    return { carb_add: -1.0 * weight_kg, prot_add: 0 };
  } else if (ratio < 0.9) {
    return { carb_add: -0.5 * weight_kg, prot_add: 0 };
  } else if (ratio <= 1.1) {
    return { carb_add: 0, prot_add: 0 };
  } else if (ratio <= 1.3) {
    return { carb_add: 0.5 * weight_kg, prot_add: 0.1 * weight_kg };
  } else {
    // ratio > 1.3
    return { carb_add: 1.0 * weight_kg, prot_add: 0.2 * weight_kg };
  }
}

/**
 * Training phase modifiers (F10, multiplicative on carb and protein).
 *
 * fat_mod is returned as documentation of intent and is NEVER applied
 * anywhere in the pipeline (Q-004, ruled 2026-08-13): fat is a pure
 * residual, and every published number was produced without it. Do not
 * apply it without a new ruling.
 */
export function phaseModifier(
  phase: TrainingPhase | undefined,
): {
  carb_mod: number;
  prot_mod: number;
  fat_mod: number;
} {
  const modifiers: Record<
    TrainingPhase,
    { carb_mod: number; prot_mod: number; fat_mod: number }
  > = {
    base: { carb_mod: 1.0, prot_mod: 1.0, fat_mod: 1.0 },
    build: { carb_mod: 1.08, prot_mod: 1.05, fat_mod: 1.0 },
    peak: { carb_mod: 1.12, prot_mod: 1.10, fat_mod: 0.95 },
    taper: { carb_mod: 0.88, prot_mod: 1.0, fat_mod: 1.05 },
    race_week: { carb_mod: 1.0, prot_mod: 1.0, fat_mod: 0.85 },
    off_season: { carb_mod: 0.80, prot_mod: 1.0, fat_mod: 1.10 },
  };

  return modifiers[phase ?? 'base'];
}
