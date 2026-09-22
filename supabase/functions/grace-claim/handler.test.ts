/**
 * Seam tests for the grace-claim edge function (mp-455 §4-5, mp-461; paywall ticket 09).
 *
 * The handler is built by `makeGraceClaimHandler()` with the caller lookup,
 * the flip date and the RevenueCat REST client injected, so these tests run
 * the code the deployed function runs. The caller is shaped as GoTrue's
 * `getUser` returns it (created_at, is_anonymous, identities with their own
 * created_at: an anonymous user has none, and linking adds one then), and
 * RevenueCat is the wire-level fake the flip-day run is tested against.
 *
 * What it must do:
 *   - an install that was still anonymous at the flip, created before it and
 *     now signed up, gets 30 days of `pro` and founding_member, once;
 *   - a second claim grants nothing;
 *   - a still-anonymous caller, an account created at or after the flip, an
 *     account that was registered before the flip (the flip-day run's), and
 *     any claim before the flip get nothing;
 *   - a RevenueCat failure answers 502 and a later claim still grants.
 *
 * Run with:
 *   deno test --allow-all --node-modules-dir=none supabase/functions/grace-claim/handler.test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { type ClaimCaller, makeGraceClaimHandler } from './handler.ts';
import { FOUNDING_MEMBER_ATTRIBUTE, GRACE_DAYS } from '../_shared/grace/grace.ts';
import { World } from '../tests/grace/support/revenuecat_world.ts';

const DAY = 24 * 60 * 60 * 1000;
const FLIP = new Date('2026-10-01T07:00:00Z');
const AFTER_FLIP = Date.parse('2026-10-03T15:00:00Z');

const OLD_INSTALL = 'a0000000-0000-4000-8000-00000000a0a0';

/** GoTrue's user, after the old anonymous user linked an email on [linkedAt]. */
function caller(over: Partial<ClaimCaller> = {}): ClaimCaller {
  return {
    userId: OLD_INSTALL,
    anonymous: false,
    createdAt: '2026-03-14T18:22:05.114Z',
    identities: [{ provider: 'email', created_at: '2026-10-03T14:59:40.000Z' }],
    ...over,
  };
}

async function claim(
  w: World,
  who: ClaimCaller | null,
  opts: { flipAt?: Date | null; method?: string } = {},
): Promise<{ status: number; body: Record<string, unknown> }> {
  const handler = makeGraceClaimHandler({
    caller: () => Promise.resolve(who),
    flipAt: () => (opts.flipAt === undefined ? FLIP : opts.flipAt),
    revenueCat: () => w.rc(),
    now: () => w.now,
    sleep: () => Promise.resolve(),
  });
  const res = await handler(
    new Request('https://stub.supabase.test/functions/v1/grace-claim', {
      method: opts.method ?? 'POST',
      headers: { Authorization: 'Bearer user-jwt' },
    }),
  );
  return { status: res.status, body: await res.json() };
}

const granted = (w: World) => w.writes.filter((x) => x.startsWith('grant'));

describe('an old anonymous install that signed up after the flip', () => {
  it('gets 30 days of pro and founding_member', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    const res = await claim(w, caller());

    assertEquals(res.status, 200);
    assertEquals(res.body, { ok: true, status: 'granted', pro_days: GRACE_DAYS });
    assertEquals(w.promoEnd(OLD_INSTALL), AFTER_FLIP + GRACE_DAYS * DAY);
    assertEquals(w.customers.get(OLD_INSTALL)?.attributes[FOUNDING_MEMBER_ATTRIBUTE], 'true');
  });

  it('gets it once: a second claim grants nothing', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    await claim(w, caller());
    w.now += 60 * 60 * 1000;
    const again = await claim(w, caller());

    assertEquals(again.status, 200);
    assertEquals(again.body, { ok: true, status: 'already', pro_days: 0 });
    assertEquals(granted(w).length, 1);
  });

  it('RevenueCat has never seen it: the customer is made, then granted', async () => {
    const w = new World(AFTER_FLIP);
    const res = await claim(w, caller());
    assertEquals(res.body.status, 'granted');
    assertEquals(w.writes.slice(0, 2), [`create ${OLD_INSTALL}`, `grant ${OLD_INSTALL}`]);
  });

  it('linked with Apple or Google counts the same as email', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    const res = await claim(w, caller({ identities: [{ provider: 'apple', created_at: '2026-10-02T09:00:00Z' }] }));
    assertEquals(res.body.status, 'granted');
  });

  it('a RevenueCat outage answers 502, and the next claim grants', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    w.failures.set('/actions/grant_entitlement', [503, 503, 503]);
    const res = await claim(w, caller());
    assertEquals(res.status, 502);
    assertEquals(res.body.error, 'store_unavailable');
    assertEquals(w.promoEnd(OLD_INSTALL), undefined);

    const retry = await claim(w, caller());
    assertEquals(retry.body.status, 'granted');
  });
});

describe('the claim grants nothing to', () => {
  it('a caller still anonymous: the claim is made by signing up', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    const res = await claim(w, caller({ anonymous: true, identities: [] }));
    assertEquals(res.status, 403);
    assertEquals(res.body.error, 'sign_in_required');
    assertEquals(w.writes, []);
  });

  it('an account created after the flip', async () => {
    const w = new World(AFTER_FLIP);
    const res = await claim(w, caller({ createdAt: '2026-10-02T10:00:00Z' }));
    assertEquals(res.body, { ok: false, reason: 'not_eligible' });
    assertEquals(w.writes, []);
  });

  it('an account created at the flip exactly', async () => {
    const w = new World(AFTER_FLIP);
    const res = await claim(w, caller({ createdAt: FLIP.toISOString() }));
    assertEquals(res.body, { ok: false, reason: 'not_eligible' });
  });

  it('an account registered before the flip: the flip-day run grants those', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    const res = await claim(w, caller({ identities: [{ provider: 'email', created_at: '2026-03-14T18:22:05.300Z' }] }));
    assertEquals(res.body, { ok: false, reason: 'not_eligible' });
    assertEquals(w.writes, []);
  });

  it('an old install linked before the flip (registered at the flip) ', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    const res = await claim(w, caller({ identities: [{ provider: 'google', created_at: '2026-09-28T12:00:00Z' }] }));
    assertEquals(res.body, { ok: false, reason: 'not_eligible' });
  });

  it('anyone, before the flip: a grant then would end before the grace month does', async () => {
    const w = new World(FLIP.getTime() - DAY).customer(OLD_INSTALL);
    const res = await claim(w, caller({ identities: [{ provider: 'email', created_at: '2026-09-30T06:00:00Z' }] }));
    assertEquals(res.body, { ok: false, reason: 'before_flip' });
    assertEquals(w.writes, []);
  });

  it('anyone, while the flip date is not configured', async () => {
    const w = new World(AFTER_FLIP).customer(OLD_INSTALL);
    const res = await claim(w, caller(), { flipAt: null });
    assertEquals(res.status, 503);
    assertEquals(res.body.error, 'grace_not_configured');
    assertEquals(w.writes, []);
  });
});

describe('the request', () => {
  it('with no signed-in caller is 401', async () => {
    const res = await claim(new World(AFTER_FLIP), null);
    assertEquals(res.status, 401);
  });

  it('other than POST is 405', async () => {
    const res = await claim(new World(AFTER_FLIP), caller(), { method: 'GET' });
    assertEquals(res.status, 405);
  });
});
