/** A repeated Vana write runs once (testing-wave 134, IMPROVEMENTS #82, Lee 2026-09-26).
 *
 *  The phone's 20 s transport timeout reports "needs a connection" while the edge function keeps running, so a slow
 *  `pick_meals`, `log_from_plan` or `save_meal` can land after the screen said it failed, and a second tap wrote it
 *  twice. The phone now mints one id per user action (a UUID the action's retry reuses) and sends it as `requestId`.
 *
 *  Here the id is claimed in `vana_action_requests` BEFORE the action runs (migration 20260926163400): the row is the
 *  lock, an insert that conflicts on (user, request id) claims nothing. Whoever claims it runs the action and stores
 *  the result on the row; a repeat that arrives afterwards gets that stored result back and writes nothing; a repeat
 *  that arrives while the first is still running is refused as `in_progress` (409). A run that throws releases its
 *  claim so the retry runs again. A `running` row older than the TTL is taken over (an isolate torn down mid-write).
 *
 *  Only the three write types the ruling names are covered; every other action, and any call without a `requestId`,
 *  runs as before. A claim that cannot be asked for (the RPC missing on a project the migration has not reached, a
 *  database error) fails OPEN: the table is a safety net behind the phone's own in-flight guards, never a gate. */
import type { VanaCtx } from './env.ts';
import type { ActionResult } from './actions.ts';

/** The writes a `requestId` dedupes. `unpick_meal` is idempotent by nature (removing twice removes once). */
export const IDEMPOTENT_ACTIONS: ReadonlySet<string> = new Set(['pick_meals', 'log_from_plan', 'save_meal']);
export const REQUEST_ID_MAX = 64;
/** How long a `running` claim is honoured before another request may take it over. */
export const REQUEST_TTL_SECONDS = 120;

/** The same request id arrived while its first run is still on the server. vana-action answers 409. */
export class RequestInProgressError extends Error {
  constructor(public readonly requestId: string) { super('in_progress'); this.name = 'RequestInProgressError'; }
}

/** `payload.requestId` (or `request_id`), trimmed; null when absent. A malformed id is a bad request, not a silent run. */
// deno-lint-ignore no-explicit-any
export function requestIdOf(payload: Record<string, any>): string | null {
  const raw = payload.requestId ?? payload.request_id;
  if (raw == null || raw === '') return null;
  const id = String(raw).trim();
  if (!id || id.length > REQUEST_ID_MAX) throw new Error(`requestId must be 1-${REQUEST_ID_MAX} characters`);
  return id;
}

type Claim = { claimed: boolean; status?: 'running' | 'done'; action_type?: string; result?: unknown };

/** Run `run` once per (user, requestId) for the idempotent action types; see the module comment. */
// deno-lint-ignore no-explicit-any
export async function withRequestId(v: VanaCtx, type: string, payload: Record<string, any>, run: () => Promise<ActionResult>): Promise<ActionResult> {
  const id = requestIdOf(payload);
  if (!id || !IDEMPOTENT_ACTIONS.has(type)) return run();

  const { data, error } = await v.db.rpc('vana_claim_action_request', { p_request_id: id, p_action_type: type, p_ttl_seconds: REQUEST_TTL_SECONDS });
  if (error || !data || typeof data !== 'object') {
    console.warn(`[vana] request claim unavailable for ${type} ${id}: ${error?.message ?? 'no answer'}; running unguarded`);
    return run();
  }
  const claim = data as Claim;
  if (!claim.claimed) {
    if (claim.action_type && claim.action_type !== type) throw new Error(`requestId ${id} was used for ${claim.action_type}, not ${type}`);
    if (claim.status === 'done' && claim.result && typeof claim.result === 'object') {
      console.log(`[vana] ${type} ${id} repeated: answering the stored result, nothing written`);
      return claim.result as ActionResult;
    }
    throw new RequestInProgressError(id);
  }

  try {
    const result = await run();
    const { error: finishError } = await v.db.rpc('vana_finish_action_request', { p_request_id: id, p_result: result });
    if (finishError) console.warn(`[vana] request ${id} ran but its result was not stored: ${finishError.message}`);
    return result;
  } catch (e) {
    // Nothing of ours landed as a whole: let the retry run again instead of answering "in progress" forever.
    const { error: releaseError } = await v.db.rpc('vana_release_action_request', { p_request_id: id });
    if (releaseError) console.warn(`[vana] request ${id} failed and its claim was not released: ${releaseError.message}`);
    throw e;
  }
}
