/**
 * calculate-daily-macros Edge Function
 *
 * Daily macronutrient calculator for endurance athletes.
 * Implements 4-iteration algorithm:
 * - Iteration 1: Baseline RMR, TDEE, macros with session demands
 * - Iteration 2: Multi-day context (recovery, pre-load, weekly load, phase)
 * - Iteration 3: Dynamic NEAT + iterative TEF
 * - Iteration 4: Safety (EA check, multi-session compounding, carb cycling)
 * - Iteration 5: Garmin body comp + daily summary wired server-side
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import {
  errorResponse,
  jsonResponse,
  validationError,
  serverError,
} from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import type {
  DailyMacroInput,
  GarminActivityForSession,
  WeekMacroInput,
  WeekDayInput,
} from './types.ts';
import { validateInput, calculateDailyMacros, calculateWeekMacros } from './pipeline.ts';

// ---------------------------------------------------------------------------
// Supabase service-role client (server-side only)
// ---------------------------------------------------------------------------

function createServiceClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}

// ---------------------------------------------------------------------------
// Garmin connectedness gate
// ---------------------------------------------------------------------------

async function isGarminConnected(
  supabase: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data } = await supabase
    .from('garmin_user_mappings')
    .select('garmin_user_id')
    .eq('user_id', userId)
    .limit(1)
    .maybeSingle();
  return !!data;
}

// ---------------------------------------------------------------------------
// Convert DB ISO timestamp string → Unix seconds (null when absent)
// ---------------------------------------------------------------------------

function tsToSec(s?: string | null): number | null {
  return s ? Math.floor(new Date(s).getTime() / 1000) : null;
}

// ---------------------------------------------------------------------------
// Per-session Garmin activity lookup
// ---------------------------------------------------------------------------

/**
 * Fetch per-session Garmin completion data from the activities table.
 * Returns an array aligned to `activityIds` order, with null where the row
 * has no garmin_summary_id (i.e., not yet Garmin-uploaded) or the id is
 * missing.
 *
 * Per Iter 5 spec, this drives `resolveSessionData()` retrospective overrides
 * for session_kcal and duration.
 */
async function fetchGarminActivitiesForSessions(
  supabase: SupabaseClient,
  activityIds: (string | null | undefined)[],
): Promise<(GarminActivityForSession | null)[]> {
  const knownIds = activityIds.filter((id): id is string => !!id);
  if (knownIds.length === 0) {
    return activityIds.map(() => null);
  }

  const { data: rows, error } = await supabase
    .from('activities')
    .select('id, garmin_summary_id, calories_burned, actual_duration_minutes, duration_minutes')
    .in('id', knownIds);

  if (error || !rows) {
    return activityIds.map(() => null);
  }

  const byId = new Map<string, Record<string, unknown>>();
  for (const r of rows) {
    if (r.id) byId.set(String(r.id), r as Record<string, unknown>);
  }

  return activityIds.map((id) => {
    if (!id) return null;
    const row = byId.get(id);
    if (!row || !row.garmin_summary_id) return null;
    const kcal = typeof row.calories_burned === 'number' ? row.calories_burned : null;
    const minutes = typeof row.actual_duration_minutes === 'number'
      ? row.actual_duration_minutes
      : (typeof row.duration_minutes === 'number' ? row.duration_minutes : null);
    const seconds = minutes != null ? minutes * 60 : null;
    if (kcal == null && seconds == null) return null;
    return { activeKilocalories: kcal, durationInSeconds: seconds };
  });
}

// ---------------------------------------------------------------------------
// Garmin context attachment for a single day
// ---------------------------------------------------------------------------

/**
 * Fetches Garmin body comp + daily summary for the given user/date and merges
 * them into the input.  Never throws — on any error logs and returns input
 * unchanged so the calculation always proceeds.
 */
async function attachGarminContext(
  supabase: SupabaseClient,
  input: DailyMacroInput,
): Promise<DailyMacroInput> {
  const userId = input.user_id;
  const date = input.date;
  if (!userId || !date) return input;

  try {
    // Fetch user timestamps for latest-wins weight/BF resolution
    const { data: userRow } = await supabase
      .from('users')
      .select('weight_pounds_updated_at, body_fat_pct_updated_at')
      .eq('id', userId)
      .maybeSingle();

    let augmented: DailyMacroInput = {
      ...input,
      user_weight_updated_at_seconds: tsToSec(userRow?.weight_pounds_updated_at),
      user_body_fat_updated_at_seconds: tsToSec(userRow?.body_fat_pct_updated_at),
    };

    // Connectedness gate — skip Garmin queries entirely if not mapped
    const connected = await isGarminConnected(supabase, userId);
    if (!connected) {
      console.log(`[CALC_MACROS] Garmin not connected for user ${userId} — skipping Garmin context`);
      return augmented;
    }

    // Daily summary for the date (provides RMR via bmrKilocalories and NEAT
    // via activeKilocalories in retrospective mode)
    const { data: dailyRows } = await supabase
      .from('garmin_health_data')
      .select('data, created_at')
      .eq('user_id', userId)
      .eq('data_type', 'daily')
      .eq('calendar_date', date)
      .order('created_at', { ascending: false })
      .limit(1);

    const daily = dailyRows?.[0]?.data as Record<string, unknown> | undefined;
    if (daily) {
      augmented = {
        ...augmented,
        garmin_daily: {
          bmrKilocalories: (daily.bmr_kilocalories as number | null) ?? null,
          activeKilocalories: (daily.active_kilocalories as number | null) ?? null,
        },
      };
    }

    // Latest body comp (no date filter — resolver enforces 30-day staleness)
    const { data: bcRows } = await supabase
      .from('garmin_health_data')
      .select('data, created_at')
      .eq('user_id', userId)
      .eq('data_type', 'body_composition')
      .order('created_at', { ascending: false })
      .limit(1);

    const bc = bcRows?.[0]?.data as Record<string, unknown> | undefined;
    if (bc) {
      // DB stores snake_case; resolver expects camelCase.
      augmented = {
        ...augmented,
        garmin_body_comp: {
          weightInGrams: (bc.weight_grams as number | null) ?? null,
          percentFat: (bc.percent_fat as number | null) ?? null,
          measurementTimeInSeconds: (bc.measurement_time_seconds as number | null) ?? null,
        },
      };
    }

    // Per-session Garmin completion data (calories_burned, actual_duration_minutes)
    if (Array.isArray(augmented.sessions) && augmented.sessions.length > 0) {
      const ids = augmented.sessions.map((s) => s.activity_id ?? null);
      const garminActivities = await fetchGarminActivitiesForSessions(supabase, ids);
      // Only attach if at least one session has Garmin data — keeps the input
      // identical to the legacy shape when nothing was Garmin-uploaded.
      if (garminActivities.some((g) => g != null)) {
        augmented = { ...augmented, garmin_activities: garminActivities };
      }
    }

    return augmented;
  } catch (err) {
    console.error('[CALC_MACROS] attachGarminContext error — proceeding without Garmin context', err);
    return input;
  }
}

// ---------------------------------------------------------------------------
// Garmin context attachment for a week (per-day, tolerant)
// ---------------------------------------------------------------------------

/**
 * Fetches user timestamps once (shared across the week) and attaches per-day
 * Garmin daily summaries to each day entry.  Body comp uses the single latest
 * reading (resolver handles staleness) so it is fetched once and shared.
 * Any individual day failure is silently swallowed — the rest of the week
 * proceeds normally.
 */
async function attachWeekGarminContext(
  supabase: SupabaseClient,
  input: WeekMacroInput,
): Promise<WeekMacroInput> {
  const userId = input.user_id;
  if (!userId) return input;

  try {
    // User timestamps — fetched once, shared across all days
    const { data: userRow } = await supabase
      .from('users')
      .select('weight_pounds_updated_at, body_fat_pct_updated_at')
      .eq('id', userId)
      .maybeSingle();

    const sharedWeightTs = tsToSec(userRow?.weight_pounds_updated_at);
    const sharedBFTs = tsToSec(userRow?.body_fat_pct_updated_at);

    // Connectedness gate
    const connected = await isGarminConnected(supabase, userId);
    if (!connected) {
      console.log(`[CALC_MACROS] Garmin not connected for user ${userId} — skipping week Garmin context`);
      return {
        ...input,
        user_weight_updated_at_seconds: sharedWeightTs,
        user_body_fat_updated_at_seconds: sharedBFTs,
      };
    }

    // Latest body comp — fetched once (shared across week days)
    const { data: bcRows } = await supabase
      .from('garmin_health_data')
      .select('data, created_at')
      .eq('user_id', userId)
      .eq('data_type', 'body_composition')
      .order('created_at', { ascending: false })
      .limit(1);

    const bc = bcRows?.[0]?.data as Record<string, unknown> | undefined;
    const sharedBodyComp: WeekDayInput['garmin_body_comp'] = bc
      ? {
          weightInGrams: (bc.weight_grams as number | null) ?? null,
          percentFat: (bc.percent_fat as number | null) ?? null,
          measurementTimeInSeconds: (bc.measurement_time_seconds as number | null) ?? null,
        }
      : null;

    // Collect all day dates for a bulk query
    const dayDates = input.days
      .map((d) => d.date)
      .filter((d): d is string => !!d);

    // Fetch all daily summaries in one query when we have dates
    let dailyByDate: Record<string, Record<string, unknown>> = {};
    if (dayDates.length > 0) {
      const { data: dailyRows } = await supabase
        .from('garmin_health_data')
        .select('calendar_date, data')
        .eq('user_id', userId)
        .eq('data_type', 'daily')
        .in('calendar_date', dayDates)
        .order('created_at', { ascending: false });

      // Build a map date → first (most recent) row per date
      for (const row of (dailyRows ?? [])) {
        if (row.calendar_date && !dailyByDate[row.calendar_date]) {
          dailyByDate[row.calendar_date] = row.data as Record<string, unknown>;
        }
      }
    }

    // Bulk-fetch per-session Garmin completion across all days in one query
    const allActivityIds: string[] = [];
    for (const day of input.days) {
      for (const s of day.sessions ?? []) {
        if (s.activity_id) allActivityIds.push(s.activity_id);
      }
    }
    let activityById = new Map<string, GarminActivityForSession>();
    if (allActivityIds.length > 0) {
      const { data: actRows } = await supabase
        .from('activities')
        .select('id, garmin_summary_id, calories_burned, actual_duration_minutes, duration_minutes')
        .in('id', allActivityIds);
      for (const r of (actRows ?? [])) {
        if (!r.id || !r.garmin_summary_id) continue;
        const kcal = typeof r.calories_burned === 'number' ? r.calories_burned : null;
        const minutes = typeof r.actual_duration_minutes === 'number'
          ? r.actual_duration_minutes
          : (typeof r.duration_minutes === 'number' ? r.duration_minutes : null);
        if (kcal == null && minutes == null) continue;
        activityById.set(String(r.id), {
          activeKilocalories: kcal,
          durationInSeconds: minutes != null ? minutes * 60 : null,
        });
      }
    }

    // Attach Garmin context to each day
    const augmentedDays: WeekDayInput[] = input.days.map((day) => {
      const daily = day.date ? dailyByDate[day.date] : undefined;
      const sessionGarmin = (day.sessions ?? []).map((s) =>
        s.activity_id ? activityById.get(s.activity_id) ?? null : null,
      );
      const hasAny = sessionGarmin.some((g) => g != null);
      return {
        ...day,
        garmin_body_comp: sharedBodyComp,
        garmin_daily: daily
          ? {
              bmrKilocalories: (daily.bmr_kilocalories as number | null) ?? null,
              activeKilocalories: (daily.active_kilocalories as number | null) ?? null,
            }
          : day.garmin_daily ?? null,
        garmin_activities: hasAny ? sessionGarmin : (day.garmin_activities ?? null),
        user_weight_updated_at_seconds: sharedWeightTs,
        user_body_fat_updated_at_seconds: sharedBFTs,
      };
    });

    return {
      ...input,
      user_weight_updated_at_seconds: sharedWeightTs,
      user_body_fat_updated_at_seconds: sharedBFTs,
      days: augmentedDays,
    };
  } catch (err) {
    console.error('[CALC_MACROS] attachWeekGarminContext error — proceeding without Garmin context', err);
    return input;
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Only accept POST
    if (req.method !== 'POST') {
      return errorResponse('Method not allowed. Use POST.', 405);
    }

    // Parse JSON body
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return validationError('Invalid JSON body');
    }

    const supabase = createServiceClient();

    // Week scope: batch 7 days in one call
    if (body.scope === 'week') {
      let weekInput = body as unknown as WeekMacroInput;

      if (!Array.isArray(weekInput.days) || weekInput.days.length === 0) {
        return validationError('week scope requires a non-empty "days" array');
      }

      // Validate each day by merging with shared profile fields
      for (let i = 0; i < weekInput.days.length; i++) {
        const merged: DailyMacroInput = {
          sex: weekInput.sex,
          age: weekInput.age,
          weight_kg: weekInput.weight_kg,
          height_cm: weekInput.height_cm,
          body_fat_pct: weekInput.body_fat_pct,
          lifestyle: weekInput.lifestyle,
          typical_weekly_hours: weekInput.typical_weekly_hours,
          carb_cycle_opt_in: weekInput.carb_cycle_opt_in,
          training_phase: weekInput.training_phase,
          mode: weekInput.mode,
          ...weekInput.days[i],
        };
        const err = validateInput(merged);
        if (err) {
          return validationError(`day ${i}: ${err}`);
        }
      }

      // Attach Garmin context (tolerant — failure falls back to raw input)
      weekInput = await attachWeekGarminContext(supabase, weekInput);

      const results = calculateWeekMacros(weekInput);
      return jsonResponse({ days: results });
    }

    // Single-day scope (default)
    let input = body as unknown as DailyMacroInput;

    // Validate input
    const validationErr = validateInput(input);
    if (validationErr) {
      return validationError(validationErr);
    }

    // Attach Garmin context (tolerant — failure falls back to raw input)
    input = await attachGarminContext(supabase, input);

    // Calculate macros
    const result = calculateDailyMacros(input);

    return jsonResponse(result);
  } catch (error) {
    console.error('[CALCULATE_DAILY_MACROS_ERROR]', error);
    return serverError(error);
  }
}));
