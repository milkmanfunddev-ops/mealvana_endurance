/**
 * Garmin Push Notification Handler
 *
 * Garmin sends activity and health data directly to this endpoint
 * when users sync their devices. This is the primary data ingestion path.
 *
 * Endpoint: POST /functions/v1/garmin-push
 * Auth: garmin-client-id header validation
 *
 * Supported push types:
 * - activities: Activity summaries (runs, rides, swims, etc.)
 * - activityDetails: Detailed activity data with samples/laps
 * - dailies: Daily wellness summaries
 * - epochs: 15-minute granularity data
 * - sleeps: Sleep summaries
 * - bodyComps: Body composition measurements
 * - stressDetails: Stress + body battery timelines
 * - userMetrics: VO2 max, fitness age, etc.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { validateGarminRequest } from '../_shared/garmin/auth.ts';
import { mapGarminActivityToActivity, mapGarminDailySummary, mapGarminSleepSummary } from '../_shared/garmin/mappers.ts';
import type { GarminPushNotification } from '../_shared/garmin/types.ts';

const GARMIN_CLIENT_ID = Deno.env.get('GARMIN_CLIENT_ID') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

serve(async (req: Request) => {
  // Validate the request is from Garmin
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-push] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Respond 200 immediately - Garmin requires response within 30 seconds
  // We process asynchronously below, but for Deno serve we need to
  // complete processing before returning the response.
  try {
    const body: GarminPushNotification = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { processed: number; errors: number }> = {};

    // Process activities
    if (body.activities && body.activities.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const activity of body.activities) {
        try {
          // Look up our user by Garmin userId
          const { data: mapping } = await supabase
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', activity.userId)
            .single();

          if (!mapping) {
            console.warn(`[garmin-push] No user mapping for Garmin userId: ${activity.userId}`);
            stats.errors++;
            continue;
          }

          const activityRow = mapGarminActivityToActivity(activity, mapping.user_id);

          // Upsert using id (primary key) - never use onConflict with partial unique indexes
          const { error } = await supabase
            .from('activities')
            .upsert(activityRow, { onConflict: 'id' });

          if (error) {
            console.error(`[garmin-push] Activity upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
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
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', daily.userId)
            .single();

          if (!mapping) {
            console.warn(`[garmin-push] No user mapping for Garmin userId: ${daily.userId}`);
            stats.errors++;
            continue;
          }

          const record = mapGarminDailySummary(daily);
          record.user_id = mapping.user_id;

          const { error } = await supabase
            .from('garmin_health_data')
            .upsert(record, { onConflict: 'summary_id' });

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
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', sleep.userId)
            .single();

          if (!mapping) {
            console.warn(`[garmin-push] No user mapping for Garmin userId: ${sleep.userId}`);
            stats.errors++;
            continue;
          }

          const record = mapGarminSleepSummary(sleep);
          record.user_id = mapping.user_id;

          const { error } = await supabase
            .from('garmin_health_data')
            .upsert(record, { onConflict: 'summary_id' });

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
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', bodyComp.userId)
            .single();

          if (!mapping) {
            stats.errors++;
            continue;
          }

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: bodyComp.userId,
            summary_id: bodyComp.summaryId,
            data_type: 'body_composition',
            calendar_date: new Date(bodyComp.measurementTimeInSeconds * 1000).toISOString().split('T')[0],
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
            .from('garmin_health_data')
            .upsert(record, { onConflict: 'summary_id' });

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
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', stress.userId)
            .single();

          if (!mapping) {
            stats.errors++;
            continue;
          }

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: stress.userId,
            summary_id: stress.summaryId,
            data_type: 'stress',
            calendar_date: stress.calendarDate,
            data: {
              duration_seconds: stress.durationInSeconds,
              stress_levels: stress.timeOffsetStressLevelValues,
              body_battery_values: stress.timeOffsetBodyBatteryValues,
            },
          };

          const { error } = await supabase
            .from('garmin_health_data')
            .upsert(record, { onConflict: 'summary_id' });

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

    // Process manually updated activities (same format as regular activities)
    if (body.manuallyUpdatedActivities && body.manuallyUpdatedActivities.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const activity of body.manuallyUpdatedActivities) {
        try {
          const { data: mapping } = await supabase
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', activity.userId)
            .single();

          if (!mapping) {
            console.warn(`[garmin-push] No user mapping for Garmin userId: ${activity.userId}`);
            stats.errors++;
            continue;
          }

          const activityRow = mapGarminActivityToActivity(activity, mapping.user_id);

          const { error } = await supabase
            .from('activities')
            .upsert(activityRow, { onConflict: 'id' });

          if (error) {
            console.error(`[garmin-push] Manually updated activity upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
          }
        } catch (err) {
          console.error(`[garmin-push] Manually updated activity processing error:`, err);
          stats.errors++;
        }
      }
      results.manuallyUpdatedActivities = stats;
    }

    // Process activity details (extract summary and process like regular activities)
    if (body.activityDetails && body.activityDetails.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const detail of body.activityDetails) {
        try {
          const { data: mapping } = await supabase
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', detail.userId)
            .single();

          if (!mapping) {
            console.warn(`[garmin-push] No user mapping for Garmin userId: ${detail.userId}`);
            stats.errors++;
            continue;
          }

          // Use the embedded summary for mapping
          const activityRow = mapGarminActivityToActivity(detail.summary, mapping.user_id);

          const { error } = await supabase
            .from('activities')
            .upsert(activityRow, { onConflict: 'id' });

          if (error) {
            console.error(`[garmin-push] Activity detail upsert error:`, error);
            stats.errors++;
          } else {
            stats.processed++;
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
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', epoch.userId)
            .single();

          if (!mapping) {
            stats.errors++;
            continue;
          }

          const localEpochMs = (epoch.startTimeInSeconds + epoch.startTimeOffsetInSeconds) * 1000;
          const calendarDate = new Date(localEpochMs).toISOString().split('T')[0];

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: epoch.userId,
            summary_id: epoch.summaryId,
            data_type: 'epoch',
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
            .from('garmin_health_data')
            .upsert(record, { onConflict: 'summary_id' });

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
            .from('garmin_user_mappings')
            .select('user_id')
            .eq('garmin_user_id', metric.userId)
            .single();

          if (!mapping) {
            stats.errors++;
            continue;
          }

          const record = {
            user_id: mapping.user_id,
            garmin_user_id: metric.userId,
            summary_id: metric.summaryId,
            data_type: 'user_metrics',
            calendar_date: metric.calendarDate,
            data: {
              vo2_max: metric.vo2Max,
              fitness_age: metric.fitnessAge,
            },
          };

          const { error } = await supabase
            .from('garmin_health_data')
            .upsert(record, { onConflict: 'summary_id' });

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
      console.log(`[garmin-push] User permissions change received for ${body.userPermissionsChange.length} user(s)`);
      for (const perm of body.userPermissionsChange) {
        console.log(`[garmin-push] Permissions for user ${perm.userId}:`, JSON.stringify(perm.permissions));
      }
      results.userPermissionsChange = { processed: body.userPermissionsChange.length, errors: 0 };
    }

    console.log('[garmin-push] Processing complete:', JSON.stringify(results));

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('[garmin-push] Fatal error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
