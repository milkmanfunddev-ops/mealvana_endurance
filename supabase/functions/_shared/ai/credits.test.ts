/**
 * AI credits (round develop-2026-10, ticket 23): the 50-token free grant, a
 * cost of 1 per describe / photo / formula-kit call, the 402 body, and the
 * debit RPC. CREDITS_ENFORCED is read at module load, so the env is set
 * before a dynamic import. The RPC client is a fake.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/_shared/ai
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { setSentryClientForTesting } from '../sentry.ts';
import { FakeSentry } from '../sentry_fake_client.ts';

Deno.env.set('AI_CREDITS_ENFORCED', 'true');
Deno.env.delete('AI_FREE_MONTHLY_CREDITS');
for (const k of ['AI_COST_DESCRIBE_MEAL', 'AI_COST_ANALYZE_MEAL_PHOTO', 'AI_COST_AI_COACH']) Deno.env.delete(k);

const credits = await import('./credits.ts');

// deno-lint-ignore no-explicit-any
function fakeClient(answers: Record<string, { data: unknown; error: unknown }>): any {
  const calls: Array<{ fn: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    rpc: (fn: string, args: Record<string, unknown>) => {
      calls.push({ fn, args });
      return Promise.resolve(answers[fn] ?? { data: null, error: null });
    },
  };
}

Deno.test('enforcement is on and the free grant is 50 with the env unset', () => {
  assertEquals(credits.CREDITS_ENFORCED, true);
  assertEquals(credits.FREE_MONTHLY_CREDITS, 50);
});

Deno.test('describe, photo and formula-kit calls each cost 1', () => {
  assertEquals(credits.creditCost('describe-meal'), 1);
  assertEquals(credits.creditCost('analyze-meal-photo'), 1);
  assertEquals(credits.creditCost('ai-coach'), 1);
});

Deno.test('a balance of 0 is refused with the structured 402 body', async () => {
  const client = fakeClient({ ensure_free_credits: { data: 0, error: null } });

  const check = await credits.ensureAndCheckCredits(client, 'user-1', 'describe-meal');

  assertEquals(check, { allowed: false, balance: 0, cost: 1 });
  assertEquals(client.calls, [{ fn: 'ensure_free_credits', args: { p_user_id: 'user-1', p_amount: 50 } }]);
  assertEquals(credits.insufficientCreditsBody(check), {
    error: 'insufficient_credits',
    message: 'You are out of AI credits. Purchase more to continue.',
    balance: 0,
    cost: 1,
  });
});

Deno.test('a balance of 1 is allowed', async () => {
  const client = fakeClient({ ensure_free_credits: { data: 1, error: null } });
  const check = await credits.ensureAndCheckCredits(client, 'user-1', 'ai-coach');
  assertEquals(check, { allowed: true, balance: 1, cost: 1 });
});

Deno.test('debitForUsage sends debit_credits for 1 with the function as ref', async () => {
  const client = fakeClient({ debit_credits: { data: { success: true, balance: 49 }, error: null } });

  await credits.debitForUsage(client, 'user-1', 'analyze-meal-photo');

  assertEquals(client.calls, [{
    fn: 'debit_credits',
    args: { p_user_id: 'user-1', p_amount: 1, p_reason: 'debit_usage', p_ref: 'analyze-meal-photo' },
  }]);
});

Deno.test('a success:false debit logs and does not throw', async () => {
  const sentry = new FakeSentry();
  setSentryClientForTesting(sentry);
  const warnings: unknown[] = [];
  const originalWarn = console.warn;
  console.warn = (...args: unknown[]) => warnings.push(args);
  try {
    const client = fakeClient({ debit_credits: { data: { success: false, balance: 0 }, error: null } });
    await credits.debitForUsage(client, 'user-1', 'describe-meal');
    assertEquals(warnings.length, 1);
  } finally {
    console.warn = originalWarn;
    setSentryClientForTesting(null);
  }
});

Deno.test('a debit RPC error is reported as a warning and does not throw', async () => {
  const sentry = new FakeSentry();
  setSentryClientForTesting(sentry);
  try {
    const client = fakeClient({ debit_credits: { data: null, error: { message: 'boom' } } });
    await credits.debitForUsage(client, 'user-1', 'ai-coach');
    assertEquals(sentry.captures.length, 1);
    assertEquals(sentry.captures[0].context?.level, 'warning');
  } finally {
    setSentryClientForTesting(null);
  }
});
