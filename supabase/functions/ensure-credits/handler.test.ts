/**
 * ensure-credits handler (round develop-2026-10, ticket 23): the grant answer
 * and the D9 warning for a wallet that is not in whole tokens. Drives the real
 * handler with a fake service-role client and a fake Sentry client.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/ensure-credits
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { makeEnsureCreditsHandler } from './handler.ts';
import { FREE_MONTHLY_CREDITS } from '../_shared/ai/credits.ts';
import { setSentryClientForTesting } from '../_shared/sentry.ts';
import { FakeSentry } from '../_shared/sentry_fake_client.ts';

const USER_ID = '6f0c1a52-1111-4a3b-9c1e-0d2a6b7c8d9e';

/** A wallet row as PostgREST serves it; `extra` adds dev-only columns. */
function fakeAdmin(walletExtra: Record<string, unknown> | null) {
  let wallet: Record<string, unknown> | null = null;
  const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = [];
  // deno-lint-ignore no-explicit-any
  const admin: any = {
    auth: {
      getUser: (token: string) =>
        Promise.resolve(
          token === 'good-jwt'
            ? { data: { user: { id: USER_ID } }, error: null }
            : { data: { user: null }, error: { message: 'bad jwt' } },
        ),
    },
    rpc: (fn: string, args: Record<string, unknown>) => {
      rpcCalls.push({ fn, args });
      // ensure_free_credits: a new user gets a wallet holding the grant.
      if (wallet == null) {
        wallet = {
          user_id: USER_ID,
          balance: args.p_amount,
          free_period: '2026-10',
          updated_at: '2026-10-07T09:14:22.512834+00:00',
          ...(walletExtra ?? {}),
        };
      }
      return Promise.resolve({ data: wallet.balance, error: null });
    },
    from: (table: string) => {
      assertEquals(table, 'token_wallets');
      const q = {
        select: (_cols: string) => q,
        eq: (_col: string, _v: unknown) => q,
        maybeSingle: () => Promise.resolve({ data: wallet, error: null }),
      };
      return q;
    },
  };
  return { admin, rpcCalls };
}

function request(token = 'good-jwt') {
  return new Request('http://localhost/functions/v1/ensure-credits', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
}

function withFakeSentry() {
  const sentry = new FakeSentry();
  setSentryClientForTesting(sentry);
  return sentry;
}

Deno.test('a new user\'s first call answers the 50-token grant', async () => {
  const sentry = withFakeSentry();
  const { admin, rpcCalls } = fakeAdmin(null);
  const handle = makeEnsureCreditsHandler({ admin: () => admin, freeMonthly: FREE_MONTHLY_CREDITS, enforced: true });

  const res = await handle(request());

  assertEquals(res.status, 200);
  assertEquals(await res.json(), { balance: 50, free_monthly: 50, enforced: true });
  assertEquals(rpcCalls, [{ fn: 'ensure_free_credits', args: { p_user_id: USER_ID, p_amount: 50 } }]);
  assertEquals(sentry.captures.length, 0);
  setSentryClientForTesting(null);
});

Deno.test('a wallet in usd_micro captures one warning and still answers 200', async () => {
  const sentry = withFakeSentry();
  // The dev shape after mealplanning's micro-dollar migration.
  const { admin } = fakeAdmin({
    unit: 'usd_micro',
    balance: 49897485,
    allowance: 0,
    allowance_monthly: 0,
    allowance_expires_at: null,
  });
  const handle = makeEnsureCreditsHandler({ admin: () => admin, freeMonthly: 50, enforced: true });

  const res = await handle(request());

  assertEquals(res.status, 200);
  assertEquals((await res.json()).balance, 49897485);
  assertEquals(sentry.captures.length, 1);
  const c = sentry.captures[0];
  assertEquals(c.context?.level, 'warning');
  assertEquals(c.context?.extra?.message, '[credits] wallet not in whole tokens');
  assertEquals(c.context?.extra?.userId, USER_ID);
  assertEquals(c.context?.extra?.unit, 'usd_micro');
  assertEquals(c.context?.extra?.balance, 49897485);
  setSentryClientForTesting(null);
});

Deno.test('a wallet labelled credit captures nothing', async () => {
  const sentry = withFakeSentry();
  const { admin } = fakeAdmin({ unit: 'credit' });
  const handle = makeEnsureCreditsHandler({ admin: () => admin, freeMonthly: 50, enforced: true });

  const res = await handle(request());

  assertEquals(res.status, 200);
  assertEquals(sentry.captures.length, 0);
  setSentryClientForTesting(null);
});

Deno.test('a row without unit (prod shape) captures nothing', async () => {
  const sentry = withFakeSentry();
  const { admin } = fakeAdmin(null);
  const handle = makeEnsureCreditsHandler({ admin: () => admin, freeMonthly: 50, enforced: false });

  const res = await handle(request());

  assertEquals(res.status, 200);
  assertEquals(await res.json(), { balance: 50, free_monthly: 50, enforced: false });
  assertEquals(sentry.captures.length, 0);
  setSentryClientForTesting(null);
});

Deno.test('a failed wallet read leaves the 200 answer unchanged', async () => {
  const sentry = withFakeSentry();
  const { admin } = fakeAdmin(null);
  admin.from = () => {
    const q = {
      select: () => q,
      eq: () => q,
      maybeSingle: () => Promise.resolve({ data: null, error: { message: 'permission denied' } }),
    };
    return q;
  };
  const handle = makeEnsureCreditsHandler({ admin: () => admin, freeMonthly: 50, enforced: true });

  const res = await handle(request());

  assertEquals(res.status, 200);
  assertEquals((await res.json()).balance, 50);
  assertEquals(sentry.captures.length, 0);
  assertEquals(sentry.breadcrumbs.length, 1);
  setSentryClientForTesting(null);
});

Deno.test('a bad token answers 401 and never touches the wallet', async () => {
  withFakeSentry();
  const { admin, rpcCalls } = fakeAdmin(null);
  const handle = makeEnsureCreditsHandler({ admin: () => admin, freeMonthly: 50, enforced: true });

  const res = await handle(request('bad'));

  assertEquals(res.status, 401);
  assertEquals(rpcCalls.length, 0);
  setSentryClientForTesting(null);
});
