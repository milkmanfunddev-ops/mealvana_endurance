/**
 * vana-eval Edge Function: the eval system's way into Vana (eval-v2 ticket 02). DEV ONLY, never deployed to prod.
 * The contract is in handler.ts; the copy of an Eval athlete in copy.ts. This file wires the real clients.
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { jsonResponse } from '../_shared/responses.ts';
import { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } from '../_shared/vana/env.ts';
import { makeVanaEvalHandler } from './handler.ts';

const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const LIST_PAGE = 1000;

initSentry();

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });

const handle = makeVanaEvalHandler({
  caller: async (req) => {
    const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
    if (!token) return null;
    const { data: { user }, error } = await admin.auth.getUser(token);
    return error || !user ? null : user.id;
  },
  admin,
  auth: {
    create: async (email, password) => {
      const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, app_metadata: { vana_eval: true } });
      if (error || !data.user) throw new Error(`creating the copy's user: ${error?.message ?? 'no user'}`);
      return data.user.id;
    },
    signIn: async (email, password) => {
      const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
      const { data, error } = await anon.auth.signInWithPassword({ email, password });
      if (error || !data.session) throw new Error(`signing in as the copy: ${error?.message ?? 'no session'}`);
      return data.session.access_token;
    },
    remove: async (userId) => {
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error && !/not.?found/i.test(error.message)) throw new Error(`deleting the copy's user: ${error.message}`);
    },
    listStale: async (beforeIso) => {
      const ids: string[] = [];
      for (let page = 1; ; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: LIST_PAGE });
        if (error) throw new Error(`listing users: ${error.message}`);
        for (const u of data.users) if (u.app_metadata?.vana_eval === true && u.created_at < beforeIso) ids.push(u.id);
        if (data.users.length < LIST_PAGE) return ids;
      }
    },
  },
  secret: SUPABASE_SERVICE_ROLE_KEY,
  // The copy's own JWT on every request: PostgREST runs as `authenticated` with auth.uid() = the copy, as
  // _shared/vana/auth.ts builds it for vana-chat.
  ctxFor: (userId, token) => ({
    db: createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false } }),
    admin,
    userId,
    token,
  }),
  now: () => Date.now(),
});

serve(withSentry(async (req: Request) => {
  if (!Deno.env.get('AI_GATEWAY_API_KEY')) { console.error('[vana-eval] AI_GATEWAY_API_KEY secret is not set'); return jsonResponse({ error: 'ai_not_configured' }, 500); }
  return await handle(req);
}));
