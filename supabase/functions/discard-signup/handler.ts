/**
 * The discard-signup request handler (testing-wave 121-003, Lee 2026-09-26),
 * built with its client injected so handler.test.ts runs this exact code
 * against a fake. index.ts wires it to the service-role client.
 *
 * "Use a different email" (or "Log in") on Verify your email, before any code
 * was entered, used to leave the abandoned address as an unconfirmed
 * `auth.users` row. There is no session to act under (the signup never
 * confirmed), so the app posts the `user_id` GoTrue's signup answer gave it
 * and the email, and this function deletes the auth user only when ALL hold:
 *
 *   - the id is a UUID and the email a plausible address;
 *   - a user with that id exists, and its email is that email (case-insensitive);
 *   - `email_confirmed_at` is null (never confirmed);
 *   - `last_sign_in_at` is null (never signed in);
 *   - it is not an anonymous user (an upgrade keeps its uid);
 *   - it was created within the last [MAX_AGE_MS].
 *
 * Whatever happened, it answers 200 `{ ok: true }` and says nothing else: an
 * address that is already a confirmed account (GoTrue then hands the signup a
 * decoy id, 124-002) must not become knowable here. A decoy id matches no
 * user and deletes nothing. `public.users` never has a row for an unconfirmed
 * signup, so only `auth.users` is touched.
 *
 * Abuse: a caller needs both a fresh unconfirmed user's exact id and its
 * email, within the hour, to delete something, and what they delete is a
 * login that was never used. The gateway's `verify_jwt` (anon key) fronts it
 * as for every other function.
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/** How old a never-confirmed signup may be and still be discarded here. */
export const MAX_AGE_MS = 60 * 60_000;

// deno-lint-ignore no-explicit-any
type Client = any;

export interface DiscardSignupDeps {
  /** The service-role client: `auth.admin.getUserById` and `auth.admin.deleteUser`. */
  admin: () => Client;
  /** The clock, for the age check. */
  now?: () => number;
}

/** What the fake and the real client both answer for `getUserById`. */
export interface AdminUser {
  id: string;
  email?: string | null;
  email_confirmed_at?: string | null;
  last_sign_in_at?: string | null;
  created_at?: string;
  is_anonymous?: boolean;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function ok(): Response {
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/**
 * Pure rule: whether [user] is a fresh, never-used signup for [email].
 * Exported so the test pins each clause against GoTrue-shaped users.
 */
export function isDiscardable(user: AdminUser | null | undefined, email: string, nowMs: number): boolean {
  if (!user) return false;
  if ((user.email ?? '').trim().toLowerCase() !== email.trim().toLowerCase()) return false;
  if (user.email_confirmed_at != null) return false;
  if (user.last_sign_in_at != null) return false;
  if (user.is_anonymous === true) return false;
  const created = user.created_at ? Date.parse(user.created_at) : NaN;
  if (!Number.isFinite(created)) return false;
  return nowMs - created >= 0 && nowMs - created <= MAX_AGE_MS;
}

export function makeDiscardSignupHandler(deps: DiscardSignupDeps) {
  const now = deps.now ?? Date.now;
  return async function handle(req: Request): Promise<Response> {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: corsHeaders });
    try {
      const body = await req.json().catch(() => null) as { user_id?: unknown; email?: unknown } | null;
      const userId = typeof body?.user_id === 'string' ? body.user_id.trim() : '';
      const email = typeof body?.email === 'string' ? body.email.trim() : '';
      if (!UUID.test(userId) || !email.includes('@') || email.length > 320) return ok();

      const admin = deps.admin();
      const { data, error } = await admin.auth.admin.getUserById(userId);
      if (error || !data?.user) return ok();

      if (!isDiscardable(data.user as AdminUser, email, now())) return ok();

      const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
      if (deleteError) console.error('[discard-signup] delete failed:', deleteError.message ?? deleteError);
      else console.log(`[discard-signup] discarded abandoned signup ${userId}`);
      return ok();
    } catch (e) {
      console.error('[discard-signup] unexpected:', (e as Error).message);
      return ok();
    }
  };
}
