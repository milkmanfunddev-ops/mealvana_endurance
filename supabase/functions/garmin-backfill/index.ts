/**
 * Garmin Backfill Trigger
 *
 * Garmin's Health API is push-only — there is no on-demand pull endpoint for
 * body composition / weight. To retroactively get historical data (or to
 * "force a refresh" when the user expects fresh data but no device sync has
 * happened) we call Garmin's Backfill API, which asynchronously pushes the
 * requested summary windows back through our existing `garmin-push` webhook.
 *
 * Endpoint: POST /functions/v1/garmin-backfill
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Request body (all optional):
 *   {
 *     summary_types?: ('body_composition' | 'user_metrics' | 'dailies' | 'sleeps' | 'stress')[];
 *     window_days?: number;   // default 90, max 90 (Garmin's window limit)
 *   }
 *
 * Response:
 *   { success: true, queued: { body_composition: 202, user_metrics: 202 } }
 *
 * Garmin will then deliver the data via async webhook to garmin-push, which
 * mirrors body comp readings into `users.weight_pounds` / `users.body_fat_pct`.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { handleCors } from '../_shared/cors.ts';
import { errorResponse, successResponse } from '../_shared/responses.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/**
 * Maps our internal summary-type identifiers to Garmin's backfill path
 * segment. The path under wellness-api/rest/backfill/ is camelCase per
 * Garmin's Health API surface.
 */
const GARMIN_BACKFILL_PATH: Record<string, string> = {
  body_composition: 'bodyComps',
  user_metrics: 'userMetrics',
  dailies: 'dailies',
  sleeps: 'sleeps',
  stress: 'stressDetails',
};

const DEFAULT_SUMMARY_TYPES = ['body_composition', 'user_metrics'];
const MAX_WINDOW_DAYS = 90;
const GARMIN_BACKFILL_BASE = 'https://apis.garmin.com/wellness-api/rest/backfill';

interface BackfillRequest {
  summary_types?: string[];
  window_days?: number;
}

async function requireUser(req: Request) {
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return {
      user: null,
      response: errorResponse('Missing authorization header', 401),
    };
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const {
    data: { user },
    error,
  } = await adminClient.auth.getUser(token);

  if (error || !user) {
    console.error('[garmin-backfill] Auth error:', error);
    return {
      user: null,
      response: errorResponse('Invalid or expired authentication token', 401),
    };
  }

  return { user, response: null };
}

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  try {
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse('Invalid authentication state', 401);

    let body: BackfillRequest = {};
    try {
      const text = await req.text();
      if (text.trim().length > 0) {
        body = JSON.parse(text) as BackfillRequest;
      }
    } catch (_) {
      // Tolerate missing/invalid body — fall back to defaults below.
    }

    const summaryTypes = (body.summary_types?.length
      ? body.summary_types
      : DEFAULT_SUMMARY_TYPES).filter((t) => t in GARMIN_BACKFILL_PATH);

    if (summaryTypes.length === 0) {
      return errorResponse(
        `No supported summary_types provided. Allowed: ${
          Object.keys(GARMIN_BACKFILL_PATH).join(', ')
        }`,
        400,
      );
    }

    const windowDays = Math.min(
      Math.max(Math.floor(body.window_days ?? MAX_WINDOW_DAYS), 1),
      MAX_WINDOW_DAYS,
    );

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: mapping, error: mappingErr } = await supabase
      .from('garmin_user_mappings')
      .select('garmin_user_id, access_token, token_expires_at')
      .eq('user_id', user.id)
      .maybeSingle();

    if (mappingErr) {
      console.error('[garmin-backfill] Mapping lookup error:', mappingErr);
      return errorResponse('Failed to look up Garmin mapping', 500);
    }
    if (!mapping?.access_token) {
      return errorResponse(
        'Garmin is not connected for this user',
        404,
      );
    }

    // Garmin's backfill takes a window in UNIX seconds. We request whole-day
    // boundaries so we don't accidentally split a measurement record.
    const nowSec = Math.floor(Date.now() / 1000);
    const endSec = nowSec;
    const startSec = endSec - windowDays * 86400;

    const queued: Record<string, number> = {};
    const errors: Record<string, string> = {};

    for (const summaryType of summaryTypes) {
      const path = GARMIN_BACKFILL_PATH[summaryType];
      const url =
        `${GARMIN_BACKFILL_BASE}/${path}?summaryStartTimeInSeconds=${startSec}&summaryEndTimeInSeconds=${endSec}`;

      try {
        // Garmin's backfill API rejects empty body (502) AND missing
        // Content-Length (411 Length Required). The endpoint accepts no
        // payload — params are entirely in the query string — so the
        // working combination is: no body + explicit `Content-Length: 0`.
        const resp = await fetch(url, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${mapping.access_token}`,
            'Content-Length': '0',
          },
        });

        queued[summaryType] = resp.status;

        if (!resp.ok) {
          const text = await resp.text();
          errors[summaryType] = text.slice(0, 500);
          console.error(
            `[garmin-backfill] ${summaryType} → ${resp.status}: ${text}`,
          );
        } else {
          console.log(
            `[garmin-backfill] ${summaryType} queued (status ${resp.status}) for user ${user.id}, window ${startSec}-${endSec}`,
          );
        }
      } catch (err) {
        errors[summaryType] = String(err);
        console.error(`[garmin-backfill] ${summaryType} fetch error:`, err);
      }
    }

    const allFailed = Object.keys(queued).length === 0 ||
      Object.values(queued).every((s) => s >= 400);

    if (allFailed) {
      return errorResponse(
        'Garmin backfill request failed for all summary types',
        502,
        JSON.stringify(errors),
      );
    }

    return successResponse({
      queued,
      errors: Object.keys(errors).length > 0 ? errors : undefined,
      window: { start_seconds: startSec, end_seconds: endSec },
    });
  } catch (err) {
    console.error('[garmin-backfill] Fatal error:', err);
    return errorResponse('Internal server error', 500, String(err));
  }
});
