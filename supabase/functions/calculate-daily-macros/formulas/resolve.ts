/**
 * Iteration 5: Source-resolution layer between platform data and the v4 pipeline.
 *
 * The pipeline never checks "is Garmin connected?" — it receives resolved values
 * and produces the same output regardless of source. This makes the pipeline
 * testable without platform mocks.
 *
 * Notion spec: https://www.notion.so/Daily-Macro-Calculation-326e3fdb754c80199486c17ecf9947cd
 *  → daily_macro_calc_iteration5_spec
 */

import type {
  Lifestyle,
  Mode,
  SessionInput,
  Sex,
} from '../types.ts';
import {
  zoneDistributionToIF,
  sessionCost,
  carbDemand,
} from './session.ts';
import { calculateRMR } from './rmr.ts';
import { calculateNEAT, type VolumeTier } from './neat-tef.ts';

// ============================================================================
// Source enum & input shapes
// ============================================================================

export type ResolveSource =
  | 'GARMIN'
  | 'TP_ACTUAL'
  | 'TP_PLANNED'
  | 'TP'
  | 'TP_CALENDAR'
  | 'ZONE_DIST'
  | 'FORMULA'
  | 'MANUAL'
  | 'NONE';

/**
 * Garmin Activity Summary subset relevant to per-session resolution.
 * Mapped from `_shared/garmin/types.ts: GarminActivitySummary` by index.ts
 * before being passed into the pipeline.
 */
export interface GarminActivityForSession {
  activeKilocalories?: number | null;
  durationInSeconds?: number | null;
}

/**
 * Garmin Daily Summary subset relevant to global resolution.
 * Mapped from `_shared/garmin/types.ts: GarminDailySummary`.
 */
export interface GarminDailyForResolve {
  bmrKilocalories?: number | null;
  activeKilocalories?: number | null;
}

/**
 * Garmin Body Composition subset relevant to athlete profile resolution.
 * Mapped from `_shared/garmin/types.ts: GarminBodyComposition`.
 */
export interface GarminBodyCompForResolve {
  weightInGrams?: number | null;
  percentFat?: number | null;
  measurementTimeInSeconds?: number | null;
}

/**
 * TrainingPeaks/Final Surge per-session data. All fields optional —
 * any null/undefined causes that branch to fall through to the next source.
 */
export interface TPSessionData {
  actual_IF?: number | null;
  planned_IF?: number | null;
  actual_TSS?: number | null;
  planned_TSS?: number | null;
  planned_duration_hr?: number | null;
}

/**
 * TrainingPeaks/Final Surge global data (date-level, not per-session).
 */
export interface TPGlobalData {
  ATL?: number | null;
  CTL?: number | null;
  tomorrow_planned?: {
    tss?: number | null;
    duration_hr?: number | null;
    is_race?: boolean | null;
  } | null;
}

// ============================================================================
// Output shapes
// ============================================================================

export interface ResolvedSessionData {
  session_kcal: number;
  intensity_factor: number;
  TSS: number;
  duration_hr: number;
  session_carb: number;
  kcal_source: ResolveSource;
  if_source: ResolveSource;
  tss_source: ResolveSource;
  duration_source: ResolveSource;
}

export interface ResolvedNEAT {
  neat_kcal: number;
  source: ResolveSource;
}

export interface ResolvedRMR {
  rmr: number;
  source: ResolveSource;
}

export interface ResolvedTomorrow {
  tomorrow_tss: number | null;
  tomorrow_duration_hr: number | null;
  tomorrow_is_race: boolean;
  source: ResolveSource;
}

export interface ResolvedWeeklyRatio {
  ratio: number;
  source: ResolveSource;
}

export interface ResolvedAthleteProfile {
  weight_kg: number;
  body_fat_pct: number | null;
  weight_source: ResolveSource;
  body_fat_source: ResolveSource;
}

// ============================================================================
// Resolvers (Notion §22–§26)
// ============================================================================

/**
 * §22 — Resolve a single session's kcal, IF, TSS, duration with source priority:
 *   - kcal:     GARMIN (retrospective only) > FORMULA
 *   - IF:       TP_ACTUAL (retrospective) > TP_PLANNED > ZONE_DIST
 *   - TSS:      TP_ACTUAL (retrospective) > TP_PLANNED > derived (duration_hr × IF² × 100)
 *   - duration: GARMIN (retrospective) > TP_PLANNED > session input
 *
 * If kcal_source = FORMULA, recompute session_kcal with the resolved IF and duration.
 */
export function resolveSessionData(
  session: SessionInput,
  weight_kg: number,
  mode: Mode,
  garmin_activity?: GarminActivityForSession | null,
  tp_session?: TPSessionData | null,
): ResolvedSessionData {
  const isRetrospective = mode === 'retrospective';

  // ---- Duration ----
  let duration_hr = session.duration_hr;
  let duration_source: ResolveSource = 'FORMULA';
  if (
    isRetrospective &&
    garmin_activity?.durationInSeconds != null &&
    garmin_activity.durationInSeconds > 0
  ) {
    duration_hr = garmin_activity.durationInSeconds / 3600;
    duration_source = 'GARMIN';
  } else if (
    tp_session?.planned_duration_hr != null &&
    tp_session.planned_duration_hr > 0
  ) {
    duration_hr = tp_session.planned_duration_hr;
    duration_source = 'TP_PLANNED';
  }

  // ---- IF ----
  let intensity_factor: number;
  let if_source: ResolveSource;
  if (isRetrospective && tp_session?.actual_IF != null) {
    intensity_factor = tp_session.actual_IF;
    if_source = 'TP_ACTUAL';
  } else if (tp_session?.planned_IF != null) {
    intensity_factor = tp_session.planned_IF;
    if_source = 'TP_PLANNED';
  } else {
    intensity_factor = zoneDistributionToIF(
      session.pct_conversational,
      session.pct_tempo,
      session.pct_allout,
    );
    if_source = 'ZONE_DIST';
  }

  // ---- TSS ----
  let TSS: number;
  let tss_source: ResolveSource;
  if (isRetrospective && tp_session?.actual_TSS != null) {
    TSS = tp_session.actual_TSS;
    tss_source = 'TP_ACTUAL';
  } else if (tp_session?.planned_TSS != null) {
    TSS = tp_session.planned_TSS;
    tss_source = 'TP_PLANNED';
  } else {
    TSS = duration_hr * intensity_factor * intensity_factor * 100;
    tss_source = 'FORMULA';
  }

  // ---- Session kcal ----
  let session_kcal: number;
  let kcal_source: ResolveSource;
  if (
    isRetrospective &&
    garmin_activity?.activeKilocalories != null &&
    garmin_activity.activeKilocalories > 0
  ) {
    session_kcal = garmin_activity.activeKilocalories;
    kcal_source = 'GARMIN';
  } else {
    session_kcal = sessionCost(
      session.sport,
      duration_hr,
      intensity_factor,
      weight_kg,
    );
    kcal_source = 'FORMULA';
  }

  // Carb demand always uses resolved IF + duration (no platform source for this).
  const session_carb = carbDemand(intensity_factor, duration_hr, weight_kg);

  return {
    session_kcal,
    intensity_factor,
    TSS,
    duration_hr,
    session_carb,
    kcal_source,
    if_source,
    tss_source,
    duration_source,
  };
}

/**
 * §23 — Resolve NEAT.
 * Retrospective + Garmin daily ActiveKilocalories: NEAT = max(active − sessions, 0).
 * Otherwise fall back to existing v4 formula.
 *
 * Note: Garmin's `activeKilocalories` is total non-rest energy expenditure for the day,
 * which already includes session kcal. Subtracting session_kcal_total isolates NEAT.
 */
export function resolveNEAT(
  mode: Mode,
  garmin_daily: GarminDailyForResolve | null | undefined,
  session_kcal_total: number,
  rmr: number,
  base_neat: number,
  day_modifier: number,
  lifestyle: Lifestyle | undefined,
): ResolvedNEAT {
  const isRetrospective = mode === 'retrospective';
  if (
    isRetrospective &&
    garmin_daily?.activeKilocalories != null &&
    garmin_daily.activeKilocalories > 0
  ) {
    const neat = Math.max(
      garmin_daily.activeKilocalories - session_kcal_total,
      0,
    );
    return { neat_kcal: neat, source: 'GARMIN' };
  }

  return {
    neat_kcal: calculateNEAT(rmr, base_neat, day_modifier, lifestyle),
    source: 'FORMULA',
  };
}

/**
 * §24 — Resolve RMR.
 * Garmin daily.bmrKilocalories wins when present; else compute from athlete profile.
 */
export function resolveRMR(
  garmin_daily: GarminDailyForResolve | null | undefined,
  athlete: {
    weight_kg: number;
    height_cm: number;
    age: number;
    sex: Sex;
    body_fat_pct?: number | null;
  },
): ResolvedRMR {
  if (
    garmin_daily?.bmrKilocalories != null &&
    garmin_daily.bmrKilocalories > 0
  ) {
    return { rmr: garmin_daily.bmrKilocalories, source: 'GARMIN' };
  }

  return {
    rmr: calculateRMR(
      athlete.weight_kg,
      athlete.height_cm,
      athlete.age,
      athlete.sex,
      athlete.body_fat_pct,
    ),
    source: 'FORMULA',
  };
}

/**
 * §25 — Resolve tomorrow's planned session for pre-load logic.
 * TP_CALENDAR > MANUAL > NONE.
 */
export function resolveTomorrow(
  tp: TPGlobalData | null | undefined,
  manual: {
    tomorrow_tss?: number | null;
    tomorrow_duration_hr?: number | null;
    tomorrow_is_race?: boolean;
  },
): ResolvedTomorrow {
  const planned = tp?.tomorrow_planned;
  if (planned && (planned.tss != null || planned.duration_hr != null)) {
    return {
      tomorrow_tss: planned.tss ?? null,
      tomorrow_duration_hr: planned.duration_hr ?? null,
      tomorrow_is_race: planned.is_race === true,
      source: 'TP_CALENDAR',
    };
  }

  if (
    manual.tomorrow_tss != null ||
    manual.tomorrow_duration_hr != null ||
    manual.tomorrow_is_race === true
  ) {
    return {
      tomorrow_tss: manual.tomorrow_tss ?? null,
      tomorrow_duration_hr: manual.tomorrow_duration_hr ?? null,
      tomorrow_is_race: manual.tomorrow_is_race === true,
      source: 'MANUAL',
    };
  }

  return {
    tomorrow_tss: null,
    tomorrow_duration_hr: null,
    tomorrow_is_race: false,
    source: 'NONE',
  };
}

/**
 * §26 — Resolve weekly load ratio (yesterday's load vs typical).
 * TP if both ATL and CTL>0; else manual; else default 1.0.
 */
export function resolveWeeklyRatio(
  tp: TPGlobalData | null | undefined,
  manual_ratio: number | null | undefined,
): ResolvedWeeklyRatio {
  if (
    tp?.ATL != null &&
    tp.CTL != null &&
    tp.CTL > 0
  ) {
    return { ratio: tp.ATL / tp.CTL, source: 'TP' };
  }

  if (manual_ratio != null) {
    return { ratio: manual_ratio, source: 'MANUAL' };
  }

  return { ratio: 1.0, source: 'MANUAL' };
}

/**
 * Resolve athlete weight + body fat % using latest-wins precedence.
 *
 * Decision logic (2026-05-03 — Iter 5 Garmin):
 *   - Compare the Garmin measurement_time_seconds against the user's
 *     weight_pounds_updated_at / body_fat_pct_updated_at timestamp.
 *   - The newer source wins.
 *   - If neither has a timestamp, user wins (safe default).
 *   - If the user has no value (null/zero), Garmin fills as a fallback
 *     regardless of timestamps.
 *   - Body comp readings older than GARMIN_BODY_COMP_MAX_AGE_DAYS are
 *     rejected for the "latest-wins" path but can still fill null user values
 *     if within the window — actually no: stale Garmin is rejected entirely.
 *     A Garmin reading older than 30 days is never used, even as a fallback.
 */
export const GARMIN_BODY_COMP_MAX_AGE_DAYS = 30;

export function resolveAthleteProfile(
  garmin_body_comp: GarminBodyCompForResolve | null | undefined,
  user_weight_kg: number,
  user_body_fat_pct: number | null | undefined,
  now_seconds: number = Math.floor(Date.now() / 1000),
  /**
   * Unix-seconds timestamp of the user's last manual weight entry.
   * Derived from `users.weight_pounds_updated_at` (TIMESTAMPTZ → epoch).
   */
  user_weight_updated_at_seconds: number | null | undefined = undefined,
  /**
   * Unix-seconds timestamp of the user's last manual body fat entry.
   * Derived from `users.body_fat_pct_updated_at` (TIMESTAMPTZ → epoch).
   */
  user_body_fat_updated_at_seconds: number | null | undefined = undefined,
): ResolvedAthleteProfile {
  // Stale check — Garmin reading must be within 30 days to be eligible at all.
  let bcUsable: GarminBodyCompForResolve | null = null;
  if (garmin_body_comp?.measurementTimeInSeconds != null) {
    const ageDays =
      (now_seconds - garmin_body_comp.measurementTimeInSeconds) / 86400;
    if (ageDays <= GARMIN_BODY_COMP_MAX_AGE_DAYS && ageDays >= 0) {
      bcUsable = garmin_body_comp;
    }
  }

  const garminTs = bcUsable?.measurementTimeInSeconds ?? null;

  // ---- Weight: latest-wins ----
  let weight_kg = user_weight_kg;
  let weight_source: ResolveSource = 'MANUAL';

  const userHasWeight = user_weight_kg != null && user_weight_kg > 0;
  const garminHasWeight =
    bcUsable?.weightInGrams != null && bcUsable.weightInGrams > 0;

  if (!userHasWeight && garminHasWeight) {
    // User has no weight — Garmin fills unconditionally (within staleness window).
    weight_kg = bcUsable!.weightInGrams! / 1000;
    weight_source = 'GARMIN';
  } else if (userHasWeight && garminHasWeight) {
    // Both have a value — compare timestamps.
    const userTs = user_weight_updated_at_seconds ?? null;
    if (garminTs != null && userTs != null) {
      // Garmin is newer → use Garmin.
      if (garminTs > userTs) {
        weight_kg = bcUsable!.weightInGrams! / 1000;
        weight_source = 'GARMIN';
      }
      // else user is newer → keep MANUAL (already set above).
    }
    // If either timestamp is null, keep user value (safe default).
  }
  // else: user has weight, Garmin doesn't → keep MANUAL.

  // ---- Body fat %: latest-wins ----
  let body_fat_pct: number | null =
    user_body_fat_pct == null ? null : user_body_fat_pct;
  let body_fat_source: ResolveSource =
    body_fat_pct == null ? 'NONE' : 'MANUAL';

  const userHasBF = body_fat_pct != null;
  const garminHasBF =
    bcUsable?.percentFat != null;

  if (!userHasBF && garminHasBF) {
    // User has no body fat — Garmin fills unconditionally.
    body_fat_pct = bcUsable!.percentFat!;
    body_fat_source = 'GARMIN';
  } else if (userHasBF && garminHasBF) {
    // Both have a value — compare timestamps.
    const userTs = user_body_fat_updated_at_seconds ?? null;
    if (garminTs != null && userTs != null) {
      if (garminTs > userTs) {
        body_fat_pct = bcUsable!.percentFat!;
        body_fat_source = 'GARMIN';
      }
      // else user is newer → keep MANUAL.
    }
    // If either timestamp is null, keep user value (safe default).
  }
  // else: user has BF, Garmin doesn't → keep MANUAL.

  return { weight_kg, body_fat_pct, weight_source, body_fat_source };
}

/**
 * CTL → Volume Tier (extends Formula 12).
 * Notion §iteration5_spec: when TP CTL is present, use it instead of weekly_hours.
 *
 *   CTL < 30        → recreational (base_neat 0.30)
 *   30 ≤ CTL < 55   → moderate     (0.25)
 *   55 ≤ CTL < 85   → serious      (0.20)
 *   85 ≤ CTL < 120  → high_volume  (0.17)
 *   CTL ≥ 120       → professional (0.13)
 */
export function ctlToVolumeTier(
  ctl: number | null | undefined,
): { tier: VolumeTier; base_neat: number } | null {
  if (ctl == null || ctl < 0) return null;

  if (ctl < 30) return { tier: 'recreational', base_neat: 0.30 };
  if (ctl < 55) return { tier: 'moderate', base_neat: 0.25 };
  if (ctl < 85) return { tier: 'serious', base_neat: 0.20 };
  if (ctl < 120) return { tier: 'high_volume', base_neat: 0.17 };
  return { tier: 'professional', base_neat: 0.13 };
}
