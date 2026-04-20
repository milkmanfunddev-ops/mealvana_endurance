/**
 * Garmin Deregistration Handler
 *
 * Called when a user disconnects Mealvana from their Garmin account
 * (either from Garmin Connect settings or our app).
 *
 * Flow:
 * 1. Garmin POSTs deregistration notification with Garmin userIds
 * 2. We validate the request
 * 3. For each user, we mark the integration as inactive
 * 4. Clean up the garmin_user_mappings entry
 *
 * Endpoint: POST /functions/v1/garmin-deregistration
 * Auth: garmin-client-id header validation
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { validateGarminRequest } from '../_shared/garmin/auth.ts';
import type { GarminDeregistrationNotification } from '../_shared/garmin/types.ts';

const GARMIN_CLIENT_ID = Deno.env.get('GARMIN_CLIENT_ID') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

serve(async (req: Request) => {
  // Validate the request is from Garmin
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-deregistration] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const body: GarminDeregistrationNotification = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (!body.deregistrations || body.deregistrations.length === 0) {
      return new Response(JSON.stringify({ success: true, processed: 0 }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    let processed = 0;
    let errors = 0;

    for (const dereg of body.deregistrations) {
      try {
        // Delete the user mapping (this effectively disconnects the integration)
        const { error } = await supabase
          .from('garmin_user_mappings')
          .delete()
          .eq('garmin_user_id', dereg.userId);

        if (error) {
          console.error(`[garmin-deregistration] Delete error for ${dereg.userId}:`, error);
          errors++;
        } else {
          console.log(`[garmin-deregistration] Deregistered Garmin userId: ${dereg.userId}`);
          processed++;
        }
      } catch (err) {
        console.error(`[garmin-deregistration] Processing error:`, err);
        errors++;
      }
    }

    console.log(`[garmin-deregistration] Complete: ${processed} processed, ${errors} errors`);

    return new Response(
      JSON.stringify({ success: true, processed, errors }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('[garmin-deregistration] Fatal error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
