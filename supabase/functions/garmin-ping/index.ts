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
import { initSentry, withSentry } from "../_shared/sentry.ts";
import {
  mapGarminActivityToActivity,
  mapGarminDailySummary,
  mapGarminSleepSummary,
} from "../_shared/garmin/mappers.ts";
import {
  buildGarminCompletionUpdate,
  enrichCompletedGarminActivity,
  findMatchingPlannedActivity,
  getGarminScheduledDate,
  insertGarminActivityIfMissing,
} from "../_shared/garmin/activity_completion.ts";
import {
  buildGarminProviderLabel,
  sendActivityUploadedPush,
} from "../_shared/garmin/onesignal.ts";
import type {
  GarminActivityDetail,
  GarminActivitySummary,
  GarminBodyComposition,
  GarminDailySummary,
  GarminEpochSummary,
  GarminPingNotification,
  GarminSleepSummary,
  GarminStressDetail,
  GarminUserMetrics,
} from "../_shared/garmin/types.ts";

const GARMIN_CLIENT_ID = Deno.env.get("GARMIN_CLIENT_ID") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
} | undefined;

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req: Request) => {
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
}));

async function processPingBody(body: GarminPingNotification): Promise<void> {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { processed: number; errors: number }> = {};

    // Process activity pings using the same match-or-insert strategy as
    // garmin-push: complete a matching planned activity, otherwise auto-create
    // for endurance sports so the user gets a notification + nutrition surface.
    if (body.activities && body.activities.length > 0) {
      const stats = {
        processed: 0,
        errors: 0,
        matched: 0,
        inserted: 0,
        skipped: 0,
      };
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
              const outcome = await insertGarminActivityIfMissing(
                supabase,
                activity,
                activityRow,
              );
              switch (outcome.kind) {
                case "inserted":
                  console.log(
                    `[garmin-ping] Auto-created completed activity ${outcome.activityId} for ${sportType} on ${scheduledDate}`,
                  );
                  await sendActivityUploadedPush({
                    userId: mapping.user_id,
                    activityId: outcome.activityId,
                    scheduledDate,
                    provider: buildGarminProviderLabel(activity.deviceName),
                    logPrefix: "[garmin-ping]",
                  });
                  stats.inserted++;
                  stats.processed++;
                  break;
                case "duplicate": {
                  console.log(
                    `[garmin-ping] Activity for ${sportType} on ${scheduledDate} already inserted by a concurrent push — skipping duplicate notification`,
                  );
                  const dupSummaryId = activity.summaryId ??
                    (activity as { activityId?: string }).activityId;
                  if (dupSummaryId) {
                    await enrichCompletedGarminActivity(
                      supabase,
                      mapping.user_id,
                      String(dupSummaryId),
                      activityRow,
                      "[garmin-ping]",
                    );
                  }
                  stats.skipped++;
                  break;
                }
                case "skipped_non_endurance":
                  console.log(
                    `[garmin-ping] No matching planned activity for non-endurance sport "${outcome.sportType}" on ${scheduledDate} — skipping`,
                  );
                  stats.skipped++;
                  break;
                case "skipped_enum_not_ready":
                  console.warn(
                    `[garmin-ping] "other" activity_type not yet migrated on this database — skipping import for ${scheduledDate}`,
                  );
                  stats.skipped++;
                  break;
                case "skipped_no_summary_id":
                  console.warn(
                    "[garmin-ping] No matching planned activity and missing summaryId — skipping",
                  );
                  stats.errors++;
                  break;
                case "error":
                  console.error(
                    "[garmin-ping] Auto-create insert error:",
                    outcome.error,
                  );
                  stats.errors++;
                  break;
              }
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
              // The winning push may have carried a preliminary payload
              // (0 duration / 0 distance) — fill any metric gaps from ours.
              await enrichCompletedGarminActivity(
                supabase,
                mapping.user_id,
                String(summaryId),
                activityRow,
                "[garmin-ping]",
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
      const stats = {
        processed: 0,
        errors: 0,
        matched: 0,
        inserted: 0,
        skipped: 0,
      };
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
            // Guard against missing summaryId — same reasoning as garmin-push.
            const detailSummaryId = summary.summaryId ??
              (summary as { activityId?: string }).activityId ??
              (detail as { activityId?: string }).activityId;
            if (!detailSummaryId) {
              console.warn(
                "[garmin-ping] ActivityDetails missing summaryId — skipping",
              );
              stats.errors++;
              continue;
            }
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
              const outcome = await insertGarminActivityIfMissing(
                supabase,
                summary,
                activityRow,
              );
              switch (outcome.kind) {
                case "inserted":
                  console.log(
                    `[garmin-ping] Auto-created completed activity ${outcome.activityId} from detail ping for ${sportType} on ${scheduledDate}`,
                  );
                  await sendActivityUploadedPush({
                    userId: mapping.user_id,
                    activityId: outcome.activityId,
                    scheduledDate,
                    provider: buildGarminProviderLabel(summary.deviceName),
                    logPrefix: "[garmin-ping]",
                  });
                  stats.inserted++;
                  stats.processed++;
                  break;
                case "duplicate":
                  console.log(
                    `[garmin-ping] Activity for detail ${sportType} on ${scheduledDate} already inserted by a concurrent push — skipping duplicate notification`,
                  );
                  await enrichCompletedGarminActivity(
                    supabase,
                    mapping.user_id,
                    String(detailSummaryId),
                    activityRow,
                    "[garmin-ping]",
                  );
                  stats.skipped++;
                  break;
                case "skipped_non_endurance":
                  console.log(
                    `[garmin-ping] No matching planned activity for detail non-endurance sport "${outcome.sportType}" on ${scheduledDate} — skipping`,
                  );
                  stats.skipped++;
                  break;
                case "skipped_enum_not_ready":
                  console.warn(
                    `[garmin-ping] "other" activity_type not yet migrated on this database — skipping detail import for ${scheduledDate}`,
                  );
                  stats.skipped++;
                  break;
                case "skipped_no_summary_id":
                  console.warn(
                    "[garmin-ping] No matching planned activity for detail and missing summaryId — skipping",
                  );
                  stats.errors++;
                  break;
                case "error":
                  console.error(
                    "[garmin-ping] Auto-create insert error (detail):",
                    outcome.error,
                  );
                  stats.errors++;
                  break;
              }
              continue;
            }

            const updateFields = buildGarminCompletionUpdate(
              summary,
              activityRow,
            );
            updateFields.garmin_summary_id = String(detailSummaryId);

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
              // Detail pings usually carry the richest data — backfill any
              // metric gaps left by the preliminary payload that won the race.
              await enrichCompletedGarminActivity(
                supabase,
                mapping.user_id,
                String(detailSummaryId),
                activityRow,
                "[garmin-ping]",
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

    // Process body comp pings
    if (body.bodyComps && body.bodyComps.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.bodyComps) {
        try {
          if (!ping.callbackURL) {
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const bodyComps =
            (Array.isArray(data) ? data : [data]) as GarminBodyComposition[];

          for (const bodyComp of bodyComps) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = {
              user_id: mapping.user_id,
              garmin_user_id: ping.userId,
              summary_id: bodyComp.summaryId,
              data_type: "body_composition",
              calendar_date:
                new Date(bodyComp.measurementTimeInSeconds * 1000)
                  .toISOString()
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
              console.error("[garmin-ping] Body comp upsert error:", error);
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Body comp ping error:", err);
          stats.errors++;
        }
      }
      results.bodyComps = stats;
    }

    // Process stress detail pings
    if (body.stressDetails && body.stressDetails.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.stressDetails) {
        try {
          if (!ping.callbackURL) {
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const stresses =
            (Array.isArray(data) ? data : [data]) as GarminStressDetail[];

          for (const stress of stresses) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = {
              user_id: mapping.user_id,
              garmin_user_id: ping.userId,
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
              console.error("[garmin-ping] Stress upsert error:", error);
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Stress ping error:", err);
          stats.errors++;
        }
      }
      results.stressDetails = stats;
    }

    // Process epoch pings
    if (body.epochs && body.epochs.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.epochs) {
        try {
          if (!ping.callbackURL) {
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const epochs =
            (Array.isArray(data) ? data : [data]) as GarminEpochSummary[];

          for (const epoch of epochs) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const localEpochMs =
              (epoch.startTimeInSeconds + epoch.startTimeOffsetInSeconds) *
              1000;
            const calendarDate =
              new Date(localEpochMs).toISOString().split("T")[0];

            const record = {
              user_id: mapping.user_id,
              garmin_user_id: ping.userId,
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
              console.error("[garmin-ping] Epoch upsert error:", error);
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] Epoch ping error:", err);
          stats.errors++;
        }
      }
      results.epochs = stats;
    }

    // Process user metrics pings
    if (body.userMetrics && body.userMetrics.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.userMetrics) {
        try {
          if (!ping.callbackURL) {
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const metrics =
            (Array.isArray(data) ? data : [data]) as GarminUserMetrics[];

          for (const metric of metrics) {
            const { data: mapping } = await supabase
              .from("garmin_user_mappings")
              .select("user_id")
              .eq("garmin_user_id", ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = {
              user_id: mapping.user_id,
              garmin_user_id: ping.userId,
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
              console.error("[garmin-ping] User metrics upsert error:", error);
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error("[garmin-ping] User metrics ping error:", err);
          stats.errors++;
        }
      }
      results.userMetrics = stats;
    }

    console.log("[garmin-ping] Processing complete:", JSON.stringify(results));
  } catch (err) {
    console.error("[garmin-ping] Fatal error:", err);
  }
}
