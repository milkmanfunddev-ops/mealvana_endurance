/**
 * The cached prefix at the chat seam (mp-276): the prompt order is tools, persona, context, messages; the
 * gateway call carries Anthropic's automatic cache_control; the cache-read count reaches vana_calls and the
 * NDJSON `done` line. No model is called — the stream is fed producer-shaped AI SDK parts.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { systemPrompt, CACHE_PROVIDER_OPTIONS } from '../../_shared/vana/chat.ts';
import { PLANNING_PROMPT, GENERAL_PROMPT } from '../../_shared/vana/persona.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { logCall } from '../../_shared/vana/log.ts';
import { ndjsonFromFullStream, cacheReadTokens } from '../../_shared/vana/stream.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';

Deno.test('prompt order: persona first, the context block last, nothing after it', async () => {
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }] });
  const c = await buildAthleteContext(v, ANCHOR, offlineDeps());
  for (const [kind, persona] of [['meal_planning', PLANNING_PROMPT], ['general', GENERAL_PROMPT]] as const) {
    const p = systemPrompt(kind, c, ANCHOR);
    assert(p.startsWith(persona), `${kind}: the persona opens the system prompt`);
    assert(p.endsWith(contextBlock(c)), `${kind}: the block closes it`);
    assertEquals(p, `${persona}\n--- CONTEXT (today 2026-09-09, Wednesday) ---\n${contextBlock(c)}`);
  }
  // Two turns on one day, no writes between: the same bytes go to the model.
  assertEquals(systemPrompt('general', c, ANCHOR), systemPrompt('general', await buildAthleteContext(v, ANCHOR, offlineDeps()), ANCHOR));
});

Deno.test('the gateway call carries automatic caching', () => {
  assertEquals(CACHE_PROVIDER_OPTIONS, { anthropic: { cacheControl: { type: 'ephemeral' } } });
});

Deno.test('the cache-read count is written to vana_calls beside the input tokens', async () => {
  const v = testCtx();
  await logCall(v.admin, { userId: U, conversationId: 'conv-1', functionName: 'vana.chat.general', model: 'anthropic/claude-haiku-4-5', inputTokens: 5200, outputTokens: 90, cacheReadTokens: 4900 });
  await logCall(v.admin, { userId: U, conversationId: 'conv-1', functionName: 'vana.chat.general', model: 'anthropic/claude-haiku-4-5', inputTokens: 5200, outputTokens: 90 });
  const rows = v.fake.writesTo('vana_calls', 'insert').map((w) => w.values);
  assertEquals(rows[0].input_tokens, 5200); assertEquals(rows[0].cache_read_tokens, 4900);
  assertEquals(rows[1].cache_read_tokens, null, 'a call that reported nothing logs null, not a fake zero');
});

Deno.test('cacheReadTokens reads the v6 usage shape, the deprecated one, and nothing', () => {
  assertEquals(cacheReadTokens({ inputTokens: 100, inputTokenDetails: { cacheReadTokens: 80 } }), 80);
  assertEquals(cacheReadTokens({ inputTokens: 100, inputTokenDetails: { cacheReadTokens: 0 } }), 0);
  assertEquals(cacheReadTokens({ inputTokens: 100, cachedInputTokens: 42 }), 42);
  assertEquals(cacheReadTokens({ inputTokens: 100 }), null);
  assertEquals(cacheReadTokens(undefined), null);
});

async function* parts(finishUsage: unknown) {
  yield { type: 'text-start' };
  yield { type: 'text-delta', text: 'Rice.' };
  yield { type: 'finish', totalUsage: finishUsage };
}
const lines = async (usage: unknown) => {
  const body = await new Response(ndjsonFromFullStream(parts(usage))).text();
  return body.trim().split('\n').map((l) => JSON.parse(l));
};

Deno.test('the done line carries cache_read_tokens for the eval', async () => {
  const out = await lines({ inputTokens: 5200, outputTokens: 90, inputTokenDetails: { noCacheTokens: 300, cacheReadTokens: 4900, cacheWriteTokens: 0 } });
  assertEquals(out.at(-1), { type: 'done', usage: { input_tokens: 5200, output_tokens: 90, cache_read_tokens: 4900 } });
  const none = await lines({ inputTokens: 5200, outputTokens: 90 });
  assertEquals(none.at(-1), { type: 'done', usage: { input_tokens: 5200, output_tokens: 90, cache_read_tokens: null } });
});
