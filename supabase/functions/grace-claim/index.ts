/**
 * grace-claim Edge Function — the grace month for an old anonymous install
 * that signs up after the flip (mp-455 §4-5; paywall ticket 09).
 *
 * POST /functions/v1/grace-claim     Auth: Supabase user JWT (signed up, not anonymous)
 * Body: none
 *
 * Who gets what, and the answers, are in handler.ts.
 *
 * Secrets:
 *   GRACE_FLIP_AT          the flip, ISO with a zone, the same instant passed to
 *                          scripts/grace-grant.mjs --flip. Unset: every claim
 *                          answers 503 and nothing is granted.
 *   REVENUECAT_SECRET_KEY  RevenueCat v2 secret API key (the webhook's).
 *   REVENUECAT_PROJECT_ID  optional, defaults to proj77b3c48f
 *
 * Deploy: ./scripts/deploy_dev.sh grace-claim  (verify_jwt stays on; the caller
 * is also resolved from the token here, since the gateway accepts the anon key).
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { makeRevenueCatClient, type RevenueCatClient } from '../_shared/revenuecat/client.ts';
import { SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL } from '../_shared/vana/env.ts';
import { type ClaimCaller, makeGraceClaimHandler } from './handler.ts';

/** One RevenueCat project serves dev and prod. */
const DEFAULT_REVENUECAT_PROJECT_ID = 'proj77b3c48f';

initSentry();

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Kept across requests so the `pro` entitlement id is looked up once per instance.
let revenueCat: RevenueCatClient | null = null;

async function callerFrom(req: Request): Promise<ClaimCaller | null> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  if (!token) return null;
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return null;
  return {
    userId: user.id,
    anonymous: user.is_anonymous === true,
    createdAt: user.created_at,
    identities: (user.identities ?? []).map((i) => ({ provider: i.provider, created_at: i.created_at ?? null })),
  };
}

/** The flip, or null when unset or unreadable (a zone is required, as for the script). */
function flipAt(): Date | null {
  const raw = Deno.env.get('GRACE_FLIP_AT') ?? '';
  if (!/(Z|[+-]\d\d:\d\d)$/.test(raw)) return null;
  const at = new Date(raw);
  return Number.isNaN(at.getTime()) ? null : at;
}

serve(withSentry(makeGraceClaimHandler({
  caller: callerFrom,
  flipAt,
  revenueCat: () =>
    revenueCat ??= makeRevenueCatClient({
      secretKey: Deno.env.get('REVENUECAT_SECRET_KEY') ?? '',
      projectId: Deno.env.get('REVENUECAT_PROJECT_ID') || DEFAULT_REVENUECAT_PROJECT_ID,
    }),
})));
