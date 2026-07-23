/**
 * Core calculation pipeline for calculate-daily-macros
 * Extracted from index.ts so tests can import without triggering serve()
 */

import type {
  DailyMacroInput,
  DailyMacroOutput,
  MacroSources,
  SessionSources,
  WeekMacroInput,
} from './types.ts';
import {
  zoneDistributionToIF,
  carbDemand,
} from './formulas/session.ts';
import {
  baselineMacros,
  calculateProteinBump,
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
  calculateTDEE,
} from './formulas/neat-tef.ts';
import {
  deriveFFM,
  checkEnergyAvailability,
  eaOverride,
  multiSessionCarbCompound,
  carbCycleAdjust,
} from './formulas/safety.ts';
import {
  resolveAthleteProfile,
  resolveRMR,
  resolveNEAT,
  resolveSessionData,
  type ResolvedSessionData,
} from './formulas/resolve.ts';

export const ALGORITHM_VERSION = 'v5.0.0';

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

    // Zone percentages must sum to 1.0 (with tolerance)
    const sum =
      session.pct_conversational + session.pct_tempo + session.pct_allout;
    if (Math.abs(sum - 1.0) > 0.001) {
      return `session ${i}: zone percentages must sum to 1.0 (got ${sum})`;
    }
  }

  return null;
}

/**
 * Main calculation pipeline
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
    tomorrow_tss,
    tomorrow_duration_hr,
    tomorrow_is_race,
    weekly_hours_ratio,
    mode,
  } = input;

  // Auto-promote prospective → retrospective when Garmin data is present.
  // Prospective plans are forecasts; the moment we have Garmin's measured
  // session/daily kcal, we should be using it rather than formulas. Callers can
  // pass mode='prospective' explicitly without having to also know to flip it
  // when Garmin data shows up — the pipeline figures it out from the input.
  const hasGarminActivity = (input.garmin_activities ?? []).some(
    (a) => a != null && (a.activeKilocalories ?? 0) > 0,
  );
  const hasGarminDaily =
    (input.garmin_daily?.activeKilocalories ?? 0) > 0;
  const effectiveMode =
    mode === 'retrospective' || hasGarminActivity || hasGarminDaily
      ? 'retrospective'
      : (mode ?? 'prospective');

  // Resolve weight + body fat % — Garmin body comp wins when newer than user's
  // last manual entry (latest-wins precedence). Falls back to input fields when
  // no Garmin data is present.
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

  // Calculate LBM if body fat % available
  const lbm_kg =
    body_fat_pct !== null && body_fat_pct !== undefined
      ? weight_kg * (1 - body_fat_pct / 100)
      : null;

  // Derive FFM for EA check
  const ffm_kg = deriveFFM(weight_kg, sex, body_fat_pct);

  // ====================================================================
  // STEP 1: Baseline macros (with carb cycling modification)
  // ====================================================================

  const baseline = baselineMacros(weight_kg, lbm_kg, age);
  let carb = baseline.carb_g;
  let prot = baseline.prot_g;

  // Carb cycling: only for single-session days
  if (sessions.length === 1 && carb_cycle_opt_in) {
    const session = sessions[0];
    const session_if = zoneDistributionToIF(
      session.pct_conversational,
      session.pct_tempo,
      session.pct_allout,
    );

    carb = carbCycleAdjust(
      session_if,
      session.duration_hr,
      carb_cycle_opt_in,
      training_phase,
      carb,
      weight_kg,
    );
  }

  // ====================================================================
  // STEP 2: Today's sessions (with compounding for multi-session)
  //
  // Per-session resolution: when Garmin (or TP, future) data is present we
  // override formula kcal/duration. Resolved values are also used to populate
  // the `sources` block returned to the client.
  // ====================================================================

  const garmin_activities = input.garmin_activities ?? null;
  const resolved_sessions: ResolvedSessionData[] = sessions.map((session, i) =>
    resolveSessionData(
      session,
      weight_kg,
      effectiveMode,
      garmin_activities?.[i] ?? null,
      null, // tp_session — not yet wired
    ),
  );

  let total_session_kcal = 0;
  let session_carb_add = 0;
  let prot_bump = 0;

  if (sessions.length === 0) {
    // Rest day
    session_carb_add = 0;
    prot_bump = 0;
  } else if (sessions.length === 1) {
    // Single session: standard logic from Iteration 1
    const r = resolved_sessions[0];
    total_session_kcal = r.session_kcal;
    session_carb_add = Math.round(r.session_carb);
    prot_bump = calculateProteinBump(sessions, weight_kg);
  } else {
    // Multi-session: carb-compounding stays formula-driven (carb demand is
    // intensity-driven, not energy-driven, so Garmin kcal doesn't affect it).
    const compound = multiSessionCarbCompound(
      sessions,
      weight_kg,
      carbDemand,
      zoneDistributionToIF,
    );

    session_carb_add = compound.session_carb;
    prot_bump = compound.prot_bump;

    // Total kcal sums resolved values — Garmin overrides flow through here.
    for (const r of resolved_sessions) {
      total_session_kcal += r.session_kcal;
    }
  }

  carb += session_carb_add;
  prot += prot_bump;

  // ====================================================================
  // STEP 3: Recovery debt
  // ====================================================================

  const debt = recoveryDebt(yesterday_tss, yesterday_hours_since, weight_kg);
  carb += debt.carb_add;
  prot += debt.prot_add;

  // ====================================================================
  // STEP 4: Pre-load override
  // ====================================================================

  carb = preLoadOverride(
    tomorrow_tss,
    tomorrow_duration_hr,
    tomorrow_is_race,
    carb,
    weight_kg,
  );

  // ====================================================================
  // STEP 5: Weekly load adjust
  // ====================================================================

  const weekly = weeklyLoadAdjust(weekly_hours_ratio, weight_kg);
  carb += weekly.carb_add;
  prot += weekly.prot_add;

  // ====================================================================
  // STEP 6: Phase modifiers
  // ====================================================================

  const phase_mod = phaseModifier(training_phase);
  carb *= phase_mod.carb_mod;
  prot *= phase_mod.prot_mod;

  // ====================================================================
  // STEP 7: Clamp ranges
  // ====================================================================

  const clamped = clampMacros(carb, prot, weight_kg);
  carb = clamped.carb_g;
  prot = clamped.prot_g;

  // ====================================================================
  // STEP 8: Dynamic NEAT + iterative TEF → TDEE + fat
  // ====================================================================

  // RMR: use Garmin daily BMR when present (positive number), else formula.
  // Predicate: input.garmin_daily?.bmrKilocalories != null &&
  //            input.garmin_daily.bmrKilocalories > 0
  const resolvedRMR = resolveRMR(input.garmin_daily ?? null, {
    weight_kg,
    height_cm,
    age,
    sex,
    body_fat_pct,
  });
  const rmr = resolvedRMR.rmr;

  const volume = inferVolumeTier(typical_weekly_hours);
  const day_info = getDayModifier(sessions, yesterday_tss);

  // NEAT: use Garmin daily activeKilocalories − session kcal when:
  //   - mode is 'retrospective', AND
  //   - input.garmin_daily?.activeKilocalories != null &&
  //     input.garmin_daily.activeKilocalories > 0
  // Otherwise use the formula-derived NEAT.
  const resolvedNEAT = resolveNEAT(
    effectiveMode,
    input.garmin_daily ?? null,
    total_session_kcal,
    rmr,
    volume.base_neat,
    day_info.modifier,
    lifestyle,
  );
  const neat = resolvedNEAT.neat_kcal;

  const tdee_result = calculateTDEE(
    rmr,
    neat,
    total_session_kcal,
    carb,
    prot,
    weight_kg,
  );

  let fat = tdee_result.fat_g;
  let tdee = tdee_result.tdee;
  let tef = tdee_result.tef;

  // ====================================================================
  // STEP 9: EA Safety Check + Override
  // ====================================================================

  const intake = carb * 4 + prot * 4 + fat * 9;
  const ea_check = checkEnergyAvailability(
    intake,
    total_session_kcal,
    ffm_kg,
  );

  let ea_status = ea_check.status;
  let ea_value = ea_check.ea;

  // Fat is normally clamped to 1.5 g/kg by calculateTDEE so race-day TDEE
  // doesn't translate into absurd 5+ g/kg fat targets (issue #6). On extreme
  // single-day session loads, that clamp can drop intake far enough below TDEE
  // to push EA into BLOCK. In that case, relax the fat ceiling just enough to
  // keep EA at the floor (20 kcal/kg FFM) — physiologically the body covers
  // the gap from glycogen + body fat anyway, and we'd rather warn than refuse.
  if (ea_check.status === 'BLOCK') {
    // Target a small buffer above the BLOCK threshold so int rounding can't
    // dip the result back below 20.
    const target_ea = 20.5;
    const min_intake_for_safety = target_ea * ffm_kg + total_session_kcal;
    const intake_deficit = min_intake_for_safety - intake;
    if (intake_deficit > 0) {
      const additional_fat = intake_deficit / 9;
      fat = Math.ceil(fat + additional_fat);
      const recomputed_intake = carb * 4 + prot * 4 + fat * 9;
      tef = Math.round(recomputed_intake * 0.10);
      tdee = Math.round(rmr + neat + tef + total_session_kcal);
      const recheck = checkEnergyAvailability(
        recomputed_intake,
        total_session_kcal,
        ffm_kg,
      );
      ea_value = recheck.ea;
      ea_status = recheck.status;
      console.log(
        `[FAT-RELAX] EA was BLOCK; relaxed fat ceiling: fat=${fat}g, EA=${ea_value.toFixed(1)} (${ea_status})`,
      );
    }
  }

  if (ea_status === 'BLOCK') {
    throw new Error(
      `Energy Availability too low (${ea_value.toFixed(1)} kcal/kg FFM). Cannot generate plan. Please increase intake or reduce exercise volume.`,
    );
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
      throw new Error(
        'Energy Availability override failed. Cannot generate safe plan.',
      );
    }

    if (override.adjusted) {
      carb = override.carb;
      prot = override.prot;
      fat = override.fat;

      // Recalculate TDEE after override
      const new_intake = carb * 4 + prot * 4 + fat * 9;
      const new_tef = new_intake * 0.10;
      tdee = Math.round(rmr + neat + new_tef + total_session_kcal);

      // Recalculate EA
      const new_ea_check = checkEnergyAvailability(
        new_intake,
        total_session_kcal,
        ffm_kg,
      );
      ea_value = new_ea_check.ea;
      ea_status = new_ea_check.status;
    }
  }

  // ====================================================================
  // RETURN
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
    sessions: session_sources,
  };

  const carb_g = Math.round(carb);
  const prot_g = Math.round(prot);
  const fat_g = Math.round(fat);
  const session_kcal = Math.round(total_session_kcal);

  // Delta vs prior prospective plan — only emitted when we just recomputed
  // retrospectively and the caller passed in the prospective baseline. The
  // contract is asymmetric on purpose: prospective recomputes never emit
  // delta even if a prior plan is passed in (a forecast diffing another
  // forecast isn't useful — we only diff against measured truth).
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
      : undefined;

  return {
    carb_g,
    prot_g,
    fat_g,
    tdee: tdee,
    rmr: Math.round(rmr),
    session_kcal,
    neat_kcal: Math.round(neat),
    tef_kcal: tef,
    mode: effectiveMode,
    ea: parseFloat(ea_value.toFixed(1)),
    ea_status: ea_status,
    algorithm_version: ALGORITHM_VERSION,
    weight_kg: parseFloat(weight_kg.toFixed(2)),
    body_fat_pct: body_fat_pct,
    sources,
    ...(delta !== undefined && { delta }),
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
