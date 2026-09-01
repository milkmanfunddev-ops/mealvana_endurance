/** Resolve the caller from the Authorization header and build the per-request VanaCtx:
 *  `db` = a client carrying the caller's JWT (RLS applies), `admin` = service role for the few sanctioned admin writes. */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } from './env.ts';
import type { VanaCtx } from './env.ts';

const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

export type AuthResult = { ok: true; v: VanaCtx } | { ok: false; status: 401; error: string };

export async function authenticate(req: Request): Promise<AuthResult> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '') ?? '';
  if (!token) return { ok: false, status: 401, error: 'unauthenticated' };
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) return { ok: false, status: 401, error: 'unauthenticated' };
  // The anon key + the caller's JWT on every request = PostgREST runs as `authenticated` with auth.uid() = the caller.
  const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false } });
  return { ok: true, v: { db, admin, userId: user.id, token } };
}
