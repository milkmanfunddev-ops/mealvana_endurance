/**
 * Every debiting call draws the monthly budget, openers included (mp-430 clause 1; ai-cost ticket 09), and what a
 * refused call is told is a share, a refill date and bought extra — never a dollar figure (mp-436 clause 3).
 *
 * The functions are served through the paywall harness: a fake Supabase behind fetch, the real function code, an
 * active subscriber. With the wallet empty each call must stop at `ai_budget_reserve` with the one 402 the client
 * handles; with the wallet unreadable each must refuse as ours (503 ai_unavailable), never as the athlete's.
 *
 * Run with:
 *   deno test --allow-env --allow-sys --allow-net --allow-read supabase/functions/tests/vana/budget.test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { type Call, loadFunction, setStubEnv, type World, withWorld } from '../paywall/support/serve_harness.ts';

const USER = 'c18d3737-0000-4000-8000-0000000000a1';
const HOUR = 60 * 60 * 1000;
const iso = (offsetMs: number) => new Date(Date.now() + offsetMs).toISOString();

/** An active subscriber whose month is used up. */
const spent = (): World => ({
  userId: USER,
  entitlements: [{ user_id: USER, active_until: iso(30 * 24 * HOUR), period_type: 'NORMAL' }],
  balance: 0,
  users: [{ id: USER, is_internal: true }],
});

const post = (fn: string, body: unknown) =>
  new Request(`https://stub.supabase.test/functions/v1/${fn}`, {
    method: 'POST',
    headers: { Authorization: 'Bearer user-jwt', 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

/** One request per debiting call, valid past every other check so a refusal can only be the budget's. */
const DEBITING: Record<string, { fn: string; body: unknown }> = {
  'chat turn': { fn: 'vana-chat', body: { message: 'What should I eat tonight?', kind: 'general' } },
  'opener': { fn: 'vana-chat', body: { opener: true, kind: 'meal_planning' } },
  'described meal': { fn: 'describe-meal', body: { description: 'two eggs on toast with butter and OJ' } },
  'meal photo': { fn: 'analyze-meal-photo', body: { photo_path: `${USER}/lunch.jpg` } },
  'pantry photo': { fn: 'vana-action', body: { type: 'pantry_photo', payload: { conversationId: '11111111-1111-4111-8111-111111111111', photoPath: `${USER}/fridge.jpg` } } },
};

const test = (name: string, fn: () => Promise<void>) => Deno.test({ name, fn, sanitizeOps: false, sanitizeResources: false });

setStubEnv();
const calls: Record<string, Call> = {};
for (const fn of ['vana-chat', 'describe-meal', 'analyze-meal-photo', 'vana-action']) {
  calls[fn] = await loadFunction(new URL(`../../${fn}/index.ts`, import.meta.url).href);
}

for (const [label, { fn, body }] of Object.entries(DEBITING)) {
  test(`${label}: a used-up month is refused at the budget with the one 402, and the model is never called`, async () => {
    await withWorld(spent(), async (hits) => {
      const res = await calls[fn](post(fn, body));
      const out = await res.json();
      assertEquals(res.status, 402, `${label}: ${JSON.stringify(out)}`);
      assertEquals(out.error, 'insufficient_credits');
      assertEquals(Object.keys(out).sort(), ['allowance_expires_at', 'bought_extra_share', 'error', 'message', 'refill_at', 'share_used']);
      const reserve = hits.filter((h) => h === 'POST /rest/v1/rpc/ai_budget_reserve');
      assertEquals(reserve.length, 1, `${label} reserved once: ${hits.join(', ')}`);
      assertEquals(hits.filter((h) => h.startsWith('POST https://')), [], `${label} never reached the gateway`);
      assertEquals(hits.filter((h) => h.includes('vana_reserve_call')), [], `${label} was refused before the limiter took a place`);
    });
  });

  test(`${label}: a wallet that cannot be read refuses the call as ours (503 ai_unavailable), not as the athlete's`, async () => {
    await withWorld({ ...spent(), budgetDown: true }, async (hits) => {
      const res = await calls[fn](post(fn, body));
      const out = await res.json();
      assertEquals(res.status, 503, `${label}: ${JSON.stringify(out)}`);
      assertEquals(out.error, 'ai_unavailable');
      assertEquals(hits.filter((h) => h.startsWith('POST https://')), [], `${label} never reached the gateway`);
    });
  });
}

test('the opener and a chat turn reserve under their own kinds', async () => {
  const kinds: string[] = [];
  const realFetch = globalThis.fetch;
  await withWorld(spent(), async () => {
    const inner = globalThis.fetch;
    globalThis.fetch = (async (input: Request | URL | string, init?: RequestInit) => {
      const req = input instanceof Request ? input : new Request(input, init);
      if (new URL(req.url).pathname === '/rest/v1/rpc/ai_budget_reserve') kinds.push((await req.clone().json()).p_kind);
      return inner(req);
    }) as typeof fetch;
    await calls['vana-chat'](post('vana-chat', DEBITING['opener'].body));
    await calls['vana-chat'](post('vana-chat', DEBITING['chat turn'].body));
  });
  globalThis.fetch = realFetch;
  assertEquals(kinds, ['vana-opener', 'vana-chat']);
  assert(kinds.every((k) => k.length > 0));
});
