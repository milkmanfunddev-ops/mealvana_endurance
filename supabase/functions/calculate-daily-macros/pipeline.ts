/**
 * Core calculation pipeline for calculate-daily-macros
 * Extracted from index.ts so tests can import without triggering serve()
 *
 * Implements the ratified v5 pipeline (SSOT: docs/ssot/spec/daily-macros/,
 * bundle daily-macros-dashboard@v1). Structure:
 *
 *   calculateDailyMacrosCore  — steps 3..11 over already-resolved inputs,
 *                               UNROUNDED throughout (R1); this is what the
 *                               conformance vectors pin.
 *   calculateDailyMacros      — steps 0..2 (validate + resolve) around the
 *                               core, rounding once at return (step 12).
 */

import type {
  DailyMacroInput,
  DailyMacroOutput,
  MacroSources,
  Mode,
  SessionSources,
  Sex,
  Sport,
  TrainingPhase,
  Lifestyle,
  WeekMacroInput,
} from './types.ts';
import { carbDemand } from './formulas/session.ts';
import {
  baselineMacros,
  clampMacros,
} from './formulas/baseline.ts';
import {
  recoveryDebt,
  preLoadOverride,
  weeklyLoadAdjust,
  phaseModifier,
} from './formulas/multi-day.ts';
import {
  inferVolumeTier,
  getDayModifier,
  calculateNEAT,
  calculateTDEE,
} from './formulas/neat-tef.ts';
import {
  deriveFFM,
  checkEnergyAvailability,
  eaOverride,
  multiSessionCarbCompound,
  carbCycleAdjust,
  type EAStatus,
} from './formulas/safety.ts';
import {
  resolveAthleteProfile,
  resolveRMR,
  resolveNEAT,
  resolveSessionData,
  resolveTomorrow,
  resolveWeeklyRatio,
  ctlToVolumeTier,
  type ResolvedSessionData,
} from './formulas/resolve.ts';

export const ALGORITHM_VERSION = 'v6.0.0';

/**
 * Validate input data
 */
export function validateInput(input: DailyMacroInput): string | null {
  // Required fields
  if (!input.sex || !['male', 'female'].includes(input.sex)) {
    return 'sex must be "male" or "female"';
  }

  if (typeof input.age !== 'number' || input.age <= 0 || input.age > 120) {
    return 'age must be a positive number <= 120';
  }

  if (
    typeof input.weight_kg !== 'number' ||
    input.weight_kg <= 0 ||
    input.weight_kg > 300
  ) {
    return 'weight_kg must be a positive number <= 300';
  }

  if (
    typeof input.height_cm !== 'number' ||
    input.height_cm <= 0 ||
    input.height_cm > 300
  ) {
    return 'height_cm must be a positive number <= 300';
  }

  if (!Array.isArray(input.sessions)) {
    return 'sessions must be an array';
  }

  // Validate sessions
  for (let i = 0; i < input.sessions.length; i++) {
    const session = input.sessions[i];

    if (
      !session.sport ||
      !['running', 'cycling', 'swimming', 'strength'].includes(session.sport)
    ) {
      return `session ${i}: sport must be running/cycling/swimming/strength`;
    }

    if (
      typeof session.duration_hr !== 'number' ||
      session.duration_hr <= 0 ||
      session.duration_hr > 24
    ) {
      return `session ${i}: duration_hr must be positive and <= 24`;
    }

    if (
      typeof session.pct_conversational !== 'number' ||
      session.pct_conversational < 0 ||
      session.pct_conversational > 1
    ) {
      return `session ${i}: pct_conversational must be 0-1`;
    }

    if (
      typeof session.pct_tempo !== 'number' ||
      session.pct_tempo < 0 ||
      session.pct_tempo > 1
    ) {
      return `session ${i}: pct_tempo must be 0-1`;
    }

    if (
      typeof session.pct_allout !== 'number' ||
      session.pct_allout < 0 ||
      session.pct_allout > 1
    ) {
      return `session ${i}: pct_allout must be 0-1`;
    }

    // Zone percentages must sum to 1.0 (with tolerance) — step 0: reject,
    // never normalize (also enforced inside zoneDistributionToIF itself).
    const sum =
      session.pct_conversational + session.pct_tempo + session.pct_allout;
    if (Math.abs(sum - 1.0) > 0.001) {
      return `session ${i}: zone percentages must sum to 1.0 (got ${sum})`;
    }
  }

  return null;
}

/** Thrown by the core when the EA gate refuses to produce a plan. */
export class EnergyAvailabilityBlockError extends Error {
  readonly ea: number;
  constructor(ea: number) {
    super(
      `Energy Availability too low (${ea.toFixed(1)} kcal/kg FFM). Cannot generate plan. Please increase intake or reduce exercise volume.`,
    );
    this.ea = ea;
  }
}

/** A session after F22 resolution — the only session shape the core sees. */
export interface CoreSession {
  sport: Sport;
  intensity_factor: number;
  duration_hr: number;
  /** Resolved energy cost (Garmin measured, or F4 at the resolved IF/duration). */
  session_kcal: number;
  start_time?: string | null;
}

export interface CoreInput {
  weight_kg: number;
  lbm_kg: number | null;
  age: number;
  sex: Sex;
  body_fat_pct: number | null;
  lifestyle?: Lifestyle;
  carb_cycle_opt_in?: boolean;
  training_phase?: TrainingPhase;
  sessions: CoreSession[];
  yesterday_tss?: number | null;
  yesterday_hours_since?: number | null;
  tomorrow_tss?: number | null;
  tomorrow_duration_hr?: number | null;
  tomorrow_is_race?: boolean;
  weekly_ratio: number;
  rmr: number;
  /** base_neat for the resolved volume tier (weekly hours, or TP CTL). */
  base_neat: number;
  /** Measured NEAT (F23 Garmin path); null/undefined → model via F13/F14. */
  neat_measured_kcal?: number | null;
}

export interface CorePlan {
  carb_g: number;
  prot_g: number;
  fat_g: number;
  tdee: number;
  session_kcal: number;
  neat_kcal: number;
  tef_kcal: number;
  ea: number;
  ea_status: EAStatus;
  energy_basis: 'as_computed' | 'pre_override';
}

/**
 * Steps 3–11 of the v5 pipeline over resolved inputs. UNROUNDED (R1):
 * rounding happens once, in the returning wrapper (step 12). The one
 * exception is F18's own return, rounded by spec.
 *
 * Throws EnergyAvailabilityBlockError when the EA gate refuses a plan.
 */
export function calculateDailyMacrosCore(input: CoreInput): CorePlan {
  const {
    weight_kg,
    lbm_kg,
    age,
    sex,
    body_fat_pct,
    lifestyle,
    carb_cycle_opt_in,
    training_phase,
    sessions,
    yesterday_tss,
    yesterday_hours_since,
    tomorrow_tss,
    tomorrow_duration_hr,
    tomorrow_is_race,
    weekly_ratio,
    rmr,
    base_neat,
    neat_measured_kcal,
  } = input;

  // ====================================================================
  // STEP 3: Baseline macros (with carb cycling on qualifying single days)
  // ====================================================================

  const baseline = baselineMacros(weight_kg, lbm_kg, age);
  let carb = baseline.carb_g;
  let prot = baseline.prot_g;

  if (sessions.length === 1 && carb_cycle_opt_in) {
    const s = sessions[0];
    carb = carbCycleAdjust(
      s.intensity_factor,
      s.duration_hr,
      carb_cycle_opt_in,
      training_phase,
      carb,
      weight_kg,
    );
  }

  // ====================================================================
  // STEP 4: Today's sessions (F5/F19 + protein bump)
  // ====================================================================

  let total_session_kcal = 0;
  for (const s of sessions) {
    total_session_kcal += s.session_kcal;
  }

  let session_carb_add = 0;
  let prot_bump = 0;

  if (sessions.length === 1) {
    const s = sessions[0];
    session_carb_add = carbDemand(
      s.sport,
      s.intensity_factor,
      s.duration_hr,
      weight_kg,
    );
    prot_bump = s.sport === 'strength'
      ? 0.3 * weight_kg
      : s.duration_hr > 1.0
      ? 0.2 * weight_kg
      : 0;
  } else if (sessions.length >= 2) {
    const compound = multiSessionCarbCompound(sessions, weight_kg, carbDemand);
    session_carb_add = compound.session_carb;
    prot_bump = compound.prot_bump;
  }

  carb += session_carb_add;
  prot += prot_bump;

  // ====================================================================
  // STEP 5: Recovery debt (additive)
  // ====================================================================

  const debt = recoveryDebt(yesterday_tss, yesterday_hours_since, weight_kg);
  carb += debt.carb_add;
  prot += debt.prot_add;

  // ====================================================================
  // STEP 6: Pre-load override (upward only)
  // ====================================================================

  carb = preLoadOverride(
    tomorrow_tss,
    tomorrow_duration_hr,
    tomorrow_is_race,
    carb,
    weight_kg,
  );

  // ====================================================================
  // STEP 7: Weekly load (additive)
  // ====================================================================

  const weekly = weeklyLoadAdjust(weekly_ratio, weight_kg);
  carb += weekly.carb_add;
  prot += weekly.prot_add;

  // ====================================================================
  // STEP 8: Phase modifiers (multiplicative; fat_mod NOT applied — Q-004)
  // ====================================================================

  const phase_mod = phaseModifier(training_phase);
  carb *= phase_mod.carb_mod;
  prot *= phase_mod.prot_mod;

  // ====================================================================
  // STEP 9: Clamp (the last word on carb and protein)
  // ====================================================================

  const clamped = clampMacros(carb, prot, weight_kg);
  carb = clamped.carb_g;
  prot = clamped.prot_g;

  // ====================================================================
  // STEP 10: Energy accounting — NEAT (F13/F14 or measured) + iterative TEF
  // ====================================================================

  const day_info = getDayModifier(sessions, yesterday_tss);
  const neat = neat_measured_kcal != null
    ? neat_measured_kcal
    : calculateNEAT(rmr, base_neat, day_info.modifier, lifestyle);

  const tdee_result = calculateTDEE(
    rmr,
    neat,
    total_session_kcal,
    carb,
    prot,
    weight_kg,
  );

  let fat = tdee_result.fat_g;
  const tdee = tdee_result.tdee;
  const tef = tdee_result.tef;

  // ====================================================================
  // STEP 10b: Fat ceiling — 30 %E of TDEE, excess → carb (Q-014)
  // Redistribution conserves energy exactly: intake, TEF, TDEE and EA are
  // unchanged across this step (invariant I10).
  // ====================================================================

  const fat_cap = 0.30 * tdee / 9;
  if (fat > fat_cap) {
    const excess_kcal = (fat - fat_cap) * 9;
    const headroom = 12.0 * weight_kg - carb; // step-9 clamp's remaining room
    carb += Math.min(excess_kcal / 4, headroom);
    // Corner case: when the carb clamp saturates, fat keeps the remainder
    // rather than energy being dropped.
    fat = fat_cap + Math.max(0, excess_kcal - headroom * 4) / 9;
  }

  // ====================================================================
  // STEP 11: EA safety gate (last)
  // ====================================================================

  const ffm_kg = deriveFFM(weight_kg, sex, body_fat_pct);
  const intake = carb * 4 + prot * 4 + fat * 9;
  const ea_check = checkEnergyAvailability(intake, total_session_kcal, ffm_kg);

  let energy_basis: CorePlan['energy_basis'] = 'as_computed';

  if (ea_check.status === 'BLOCK') {
    throw new EnergyAvailabilityBlockError(ea_check.ea);
  }

  if (ea_check.status === 'HARD_WARNING') {
    const override = eaOverride(
      carb,
      prot,
      fat,
      total_session_kcal,
      ffm_kg,
      weight_kg,
    );

    if ('block' in override) {
      throw new EnergyAvailabilityBlockError(ea_check.ea);
    }

    if (override.adjusted) {
      carb = override.carb;
      prot = override.prot;
      fat = override.fat;
      // TDEE and TEF are deliberately NOT recomputed (Q-009): the override
      // enforces a floor, it does not re-estimate energy. The returned
      // energy figures describe the PRE-override macros; energy_basis says so.
      energy_basis = 'pre_override';
    }
  }

  return {
    carb_g: carb,
    prot_g: prot,
    fat_g: fat,
    tdee,
    session_kcal: total_session_kcal,
    neat_kcal: neat,
    tef_kcal: tef,
    // ea/ea_status are the gate's decision values (pre-override), consistent
    // with Q-009's pre-override energy figures.
    ea: ea_check.ea,
    ea_status: ea_check.status,
    energy_basis,
  };
}

/**
 * Main calculation pipeline: steps 0–2 (validate + resolve) around the core,
 * rounding once at return (step 12, R1).
 */
export function calculateDailyMacros(input: DailyMacroInput): DailyMacroOutput {
  const {
    sex,
    age,
    height_cm,
    lifestyle,
    typical_weekly_hours,
    carb_cycle_opt_in,
    training_phase,
    sessions,
    yesterday_tss,
    yesterday_hours_since,
    weekly_hours_ratio,
    mode,
  } = input;

  // Mode is the caller's declaration (I5: identical math either way; the
  // resolution ladders are what gate on it). The retired auto-promotion to
  // retrospective on Garmin presence violated the prospective-never-uses-
  // measured-data contract and is deliberately gone.
  const effectiveMode: Mode = mode ?? 'prospective';

  // ====================================================================
  // STEP 1: Resolve global inputs
  // ====================================================================

  // Garmin body composition updates the athlete profile FIRST, so every
  // weight-dependent value below uses the new figures. (Latest-wins vs the
  // user's manual entry timestamps — see resolveAthleteProfile.)
  const resolved = resolveAthleteProfile(
    input.garmin_body_comp ?? null,
    input.weight_kg,
    input.body_fat_pct ?? null,
    Math.floor(Date.now() / 1000),
    input.user_weight_updated_at_seconds ?? null,
    input.user_body_fat_updated_at_seconds ?? null,
  );
  const weight_kg = resolved.weight_kg;
  const body_fat_pct = resolved.body_fat_pct;

  const lbm_kg =
    body_fat_pct !== null && body_fat_pct !== undefined
      ? weight_kg * (1 - body_fat_pct / 100)
      : null;

  const resolvedRMR = resolveRMR(input.garmin_daily ?? null, {
    weight_kg,
    height_cm,
    age,
    sex,
    body_fat_pct,
  });

  const tp_data = input.tp_data ?? null;

  const resolvedTomorrow = resolveTomorrow(tp_data, {
    tomorrow_tss: input.tomorrow_tss,
    tomorrow_duration_hr: input.tomorrow_duration_hr,
    tomorrow_is_race: input.tomorrow_is_race,
  });

  const resolvedRatio = resolveWeeklyRatio(tp_data, weekly_hours_ratio);

  // Volume tier: TP CTL replaces weekly hours when present (F12 CTL variant).
  const volume = ctlToVolumeTier(tp_data?.CTL) ??
    inferVolumeTier(typical_weekly_hours);

  // ====================================================================
  // STEP 2: Resolve per-session inputs (F22)
  // ====================================================================

  const garmin_activities = input.garmin_activities ?? null;
  const tp_sessions = input.tp_sessions ?? null;
  const resolved_sessions: ResolvedSessionData[] = sessions.map((session, i) =>
    resolveSessionData(
      session,
      weight_kg,
      effectiveMode,
      garmin_activities?.[i] ?? null,
      tp_sessions?.[i] ?? null,
    ),
  );

  const core_sessions: CoreSession[] = resolved_sessions.map((r, i) => ({
    sport: sessions[i].sport,
    intensity_factor: r.intensity_factor,
    duration_hr: r.duration_hr,
    session_kcal: r.session_kcal,
    start_time: sessions[i].start_time ?? null,
  }));

  let total_session_kcal = 0;
  for (const r of resolved_sessions) total_session_kcal += r.session_kcal;

  // NEAT: measured on the retrospective Garmin path, modeled otherwise (F23).
  const resolvedNEAT = resolveNEAT(
    effectiveMode,
    input.garmin_daily ?? null,
    total_session_kcal,
    resolvedRMR.rmr,
    volume.base_neat,
    1.0, // day modifier applied inside the core on the formula path
    lifestyle,
  );
  const neat_measured_kcal =
    resolvedNEAT.source === 'GARMIN' ? resolvedNEAT.neat_kcal : null;

  // ====================================================================
  // STEPS 3–11: the core
  // ====================================================================

  const plan = calculateDailyMacrosCore({
    weight_kg,
    lbm_kg,
    age,
    sex,
    body_fat_pct: body_fat_pct ?? null,
    lifestyle,
    carb_cycle_opt_in,
    training_phase,
    sessions: core_sessions,
    yesterday_tss,
    yesterday_hours_since,
    tomorrow_tss: resolvedTomorrow.tomorrow_tss,
    tomorrow_duration_hr: resolvedTomorrow.tomorrow_duration_hr,
    tomorrow_is_race: resolvedTomorrow.tomorrow_is_race,
    weekly_ratio: resolvedRatio.ratio,
    rmr: resolvedRMR.rmr,
    base_neat: volume.base_neat,
    neat_measured_kcal,
  });

  // ====================================================================
  // STEP 12: Return — round here, and only here (R1)
  // ====================================================================

  const session_sources: SessionSources[] = resolved_sessions.map((r) => ({
    session_kcal: r.kcal_source,
    intensity_factor: r.if_source,
    tss: r.tss_source,
    duration: r.duration_source,
  }));

  const sources: MacroSources = {
    rmr: resolvedRMR.source,
    neat: resolvedNEAT.source,
    weight: resolved.weight_source,
    body_fat: resolved.body_fat_source,
    tomorrow: resolvedTomorrow.source,
    weekly_ratio: resolvedRatio.source,
    sessions: session_sources,
  };

  const carb_g = Math.round(plan.carb_g);
  const prot_g = Math.round(plan.prot_g);
  const fat_g = Math.round(plan.fat_g);
  const tdee = Math.round(plan.tdee);
  const session_kcal = Math.round(plan.session_kcal);

  // Delta is null on every path except retrospective recalculation with a
  // prior prospective plan — null, not absent, so a consumer can distinguish
  // "no recalculation happened" from "recalculation happened, nothing moved".
  const prior = input.prospective_plan;
  const delta =
    effectiveMode === 'retrospective' && prior
      ? {
          carb_g: carb_g - prior.carb_g,
          prot_g: prot_g - prior.prot_g,
          fat_g: fat_g - prior.fat_g,
          tdee: tdee - prior.tdee,
          session_kcal: session_kcal - prior.session_kcal,
        }
      : null;

  return {
    carb_g,
    prot_g,
    fat_g,
    tdee,
    rmr: Math.round(resolvedRMR.rmr),
    session_kcal,
    neat_kcal: Math.round(plan.neat_kcal),
    tef_kcal: Math.round(plan.tef_kcal),
    mode: effectiveMode,
    ea: parseFloat(plan.ea.toFixed(1)),
    ea_status: plan.ea_status,
    energy_basis: plan.energy_basis,
    algorithm_version: ALGORITHM_VERSION,
    weight_kg: parseFloat(weight_kg.toFixed(2)),
    body_fat_pct: body_fat_pct,
    sources,
    delta,
  };
}

/**
 * Calculate macros for an entire week in a single call.
 * Merges shared profile fields with each day's sessions/context.
 * Per-day Garmin context (garmin_body_comp, garmin_daily) flows through from
 * each WeekDayInput when present — populated server-side by attachGarminContext.
 */
export function calculateWeekMacros(input: WeekMacroInput): DailyMacroOutput[] {
  return input.days.map((day) => {
    const dayInput: DailyMacroInput = {
      sex: input.sex,
      age: input.age,
      weight_kg: input.weight_kg,
      height_cm: input.height_cm,
      body_fat_pct: input.body_fat_pct,
      lifestyle: input.lifestyle,
      typical_weekly_hours: input.typical_weekly_hours,
      carb_cycle_opt_in: input.carb_cycle_opt_in,
      training_phase: input.training_phase,
      mode: input.mode,
      // Shared user timestamps (used by resolveAthleteProfile)
      user_weight_updated_at_seconds: input.user_weight_updated_at_seconds,
      user_body_fat_updated_at_seconds: input.user_body_fat_updated_at_seconds,
      ...day,
    };
    return calculateDailyMacros(dayInput);
  });
}
