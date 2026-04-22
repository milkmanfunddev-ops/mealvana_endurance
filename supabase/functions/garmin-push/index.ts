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
import { validateGarminRequest } from "../_shared/garmin/auth.ts";
import {
  garminTimestampToDateString,
  mapGarminActivityToActivity,
  mapGarminDailySummary,
  mapGarminSleepSummary,
  mapGarminSportType,
} from "../_shared/garmin/mappers.ts";
import {
  buildGarminCompletionUpdate,
  findMatchingPlannedActivity,
} from "../_shared/garmin/activity_completion.ts";
import {
  buildGarminProviderLabel,
  sendActivityUploadedPush,
} from "../_shared/garmin/onesignal.ts";
import type { GarminPushNotification } from "../_shared/garmin/types.ts";

const GARMIN_CLIENT_ID = Deno.env.get("GARMIN_CLIENT_ID") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

// Supabase edge runtime global for background task lifetime.
// See: https://supabase.com/docs/guides/functions/background-tasks
declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
} | undefined;

serve(async (req: Request) => {
  // Validate the request is from Garmin (header-only, synchronous)
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-push] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse the body BEFORE returning the response. The request body stream
  // is closed once we return, so any deferred `req.json()` call fails with
  // "Interrupted: operation canceled". JSON parsing is fast (< a few ms
  // even for 100MB payloads) — only the DB writes + outbound fetches get
  // moved to the background task below.
  let body: GarminPushNotification;
  try {
    body = await req.json();
  } catch (err) {
    console.error("[garmin-push] Failed to parse request body:", err);
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Garmin requires HTTP 200 returned asynchronously within 30 seconds.
  // Ack immediately and process the parsed payload in the background.
  const processing = processPushBody(body).catch((err) => {
    console.error("[garmin-push] Background processing error:", err);
  });

  if (typeof EdgeRuntime !== "undefined") {
    EdgeRuntime.waitUntil(processing);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

async function processPushBody(body: GarminPushNotification): Promise<void> {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { processed: number; errors: number }> = {};

    // Process activities — with matching to existing planned activities
    if (body.activities && body.activities.length > 0) {
      const stats = { processed: 0, errors: 0, matched: 0, skipped: 0 };
      for (const activity of body.activities) {
        try {
          // Look up our user by Garmin userId
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", activity.userId)
            .single();

          if (!mapping) {
            console.warn(
              `[garmin-push] No user mapping for Garmin userId: ${activity.userId}`,
            );
            stats.errors++;
            continue;
          }

          const activityRow = mapGarminActivityToActivity(
            activity,
            mapping.user_id,
          );
          const sportType = mapGarminSportType(activity.activityType);
          const scheduledDate = garminTimestampToDateString(
            activity.startTimeInSeconds,
            activity.startTimeOffsetInSeconds,
          );

          // Try to match an existing planned activity from TP/FS
          const matchedActivity = await findMatchingPlannedActivity(
            supabase,
            mapping.user_id,
            sportType,
            activity,
          );

          if (matchedActivity) {
            // Update the existing planned activity with Garmin completion data
            // while preserving the original provider identity (TP/FS/etc).
            // Store Garmin linkage separately for follow-up Garmin updates.
            const summaryId = activity.summaryId ??
              (activity as { activityId?: string }).activityId;
            if (!summaryId) {
              console.warn(
                "[garmin-push] Missing activity summary id - skipping",
              );
              stats.errors++;
              continue;
            }
            const updateFields = buildGarminCompletionUpdate(
              activity,
              activityRow,
            );
            updateFields.garmin_summary_id = String(summaryId);

            // Atomic "win-the-race" update: only complete the activity if it
            // is still planned/draft. Garmin often fires the Activities and
            // ActivityDetails webhooks for the same workout simultaneously;
            // whichever request updates the row first gets to notify.
            const { data: updatedRows, error } = await supabase
              .from("activities")
              .update(updateFields)
              .eq("id", matchedActivity.id)
              .in("status", ["planned", "draft"])
              .select("id");

            if (error) {
              console.error(
                `[garmin-push] Matched activity update error:`,
                error,
              );
              stats.errors++;
            } else if (!updatedRows || updatedRows.length === 0) {
              console.log(
                `[garmin-push] Activity ${matchedActivity.id} already completed by a concurrent push - skipping duplicate notification`,
              );
              stats.skipped++;
            } else {
              console.log(
                `[garmin-push] Matched & completed activity ${matchedActivity.id} (${matchedActivity.title})`,
              );
              await sendActivityUploadedPush({
                userId: mapping.user_id,
                activityId: String(matchedActivity.id),
                scheduledDate,
                provider: buildGarminProviderLabel(activity.deviceName),
                logPrefix: "[garmin-push]",
              });
              stats.matched++;
              stats.processed++;
            }
          } else {
            console.log(
              `[garmin-push] No matching planned activity for ${sportType} on ${scheduledDate} — skipping`,
            );
            stats.skipped++;
          }
        } catch (err) {
          console.error(`[garmin-push] Activity processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", daily.userId)
            .single();

          if (!mapping) {
            console.warn(
              `[garmin-push] No user mapping for Garmin userId: ${daily.userId}`,
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
            console.error(`[garmin-push] Daily upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] Daily processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", sleep.userId)
            .single();

          if (!mapping) {
            console.warn(
              `[garmin-push] No user mapping for Garmin userId: ${sleep.userId}`,
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
            console.error(`[garmin-push] Sleep upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] Sleep processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", bodyComp.userId)
            .single();

          if (!mapping) {
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
            },
          };

          const { error } = await supabase
            .from("garmin_health_data")
            .upsert(record, { onConflict: "summary_id" });

          if (error) {
            console.error(`[garmin-push] Body comp upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] Body comp processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", stress.userId)
            .single();

          if (!mapping) {
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
            console.error(`[garmin-push] Stress upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] Stress processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", activity.userId)
            .single();

          if (!mapping) {
            console.warn(
              `[garmin-push] No user mapping for Garmin userId: ${activity.userId}`,
            );
            stats.errors++;
            continue;
          }

          const summaryId = activity.summaryId ??
            (activity as { activityId?: string }).activityId;
          if (!summaryId) {
            console.warn(
              "[garmin-push] Missing manual-update summary id - skipping",
            );
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
            duration_minutes: activityRow.duration_minutes,
            distance_meters: activityRow.distance_meters,
          };

          if (activityRow.average_pace_minutes_per_mile !== undefined) {
            updateFields.average_pace_minutes_per_mile =
              activityRow.average_pace_minutes_per_mile;
          }
          if (activityRow.distance_miles !== undefined) {
            updateFields.distance_miles = activityRow.distance_miles;
          }

          const { error } = await supabase
            .from("activities")
            .update(updateFields)
            .eq("id", existing[0].id);

          if (error) {
            console.error(
              `[garmin-push] Manually updated activity error:`,
              error,
            );
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
          console.error(
            `[garmin-push] Manually updated activity processing error:`,
            err,
          );
          stats.errors++;
        }
      }
      results.manuallyUpdatedActivities = stats;
    }

    // Process activity details — same match-only strategy as regular activities.
    // Only update an existing planned activity if one matches.
    if (body.activityDetails && body.activityDetails.length > 0) {
      const stats = { processed: 0, errors: 0, matched: 0, skipped: 0 };
      for (const detail of body.activityDetails) {
        try {
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", detail.userId)
            .single();

          if (!mapping) {
            console.warn(
              `[garmin-push] No user mapping for Garmin userId: ${detail.userId}`,
            );
            stats.errors++;
            continue;
          }

          const summary = detail.summary;
          const activityRow = mapGarminActivityToActivity(
            summary,
            mapping.user_id,
          );
          const sportType = mapGarminSportType(summary.activityType);
          const scheduledDate = garminTimestampToDateString(
            summary.startTimeInSeconds,
            summary.startTimeOffsetInSeconds,
          );

          const matchedActivity = await findMatchingPlannedActivity(
            supabase,
            mapping.user_id,
            sportType,
            summary,
          );

          if (matchedActivity) {
            const updateFields = buildGarminCompletionUpdate(
              summary,
              activityRow,
            );
            updateFields.garmin_summary_id = String(summary.summaryId);

            const { data: updatedRows, error } = await supabase
              .from("activities")
              .update(updateFields)
              .eq("id", matchedActivity.id)
              .in("status", ["planned", "draft"])
              .select("id");

            if (error) {
              console.error(
                `[garmin-push] Activity detail matched update error:`,
                error,
              );
              stats.errors++;
            } else if (!updatedRows || updatedRows.length === 0) {
              console.log(
                `[garmin-push] Activity ${matchedActivity.id} already completed by a concurrent push - skipping duplicate notification`,
              );
              stats.skipped++;
            } else {
              console.log(
                `[garmin-push] Matched & completed activity ${matchedActivity.id} from detail push`,
              );
              await sendActivityUploadedPush({
                userId: mapping.user_id,
                activityId: String(matchedActivity.id),
                scheduledDate,
                provider: buildGarminProviderLabel(summary.deviceName),
                logPrefix: "[garmin-push]",
              });
              stats.matched++;
              stats.processed++;
            }
          } else {
            console.log(
              `[garmin-push] No matching planned activity for detail ${sportType} on ${scheduledDate} — skipping`,
            );
            stats.skipped++;
          }
        } catch (err) {
          console.error(`[garmin-push] Activity detail processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", epoch.userId)
            .single();

          if (!mapping) {
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
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] Epoch processing error:`, err);
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
          const { data: mapping } = await supabase
            .from("garmin_user_mappings")
            .select("user_id")
            .eq("garmin_user_id", metric.userId)
            .single();

          if (!mapping) {
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
            console.error(`[garmin-push] User metrics upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] User metrics processing error:`, err);
          stats.errors++;
        }
      }
      results.userMetrics = stats;
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
  } catch (err) {
    console.error("[garmin-push] Fatal error:", err);
  }
}
