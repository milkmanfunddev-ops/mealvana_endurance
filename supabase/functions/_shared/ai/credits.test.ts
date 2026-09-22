/**
 * credits.ts at its seam with the wallet RPCs (mp-430, mp-436; ai-cost
 * ticket 09): a debiting call reserves its kind's estimate through
 * `ai_budget_reserve`, settles to the real cost through `ai_budget_settle`,
 * refunds by settling at zero, and a database error refuses the call. The
 * 402 body carries a share, a refill date and bought extra, never a dollar
 * figure. The RPC rows here are shaped like the SQL returns them (jsonb
 * objects, micro-dollars), never like this module's own output.
 *
 * `CREDITS_ENFORCED` is read from the env at import time, so the module is
 * imported dynamically after the env is set. No test here asserts a price:
 * the real cost is checked against `realCostMicro`, the one function that
 * prices, not against a number.
 *
 * Run with:
 *   deno test --allow-env --allow-sys supabase/functions/_shared/ai/credits.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { DEFAULT_MONTHLY_BUDGET, DEFAULT_TRIAL_BUDGET, budgetStatus, freeMonthlyBudget, grantFor, monthlyBudget, PAYWALL_OPENS_AT } from './allowance.ts';
import { realCostMicro } from './usage.ts';

Deno.env.set('AI_CREDITS_ENFORCED', 'true');
Deno.env.delete('AI_MONTHLY_BUDGET');
Deno.env.delete('AI_TRIAL_BUDGET');
const credits = await import('./credits.ts');

type RpcCall = { fn: string; args: Record<string, unknown> };

function fakeClient(results: Record<string, { data?: unknown; error?: { message: string } | null } | ((args: Record<string, unknown>) => { data?: unknown; error?: { message: string } | null })>) {
  const calls: RpcCall[] = [];
  const client = {
    // deno-lint-ignore require-await
    rpc: async (fn: string, args: Record<string, unknown>) => {
      calls.push({ fn, args });
      const r = results[fn];
      const out = typeof r === 'function' ? r(args) : r;
      if (!out) return { data: null, error: { message: `no handler for ${fn}` } };
      return { data: out.data ?? null, error: out.error ?? null };
    },
  };
  // deno-lint-ignore no-explicit-any
  return { client: client as any, calls };
}

const allowedRow = {
  allowed: true, reservation_id: 'res-1', balance: 3_985_000, allowance: 3_985_000, allowance_monthly: 4_000_000,
  allowance_expires_at: '2026-10-15T12:00:00+00:00',
};

Deno.test('a debiting call reserves its kind\'s estimate with the project\'s monthly and trial budgets', async () => {
  const { client, calls } = fakeClient({ ai_budget_reserve: { data: allowedRow } });
  const r = await credits.reserveBudget(client, 'user-1', 'vana-chat');
  assert(r.allowed);
  assertEquals(calls.length, 1);
  assertEquals(calls[0].fn, 'ai_budget_reserve');
  assertEquals(calls[0].args.p_user_id, 'user-1');
  assertEquals(calls[0].args.p_kind, 'vana-chat');
  assertEquals(calls[0].args.p_estimate, credits.budgetEstimate('vana-chat'));
  assertEquals(calls[0].args.p_monthly, DEFAULT_MONTHLY_BUDGET);
  assertEquals(calls[0].args.p_trial, DEFAULT_TRIAL_BUDGET);
  assert(credits.budgetEstimate('vana-chat') > 0);
  assertEquals(r.hold.reservationId, 'res-1');
});

Deno.test('every debiting kind has an estimate, and the opener is one of them', () => {
  for (const kind of ['vana-chat', 'vana-opener', 'jade-chat', 'describe-meal', 'analyze-meal-photo', 'vana-pantry-photo'] as const) {
    assert(credits.budgetEstimate(kind) > 0, kind);
  }
});

Deno.test('an empty wallet is refused with a 402 whose body is a share, a refill date and bought extra — no dollar figure', async () => {
  const { client } = fakeClient({
    ai_budget_reserve: { data: { allowed: false, balance: 250_000, allowance: 0, allowance_monthly: 4_000_000, allowance_expires_at: '2026-10-15T12:00:00+00:00' } },
  });
  const r = await credits.reserveBudget(client, 'user-1', 'describe-meal');
  assert(!r.allowed);
  assertEquals(r.status, 402);
  assertEquals(r.body, {
    error: 'insufficient_credits',
    message: 'You have used this month\'s Vana. Top up to continue.',
    share_used: 1,
    refill_at: '2026-10-15T12:00:00+00:00',
    allowance_expires_at: '2026-10-15T12:00:00+00:00',
    bought_extra_share: 0.06,
  });
  for (const key of Object.keys(r.body)) assert(!/balance|cost|usd|micro|dollar/i.test(key), `no dollar figure: ${key}`);
});

Deno.test('a database error refuses the call as ours, never as the athlete\'s wallet', async () => {
  const { client } = fakeClient({ ai_budget_reserve: { error: { message: 'boom' } } });
  const r = await credits.reserveBudget(client, 'user-1', 'vana-chat');
  assert(!r.allowed);
  assertEquals(r.status, 503);
  assertEquals(r.body.error, 'ai_unavailable');
});

Deno.test('a client that throws is the same refusal', async () => {
  // deno-lint-ignore no-explicit-any
  const client = { rpc: () => { throw new Error('socket'); } } as any;
  const r = await credits.reserveBudget(client, 'user-1', 'vana-chat');
  assert(!r.allowed);
  assertEquals(r.status, 503);
});

Deno.test('settle sends the real cost the one pricing function computes, from the gateway charge or the tokens', async () => {
  const { client, calls } = fakeClient({ ai_budget_reserve: { data: allowedRow }, ai_budget_settle: { data: { settled: true } } });
  const r = await credits.reserveBudget(client, 'user-1', 'vana-chat');
  assert(r.allowed);
  const fromGateway = { gatewayCostUsd: 0.0123, model: 'anthropic/claude-haiku-4.5', inputTokens: 100, outputTokens: 50 };
  await r.hold.settle(fromGateway);
  assertEquals(calls[1], { fn: 'ai_budget_settle', args: { p_id: 'res-1', p_real_cost: realCostMicro(fromGateway) } });

  const r2 = await credits.reserveBudget(client, 'user-1', 'vana-chat');
  assert(r2.allowed);
  const fromTokens = { gatewayCostUsd: null, model: 'anthropic/claude-haiku-4.5', inputTokens: 12_000, outputTokens: 200, cacheReadTokens: 9_000, cacheWriteTokens: 0 };
  await r2.hold.settle(fromTokens);
  const priced = realCostMicro(fromTokens);
  assert(priced != null && priced > 0);
  assertEquals(calls[3].args.p_real_cost, priced);
});

Deno.test('a call whose cost nobody can price settles at its estimate, and a settle happens once', async () => {
  const { client, calls } = fakeClient({ ai_budget_reserve: { data: allowedRow }, ai_budget_settle: { data: { settled: true } } });
  const r = await credits.reserveBudget(client, 'user-1', 'analyze-meal-photo');
  assert(r.allowed);
  await r.hold.settle({ model: 'someone/unknown-model', inputTokens: 10, outputTokens: 10 });
  assertEquals(calls[1].args.p_real_cost, credits.budgetEstimate('analyze-meal-photo'));
  assertEquals(realCostMicro({ model: 'anthropic/claude-haiku-4.5' }), null, 'a known model with no token count is not a free call');
  assertEquals(realCostMicro({ model: 'anthropic/claude-haiku-4.5', inputTokens: 0, outputTokens: 0 }), 0, 'zero tokens is zero');
  await r.hold.settle({ gatewayCostUsd: 1 });
  await r.hold.refund();
  assertEquals(calls.length, 2, 'the second settle and the refund did nothing');
});

Deno.test('a failed call refunds by settling at zero; a refund after nothing else is the only settle', async () => {
  const { client, calls } = fakeClient({ ai_budget_reserve: { data: allowedRow }, ai_budget_settle: { data: { settled: true, charged: 0 } } });
  const r = await credits.reserveBudget(client, 'user-1', 'vana-pantry-photo');
  assert(r.allowed);
  await r.hold.refund();
  assertEquals(calls[1], { fn: 'ai_budget_settle', args: { p_id: 'res-1', p_real_cost: 0 } });
  await r.hold.settle({ gatewayCostUsd: 0.01 });
  assertEquals(calls.length, 2);
});

Deno.test('a settle that fails in the database is logged, never thrown at the athlete', async () => {
  const { client } = fakeClient({ ai_budget_reserve: { data: allowedRow }, ai_budget_settle: { error: { message: 'gone' } } });
  const r = await credits.reserveBudget(client, 'user-1', 'vana-chat');
  assert(r.allowed);
  await r.hold.settle({ gatewayCostUsd: 0.01 });
});

Deno.test('with enforcement off nothing is reserved and settle is a no-op', async () => {
  Deno.env.set('AI_CREDITS_ENFORCED', 'false');
  const off = await import('./credits.ts?off');
  Deno.env.set('AI_CREDITS_ENFORCED', 'true');
  const { client, calls } = fakeClient({});
  const r = await off.reserveBudget(client, 'user-1', 'vana-chat');
  assert(r.allowed);
  await r.hold.settle({ gatewayCostUsd: 0.01 });
  await r.hold.refund();
  assertEquals(calls, []);
});

Deno.test('the status the app reads: a share of the month, the refill date, bought extra as a share of a month', () => {
  assertEquals(
    budgetStatus({ balance: 3_000_000, allowance: 2_000_000, allowance_monthly: 4_000_000, allowance_expires_at: '2026-10-15T12:00:00+00:00' }, 4_000_000),
    { share_used: 0.5, refill_at: '2026-10-15T12:00:00+00:00', bought_extra_share: 0.25 },
  );
  // Never granted an allowance: no share, no refill, what is there is extra.
  assertEquals(budgetStatus({ balance: 400_000, allowance: 0, allowance_monthly: 0, allowance_expires_at: null }, 4_000_000), { share_used: null, refill_at: null, bought_extra_share: 0.1 });
  // A lapsed subscription: the window closed, so there is no month to show, only what was bought.
  assertEquals(budgetStatus({ balance: 400_000, allowance: 0, allowance_monthly: 4_000_000, allowance_expires_at: null }, 4_000_000), { share_used: null, refill_at: null, bought_extra_share: 0.1 });
  // Over-run floored at zero inside an open window reads as the whole month used.
  assertEquals(budgetStatus({ balance: 0, allowance: 0, allowance_monthly: 4_000_000, allowance_expires_at: '2026-10-15T12:00:00+00:00' }, 4_000_000).share_used, 1);
});

Deno.test('the amounts: $4.00 a month, the trial a quarter, and the env overrides them per project', () => {
  assertEquals(monthlyBudget(() => undefined), 4_000_000);
  assertEquals(DEFAULT_TRIAL_BUDGET, 1_000_000);
  assertEquals(grantFor(() => undefined, 'TRIAL'), 1_000_000);
  assertEquals(grantFor(() => undefined, 'NORMAL'), 4_000_000);
  assertEquals(grantFor(() => undefined, null), 4_000_000);
  assertEquals(monthlyBudget(() => '120'), 120);
  assertEquals(monthlyBudget(() => 'lots'), 4_000_000);
});

Deno.test('the free grant of 20 credits ends the day the paywall opens', () => {
  const dayBefore = new Date(Date.parse(PAYWALL_OPENS_AT) - 1);
  assertEquals(freeMonthlyBudget(() => undefined, dayBefore), 400_000, '20 credits at 2 cents, until then');
  assertEquals(freeMonthlyBudget(() => undefined, new Date(PAYWALL_OPENS_AT)), 0);
  assertEquals(freeMonthlyBudget(() => undefined, new Date('2027-01-01T00:00:00Z')), 0);
});
