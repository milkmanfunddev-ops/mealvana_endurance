/**
 * The call log can say what every athlete costs (ai-cost ticket 05; mp-420 clause 6, mp-464 clause 7, mp-470).
 *
 * The seam is where the AI SDK's finished turn becomes a `vana_calls` row. The tests feed producer-shaped SDK data —
 * the step array and usage object `streamText` hands `onFinish`, snake-cased nowhere, exactly as the library shapes
 * them — and assert what reached the database. Nothing here builds the "stored" side with the code under test.
 *
 * Four claims:
 *   1. A finished turn is read for the cache both directions, the FIRST step's prompt, the step count and the
 *      gateway's charge summed over the steps — not the last step's charge, which undercounts every tool loop.
 *   2. "The gateway said nothing" is null and never 0.
 *   3. Every column the migration added is written. Asserted against the migration file itself, so a column added
 *      later without a writer fails here rather than sitting empty until October.
 *   4. tap-or-typed is narrowed, never trusted: an unknown value is null and the request is not refused over it.
 *
 * Run: deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none \
 *        supabase/functions/tests/vana/call_log.test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { asInputMode, callMetrics, costColumns, logCall } from '../../_shared/vana/log.ts';
import { completeCall, reserveCall } from '../../_shared/vana/rate-limit.ts';
import { subscriberState, UNKNOWN_SUBSCRIBER } from '../../_shared/vana/subscriber.ts';
import { cacheWriteTokens } from '../../_shared/vana/stream.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const MIGRATION = new URL('../../../migrations/20260922100000_ai_call_log_cost_view_and_retention.sql', import.meta.url);

/** A step as `streamText` hands it to onFinish: its own usage and its own gateway metadata. */
const step = (o: { input: number; cacheRead?: number; cacheWrite?: number; output: number; cost?: string }) => ({
  usage: {
    inputTokens: o.input,
    outputTokens: o.output,
    inputTokenDetails: { noCacheTokens: o.input - (o.cacheRead ?? 0), cacheReadTokens: o.cacheRead, cacheWriteTokens: o.cacheWrite },
    outputTokenDetails: { textTokens: o.output, reasoningTokens: 0 },
    totalTokens: o.input + o.output,
  },
  providerMetadata: o.cost === undefined ? undefined : { gateway: { cost: o.cost } },
});

/** The turn's `totalUsage`: the steps added up, which is what the SDK reports. */
const totalUsage = (o: { input: number; cacheRead: number; cacheWrite: number; output: number }) => ({
  inputTokens: o.input,
  outputTokens: o.output,
  inputTokenDetails: { noCacheTokens: o.input - o.cacheRead, cacheReadTokens: o.cacheRead, cacheWriteTokens: o.cacheWrite },
  outputTokenDetails: { textTokens: o.output, reasoningTokens: 0 },
  totalTokens: o.input + o.output,
});

// ---------------------------------------------------------------- 1. what a finished turn cost

Deno.test('a three-step turn is read for the cache, the first step, the steps and the summed charge', () => {
  // A planning turn: step one reads the warm prefix, the two tool steps re-read what this call wrote.
  const steps = [
    step({ input: 31_000, cacheRead: 26_000, cacheWrite: 4_800, output: 120, cost: '0.00412' }),
    step({ input: 33_500, cacheRead: 31_000, output: 210, cost: '0.00121' }),
    step({ input: 35_000, cacheRead: 33_500, output: 300, cost: '0.00098' }),
  ];
  const m = callMetrics(steps, totalUsage({ input: 99_500, cacheRead: 90_500, cacheWrite: 4_800, output: 630 }));

  assertEquals(m.steps, 3);
  assertEquals(m.cacheReadTokens, 90_500);
  assertEquals(m.cacheWriteTokens, 4_800);
  // The first step is the only one whose prompt could come from the cache: 26,000 of 31,000, not 90,500 of 99,500.
  assertEquals(m.firstStepInputTokens, 31_000);
  assertEquals(m.firstStepCacheReadTokens, 26_000);
  // The charge is the steps added up. The last step's 0.00098 alone would report a quarter of what the turn cost.
  assertEquals(m.gatewayCostUsd, 0.00412 + 0.00121 + 0.00098);
});

Deno.test('the gateway saying nothing is null, never a zero charge', () => {
  const m = callMetrics([step({ input: 900, output: 40 })], totalUsage({ input: 900, cacheRead: 0, cacheWrite: 0, output: 40 }));
  assertEquals(m.gatewayCostUsd, null, 'no charge reported is not a free call');
  assertEquals(m.cacheReadTokens, 0, 'a real zero cache read is still zero');
  assertEquals(m.cacheWriteTokens, 0);
});

Deno.test('a turn the SDK reported no steps for still logs its cache and its step count', () => {
  const m = callMetrics(undefined, totalUsage({ input: 1200, cacheRead: 0, cacheWrite: 900, output: 50 }));
  assertEquals(m.steps, 0);
  assertEquals(m.firstStepInputTokens, null);
  assertEquals(m.firstStepCacheReadTokens, null);
  assertEquals(m.cacheWriteTokens, 900);
});

Deno.test('cacheWriteTokens reads the v6 usage shape and nothing else', () => {
  assertEquals(cacheWriteTokens({ inputTokenDetails: { cacheWriteTokens: 4800 } }), 4800);
  assertEquals(cacheWriteTokens({ inputTokenDetails: { cacheWriteTokens: 0 } }), 0);
  assertEquals(cacheWriteTokens({ inputTokens: 100 }), null);
  assertEquals(cacheWriteTokens(undefined), null);
});

// ---------------------------------------------------------------- 2. every new column is written

/** The columns the migration adds to vana_calls, read out of the migration itself. */
async function migrationColumns(): Promise<string[]> {
  const sql = await Deno.readTextFile(MIGRATION);
  const alter = sql.slice(sql.indexOf('alter table public.vana_calls'));
  const block = alter.slice(0, alter.indexOf(';'));
  return [...block.matchAll(/add column if not exists\s+([a-z_]+)/g)].map((m) => m[1]);
}

Deno.test('the migration adds the columns the ticket names', async () => {
  const cols = await migrationColumns();
  for (const c of ['cache_write_tokens', 'steps', 'gateway_cost_usd', 'debited', 'input_mode', 'subscriber_period_type', 'subscriber_active_until', 'first_step_input_tokens', 'first_step_cache_read_tokens']) {
    assert(cols.includes(c), `the migration is missing ${c}`);
  }
});

Deno.test('a finished chat turn writes every new column onto its reservation', async () => {
  const v = testCtx({ vana_calls: [] });
  const reserved = await reserveCall(v.admin, U, 'vana.chat', { functionName: 'vana.chat.meal_planning', model: 'anthropic/claude-haiku-4.5' });
  assert(reserved.allowed);

  const steps = [step({ input: 31_000, cacheRead: 26_000, cacheWrite: 4_800, output: 120, cost: '0.004' })];
  await completeCall(v.admin, reserved.callId, {
    inputTokens: 31_000,
    outputTokens: 120,
    functionName: 'vana.chat.meal_planning',
    conversationId: '22222222-2222-4222-8222-222222222222',
    ...callMetrics(steps, totalUsage({ input: 31_000, cacheRead: 26_000, cacheWrite: 4_800, output: 120 })),
    debited: true,
    inputMode: 'typed',
    subscriberPeriodType: 'NORMAL',
    subscriberActiveUntil: '2027-09-21T00:00:00Z',
  });

  const row = v.fake.rows('vana_calls')[0];
  for (const c of await migrationColumns()) {
    assert(row[c] !== undefined, `${c} was added to the table but nothing writes it`);
    assert(row[c] !== null, `${c} was written as null on a turn that knows the answer`);
  }
  assertEquals(row.steps, 1);
  assertEquals(row.first_step_cache_read_tokens, 26_000);
  assertEquals(row.gateway_cost_usd, 0.004);
  assertEquals(row.debited, true);
  assertEquals(row.input_mode, 'typed');
  assertEquals(row.subscriber_period_type, 'NORMAL');
});

Deno.test('a background job logs the same columns, with the ones it cannot know left null', async () => {
  const v = testCtx();
  await logCall(v.admin, { userId: U, functionName: 'vana.daynotes', model: 'anthropic/claude-haiku-4.5', inputTokens: 2400, outputTokens: 310, steps: 1, gatewayCostUsd: 0.0021, debited: false, inputMode: null, subscriberPeriodType: 'TRIAL', subscriberActiveUntil: '2026-09-28T00:00:00Z' });
  const [write] = v.fake.writesTo('vana_calls', 'insert');
  assertEquals(write.values.input_mode, null, 'a background job is neither tapped nor typed');
  assertEquals(write.values.debited, false);
  assertEquals(write.values.subscriber_period_type, 'TRIAL');
  assertEquals(write.values.steps, 1);
});

Deno.test('a caller that mentions no cost fields leaves those columns alone', () => {
  // `completeCall` is also the meal-photo and describe-meal path; a partial caller must not blank what it did not set.
  const patch = costColumns({ cacheReadTokens: 0 });
  assertEquals(Object.keys(patch), ['cache_read_tokens']);
  assertEquals('input_mode' in patch, false);
  assertEquals('debited' in patch, false);
});

// ---------------------------------------------------------------- 3. tap or typed

Deno.test('tap or typed is narrowed, and anything else is null rather than a refusal', () => {
  assertEquals(asInputMode('tap'), 'tap');
  assertEquals(asInputMode('typed'), 'typed');
  assertEquals(asInputMode('TAP'), null);
  assertEquals(asInputMode(undefined), null);
  assertEquals(asInputMode(null), null);
  assertEquals(asInputMode(7), null);
  assertEquals(asInputMode({ tap: true }), null);
});

// ---------------------------------------------------------------- 4. the plan and trial state

Deno.test('the subscriber state is the entitlement row as the webhook wrote it', async () => {
  const v = testCtx({ user_entitlements: [{ user_id: U, period_type: 'TRIAL', active_until: '2026-09-28T12:00:00Z', event_at: '2026-09-21T12:00:00Z' }] });
  assertEquals(await subscriberState(v.admin, U), { periodType: 'TRIAL', activeUntil: '2026-09-28T12:00:00Z' });
});

Deno.test('no entitlement row, or a read that fails, logs nulls rather than not logging', async () => {
  assertEquals(await subscriberState(testCtx({ user_entitlements: [] }).admin, U), UNKNOWN_SUBSCRIBER);
  const broken = testCtx({ user_entitlements: [] }, { errors: { user_entitlements: 'connection reset' } });
  assertEquals(await subscriberState(broken.admin, U), UNKNOWN_SUBSCRIBER);
});
