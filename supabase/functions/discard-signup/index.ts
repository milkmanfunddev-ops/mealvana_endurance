/**
 * discard-signup Edge Function (testing-wave 121-003, Lee 2026-09-26).
 *
 * POST /functions/v1/discard-signup   Auth: the anon key (there is no session yet)
 * Body: { user_id: string, email: string }
 *
 * Deletes a fresh, never-confirmed, never-signed-in signup the athlete walked
 * away from on Verify your email ("Use a different email", "Log in"), when the
 * id and email match. Always answers 200 { ok: true } so it reveals nothing
 * about whether an address is an account. The rules are in handler.ts.
 *
 * Deploy: ./scripts/deploy_dev.sh discard-signup  (verify_jwt stays on: the
 * gateway takes the anon key, and the function needs no user).
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { makeDiscardSignupHandler } from './handler.ts';

initSentry();

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const admin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

serve(withSentry(makeDiscardSignupHandler({ admin: () => admin })));
