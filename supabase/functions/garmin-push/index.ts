/**
 * Garmin Push Notification Handler
 *
 * Garmin sends activity and health data directly to this endpoint
 * when users sync their devices. This is the primary data ingestion path.
 *
 * Endpoint: POST /functions/v1/garmin-push
 * Auth: garmin-client-id header validation
 *
 * Activity Strategy (match-only):
 * Garmin activities ONLY update existing planned activities from TP/FS.
 * If no matching planned activity exists, the push is logged and skipped.
 * Mealvana is a nutrition planning tool — unplanned workouts without
 * nutrition context don't belong in the activity list.
 *
 * Supported push types:
 * - activities: Activity summaries — matched to planned activities
 * - activityDetails: Detailed activity data — matched to planned activities
 * - manuallyUpdatedActivities: Edits to previously matched activities
 * - dailies: Daily wellness summaries → garmin_health_data
 * - epochs: 15-minute granularity data → garmin_health_data
 * - sleeps: Sleep summaries → garmin_health_data
 * - bodyComps: Body composition measurements → garmin_health_data
 * - stressDetails: Stress + body battery timelines → garmin_health_data
 * - userMetrics: VO2 max, fitness age, etc. → garmin_health_data
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { validateGarminRequest } from "../_shared/garmin/auth.ts";
import {
  mapGarminActivityToActivity,
  mapGarminDailySummary,
  mapGarminSleepSummary,
} from "../_shared/garmin/mappers.ts";
import {
  processInboundGarminActivity,
  tallyOutcome,
} from "../_shared/garmin/matcher_executor.ts";
import type {
  GarminGenericWellnessSummary,
  GarminPushNotification,
} from "../_shared/garmin/types.ts";
import {
  prepareDetailForCapture,
} from "../_shared/garmin/sample_capture.ts";
import {
  logGarminMappingMiss,
  logGarminRecordFailure,
} from "../_shared/garmin/push_log.ts";

const GARMIN_CLIENT_ID = Deno.env.get("GARMIN_CLIENT_ID") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

// Supabase edge runtime global for background task lifetime.
// See: https://supabase.com/docs/guides/functions/background-tasks
declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
} | undefined;

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req: Request) => {
  // Validate the request is from Garmin (header-only, synchronous)
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-push] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Capture the raw body up-front. The request body stream closes once we
  // return, so we hold the raw text in a closure for both background
  // processing AND potential fan-out to other environments.
  let rawBody: string;
  let body: GarminPushNotification;
  try {
    rawBody = await req.text();
    body = JSON.parse(rawBody) as GarminPushNotification;
  } catch (err) {
    console.error("[garmin-push] Failed to parse request body:", err);
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Snapshot the inbound Garmin headers so a fan-out call to dev passes
  // validateGarminRequest cleanly (same `garmin-client-id` value).
  const inboundClientId = req.headers.get("garmin-client-id") ?? "";

  // Garmin requires HTTP 200 returned asynchronously within 30 seconds.
  // Ack immediately and process the parsed payload in the background, plus
  // forward to any configured fan-out URL (used by prod to mirror pushes
  // into dev so the same data is available in both environments).
  const processing = Promise.all([
    processPushBody(body).catch((err) => {
      console.error("[garmin-push] Background processing error:", err);
    }),
    forwardToFanout(rawBody, inboundClientId).catch((err) => {
      console.error("[garmin-push] Fanout error:", err);
    }),
  ]);

  if (typeof EdgeRuntime !== "undefined") {
    EdgeRuntime.waitUntil(processing);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}));

/**
 * Optional fan-out: if `GARMIN_FANOUT_URL` is set, re-POST the inbound
 * Garmin payload to that URL. Used by prod to mirror Garmin's push stream
 * into dev (Garmin's developer portal only allows a single webhook URL per
 * data type, so the two environments share one feed). Dev must NOT set
 * this env var, otherwise it loops back into prod.
 */
async function forwardToFanout(
  rawBody: string,
  clientIdHeader: string,
): Promise<void> {
  const fanoutUrl = Deno.env.get("GARMIN_FANOUT_URL");
  if (!fanoutUrl || fanoutUrl.trim().length === 0) return;

  try {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      "x-garmin-fanout": "1",
    };
    if (clientIdHeader.length > 0) {
      headers["garmin-client-id"] = clientIdHeader;
    }

    const resp = await fetch(fanoutUrl, {
      method: "POST",
      headers,
      body: rawBody,
    });
    if (!resp.ok) {
      const text = await resp.text();
      console.error(
        `[garmin-push] Fanout to ${fanoutUrl} returned ${resp.status}: ${
          text.slice(0, 200)
        }`,
      );
    }
  } catch (err) {
    console.error(`[garmin-push] Fanout to ${fanoutUrl} threw:`, err);
  }
}

/**
 * Garmin body comp readings are eligible as the authoritative value only if
 * within this window. Matches GARMIN_BODY_COMP_MAX_AGE_DAYS in
 * calculate-daily-macros/formulas/resolve.ts.
 */
const GARMIN_BODY_COMP_MAX_AGE_DAYS = 30;
const GRAMS_PER_POUND = 453.592;

interface GarminBodyCompForMirror {
  weightInGrams?: number | null;
  percentFat?: number | null;
  measurementTimeInSeconds?: number | null;
}

/**
 * Mirror a Garmin body-composition reading to `users.weight_pounds` and
 * `users.body_fat_pct` (with their `_updated_at` siblings) so callers that
 * read the users table directly — Drift sync, Preferences UI, macro
 * resolver — see the freshest measured value.
 *
 * Precedence: latest-wins. If the user has manually edited their weight
 * more recently than the Garmin measurement, the user value stands.
 * Stale readings (>30 days) are ignored entirely.
 */
async function mirrorGarminBodyCompToUser(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  bodyComp: GarminBodyCompForMirror,
): Promise<void> {
  const measurementSec = bodyComp.measurementTimeInSeconds;
  if (measurementSec == null || measurementSec <= 0) return;

  const ageDays = (Date.now() / 1000 - measurementSec) / 86400;
  if (ageDays > GARMIN_BODY_COMP_MAX_AGE_DAYS || ageDays < 0) return;

  const hasWeight = bodyComp.weightInGrams != null &&
    bodyComp.weightInGrams > 0;
  const hasBodyFat = bodyComp.percentFat != null && bodyComp.percentFat > 0;
  if (!hasWeight && !hasBodyFat) return;

  const { data: userRow, error: readErr } = await supabase
    .from("users")
    .select("weight_pounds_updated_at, body_fat_pct_updated_at")
    .eq("id", userId)
    .single();

  if (readErr) {
    console.error(`[garmin-push] Users read for mirror failed:`, readErr);
    return;
  }

  const measurementIso = new Date(measurementSec * 1000).toISOString();
  // deno-lint-ignore no-explicit-any
  const update: Record<string, any> = {};

  if (hasWeight) {
    const userTsMs = userRow?.weight_pounds_updated_at
      ? Date.parse(userRow.weight_pounds_updated_at)
      : null;
    // No prior timestamp → Garmin fills the gap. Otherwise newer wins.
    if (userTsMs == null || measurementSec * 1000 > userTsMs) {
      update.weight_pounds = bodyComp.weightInGrams! / GRAMS_PER_POUND;
      update.weight_pounds_updated_at = measurementIso;
    }
  }

  if (hasBodyFat) {
    const userTsMs = userRow?.body_fat_pct_updated_at
      ? Date.parse(userRow.body_fat_pct_updated_at)
      : null;
    if (userTsMs == null || measurementSec * 1000 > userTsMs) {
      update.body_fat_pct = bodyComp.percentFat!;
      update.body_fat_pct_updated_at = measurementIso;
    }
  }

  if (Object.keys(update).length === 0) return;

  const { error: writeErr } = await supabase
    .from("users")
    .update(update)
    .eq("id", userId);

  if (writeErr) {
    console.error(`[garmin-push] Users mirror update failed:`, writeErr);
  }
}

/**
 * Persist an inbound Garmin payload verbatim, BEFORE any gate can drop it.
 *
 * Why this exists (2026-08-24): an athlete's pool swim was recorded natively by
 * a Forerunner 955, reached Final Surge and Bevel Health through Garmin's API,
 * and never appeared in our `activities` table. Every drop point in this
 * function was audited and cleared — sport mapping normalizes case, no
 * tombstone existed, the planned matcher would have matched, the insert
 * fallback admits swimming — so the payload either never arrived or was
 * discarded somewhere unlogged. We could not tell which, because inbound
 * ACTIVITY payloads were never persisted (`garmin_health_data` held only
 * daily/epoch/sleep/stress/body-composition) and the Supabase log tables
 * return nothing through the Management API. That question must be a lookup,
 * not archaeology.
 * See ops/data/bug-reports/2026-08-24-final-surge-completed-workouts-import-as-planned.md
 *
 * Storage note: reuses `garmin_health_data`'s generic (data_type, data jsonb)
 * shape rather than adding a table — deliberately, so this ships as a function
 * deploy with no migration. Every existing reader of that table filters on
 * data_type (app: body_composition; engine: daily / body_composition), so a new
 * type is invisible to all of them. `summary_id` carries a GLOBAL unique, hence
 * the `act:` / `actdet:` prefix and the conflict-ignore.
 *
 * MUST NOT THROW. This diagnoses a path that already loses activities silently;
 * a logging failure that aborted the enclosing try would make the very bug it
 * exists to catch worse.
 */
async function logInboundGarminPayload(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  kind: "activity" | "activity_detail" | "activity_detail_full",
  garminUserId: string | null | undefined,
  userId: string | null,
  summaryId: string | null | undefined,
  payload: unknown,
): Promise<void> {
  try {
    const prefix = kind === "activity"
      ? "act"
      : kind === "activity_detail"
      ? "actdet"
      : "actdetfull";
    const key = summaryId
      ? `${prefix}:${summaryId}`
      : `${prefix}:nosummary:${garminUserId ?? "unknown"}:${
        // deno-lint-ignore no-explicit-any
        (payload as any)?.startTimeInSeconds ?? "0"
      }`;
    await supabase
      .from("garmin_health_data")
      .upsert({
        user_id: userId,
        garmin_user_id: garminUserId ?? null,
        summary_id: key,
        data_type: kind === "activity"
          ? "activity_raw"
          : kind === "activity_detail"
          ? "activity_detail_raw"
          : "activity_detail_full",
        calendar_date: new Date().toISOString().slice(0, 10),
        data: payload,
      }, { onConflict: "summary_id", ignoreDuplicates: true });
  } catch (err) {
    // Swallow deliberately — see the contract above.
    console.warn("[garmin-push] inbound payload log failed (non-fatal):", err);
  }
}

/**
 * garmin_health_data.calendar_date is NOT NULL; the generic wellness types
 * don't all carry calendarDate, so fall back through the timestamps they do
 * carry (UTC date) before defaulting to today.
 */
function resolveWellnessCalendarDate(
  summary: GarminGenericWellnessSummary,
): string {
  if (summary.calendarDate) return summary.calendarDate;
  const seconds =
    summary.startTimeInSeconds ?? summary.measurementTimeInSeconds;
  if (typeof seconds === "number" && Number.isFinite(seconds)) {
    return new Date(seconds * 1000).toISOString().slice(0, 10);
  }
  return new Date().toISOString().slice(0, 10);
}

async function processPushBody(body: GarminPushNotification): Promise<void> {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { processed: number; errors: number }> = {};

    // Process activities — match an existing planned activity if one exists,
    // otherwise auto-create a completed activity for endurance sports so the
    // user gets a notification + nutrition surface for the workout.
    if (body.activities && body.activities.length > 0) {
      const stats = {
        processed: 0,
        errors: 0,
        matched: 0,
        inserted: 0,
        skipped: 0,
      };
      for (const activity of body.activities) {
        try {
          // Look up our user by Garmin userId
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", activity.userId)
            .single();

          // Forensic log FIRST — before the tombstone gate, the sport mapping
          // and the matcher, so an activity dropped by ANY of them still
          // leaves a trace. Non-fatal by contract.
          console.log(
            `[garmin-push] inbound activity type="${activity.activityType}" ` +
              `summaryId=${activity.summaryId ?? "none"} start=${activity.startTimeInSeconds}`,
          );
          await logInboundGarminPayload(
            supabase,
            "activity",
            activity.userId,
            mapping?.user_id ?? null,
            activity.summaryId != null ? String(activity.summaryId) : null,
            activity,
          );

          if (!mapping) {
            logGarminMappingMiss(
              "activities",
              activity.userId,
              activity.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          // Ratified matcher tier (data-integrations@v1): matcher.ts
          // decides, matcher_executor.ts applies; garmin-ping shares the
          // exact same pipeline.
          const outcome = await processInboundGarminActivity(
            supabase,
            mapping.user_id,
            activity,
            "[garmin-push]",
          );
          if (outcome.kind === "error") {
            logGarminRecordFailure({
              kind: "activities",
              garminUserId: activity.userId,
              summaryId: activity.summaryId,
              reason: "matcher_error",
              error: outcome.error,
            });
          }
          tallyOutcome(outcome, stats);
        } catch (err) {
          logGarminRecordFailure({
            kind: "activities",
            garminUserId: activity.userId,
            summaryId: activity.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.activities = stats;
    }

    // Process daily summaries
    if (body.dailies && body.dailies.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const daily of body.dailies) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", daily.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "dailies",
              daily.userId,
              daily.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const record = mapGarminDailySummary(daily);
          record.user_id = mapping.user_id;

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: "dailies",
              garminUserId: daily.userId,
              summaryId: daily.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: "dailies",
            garminUserId: daily.userId,
            summaryId: daily.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.dailies = stats;
    }

    // Process sleep summaries
    if (body.sleeps && body.sleeps.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const sleep of body.sleeps) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", sleep.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "sleeps",
              sleep.userId,
              sleep.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const record = mapGarminSleepSummary(sleep);
          record.user_id = mapping.user_id;

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: "sleeps",
              garminUserId: sleep.userId,
              summaryId: sleep.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: "sleeps",
            garminUserId: sleep.userId,
            summaryId: sleep.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.sleeps = stats;
    }

    // Process body composition
    if (body.bodyComps && body.bodyComps.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const bodyComp of body.bodyComps) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", bodyComp.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "bodyComps",
              bodyComp.userId,
              bodyComp.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: bodyComp.userId,
            summary_id: bodyComp.summaryId,
            data_type: "body_composition",
            calendar_date:
              new Date(bodyComp.measurementTimeInSeconds * 1000).toISOString()
                .split("T")[0],
            data: {
              weight_grams: bodyComp.weightInGrams,
              percent_fat: bodyComp.percentFat,
              percent_hydration: bodyComp.percentHydration,
              bone_mass_grams: bodyComp.boneMassInGrams,
              muscle_mass_grams: bodyComp.muscleMassInGrams,
              bmi: bodyComp.bmi,
              measurement_time_seconds: bodyComp.measurementTimeInSeconds,
            },
          };

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: "bodyComps",
              garminUserId: bodyComp.userId,
              summaryId: bodyComp.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
            continue;
          }

          stats.processed++;

          // Mirror to users.{weight_pounds, body_fat_pct} with latest-wins
          // precedence so the rest of the app (Drift sync, Preferences UI,
          // macro calc) sees the freshest value without needing to read
          // garmin_health_data directly. Mirrors the algorithm in
          // calculate-daily-macros/formulas/resolve.ts: must have a
          // measurement timestamp, within 30 days, newer than the value
          // currently in `users`.
          await mirrorGarminBodyCompToUser(supabase, mapping.user_id, bodyComp);
        } catch (err) {
          logGarminRecordFailure({
            kind: "bodyComps",
            garminUserId: bodyComp.userId,
            summaryId: bodyComp.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.bodyComps = stats;
    }

    // Process stress details
    if (body.stressDetails && body.stressDetails.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const stress of body.stressDetails) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", stress.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "stressDetails",
              stress.userId,
              stress.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: stress.userId,
            summary_id: stress.summaryId,
            data_type: "stress",
            calendar_date: stress.calendarDate,
            data: {
              duration_seconds: stress.durationInSeconds,
              stress_levels: stress.timeOffsetStressLevelValues,
              body_battery_values: stress.timeOffsetBodyBatteryValues,
            },
          };

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: "stressDetails",
              garminUserId: stress.userId,
              summaryId: stress.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: "stressDetails",
            garminUserId: stress.userId,
            summaryId: stress.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.stressDetails = stats;
    }

    // Process manually updated activities — edits to previously matched Garmin
    // completions. We preserve the original workout provider identity and use
    // garmin_summary_id as the Garmin-side linkage.
    if (
      body.manuallyUpdatedActivities &&
      body.manuallyUpdatedActivities.length > 0
    ) {
      const stats = { processed: 0, errors: 0, skipped: 0 };
      for (const activity of body.manuallyUpdatedActivities) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", activity.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "manuallyUpdatedActivities",
              activity.userId,
              activity.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const summaryId = activity.summaryId ??
            (activity as { activityId?: string }).activityId;
          if (!summaryId) {
            logGarminRecordFailure({
              kind: "manuallyUpdatedActivities",
              garminUserId: activity.userId,
              reason: "missing_summary_id",
            });
            stats.errors++;
            continue;
          }
          const activityRow = mapGarminActivityToActivity(
            activity,
            mapping.user_id,
          );

          // Only update an existing activity that was previously matched
          const { data: existing } = await supabase
            .from("activities")
            .select("id")
            .eq("user_id", mapping.user_id)
            .eq("garmin_summary_id", String(summaryId))
            .is("deleted_at", null)
            .limit(1);

          if (!existing || existing.length === 0) {
            console.log(
              `[garmin-push] No existing activity for manual update summaryId ${summaryId} — skipping`,
            );
            stats.skipped++;
            continue;
          }

          const updateFields: Record<string, unknown> = {
            updated_at: new Date().toISOString(),
            garmin_last_synced_at: new Date().toISOString(),
            average_heart_rate: activityRow.average_heart_rate,
            max_heart_rate: activityRow.max_heart_rate,
            calories_burned: activityRow.calories_burned,
          };

          // L-2 split (DI-7): a manual Garmin edit is MEASURED data — it
          // updates the actual_* family and the measured scalar columns
          // only; the planner columns (duration_minutes, distance_miles,
          // distance_meters) keep the plan. Zero is a valid value, so guard
          // with typeof === "number", not truthiness.
          if (typeof activityRow.duration_minutes === "number") {
            updateFields.actual_duration_minutes = activityRow.duration_minutes;
          }
          const manualDistanceMiles =
            typeof activityRow.distance_miles === "number"
              ? activityRow.distance_miles
              : typeof activityRow.distance_meters === "number"
              ? activityRow.distance_meters / 1609.34
              : null;
          if (manualDistanceMiles !== null) {
            updateFields.actual_distance_miles = manualDistanceMiles;
          }
          if (typeof activityRow.average_pace_minutes_per_mile === "number") {
            updateFields.average_pace_minutes_per_mile =
              activityRow.average_pace_minutes_per_mile;
          }
          if (typeof activityRow.cycling_power_watts === "number") {
            updateFields.cycling_power_watts = activityRow.cycling_power_watts;
          }
          if (typeof activityRow.cycling_speed_mph === "number") {
            updateFields.cycling_speed_mph = activityRow.cycling_speed_mph;
          }
          if (typeof activityRow.cycling_elevation_gain_ft === "number") {
            updateFields.cycling_elevation_gain_ft =
              activityRow.cycling_elevation_gain_ft;
          }
          if (typeof activityRow.swimming_pace_per_100m_seconds === "number") {
            updateFields.swimming_pace_per_100m_seconds =
              activityRow.swimming_pace_per_100m_seconds;
          }

          const { error } = await supabase
            .from("activities")
            .update(updateFields)
            .eq("id", existing[0].id);

          if (error) {
            logGarminRecordFailure({
              kind: "manuallyUpdatedActivities",
              garminUserId: activity.userId,
              summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            console.log(
              `[garmin-push] Updated activity ${
                existing[0].id
              } from manual edit`,
            );
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: "manuallyUpdatedActivities",
            garminUserId: activity.userId,
            summaryId: activity.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.manuallyUpdatedActivities = stats;
    }

    // Process activity details — same match-or-insert strategy as regular
    // activities. Match wins update an existing planned activity; on no-match
    // we auto-create for endurance sports.
    if (body.activityDetails && body.activityDetails.length > 0) {
      const stats = {
        processed: 0,
        errors: 0,
        matched: 0,
        inserted: 0,
        skipped: 0,
      };
      for (const detail of body.activityDetails) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", detail.userId)
            .single();

          // Forensic log FIRST, same contract as the activities loop. Only the
          // SUMMARY is stored — ActivityDetails carries per-second sample
          // arrays that would bloat the row for no diagnostic value.
          console.log(
            `[garmin-push] inbound activityDetail type="${detail.summary?.activityType}" ` +
              `summaryId=${detail.summary?.summaryId ?? "none"}`,
          );
          await logInboundGarminPayload(
            supabase,
            "activity_detail",
            detail.userId,
            mapping?.user_id ?? null,
            detail.summary?.summaryId != null
              ? String(detail.summary.summaryId)
              : null,
            detail.summary,
          );

          // DI-25 (L-7 item 3): the FULL detail, samples included, under the
          // 90-day TTL. GPS is stripped at ingest and the byte cap enforced
          // BEFORE the write (Xuan ruling B + recon W7) — route-level
          // location never rests here, not even transiently-committed.
          try {
            const prepared = prepareDetailForCapture(detail);
            if (prepared.samplesDropped) {
              console.warn(
                `[garmin-push] sample stream elided (over cap): ` +
                  `summaryId=${detail.summary?.summaryId ?? "none"} ` +
                  `samples=${prepared.sampleCount} bytes=${prepared.bytes}`,
              );
            }
            await logInboundGarminPayload(
              supabase,
              "activity_detail_full",
              detail.userId,
              mapping?.user_id ?? null,
              detail.summary?.summaryId != null
                ? String(detail.summary.summaryId)
                : null,
              prepared.payload,
            );
          } catch (capErr) {
            // Capture is a diagnostic side-channel on the path whose
            // documented failure mode is losing activities silently. It must
            // never be the reason an activity does not land, so its failure
            // is logged and swallowed here rather than left to the enclosing
            // per-detail catch, which would skip the rest of this detail.
            console.warn(
              "[garmin-push] full-detail capture failed (non-fatal):",
              capErr,
            );
          }

          if (!mapping) {
            logGarminMappingMiss(
              "activityDetails",
              detail.userId,
              detail.summary?.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const summary = detail.summary;
          // Guard against missing summaryId: Garmin occasionally omits it on
          // ActivityDetails payloads. Bare String(undefined) would write the
          // literal string "undefined" into garmin_summary_id and break the
          // unique index.
          const detailSummaryId = summary.summaryId ??
            (summary as { activityId?: string }).activityId ??
            (detail as { activityId?: string }).activityId;
          if (!detailSummaryId) {
            logGarminRecordFailure({
              kind: "activityDetails",
              garminUserId: detail.userId,
              reason: "missing_summary_id",
            });
            stats.errors++;
            continue;
          }
          // Same ratified matcher tier as the activities loop; the detail
          // payload's summary is a full GarminActivitySummary. The
          // duplicate/enrich path backfills metric gaps when the summary
          // push won the race (detail pushes carry the richest data).
          const detailActivity = {
            ...summary,
            summaryId: String(detailSummaryId),
          };
          const outcome = await processInboundGarminActivity(
            supabase,
            mapping.user_id,
            detailActivity,
            "[garmin-push]",
          );
          if (outcome.kind === "error") {
            logGarminRecordFailure({
              kind: "activityDetails",
              garminUserId: detail.userId,
              summaryId: detailSummaryId,
              reason: "matcher_error",
              error: outcome.error,
            });
          }
          tallyOutcome(outcome, stats);
        } catch (err) {
          logGarminRecordFailure({
            kind: "activityDetails",
            garminUserId: detail.userId,
            summaryId: detail.summary?.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.activityDetails = stats;
    }

    // Process epoch summaries
    if (body.epochs && body.epochs.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const epoch of body.epochs) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", epoch.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "epochs",
              epoch.userId,
              epoch.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const localEpochMs =
            (epoch.startTimeInSeconds + epoch.startTimeOffsetInSeconds) * 1000;
          const calendarDate =
            new Date(localEpochMs).toISOString().split("T")[0];

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: epoch.userId,
            summary_id: epoch.summaryId,
            data_type: "epoch",
            calendar_date: calendarDate,
            data: {
              duration_seconds: epoch.durationInSeconds,
              activity_type: epoch.activityType,
              active_kilocalories: epoch.activeKilocalories,
              steps: epoch.steps,
              distance_meters: epoch.distanceInMeters,
              avg_heart_rate: epoch.averageHeartRateInBeatsPerMinute,
              max_heart_rate: epoch.maxHeartRateInBeatsPerMinute,
              intensity: epoch.intensity,
            },
          };

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: "epochs",
              garminUserId: epoch.userId,
              summaryId: epoch.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: "epochs",
            garminUserId: epoch.userId,
            summaryId: epoch.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.epochs = stats;
    }

    // Process user metrics (VO2 max, fitness age, etc.)
    if (body.userMetrics && body.userMetrics.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const metric of body.userMetrics) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", metric.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              "userMetrics",
              metric.userId,
              metric.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: metric.userId,
            summary_id: metric.summaryId,
            data_type: "user_metrics",
            calendar_date: metric.calendarDate,
            data: {
              vo2_max: metric.vo2Max,
              fitness_age: metric.fitnessAge,
            },
          };

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: "userMetrics",
              garminUserId: metric.userId,
              summaryId: metric.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: "userMetrics",
            garminUserId: metric.userId,
            summaryId: metric.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results.userMetrics = stats;
    }

    // Process previously-unhandled wellness types (data-integrations@v1
    // capture, Q-INT26 item 8): hrv, pulseOx, respiration, healthSnapshot,
    // bloodPressures, skinTemp -> garmin_health_data, payload stored
    // verbatim minus the user token (lose-nothing direction). data_type is
    // free text on the table, so no schema change rides with this.
    const genericWellnessTypes: Array<
      [
        keyof Pick<
          GarminPushNotification,
          | "hrv"
          | "pulseOx"
          | "respiration"
          | "healthSnapshot"
          | "bloodPressures"
          | "skinTemp"
        >,
        string,
      ]
    > = [
      ["hrv", "hrv"],
      ["pulseOx", "pulse_ox"],
      ["respiration", "respiration"],
      ["healthSnapshot", "health_snapshot"],
      ["bloodPressures", "blood_pressures"],
      ["skinTemp", "skin_temp"],
    ];
    for (const [bodyKey, dataType] of genericWellnessTypes) {
      const summaries = body[bodyKey];
      if (!summaries || summaries.length === 0) continue;
      const stats = { processed: 0, errors: 0 };
      for (const summary of summaries) {
        try {
          const { data: mapping, error: mappingError } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", summary.userId)
            .single();

          if (!mapping) {
            logGarminMappingMiss(
              bodyKey,
              summary.userId,
              summary.summaryId,
              mappingError,
            );
            stats.errors++;
            continue;
          }

          // Never persist the user token; everything else is kept as sent.
          const { userAccessToken: _token, ...payload } = summary;

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: summary.userId,
            summary_id: summary.summaryId,
            data_type: dataType,
            calendar_date: resolveWellnessCalendarDate(summary),
            data: payload,
          };

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            logGarminRecordFailure({
              kind: bodyKey,
              garminUserId: summary.userId,
              summaryId: summary.summaryId,
              reason: "upsert_failed",
              error,
            });
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          logGarminRecordFailure({
            kind: bodyKey,
            garminUserId: summary.userId,
            summaryId: summary.summaryId,
            reason: "processing_threw",
            error: err,
          });
          stats.errors++;
        }
      }
      results[dataType] = stats;
    }

    // Process user permissions changes (just acknowledge - no data to store)
    if (body.userPermissionsChange && body.userPermissionsChange.length > 0) {
      console.log(
        `[garmin-push] User permissions change received for ${body.userPermissionsChange.length} user(s)`,
      );
      for (const perm of body.userPermissionsChange) {
        console.log(
          `[garmin-push] Permissions for user ${perm.userId}:`,
          JSON.stringify(perm.permissions),
        );
      }
      results.userPermissionsChange = {
        processed: body.userPermissionsChange.length,
        errors: 0,
      };
    }

    console.log("[garmin-push] Processing complete:", JSON.stringify(results));

    await stampIntegrationSyncHealth(supabase, body);
  } catch (err) {
    console.error("[garmin-push] Fatal error:", err);
  }
}

/// Garmin is push-based, so nothing ever ran a "sync" that could update
/// `integrations.last_sync_status` the way the pull providers (TP/FS/VDOT)
/// do client-side — every Garmin row sat at 'pending' forever even though
/// data was flowing. Stamp success whenever Garmin delivers data for a
/// mapped user: for a push provider, delivery IS the sync.
async function stampIntegrationSyncHealth(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  body: GarminPushNotification,
): Promise<void> {
  const dataSummaries = [
    body.activities,
    body.activityDetails,
    body.manuallyUpdatedActivities,
    body.dailies,
    body.epochs,
    body.sleeps,
    body.bodyComps,
    body.stressDetails,
    body.userMetrics,
  ];
  const garminUserIds = [
    ...new Set(
      dataSummaries.flatMap((entries) =>
        (entries ?? []).map((e) => e.userId).filter(Boolean)
      ),
    ),
  ];
  if (garminUserIds.length === 0) return;

  const { data: mappings, error: mapErr } = await supabase
    .from("garmin_user_mappings")
    .select("user_id")
    .in("garmin_user_id", garminUserIds);
  if (mapErr || !mappings || mappings.length === 0) return;

  const userIds = [
    ...new Set(mappings.map((m: { user_id: string }) => m.user_id)),
  ];
  const { error } = await supabase
    .from("integrations")
    .update({
      last_sync_status: "success",
      last_sync_at: new Date().toISOString(),
    })
    .eq("provider", "garmin")
    .in("user_id", userIds);
  if (error) {
    console.error("[garmin-push] Sync-health stamp failed:", error);
  }
}
