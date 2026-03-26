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

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { validateGarminRequest, fetchGarminCallback } from '../_shared/garmin/auth.ts';
import { mapGarminActivityToActivity, mapGarminDailySummary, mapGarminSleepSummary } from '../_shared/garmin/mappers.ts';
import type {
  GarminPingNotification,
  GarminActivitySummary,
  GarminDailySummary,
  GarminSleepSummary,
} from '../_shared/garmin/types.ts';

const GARMIN_CLIENT_ID = Deno.env.get('GARMIN_CLIENT_ID') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

serve(async (req: Request) => {
  // Validate the request is from Garmin
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-ping] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const body: GarminPingNotification = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const results: Record<string, { processed: number; errors: number }> = {};

    // Process activity pings
    if (body.activities && body.activities.length > 0) {
      const stats = { processed: 0, errors: 0 };
      for (const ping of body.activities) {
        try {
          if (!ping.callbackURL) {
            console.warn('[garmin-ping] Activity ping missing callbackURL');
            stats.errors++;
            continue;
          }

          const data = await fetchGarminCallback(ping.callbackURL);
          const activities = (Array.isArray(data) ? data : [data]) as GarminActivitySummary[];

          for (const activity of activities) {
            const { data: mapping } = await supabase
              .from('garmin_user_mappings')
              .select('user_id')
              .eq('garmin_user_id', ping.userId)
              .single();

            if (!mapping) {
              console.warn(`[garmin-ping] No user mapping for Garmin userId: ${ping.userId}`);
              stats.errors++;
              continue;
            }

            const activityRow = mapGarminActivityToActivity(activity, mapping.user_id);

            const { error } = await supabase
              .from('activities')
              .upsert(activityRow, { onConflict: 'id' });

            if (error) {
              console.error('[garmin-ping] Activity upsert error:', error);
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error('[garmin-ping] Activity ping error:', err);
          stats.errors++;
        }
      }
      results.activities = stats;
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
          const dailies = (Array.isArray(data) ? data : [data]) as GarminDailySummary[];

          for (const daily of dailies) {
            const { data: mapping } = await supabase
              .from('garmin_user_mappings')
              .select('user_id')
              .eq('garmin_user_id', ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = mapGarminDailySummary(daily);
            record.user_id = mapping.user_id;

            const { error } = await supabase
              .from('garmin_health_data')
              .upsert(record, { onConflict: 'summary_id' });

            if (error) {
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error('[garmin-ping] Daily ping error:', err);
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
          const sleeps = (Array.isArray(data) ? data : [data]) as GarminSleepSummary[];

          for (const sleep of sleeps) {
            const { data: mapping } = await supabase
              .from('garmin_user_mappings')
              .select('user_id')
              .eq('garmin_user_id', ping.userId)
              .single();

            if (!mapping) {
              stats.errors++;
              continue;
            }

            const record = mapGarminSleepSummary(sleep);
            record.user_id = mapping.user_id;

            const { error } = await supabase
              .from('garmin_health_data')
              .upsert(record, { onConflict: 'summary_id' });

            if (error) {
              stats.errors++;
            } else {
              stats.processed++;
            }
          }
        } catch (err) {
          console.error('[garmin-ping] Sleep ping error:', err);
          stats.errors++;
        }
      }
      results.sleeps = stats;
    }

    console.log('[garmin-ping] Processing complete:', JSON.stringify(results));

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('[garmin-ping] Fatal error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
