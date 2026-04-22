/**
 * Garmin Ping Notification Handler
 *
 * Garmin sends a "ping" notification indicating data is available,
 * along with callback URLs to fetch the actual data.
 *
 * Flow:
 * 1. Garmin POSTs ping notification with callback URLs
 * 2. We validate the request
 * 3. For each ping entry, we GET the callback URL to fetch data
 * 4. We process the fetched data (same as push handler)
 *
 * Endpoint: POST /functions/v1/garmin-ping
 * Auth: garmin-client-id header validation
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import {
  fetchGarminCallback,
  validateGarminRequest,
} from "../_shared/garmin/auth.ts";
import {
  mapGarminActivityToActivity,
  mapGarminDailySummary,
  mapGarminSleepSummary,
} from "../_shared/garmin/mappers.ts";
import {
  buildGarminCompletionUpdate,
  findMatchingPlannedActivity,
  getGarminScheduledDate,
} from "../_shared/garmin/activity_completion.ts";
import {
  buildGarminProviderLabel,
  sendActivityUploadedPush,
} from "../_shared/garmin/onesignal.ts";
import type {
  GarminActivityDetail,
  GarminActivitySummary,
  GarminDailySummary,
  GarminPingNotification,
  GarminSleepSummary,
} from "../_shared/garmin/types.ts";

const GARMIN_CLIENT_ID = Deno.env.get("GARMIN_CLIENT_ID") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
} | undefined;

serve(async (req: Request) => {
  // Validate the request is from Garmin (header-only, synchronous)
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-ping] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse body before returning — the request stream is closed after the
  // response, so any deferred `req.json()` fails with "Interrupted".
  let body: GarminPingNotification;
  try {
    body = await req.json();
  } catch (err) {
    console.error("[garmin-ping] Failed to parse request body:", err);
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Ack 200 immediately; fetch callbacks + DB writes happen in background.
  const processing = processPingBody(body).catch((err) => {
    console.error("[garmin-ping] Background processing error:", err);
  });

  if (typeof EdgeRuntime !== "undefined") {
    EdgeRuntime.waitUntil(processing);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

async function processPingBody(body: GarminPingNotification): Promise<void> {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { processed: number; errors: number }> = {};

    // Process activity pings using the same match-only strategy as garmin-push.
    // Ping notifications should complete an existing planned activity instead of
    // inserting standalone Garmin workouts.
    if (body.activities && body.activities.length > 0) {
      const stats = { processed: 0, errors: 0, matched: 0, skipped: 0 };
      for (const ping of body.activities) {
        try {
          if (!ping.callbackURL) {
            console.warn("[garmin-ping] Activity ping missing callbackURL");
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const activities =
            (Array.isArray(data) ? data : [data]) as GarminActivitySummary[];

          for (const activity of activities) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              console.warn(
                `[garmin-ping] No user mapping for Garmin userId: ${ping.userId}`,
              );
              stats.errors++;
              continue;
            }

            const activityRow = mapGarminActivityToActivity(
              activity,
              mapping.user_id,
            );
            const sportType = activityRow.activity_type?.toString() ?? "other";
            const scheduledDate = getGarminScheduledDate(activity);
            const matchedActivity = await findMatchingPlannedActivity(
              supabase,
              mapping.user_id,
              sportType,
              activity,
            );

            if (!matchedActivity) {
              console.log(
                `[garmin-ping] No matching planned activity for ${sportType} on ${scheduledDate} - skipping`,
              );
              stats.skipped++;
              continue;
            }

            const summaryId = activity.summaryId ??
              (activity as { activityId?: string }).activityId;
            if (!summaryId) {
              console.warn("[garmin-ping] Missing activity summary id");
              stats.errors++;
              continue;
            }

            const updateFields = buildGarminCompletionUpdate(
              activity,
              activityRow,
            );
            updateFields.garmin_summary_id = String(summaryId);

            const { data: updatedRows, error } = await supabase
              .from("activities")
              .update(updateFields)
              .eq("id", matchedActivity.id)
              .in("status", ["planned", "draft"])
              .select("id");

            if (error) {
              console.error(
                "[garmin-ping] Activity match update error:",
                error,
              );
              stats.errors++;
            } else if (!updatedRows || updatedRows.length === 0) {
              console.log(
                `[garmin-ping] Activity ${matchedActivity.id} already completed by a concurrent push - skipping duplicate notification`,
              );
              stats.skipped++;
            } else {
              console.log(
                `[garmin-ping] Matched & completed activity ${matchedActivity.id} (${matchedActivity.title})`,
              );
              await sendActivityUploadedPush({
                userId: mapping.user_id,
                activityId: String(matchedActivity.id),
                scheduledDate,
                provider: buildGarminProviderLabel(activity.deviceName),
                logPrefix: "[garmin-ping]",
              });
              stats.matched++;
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Activity ping error:", err);
          stats.errors++;
        }
      }
      results.activities = stats;
    }

    if (body.activityDetails && body.activityDetails.length > 0) {
      const stats = { processed: 0, errors: 0, matched: 0, skipped: 0 };
      for (const ping of body.activityDetails) {
        try {
          if (!ping.callbackURL) {
            console.warn(
              "[garmin-ping] Activity detail ping missing callbackURL",
            );
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const details =
            (Array.isArray(data) ? data : [data]) as GarminActivityDetail[];

          for (const detail of details) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              console.warn(
                `[garmin-ping] No user mapping for Garmin userId: ${ping.userId}`,
              );
              stats.errors++;
              continue;
            }

            const summary = detail.summary;
            const activityRow = mapGarminActivityToActivity(
              summary,
              mapping.user_id,
            );
            const sportType = activityRow.activity_type?.toString() ?? "other";
            const scheduledDate = getGarminScheduledDate(summary);
            const matchedActivity = await findMatchingPlannedActivity(
              supabase,
              mapping.user_id,
              sportType,
              summary,
            );

            if (!matchedActivity) {
              console.log(
                `[garmin-ping] No matching planned activity for detail ${sportType} on ${scheduledDate} - skipping`,
              );
              stats.skipped++;
              continue;
            }

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
                "[garmin-ping] Activity detail match update error:",
                error,
              );
              stats.errors++;
            } else if (!updatedRows || updatedRows.length === 0) {
              console.log(
                `[garmin-ping] Activity ${matchedActivity.id} already completed by a concurrent push - skipping duplicate notification`,
              );
              stats.skipped++;
            } else {
              console.log(
                `[garmin-ping] Matched & completed activity ${matchedActivity.id} from detail ping`,
              );
              await sendActivityUploadedPush({
                userId: mapping.user_id,
                activityId: String(matchedActivity.id),
                scheduledDate,
                provider: buildGarminProviderLabel(summary.deviceName),
                logPrefix: "[garmin-ping]",
              });
              stats.matched++;
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Activity detail ping error:", err);
          stats.errors++;
        }
      }
      results.activityDetails = stats;
    }

    // Process daily pings
    if (body.dailies && body.dailies.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.dailies) {
        try {
          if (!ping.callbackURL) {
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const dailies =
            (Array.isArray(data) ? data : [data]) as GarminDailySummary[];

          for (const daily of dailies) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = mapGarminDailySummary(daily);
            record.user_id = mapping.user_id;

            const { error } = await supabase
              .from("garmin_health_data")
              .upsert(record, { onConflict: "summary_id" });

            if (error) {
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Daily ping error:", err);
          stats.errors++;
        }
      }
      results.dailies = stats;
    }

    // Process sleep pings
    if (body.sleeps && body.sleeps.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.sleeps) {
        try {
          if (!ping.callbackURL) {
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const sleeps =
            (Array.isArray(data) ? data : [data]) as GarminSleepSummary[];

          for (const sleep of sleeps) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = mapGarminSleepSummary(sleep);
            record.user_id = mapping.user_id;

            const { error } = await supabase
              .from("garmin_health_data")
              .upsert(record, { onConflict: "summary_id" });

            if (error) {
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Sleep ping error:", err);
          stats.errors++;
        }
      }
      results.sleeps = stats;
    }

    console.log("[garmin-ping] Processing complete:", JSON.stringify(results));
  } catch (err) {
    console.error("[garmin-ping] Fatal error:", err);
  }
}
