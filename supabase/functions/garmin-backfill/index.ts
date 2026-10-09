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
import {
  captureEdgeError,
  captureEdgeMessage,
  initSentry,
  withSentry,
} from '../_shared/sentry.ts';
import {
  classifyBackfillFailure,
  describeBackfillRejection,
  RATE_LIMIT_RETRY_AFTER_SECONDS,
} from './outcome.ts';
import type { ProviderErrorSummary } from '../_shared/provider_error.ts';
import {
  ensureFreshGarminToken,
  markGarminRequiresReauth,
} from '../_shared/garmin/token.ts';

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
  // Added 2026-08-24 for the missing-swim investigation. Garmin's Activity
  // webhook is push-only and fires once, at upload — so an activity that never
  // arrived (or arrived and was dropped) cannot be re-requested any other way.
  // Backfilling `activities` makes Garmin re-push a historical window through
  // garmin-push, where the inbound-payload log records each one BEFORE any gate
  // can discard it. Deliberately NOT in DEFAULT_SUMMARY_TYPES: this is a
  // diagnostic, and re-pushing months of activities is not something a routine
  // "refresh my weight" call should do.
  // ops/data/bug-reports/2026-08-24-final-surge-completed-workouts-import-as-planned.md
  activities: 'activities',
  // Added 2026-09-22. `activities` re-pushes SUMMARIES only — no samples — so
  // it cannot recover a heart-rate or pace curve. The per-second stream lives
  // on `activityDetails`, which is push-only (the REST pull is a ping
  // callback a push integration never receives), making backfill the sole
  // route to a detail we failed to retain. Diagnostic, like `activities`:
  // re-pushing a month of details is a lot of data, so it stays out of
  // DEFAULT_SUMMARY_TYPES and must be asked for by name.
  activity_details: 'activityDetails',
};

/**
 * Types billed against Garmin's ACTIVITY backfill window (30 days), not the
 * 90-day Health/Women's window. A set, not an equality test: when
 * `activity_details` was added as a second activity-scoped type, an
 * `=== 'activities'` check would have let it request up to 90 days, which
 * Garmin rejects upstream (the Q-INT18 failure, one type over).
 */
const ACTIVITY_SCOPED_TYPES = new Set(['activities', 'activity_details']);

const DEFAULT_SUMMARY_TYPES = ['body_composition', 'user_metrics'];
const MAX_WINDOW_DAYS = 90;
// Garmin's Activity-summaries backfill max is 30 days per request — smaller
// than the 90-day Health/Women's window. The old single clamp let an
// `activities` request through at up to 90 days, which Garmin rejects
// upstream (Q-INT18 recorded bug; fixed for the Q-INT27 connect-time
// activities backfill). Health types keep the 90-day window.
const MAX_ACTIVITY_WINDOW_DAYS = 30;
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

// Token refresh lives in _shared/garmin/token.ts (ticket 138): the same
// helper serves the mapping delete and delete-user's Garmin deregistration.

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry('garmin-backfill', async (req: Request) => {
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

    // Q-INT8: tokens live on the integrations row (sole custodian).
    const { data: mapping, error: mappingErr } = await supabase
      .from('integrations')
      .select('access_token, refresh_token, token_expires_at')
      .eq('user_id', user.id)
      .eq('provider', 'garmin')
      .maybeSingle();

    if (mappingErr) {
      return errorResponse(
        'Failed to look up Garmin connection',
        500,
        undefined,
        undefined,
        mappingErr,
      );
    }
    if (!mapping?.access_token) {
      return errorResponse(
        'Garmin is not connected for this user',
        404,
      );
    }

    // Refresh the Garmin OAuth token if needed so the backfill request isn't
    // rejected with "Token is not active".
    const accessToken = await ensureFreshGarminToken(
      supabase,
      mapping,
      user.id,
      { logPrefix: '[garmin-backfill]' },
    );

    // Garmin's backfill takes a window in UNIX seconds. We request whole-day
    // boundaries so we don't accidentally split a measurement record.
    const nowSec = Math.floor(Date.now() / 1000);
    const endSec = nowSec;
    const startSec = endSec - windowDays * 86400;

    const queued: Record<string, number> = {};
    // Ticket 76 (Finding 69-012): a rejected type keeps Garmin's status and
    // error code only, never its body; a thrown fetch keeps String(err).
    const errors: Record<string, ProviderErrorSummary | string> = {};
    // Finding 118-016: Garmin's "Token is not active" means the athlete has
    // to sign in again, not that Garmin is busy.
    let tokenInactive = false;

    for (const summaryType of summaryTypes) {
      const path = GARMIN_BACKFILL_PATH[summaryType];
      // Per-type clamp: activity-scoped types are capped at Garmin's 30-day
      // Activity max; everything else keeps the requested (<=90 day) window.
      const typeStartSec = ACTIVITY_SCOPED_TYPES.has(summaryType)
        ? endSec - Math.min(windowDays, MAX_ACTIVITY_WINDOW_DAYS) * 86400
        : startSec;
      const url =
        `${GARMIN_BACKFILL_BASE}/${path}?summaryStartTimeInSeconds=${typeStartSec}&summaryEndTimeInSeconds=${endSec}`;

      try {
        // Garmin's backfill API rejects empty body (502) AND missing
        // Content-Length (411 Length Required). The endpoint accepts no
        // payload — params are entirely in the query string — so the
        // working combination is: no body + explicit `Content-Length: 0`.
        const resp = await fetch(url, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Length': '0',
          },
        });

        queued[summaryType] = resp.status;

        if (!resp.ok) {
          const rejection = describeBackfillRejection(
            resp.status,
            await resp.text(),
          );
          errors[summaryType] = rejection.summary;
          tokenInactive ||= rejection.tokenInactive;
          captureEdgeMessage(`[garmin-backfill] ${summaryType} backfill rejected`, {
            level: 'warning',
            extra: {
              userId: user.id,
              summaryType,
              status: rejection.summary.status,
              error_code: rejection.summary.error_code,
              token_inactive: rejection.tokenInactive,
            },
          });
        } else {
          console.log(
            `[garmin-backfill] ${summaryType} queued (status ${resp.status}) for user ${user.id}, window ${startSec}-${endSec}`,
          );
        }
      } catch (err) {
        errors[summaryType] = String(err);
        captureEdgeError(err, {
          message: `[garmin-backfill] ${summaryType} fetch error`,
          extra: { userId: user.id, summaryType },
        });
      }
    }

    // A dead token, a Garmin throttle and a Garmin outage each get their own
    // answer (ticket 19); only the outage stays a 502. See outcome.ts.
    const failure = classifyBackfillFailure(queued);
    const needsReauth = tokenInactive ||
      failure?.code === 'garmin_reauth_required';
    if (needsReauth) {
      // Ticket 138 (Finding 118-016): mark the row so Connected Apps shows
      // Reconnect (as ticket 64 does for TrainingPeaks and V.O2). The answer
      // keeps ticket 19's 409 `garmin_reauth_required` shape, which the app
      // reads, and says requires_reauth so the phone's row can follow.
      await markGarminRequiresReauth(supabase, user.id, '[garmin-backfill]');
    }
    if (failure) {
      const response = errorResponse(
        failure.message,
        failure.status,
        JSON.stringify(errors),
        needsReauth
          ? { code: failure.code, requires_reauth: true }
          : { code: failure.code },
      );
      if (failure.code === 'garmin_rate_limited') {
        response.headers.set(
          'Retry-After',
          String(RATE_LIMIT_RETRY_AFTER_SECONDS),
        );
      }
      return response;
    }

    return successResponse({
      queued,
      errors: Object.keys(errors).length > 0 ? errors : undefined,
      window: { start_seconds: startSec, end_seconds: endSec },
    });
  } catch (err) {
    return errorResponse(
      'Internal server error',
      500,
      String(err),
      undefined,
      err,
    );
  }
}));
