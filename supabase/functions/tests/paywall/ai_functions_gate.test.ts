/**
 * Every AI function checks the subscription on the server (paywall ticket 02; mp-429 clause 11, mp-481).
 *
 * A lapsed account holding bought credits is refused by describe-meal, analyze-meal-photo, meal-photo
 * and jade-chat exactly as vana-chat refuses it, and an active account still gets through.
 * (ai-coach was gated here too until ai-cost ticket 14 removed the route, mp-465 clause 4.)
 *
 * Each function's real `index.ts` runs in-process (support/serve_harness.ts): its own auth, body parsing,
 * gate and credit check, with Supabase and the AI Gateway behind a stubbed `fetch`. The entitlement rows
 * are shaped as the RevenueCat webhook writes them (mp-285): `active_until` + `period_type`, nothing else.
 *
 * Run: deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none \
 *        supabase/functions/tests/paywall
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { type Call, loadFunction, setStubEnv, type World, withWorld } from './support/serve_harness.ts';

const USER = 'c18d3737-0000-4000-8000-0000000000a1';
const HOUR = 3600_000;
const iso = (offsetMs: number) => new Date(Date.now() + offsetMs).toISOString();

/** A lapsed account: the webhook's row says the subscription ended yesterday; the wallet holds 50 bought credits. */
const lapsed = (): World => ({
  userId: USER,
  entitlements: [{ user_id: USER, active_until: iso(-24 * HOUR), period_type: 'NORMAL' }],
  balance: 50,
  users: [{ id: USER, is_internal: true, is_admin: false }],
});

/** A team admin (`users.is_admin`, 122-004) who never subscribed, with an empty wallet: past the gate, stopped at the credit check. */
const admin = (): World => ({
  ...lapsed(),
  entitlements: [],
  balance: 0,
  users: [{ id: USER, is_internal: true, is_admin: true }],
});

/** An account that never subscribed: no row at all, same bought credits. */
const neverSubscribed = (): World => ({ ...lapsed(), entitlements: [] });

/** An active subscriber whose wallet is empty, so a call that passes the gate stops at the credit check (402). */
const active = (): World => ({
  ...lapsed(),
  entitlements: [{ user_id: USER, active_until: iso(30 * 24 * HOUR), period_type: 'NORMAL' }],
  balance: 0,
});

const post = (fn: string, body: unknown) =>
  new Request(`https://stub.supabase.test/functions/v1/${fn}`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-jwt', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

/** A valid request per function, so a refusal can only come from the gate. */
const REQUESTS: Record<string, unknown> = {
  'describe-meal': { description: 'two eggs on toast with butter and OJ' },
  'analyze-meal-photo': { photo_path: `${USER}/lunch.jpg` },
  'jade-chat': { message: 'What should I eat before my long run?' },
  'meal-photo': { action: 'history', meal_id: 'AD-001' },
};

/** What each function does once past the gate, for an active account with an empty wallet. */
const PAST_THE_GATE: Record<string, (hits: string[]) => boolean> = {
  'describe-meal': (h) => h.includes('POST /rest/v1/rpc/ai_budget_reserve'),
  'analyze-meal-photo': (h) => h.includes('POST /rest/v1/rpc/ai_budget_reserve'),
  'jade-chat': (h) => h.includes('POST /rest/v1/rpc/ai_budget_reserve'),
  'meal-photo': (h) => h.includes('GET /rest/v1/users'),
};

const FUNCTIONS = Object.keys(REQUESTS);

/**
 * The real supabase-js clients the functions build start the auth client's refresh timers, which outlive
 * one request; that is the deployed code's behaviour, not a leak in the gate, so the op sanitizers are off.
 */
const test = (name: string, fn: () => Promise<void>) =>
  Deno.test({ name, fn, sanitizeOps: false, sanitizeResources: false });

setStubEnv();
const calls: Record<string, Call> = {};
for (const fn of [...FUNCTIONS, 'vana-chat']) {
  calls[fn] = await loadFunction(new URL(`../../${fn}/index.ts`, import.meta.url).href);
}

/** vana-chat's refusal, observed rather than written down: the reference every other function must match. */
async function vanaRefusal(world: World): Promise<{ status: number; body: unknown; type: string | null }> {
  return await withWorld(world, async () => {
    const res = await calls['vana-chat'](post('vana-chat', { message: 'hi', kind: 'general' }));
    return { status: res.status, body: await res.json(), type: res.headers.get('content-type') };
  });
}

for (const [label, world] of [['lapsed (expired row)', lapsed], ['never subscribed (no row)', neverSubscribed]] as const) {
  test(`vana-chat refuses a ${label} account with 403 pro_required (the reference)`, async () => {
    assertEquals(await vanaRefusal(world()), { status: 403, body: { error: 'pro_required' }, type: 'application/json' });
  });

  for (const fn of FUNCTIONS) {
    test(`${fn} refuses a ${label} account holding bought credits, the same way vana-chat does`, async () => {
      const reference = await vanaRefusal(world());
      await withWorld(world(), async (hits) => {
        const res = await calls[fn](post(fn, REQUESTS[fn]));
        const got = { status: res.status, body: await res.json(), type: res.headers.get('content-type') };
        assertEquals(got, reference);
        assert(hits.includes('GET /rest/v1/user_entitlements'), `${fn} read the entitlement cache: ${hits.join(', ')}`);
        // Refused before anything costs: no wallet check, no model call. The one `users` read is the
        // gate's own admin-flag check (122-004), made once the cache said no; nothing else reads the row.
        assertEquals(hits.filter((h) => h.includes('ai_budget_reserve') || h.startsWith('POST https://')), [], `${fn} stopped at the gate`);
        assertEquals(hits.filter((h) => h === 'GET /rest/v1/users'), ['GET /rest/v1/users'], `${fn} stopped at the gate`);
      });
    });
  }
}

for (const fn of [...FUNCTIONS, 'vana-chat']) {
  test(`${fn} lets an Admin with no entitlement row through (122-004)`, async () => {
    await withWorld(admin(), async (hits) => {
      const res = await calls[fn](post(fn, fn === 'vana-chat' ? { message: 'hi', kind: 'general' } : REQUESTS[fn]));
      const body = await res.json().catch(() => null);
      assertNotEquals(res.status, 403, `${fn} answered ${res.status} ${JSON.stringify(body)}`);
      assertNotEquals(body?.error, 'pro_required', `${fn} answered ${res.status} ${JSON.stringify(body)}`);
      assert(hits.includes('GET /rest/v1/user_entitlements'), `${fn} read the entitlement cache: ${hits.join(', ')}`);
      assert(hits.includes('GET /rest/v1/users'), `${fn} read the admin flag: ${hits.join(', ')}`);
    });
  });
}

for (const fn of FUNCTIONS) {
  test(`${fn} lets an active subscriber through`, async () => {
    await withWorld(active(), async (hits) => {
      const res = await calls[fn](post(fn, REQUESTS[fn]));
      const body = await res.json();
      assertNotEquals(body?.error, 'pro_required', `${fn} answered ${res.status} ${JSON.stringify(body)}`);
      assert(hits.includes('GET /rest/v1/user_entitlements'), `${fn} read the entitlement cache: ${hits.join(', ')}`);
      assert(PAST_THE_GATE[fn](hits), `${fn} went on past the gate: ${res.status} ${JSON.stringify(body)} · ${hits.join(', ')}`);
    });
  });
}
