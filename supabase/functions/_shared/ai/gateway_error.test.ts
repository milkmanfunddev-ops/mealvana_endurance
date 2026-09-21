/**
 * `deno test --allow-env --allow-sys supabase/functions/_shared/ai/gateway_error.test.ts`
 *
 * The fixtures are shaped the way the AI SDK really shapes these errors (`@ai-sdk/gateway`
 * `src/errors/*.ts`): the marker symbol `Symbol.for('vercel.ai.gateway.error')` set to `true`,
 * a numeric `statusCode`, and a `type` string. Nothing here imports the SDK — the classes are
 * not exported from `npm:ai`, and an edge function only ever sees the shape.
 */
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { AI_UNAVAILABLE, aiUnavailableBody, isGatewayRefusal } from './gateway_error.ts';

const MARKER = Symbol.for('vercel.ai.gateway.error');

/** What the SDK hands us when the gateway answers a non-2xx. */
function gatewayError(
  { statusCode, type, message = 'gateway said no' }: { statusCode: number; type?: string; message?: string },
): Error {
  const e = new Error(message) as Error & Record<string | symbol, unknown>;
  e[MARKER] = true;
  e.statusCode = statusCode;
  if (type) e.type = type;
  return e;
}

/** A bare `APICallError` from provider-utils' fetch, before the gateway wrapper sees it. */
function apiCallError({ statusCode, url }: { statusCode: number; url: string }): Error {
  const e = new Error(`API call failed: ${statusCode}`) as Error & Record<string, unknown>;
  e.name = 'AI_APICallError';
  e.statusCode = statusCode;
  e.url = url;
  return e;
}

describe('isGatewayRefusal', () => {
  it('the gateway 402 — the key\'s monthly budget hard-stopped', () => {
    assertEquals(isGatewayRefusal(gatewayError({ statusCode: 402 })), true);
  });

  it('a 402 straight off the gateway URL, before the wrapper', () => {
    assertEquals(
      isGatewayRefusal(apiCallError({ statusCode: 402, url: 'https://ai-gateway.vercel.sh/v1/chat/completions' })),
      true,
    );
  });

  it('the key is missing or revoked (401 authentication_error)', () => {
    assertEquals(isGatewayRefusal(gatewayError({ statusCode: 401, type: 'authentication_error' })), true);
  });

  it('the key is missing or revoked, as the SDK really rethrows it (a bare Error by name)', () => {
    const e = new Error('Unauthenticated request to AI Gateway.');
    e.name = 'GatewayAuthenticationError';
    assertEquals(isGatewayRefusal(e), true);
  });

  it('the key is forbidden (403 forbidden)', () => {
    assertEquals(isGatewayRefusal(gatewayError({ statusCode: 403, type: 'forbidden' })), true);
  });

  it('a refusal wrapped in another error still counts', () => {
    const outer = new Error('streamText failed');
    (outer as Error & { cause?: unknown }).cause = gatewayError({ statusCode: 402 });
    assertEquals(isGatewayRefusal(outer), true);
  });

  it('the model rate-limiting us is NOT a refusal — 429 keeps its own handling', () => {
    assertEquals(isGatewayRefusal(gatewayError({ statusCode: 429, type: 'rate_limit_exceeded' })), false);
  });

  it('a gateway 500 is NOT a refusal — that is an ordinary server error', () => {
    assertEquals(isGatewayRefusal(gatewayError({ statusCode: 500, type: 'internal_server_error' })), false);
  });

  it('a bad request is NOT a refusal', () => {
    assertEquals(isGatewayRefusal(gatewayError({ statusCode: 400, type: 'invalid_request_error' })), false);
  });

  it('a 401 from somewhere that is not the gateway is NOT a refusal', () => {
    assertEquals(isGatewayRefusal(apiCallError({ statusCode: 401, url: 'https://example.supabase.co/rest/v1/meals' })), false);
  });

  it('a plain error, a string, null and undefined are not refusals', () => {
    assertEquals(isGatewayRefusal(new Error('boom')), false);
    assertEquals(isGatewayRefusal('boom'), false);
    assertEquals(isGatewayRefusal(null), false);
    assertEquals(isGatewayRefusal(undefined), false);
  });

  it('a cycle in the cause chain terminates', () => {
    const a = new Error('a') as Error & { cause?: unknown };
    const b = new Error('b') as Error & { cause?: unknown };
    a.cause = b;
    b.cause = a;
    assertEquals(isGatewayRefusal(a), false);
  });
});

describe('aiUnavailableBody', () => {
  it('carries the one wire code the client branches on', () => {
    assertEquals(aiUnavailableBody(), { success: false, error: 'ai_unavailable' });
    assertEquals(AI_UNAVAILABLE, 'ai_unavailable');
  });
});
