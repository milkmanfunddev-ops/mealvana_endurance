/**
 * Pro gate for the Vana functions (docs/implement_mealplanning/03-backend.md §3, 04-entitlement.md).
 *
 * A caller passes when ANY of these hold:
 *   1. the PRO_GATE_ENABLED secret is 'false' (dev default — the feature is open while the paywall is being built);
 *   2. `public.has_entitlement(p_user, 'pro')` is true (Phase 3 creates `user_entitlements` + this function; until it
 *      exists the RPC errors and we log + treat the caller as NOT entitled — never fail open on a missing table);
 *   3. `users.is_internal = true` (internal testers).
 *
 * When the secret is absent: gate ON everywhere except the dev project, so a forgotten prod secret cannot open the
 * feature. Set `PRO_GATE_ENABLED=false` explicitly on dev anyway.
 */
import type { Db } from './env.ts';
import { SUPABASE_URL } from './env.ts';

const DEV_PROJECT_REF = 'vlmtsdzpnjnavdgytcmi';

export function proGateEnabled(): boolean {
  const raw = Deno.env.get('PRO_GATE_ENABLED');
  if (raw == null || raw === '') return !SUPABASE_URL.includes(DEV_PROJECT_REF);
  return raw.trim().toLowerCase() !== 'false';
}

export type ProCheck = { ok: true } | { ok: false; reason: 'pro_required' };

export async function requirePro(admin: Db, userId: string): Promise<ProCheck> {
  if (!proGateEnabled()) return { ok: true };
  try {
    const { data, error } = await admin.rpc('has_entitlement', { p_user: userId, p_key: 'pro' });
    if (error) console.warn('[vana] has_entitlement unavailable (treating as not entitled):', error.message);
    else if (data === true) return { ok: true };
  } catch (e) { console.warn('[vana] has_entitlement threw (treating as not entitled):', (e as Error).message); }
  try {
    const { data, error } = await admin.from('users').select('is_internal').eq('id', userId).maybeSingle();
    if (error) console.warn('[vana] users.is_internal lookup failed:', error.message);
    else if (data?.is_internal === true) return { ok: true };
  } catch (e) { console.warn('[vana] users.is_internal lookup threw:', (e as Error).message); }
  return { ok: false, reason: 'pro_required' };
}
