/**
 * "The fault is ours" — telling the gateway refusing US apart from the athlete's own wallet (mp-437).
 *
 * Two different 402s exist in this codebase and they must never be confused:
 *
 *   OUR 402   `insufficientCreditsBody()` in `_shared/ai/credits.ts` — the athlete's wallet is empty.
 *             The client raises the top-up sheet. Nothing here touches that path.
 *
 *   THEIR 402 the Vercel AI Gateway refusing the request: the key's monthly budget hard-stopped,
 *             or the key is missing / revoked / forbidden. The athlete's own budget is fine, so the
 *             top-up sheet would be a lie. Every such refusal leaves this server as
 *             `{ error: 'ai_unavailable' }` (HTTP 503 on a unary call, `code` on the NDJSON error
 *             line), and the client shows "Vana is unavailable right now" from the content system.
 *
 * Detection is duck-typed on purpose: the SDK's `GatewayError` classes are not exported from
 * `npm:ai`, and a refusal can also arrive as a bare `APICallError` from the provider-utils fetch
 * before the gateway wrapper sees it. The one stable contract is the marker symbol the SDK stamps
 * on every gateway error (`Symbol.for('vercel.ai.gateway.error')`, `@ai-sdk/gateway`
 * `src/errors/gateway-error.ts`) plus the HTTP status.
 */

import { jsonResponse } from '../responses.ts';

/** The wire code. One string, server and client, for every gateway refusal. */
export const AI_UNAVAILABLE = 'ai_unavailable';

/** The SDK's marker for "this error came from the gateway layer". */
const GATEWAY_MARKER = Symbol.for('vercel.ai.gateway.error');

/** Gateway error `type`s that mean the refusal is about OUR key, not the athlete's request. */
const REFUSAL_TYPES = new Set(['authentication_error', 'forbidden']);

/** Statuses the gateway answers with when it will not spend on our behalf. */
const REFUSAL_STATUSES = new Set([401, 402, 403]);

// deno-lint-ignore no-explicit-any
type Loose = any;

const statusOf = (e: Loose): number | undefined => {
  const s = e?.statusCode ?? e?.status;
  return typeof s === 'number' ? s : undefined;
};

const hasGatewayMarker = (e: Loose): boolean =>
  typeof e === 'object' && e !== null && GATEWAY_MARKER in e && e[GATEWAY_MARKER] === true;

/** `https://ai-gateway.vercel.sh/...` on an `APICallError` that never reached the gateway wrapper. */
const fromGatewayUrl = (e: Loose): boolean =>
  typeof e?.url === 'string' && e.url.includes('ai-gateway.vercel.sh');

function refusesHere(e: Loose): boolean {
  if (e == null || typeof e !== 'object') return false;
  const status = statusOf(e);
  // A 402 is only ever the gateway's: our own wallet's 402 never leaves this process as an exception.
  if (status === 402) return true;
  // A 401 from the gateway reaches us as a plain `Error` named `GatewayAuthenticationError`: the SDK swaps its own
  // error for one with setup advice and drops the marker, the status and the cause (seen on ai@6.0.277; pinned by
  // gateway_refusal.test.ts, which drives the real SDK).
  if (e.name === 'GatewayAuthenticationError') return true;
  const gatewayish = hasGatewayMarker(e) || fromGatewayUrl(e);
  if (!gatewayish) return false;
  if (status !== undefined && REFUSAL_STATUSES.has(status)) return true;
  return typeof e.type === 'string' && REFUSAL_TYPES.has(e.type);
}

/**
 * True when [error] — or anything in its `cause` chain — is the gateway refusing to serve us.
 *
 * A model's own rate limit (429), a timeout, a 5xx and a bad request are NOT refusals: those are
 * ordinary server errors and keep their existing handling.
 */
export function isGatewayRefusal(error: unknown): boolean {
  let e: Loose = error;
  for (let depth = 0; e != null && depth < 5; depth++) {
    if (refusesHere(e)) return true;
    e = e.cause;
  }
  return false;
}

/** The body every unary function returns for a refusal, alongside HTTP 503. */
export function aiUnavailableBody(): { success: false; error: string } {
  return { success: false, error: AI_UNAVAILABLE };
}

/**
 * The one catch-block arm every AI function shares: a 503 `{error:'ai_unavailable'}` when [error] is
 * the gateway refusing us, else null so the caller keeps its own handling. Nothing is debited on this
 * path: every function debits only after a successful generation.
 */
export function gatewayRefusalResponse(error: unknown, tag: string): Response | null {
  if (!isGatewayRefusal(error)) return null;
  console.error(`[${tag}] AI Gateway refused the request:`, error);
  return jsonResponse(aiUnavailableBody(), 503);
}
