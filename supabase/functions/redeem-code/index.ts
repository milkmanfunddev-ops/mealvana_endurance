/**
 * redeem-code Edge Function — our own codes: coach, influencer and giveaway (mp-458).
 *
 * POST /functions/v1/redeem-code     Auth: Supabase user JWT (signed in, not anonymous)
 * Body: { code: string }             case and spaces do not matter
 *
 * What each code does, the answers and the refusals are in handler.ts. The
 * codes live in `public.codes` (migration 20260921140000_codes.sql), which only
 * the service role reads or writes; a code is seeded by hand with SQL.
 *
 * Secrets:
 *   REVENUECAT_SECRET_KEY  RevenueCat v2 secret API key (the webhook's). Grants
 *                          and subscriber attributes go through it; without it
 *                          a redemption answers 502 and the claim is released.
 *   REVENUECAT_PROJECT_ID  optional, defaults to proj77b3c48f
 *
 * Deploy: ./scripts/deploy_dev.sh redeem-code  (verify_jwt stays on; the caller
 * is also resolved from the token here, since the gateway accepts the anon key).
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { makeRevenueCatClient, type RevenueCatClient } from '../_shared/revenuecat/client.ts';
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from '../_shared/vana/env.ts';
import { type Caller, makeRedeemHandler } from './handler.ts';

/** One RevenueCat project serves dev and prod. */
const DEFAULT_REVENUECAT_PROJECT_ID = 'proj77b3c48f';

initSentry();

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Kept across requests so the `pro` entitlement id is looked up once per instance.
let revenueCat: RevenueCatClient | null = null;

async function callerFrom(req: Request): Promise<Caller | null> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  if (!token) return null;
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return null;
  return { userId: user.id, email: user.email ?? null, anonymous: user.is_anonymous === true };
}

serve(withSentry(makeRedeemHandler({
  caller: callerFrom,
  db: () => admin,
  revenueCat: () =>
    revenueCat ??= makeRevenueCatClient({
      secretKey: Deno.env.get('REVENUECAT_SECRET_KEY') ?? '',
      projectId: Deno.env.get('REVENUECAT_PROJECT_ID') || DEFAULT_REVENUECAT_PROJECT_ID,
    }),
})));
