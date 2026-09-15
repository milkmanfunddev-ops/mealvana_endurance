/**
 * credits.ts at its seam with the wallet RPCs (mp-281, ticket 20): the check
 * before a debiting call rolls the Allowance through `ensure_allowance` and
 * the 402 body carries what the top-up sheet shows. The RPC rows here are
 * shaped like the SQL returns them (jsonb objects), never like this module's
 * own output.
 *
 * `CREDITS_ENFORCED` is read from the env at import time, so the module is
 * imported dynamically after the env is set.
 *
 * Run with:
 *   deno test --allow-env --allow-sys supabase/functions/_shared/ai/credits.test.ts
 */

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { DEFAULT_MONTHLY_ALLOWANCE, monthlyAllowance } from './allowance.ts';

Deno.env.set('AI_CREDITS_ENFORCED', 'true');
Deno.env.delete('AI_MONTHLY_ALLOWANCE');
const credits = await import('./credits.ts');

type RpcCall = { fn: string; args: Record<string, unknown> };

function fakeClient(result: { data?: unknown; error?: { message: string } | null }) {
  const calls: RpcCall[] = [];
  const client = {
    // deno-lint-ignore require-await
    rpc: async (fn: string, args: Record<string, unknown>) => {
      calls.push({ fn, args });
      return { data: result.data ?? null, error: result.error ?? null };
    },
  };
  // deno-lint-ignore no-explicit-any
  return { client: client as any, calls };
}

Deno.test('the check rolls the Allowance through ensure_allowance with the project number', async () => {
  const { client, calls } = fakeClient({
    data: { balance: 12, allowance: 10, allowance_monthly: 300, allowance_expires_at: '2026-10-15T12:00:00+00:00', granted: false },
  });
  const check = await credits.ensureAndCheckCredits(client, 'user-1', 'vana-chat');
  assertEquals(calls, [{ fn: 'ensure_allowance', args: { p_user_id: 'user-1', p_amount: DEFAULT_MONTHLY_ALLOWANCE } }]);
  assertEquals(check, {
    allowed: true,
    balance: 12,
    cost: 1,
    allowance: 10,
    allowanceMonthly: 300,
    allowanceExpiresAt: '2026-10-15T12:00:00+00:00',
  });
});

Deno.test('an empty wallet is not allowed and the 402 body names the Allowance and its renewal', async () => {
  const { client } = fakeClient({
    data: { balance: 0, allowance: 0, allowance_monthly: 300, allowance_expires_at: '2026-10-15T12:00:00+00:00', granted: false },
  });
  const check = await credits.ensureAndCheckCredits(client, 'user-1', 'describe-meal');
  assertEquals(check.allowed, false);
  assertEquals(credits.insufficientCreditsBody(check), {
    error: 'insufficient_credits',
    message: 'You are out of AI credits. Purchase more to continue.',
    balance: 0,
    cost: 1,
    allowance_monthly: 300,
    allowance_expires_at: '2026-10-15T12:00:00+00:00',
  });
});

Deno.test('a wallet that was never granted an Allowance reports 0 / null, not a lie', async () => {
  const { client } = fakeClient({ data: { balance: 3, allowance: 0, allowance_monthly: 0, allowance_expires_at: null } });
  const check = await credits.ensureAndCheckCredits(client, 'user-1', 'ai-coach');
  assertEquals(check.allowed, true);
  assertEquals(check.allowanceMonthly, 0);
  assertEquals(check.allowanceExpiresAt, null);
  assertEquals(credits.insufficientCreditsBody({ ...check, allowed: false, balance: 0 }).allowance_expires_at, null);
});

Deno.test('an RPC error fails open, as before', async () => {
  const { client } = fakeClient({ error: { message: 'boom' } });
  const check = await credits.ensureAndCheckCredits(client, 'user-1', 'vana-chat');
  assertEquals(check, { allowed: true, balance: -1, cost: 1 });
});

Deno.test('the debit still goes through debit_credits (the SQL spends the Allowance first)', async () => {
  const { client, calls } = fakeClient({ data: { success: true, balance: 11, allowance: 9, from_allowance: 1 } });
  await credits.debitForUsage(client, 'user-1', 'vana-chat');
  assertEquals(calls, [{
    fn: 'debit_credits',
    args: { p_user_id: 'user-1', p_amount: 1, p_reason: 'debit_usage', p_ref: 'vana-chat' },
  }]);
});

Deno.test('monthlyAllowance: the env override wins, garbage falls back', () => {
  assertEquals(monthlyAllowance(() => undefined), DEFAULT_MONTHLY_ALLOWANCE);
  assertEquals(monthlyAllowance(() => '120'), 120);
  assertEquals(monthlyAllowance(() => '0'), DEFAULT_MONTHLY_ALLOWANCE);
  assertEquals(monthlyAllowance(() => 'lots'), DEFAULT_MONTHLY_ALLOWANCE);
});
