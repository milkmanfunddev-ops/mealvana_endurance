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

declare const EdgeRuntime: {
  waitUntil(promise: Promise<unknown>): void;
} | undefined;

serve(async (req: Request) => {
  // Validate the request is from Garmin (header-only, synchronous)
  const validationError = validateGarminRequest(req, GARMIN_CLIENT_ID);
  if (validationError) {
    console.error(`[garmin-deregistration] Validation failed: ${validationError}`);
    return new Response(JSON.stringify({ error: validationError }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Parse body before returning — deferred `req.json()` after the response
  // returns fails with "Interrupted" because the request stream is closed.
  let body: GarminDeregistrationNotification;
  try {
    body = await req.json();
  } catch (err) {
    console.error('[garmin-deregistration] Failed to parse request body:', err);
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Ack 200 immediately; delete mappings in background so Garmin never waits.
  const processing = processDeregistrationBody(body).catch((err) => {
    console.error('[garmin-deregistration] Background processing error:', err);
  });

  if (typeof EdgeRuntime !== 'undefined') {
    EdgeRuntime.waitUntil(processing);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});

async function processDeregistrationBody(
  body: GarminDeregistrationNotification,
): Promise<void> {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (!body.deregistrations || body.deregistrations.length === 0) {
      return;
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
  } catch (err) {
    console.error('[garmin-deregistration] Fatal error:', err);
  }
}
