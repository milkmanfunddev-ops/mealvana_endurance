import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { handleCors } from '../_shared/cors.ts';
import { errorResponse, successResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { deregisterGarminForUser } from '../_shared/garmin/token.ts';
import { deleteGarminMapping } from './delete.ts';
import { verifyGarminUserId } from './verify.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

type MappingRequest = {
  action?: 'upsert' | 'delete';
  user_id?: string;
  garmin_user_id?: string;
  access_token?: string;
  refresh_token?: string | null;
  token_expires_at?: string | null;
};

async function requireUser(req: Request) {
  const authHeader = req.headers.get('Authorization');
  const token = authHeader?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return { user: null, response: errorResponse('Missing authorization header', 401) };
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const {
    data: { user },
    error,
  } = await adminClient.auth.getUser(token);

  if (error || !user) {
    console.error('[garmin-user-mapping] Auth error:', error);
    return { user: null, response: errorResponse('Invalid or expired authentication token', 401) };
  }

  return { user, response: null };
}

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry('garmin-user-mapping', async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  try {
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse('Invalid authentication state', 401);

    const body = (await req.json()) as MappingRequest;
    const action = body.action ?? 'upsert';
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (body.user_id && body.user_id !== user.id) {
      return errorResponse('User ID does not match authenticated user', 403);
    }

    if (action === 'delete') {
      // Ticket 138 (112-010, 121-010): deregister at Garmin first, with a
      // fresh token, so Garmin stops pushing; a Garmin failure is logged and
      // the row is still deleted (delete.ts).
      const result = await deleteGarminMapping(supabase, user.id, body.garmin_user_id, {
        deregister: (userId) =>
          deregisterGarminForUser(supabase, userId, { logPrefix: '[garmin-user-mapping]' }),
      });
      if (!result.ok) {
        return errorResponse(result.message, result.status, result.details);
      }
      return successResponse({
        action: 'delete',
        remaining: result.remaining,
        garmin_deregistration: result.garmin,
      });
    }

    if (action !== 'upsert') {
      return errorResponse('Invalid action', 400);
    }

    if (!body.garmin_user_id || !body.access_token) {
      return errorResponse('garmin_user_id and access_token are required', 400);
    }

    const verification = await verifyGarminUserId(
      body.access_token,
      body.garmin_user_id,
    );
    if (!verification.ok) {
      return errorResponse(verification.message, verification.status);
    }

    // Q-INT8 (RULED 2026-09-10): `integrations` is the sole token
    // custodian. The mapping row carries ONLY the identity link
    // (garmin_user_id <-> user_id); the access_token in the request body is
    // still used above to VERIFY the claimed Garmin user id, but is never
    // persisted here. Existing copies are stripped by migration
    // 20260911160000.
    const { error } = await supabase.from('garmin_user_mappings').upsert(
      {
        user_id: user.id,
        garmin_user_id: body.garmin_user_id,
        access_token: null,
        refresh_token: null,
        token_expires_at: null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'garmin_user_id' },
    );

    if (error) {
      return errorResponse(
        'Failed to save Garmin mapping',
        500,
        error.message,
        undefined,
        error,
      );
    }

    return successResponse({ action: 'upsert' });
  } catch (error) {
    return errorResponse(
      'Internal server error',
      500,
      String(error),
      undefined,
      error,
    );
  }
}));
