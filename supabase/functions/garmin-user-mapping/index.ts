import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { handleCors } from '../_shared/cors.ts';
import { errorResponse, successResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const GARMIN_USER_ID_URL =
  'https://apis.garmin.com/wellness-api/rest/user/id';

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

async function verifyGarminUserId(
  accessToken: string,
  expectedGarminUserId: string,
): Promise<Response | null> {
  const response = await fetch(GARMIN_USER_ID_URL, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    const body = await response.text();
    console.error(
      `[garmin-user-mapping] Garmin user verification failed: ${response.status}`,
      body,
    );
    return errorResponse('Unable to verify Garmin account', 401);
  }

  const payload = await response.json();
  if (payload.userId !== expectedGarminUserId) {
    console.error('[garmin-user-mapping] Garmin user ID mismatch', {
      expectedGarminUserId,
      actualGarminUserId: payload.userId,
    });
    return errorResponse('Garmin account verification mismatch', 403);
  }

  return null;
}

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req: Request) => {
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
      let query = supabase
        .from('garmin_user_mappings')
        .delete()
        .eq('user_id', user.id);

      if (body.garmin_user_id) {
        query = query.eq('garmin_user_id', body.garmin_user_id);
      }

      const { error } = await query;
      if (error) {
        console.error('[garmin-user-mapping] Delete error:', error);
        return errorResponse('Failed to delete Garmin mapping', 500, error.message);
      }

      let countQuery = supabase
        .from('garmin_user_mappings')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user.id);

      if (body.garmin_user_id) {
        countQuery = countQuery.eq('garmin_user_id', body.garmin_user_id);
      }

      const { count, error: countError } = await countQuery;
      if (countError) {
        console.error('[garmin-user-mapping] Delete verification error:', countError);
        return errorResponse('Failed to verify Garmin mapping deletion', 500, countError.message);
      }

      return successResponse({ action: 'delete', remaining: count ?? 0 });
    }

    if (action !== 'upsert') {
      return errorResponse('Invalid action', 400);
    }

    if (!body.garmin_user_id || !body.access_token) {
      return errorResponse('garmin_user_id and access_token are required', 400);
    }

    const verificationError = await verifyGarminUserId(
      body.access_token,
      body.garmin_user_id,
    );
    if (verificationError) return verificationError;

    const tokenExpiresAt =
      body.token_expires_at ??
      new Date(Date.now() + 60 * 60 * 1000).toISOString();

    const { error } = await supabase.from('garmin_user_mappings').upsert(
      {
        user_id: user.id,
        garmin_user_id: body.garmin_user_id,
        access_token: body.access_token,
        refresh_token: body.refresh_token ?? null,
        token_expires_at: tokenExpiresAt,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'garmin_user_id' },
    );

    if (error) {
      console.error('[garmin-user-mapping] Upsert error:', error);
      return errorResponse('Failed to save Garmin mapping', 500, error.message);
    }

    return successResponse({ action: 'upsert' });
  } catch (error) {
    console.error('[garmin-user-mapping] Fatal error:', error);
    return errorResponse('Internal server error', 500, String(error));
  }
}));
