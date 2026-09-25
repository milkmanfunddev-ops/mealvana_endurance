/**
 * Delete User Edge Function
 *
 * Completely deletes the caller's own account: public.users (CASCADE),
 * auth.users, then the RevenueCat customer (02-005, ticket 95). What each step
 * does and how a failure is handled is in handler.ts.
 *
 * Requires: Valid JWT token from authenticated user.
 *
 * Secrets:
 *   REVENUECAT_SECRET_KEY  RevenueCat v2 secret API key (the one redeem-code
 *                          and the webhook use). Without it the account is
 *                          still deleted and the skipped customer is logged.
 *   REVENUECAT_PROJECT_ID  optional, defaults to proj77b3c48f
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { makeRevenueCatClient, type RevenueCatClient } from '../_shared/revenuecat/client.ts';
import { makeDeleteUserHandler } from './handler.ts';

/** One RevenueCat project serves dev and prod. */
const DEFAULT_REVENUECAT_PROJECT_ID = 'proj77b3c48f';

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

let revenueCat: RevenueCatClient | null = null;

serve(withSentry(makeDeleteUserHandler({
  userClient: (authHeader) =>
    createClient(supabaseUrl, supabaseAnonKey, { global: { headers: { Authorization: authHeader } } }),
  admin: () => createClient(supabaseUrl, supabaseServiceKey),
  revenueCat: () =>
    revenueCat ??= makeRevenueCatClient({
      secretKey: Deno.env.get('REVENUECAT_SECRET_KEY') ?? '',
      projectId: Deno.env.get('REVENUECAT_PROJECT_ID') || DEFAULT_REVENUECAT_PROJECT_ID,
    }),
})));
