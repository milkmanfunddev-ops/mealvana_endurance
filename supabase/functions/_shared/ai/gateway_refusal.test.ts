/**
 * `deno test --allow-env --allow-sys --allow-net --allow-read supabase/functions/_shared/ai/gateway_refusal.test.ts`
 *
 * The gateway refusing us (mp-437, ticket ai-cost 02), driven through the REAL AI SDK: `fetch` is stubbed
 * so every call to the gateway answers 402, and the error the SDK then throws (or streams) goes through the
 * exact code the functions run: the unary catch arm (`gatewayRefusalResponse`, used by describe-meal,
 * analyze-meal-photo, ai-coach, vana-chat pre-stream and vana-action) and the NDJSON stream
 * (`ndjsonFromFullStream`, vana-chat mid-stream). No fixture is hand-shaped here, so a change in how the
 * SDK wraps a gateway error fails this file rather than production.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { generateObject, streamText } from 'npm:ai@6.0.277';
import { z } from 'npm:zod@3';
import { AI_UNAVAILABLE, gatewayRefusalResponse, isGatewayRefusal } from './gateway_error.ts';
import { ndjsonFromFullStream } from '../vana/stream.ts';

const MODEL = 'anthropic/claude-haiku-4.5';

/** Run [body] with every gateway request answered by [status] + [payload]. Returns the gateway URLs hit. */
async function withGatewayAnswering<T>(
  status: number,
  payload: unknown,
  body: () => Promise<T>,
): Promise<{ result: T; hits: string[] }> {
  const realFetch = globalThis.fetch;
  const hadKey = Deno.env.get('AI_GATEWAY_API_KEY');
  Deno.env.set('AI_GATEWAY_API_KEY', 'test-key-not-real');
  const hits: string[] = [];
  globalThis.fetch = ((input: Request | URL | string, _init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    hits.push(url);
    return Promise.resolve(
      new Response(JSON.stringify(payload), { status, headers: { 'content-type': 'application/json' } }),
    );
  }) as typeof fetch;
  try {
    return { result: await body(), hits };
  } finally {
    globalThis.fetch = realFetch;
    if (hadKey == null) Deno.env.delete('AI_GATEWAY_API_KEY');
    else Deno.env.set('AI_GATEWAY_API_KEY', hadKey);
  }
}

/** A budget hard-stop, in the gateway's error envelope. */
const BUDGET_402 = { error: { message: 'Budget exceeded for this API key', type: 'insufficient_funds' } };

async function unaryCall(): Promise<unknown> {
  try {
    await generateObject({ model: MODEL, schema: z.object({ ok: z.boolean() }), prompt: 'x', maxRetries: 0 });
    return null;
  } catch (e) {
    return e;
  }
}

Deno.test('unary: a gateway 402 becomes 503 {error:"ai_unavailable"}, never a 402', async () => {
  const { result: error, hits } = await withGatewayAnswering(402, BUDGET_402, unaryCall);
  assert(hits.some((u) => u.includes('ai-gateway.vercel.sh')), `the SDK called the gateway: ${hits.join(', ')}`);
  assert(error != null, 'the SDK threw');
  assertEquals(isGatewayRefusal(error), true);

  const res = gatewayRefusalResponse(error, 'test');
  assert(res != null);
  assertEquals(res.status, 503);
  assertEquals(await res.json(), { success: false, error: AI_UNAVAILABLE });
});

Deno.test('unary: a revoked key (401) is a refusal too', async () => {
  const { result: error } = await withGatewayAnswering(
    401,
    { error: { message: 'Invalid API key', type: 'authentication_error' } },
    unaryCall,
  );
  assertEquals(gatewayRefusalResponse(error, 'test')?.status, 503);
});

Deno.test('unary: a gateway 400 is NOT a refusal; the function keeps its own error path', async () => {
  const { result: error } = await withGatewayAnswering(
    400,
    { error: { message: 'bad request', type: 'invalid_request_error' } },
    unaryCall,
  );
  assert(error != null);
  assertEquals(gatewayRefusalResponse(error, 'test'), null);
});

Deno.test('stream: a gateway 402 mid-turn is an error line with code "ai_unavailable", then done', async () => {
  const { result: lines } = await withGatewayAnswering(402, BUDGET_402, async () => {
    const run = streamText({ model: MODEL, prompt: 'x', maxRetries: 0 });
    const body = ndjsonFromFullStream(run.fullStream, { tag: '[test]' });
    const text = await new Response(body).text();
    return text.trim().split('\n').map((l) => JSON.parse(l));
  });
  const error = lines.find((l) => l.type === 'error');
  assert(error, `an error line: ${JSON.stringify(lines)}`);
  assertEquals(error.code, AI_UNAVAILABLE);
  assertEquals(lines.at(-1).type, 'done');
});

Deno.test('stream: an ordinary gateway 500 carries no code', async () => {
  const { result: lines } = await withGatewayAnswering(
    500,
    { error: { message: 'upstream', type: 'internal_server_error' } },
    async () => {
      const run = streamText({ model: MODEL, prompt: 'x', maxRetries: 0 });
      return (await new Response(ndjsonFromFullStream(run.fullStream, { tag: '[test]' })).text())
        .trim().split('\n').map((l) => JSON.parse(l));
    },
  );
  const error = lines.find((l) => l.type === 'error');
  assert(error);
  assertEquals(error.code, undefined);
});
