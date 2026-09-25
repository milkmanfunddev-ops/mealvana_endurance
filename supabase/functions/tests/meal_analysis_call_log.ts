/**
 * The shared claim both meal-logging functions make about the call log (testing-wave ticket 43, Finding 24-001):
 * one AI logging call leaves one `vana_calls` row. `jade_calls` is a view over `vana_calls`, so an insert through it
 * is a second row, and `vana_weekly_cost` counts rows as calls and sums their tokens.
 *
 * Imported by `analyze-meal-photo/index.test.ts` and `describe-meal/index.test.ts`; each runs it for its own source.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { finishMealCall } from '../_shared/meal_analysis/call_log.ts';
import { reserveCall } from '../_shared/vana/rate-limit.ts';
import type { RateLimitedFn } from '../_shared/vana/rate-limit.ts';
import { testCtx, TEST_USER_ID } from './vana/support/vana_ctx.ts';

/** `generateObject`'s usage and provider metadata, as the AI SDK hands them back. */
const usage = {
  inputTokens: 2368,
  outputTokens: 162,
  inputTokenDetails: { noCacheTokens: 2368, cacheReadTokens: 0, cacheWriteTokens: 0 },
  outputTokenDetails: { textTokens: 162, reasoningTokens: 0 },
  totalTokens: 2530,
};
const providerMetadata = { gateway: { cost: '0.013695' } };

export function oneCallOneRow(opts: { name: string; source: URL; bucket: RateLimitedFn; model: string }) {
  Deno.test(`${opts.name}: the function writes the call log only through the reservation it finishes`, async () => {
    const src = await Deno.readTextFile(opts.source);
    assertEquals(src.match(/from\(\s*["'](jade_calls|vana_calls)["']\s*\)/g), null, 'a direct call-log write is a second row for the same call');
    assertEquals(src.match(/\bcompleteCall\(|\blogCall\(/g), null, 'finish the call through finishMealCall, which covers the fail-open reservation');
    assertEquals(src.match(/\bfinishMealCall\(/g)?.length, 1, 'the call is finished exactly once');
  });

  Deno.test(`${opts.name}: one call leaves one call-log row carrying its tokens, charge and plan state`, async () => {
    const v = testCtx({ vana_calls: [], user_entitlements: [{ user_id: TEST_USER_ID, period_type: 'NORMAL', active_until: '2027-09-21T00:00:00Z' }] });
    const reserved = await reserveCall(v.admin, TEST_USER_ID, opts.bucket, { model: opts.model });
    assert(reserved.allowed && reserved.callId);

    await finishMealCall(v.admin, { userId: TEST_USER_ID, callId: reserved.callId, bucket: opts.bucket, model: opts.model, usage, providerMetadata });

    const rows = v.fake.rows('vana_calls');
    assertEquals(rows.length, 1);
    assertEquals(rows[0].function_name, opts.bucket);
    assertEquals(rows[0].input_tokens, 2368);
    assertEquals(rows[0].output_tokens, 162);
    assertEquals(rows[0].gateway_cost_usd, 0.013695);
    assertEquals(rows[0].debited, true);
    assertEquals(rows[0].steps, 1);
    assertEquals(rows[0].subscriber_period_type, 'NORMAL');
  });

  Deno.test(`${opts.name}: a reservation that failed open still leaves exactly one row`, async () => {
    const v = testCtx({ vana_calls: [], user_entitlements: [] });
    await finishMealCall(v.admin, { userId: TEST_USER_ID, callId: null, bucket: opts.bucket, model: opts.model, usage, providerMetadata });

    const rows = v.fake.rows('vana_calls');
    assertEquals(rows.length, 1);
    assertEquals(rows[0].user_id, TEST_USER_ID);
    assertEquals(rows[0].function_name, opts.bucket);
    assertEquals(rows[0].model, opts.model);
    assertEquals(rows[0].input_tokens, 2368);
    assertEquals(rows[0].debited, true);
  });
}
