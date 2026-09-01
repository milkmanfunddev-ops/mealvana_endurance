/**
 * F27 — recalculateAfterSync (SSOT: docs/ssot/spec/daily-macros/
 * platform-resolution.md). Re-runs the full pipeline in RETROSPECTIVE mode;
 * the retro plan replaces today's plan, including the remaining day
 * ("today is for today" ruling), and the movement is reported as `delta`.
 *
 * Every run MUST persist exactly one row to public.plan_recalc_log (the
 * Garmin-first calibration ruling, 2026-08-13): sessions[].formula_kcal is
 * computed with the SAME resolved IF/duration as the Garmin comparison —
 * like-for-like, or the calibration is noise. The insert follows the
 * plan_generation_log pattern: pure row builder + never-throw insert,
 * fire-and-forget at the call site.
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { DailyMacroInput, DailyMacroOutput } from './types.ts';
import { calculateDailyMacros } from './pipeline.ts';
import { sessionCost } from './formulas/session.ts';
import {
  resolveAthleteProfile,
  resolveSessionData,
} from './formulas/resolve.ts';

export interface PlanRecalcLogRow {
  device_id: string | null;
  local_sync_time: string | null; // 'HH:MM:SS' time-of-day the recalc landed
  sessions: Array<{
    sport: string;
    duration_hr: number;
    resolved_if: number;
    formula_kcal: number;
    garmin_kcal: number | null;
    kcal_source: string;
  }>;
  delta: DailyMacroOutput['delta'];
  ea_status_before: string | null;
  ea_status_after: string | null;
}

export interface RecalcResult {
  plan: DailyMacroOutput;
  logRow: PlanRecalcLogRow;
}

/**
 * Run the F27 retrospective recalculation and build its calibration row.
 * The caller persists the row via insertPlanRecalcLog (fire-and-forget).
 */
export function recalculateAfterSync(
  input: DailyMacroInput,
  options?: {
    device_id?: string | null;
    /** Athlete-local time-of-day ('HH:MM:SS'); falls back to server UTC. */
    local_sync_time?: string | null;
  },
): RecalcResult {
  const retroInput: DailyMacroInput = { ...input, mode: 'retrospective' };
  const plan = calculateDailyMacros(retroInput);

  // Like-for-like calibration pairs: resolve each session exactly the way
  // the pipeline did (same profile resolution, same ladders), then price the
  // FORMULA side at the resolved IF/duration.
  const resolved = resolveAthleteProfile(
    input.garmin_body_comp ?? null,
    input.weight_kg,
    input.body_fat_pct ?? null,
    Math.floor(Date.now() / 1000),
    input.user_weight_updated_at_seconds ?? null,
    input.user_body_fat_updated_at_seconds ?? null,
  );

  const sessions = (input.sessions ?? []).map((session, i) => {
    const garmin = input.garmin_activities?.[i] ?? null;
    const r = resolveSessionData(
      session,
      resolved.weight_kg,
      'retrospective',
      garmin,
      input.tp_sessions?.[i] ?? null,
    );
    return {
      sport: session.sport,
      duration_hr: r.duration_hr,
      resolved_if: r.intensity_factor,
      formula_kcal: sessionCost(
        session.sport,
        r.duration_hr,
        r.intensity_factor,
        resolved.weight_kg,
      ),
      garmin_kcal: garmin?.activeKilocalories ?? null,
      kcal_source: r.kcal_source,
    };
  });

  const logRow: PlanRecalcLogRow = {
    device_id: options?.device_id ?? null,
    local_sync_time: options?.local_sync_time ??
      new Date().toISOString().slice(11, 19),
    sessions,
    delta: plan.delta,
    ea_status_before: input.prospective_plan?.ea_status ?? null,
    ea_status_after: plan.ea_status,
  };

  return { plan, logRow };
}

/**
 * Insert the calibration row. Never throws and never blocks the response —
 * a lost ledger row must not fail a recalculation.
 */
export async function insertPlanRecalcLog(
  supabase: SupabaseClient,
  row: PlanRecalcLogRow,
): Promise<void> {
  try {
    const { error } = await supabase.from('plan_recalc_log').insert(row);
    if (error) {
      console.warn('[PLAN_RECALC_LOG] insert failed', error.message);
    }
  } catch (err) {
    console.warn('[PLAN_RECALC_LOG] insert threw', err);
  }
}
