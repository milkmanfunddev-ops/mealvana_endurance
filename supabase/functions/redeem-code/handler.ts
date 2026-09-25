/**
 * The redeem-code request handler (mp-458, mp-429 clauses 4 and 8; paywall ticket 07),
 * built with its dependencies injected so the seam tests (handler.test.ts) run
 * this exact code against a fake database and a fake RevenueCat client.
 * index.ts wires it to the caller's JWT, the service-role client and the one
 * RevenueCat REST client (_shared/revenuecat).
 *
 * A signed-in caller posts `{ code }`. The code is looked up in `public.codes`
 * and, once its window is checked, claimed through `code_claim` (one row in
 * `code_redemptions`, taken under a lock on the code so a giveaway cannot be
 * won twice). The row outlives the account: deleting it nulls `user_id` and
 * keeps the row, so a spent giveaway stays spent (mp-535, testing-wave 39).
 * Then, by type:
 *
 *   coach, entered by its owner      the account is marked coach (an approved
 *                                    `coaches` row) and gets `perk_days` (30)
 *                                    of `pro` from RevenueCat
 *   coach or influencer, by anyone   `coach_code` / `influencer_code` is set as
 *   else                             a subscriber attribute, and a pending,
 *                                    athlete-requested pairing with the owner
 *                                    is opened in `coach_athlete_relationships`,
 *                                    the row the app's pairing path writes and
 *                                    the coach accepts
 *   giveaway                         `perk_days` (365) of `pro`, once
 *
 * If a RevenueCat call or a write fails after the claim, the claim is released,
 * so the caller can try again and a code is never spent on nothing.
 *
 * Answers:
 *   200 { ok: true, kind: 'coach' | 'giveaway', pro_days }
 *   200 { ok: true, kind: 'paired', coach_user_id } | { ok: true, kind: 'attributed' }
 *   200 { ok: false, reason, message }   a refusal: the code is wrong, not open
 *                                        yet, expired, used, already redeemed
 *                                        by this caller, or the caller's own
 *                                        influencer code
 *   400 invalid_input · 401 unauthenticated · 403 sign_in_required (anonymous)
 *   405 method_not_allowed · 500 server_error · 502 store_unavailable
 *
 * A refusal is a 200 because it is an answer, not a failure: the app shows the
 * reason and the caller tries another code.
 */
import { corsHeaders } from '../_shared/cors.ts';
import { RevenueCatError, type RevenueCatClient } from '../_shared/revenuecat/client.ts';
import type { Db } from '../_shared/vana/env.ts';

export interface Caller {
  /** auth.users id — the same id RevenueCat knows the customer by. */
  userId: string;
  email: string | null;
  /** An anonymous session is not a signed-in caller (mp-458 clause 2). */
  anonymous: boolean;
}

export interface RedeemDeps {
  /** The caller behind the request's JWT, or null when there is none. */
  caller: (req: Request) => Promise<Caller | null>;
  /** Service-role client: the only reader and writer of `codes`. */
  db: () => Db;
  /** RevenueCat's REST API; throws when the secret key is not configured. */
  revenueCat: () => RevenueCatClient;
  now?: () => number;
}

export type CodeType = 'coach' | 'influencer' | 'giveaway';

interface CodeRow {
  id: string;
  code: string;
  type: CodeType;
  owner_user_id: string | null;
  valid_from: string;
  valid_until: string | null;
  perk_days: number;
}

/** The plain reasons a caller is given, one per refusal (mp-458 clause 6). */
export const REFUSALS = {
  not_found: "We don't recognise that code. Check it and try again.",
  not_yet_valid: "That code isn't active yet.",
  expired: 'That code has expired.',
  used: 'That code has already been used.',
  already_redeemed: "You've already used that code.",
  own_code: "That's your own code. Share it with your athletes.",
} as const;
export type Refusal = keyof typeof REFUSALS;

/** What `code_claim` answers: the claim was taken, or why not. */
type ClaimOutcome = 'claimed' | 'not_found' | 'used' | 'already_redeemed';

/** Codes are stored upper-case with no spaces; the longest one we would print. */
export const MAX_CODE_LENGTH = 32;

const CODE_COLUMNS = 'id, code, type, owner_user_id, valid_from, valid_until, perk_days';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

const refuse = (reason: Refusal) => json({ ok: false, reason, message: REFUSALS[reason] });

/** How the caller typed it → how the table holds it. */
export function normalizeCode(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const c = raw.replace(/\s+/g, '').toUpperCase();
  if (!c || c.length > MAX_CODE_LENGTH) return null;
  return c;
}

/** A failure after the claim: the claim is given back and the caller told to retry. */
class AfterClaimError extends Error {
  constructor(readonly status: 500 | 502, readonly error: 'server_error' | 'store_unavailable', message: string) {
    super(message);
  }
}

export function makeRedeemHandler(deps: RedeemDeps) {
  const now = deps.now ?? Date.now;

  return async function handle(req: Request): Promise<Response> {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

    const caller = await deps.caller(req);
    if (!caller) return json({ error: 'unauthenticated' }, 401);
    if (caller.anonymous) return json({ error: 'sign_in_required' }, 403);

    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return json({ error: 'invalid_input', details: 'body is not JSON' }, 400);
    }
    const entered = normalizeCode(body?.code);
    if (!entered) return json({ error: 'invalid_input', details: 'code is required' }, 400);

    const db = deps.db();
    const { data, error } = await db.from('codes').select(CODE_COLUMNS).eq('code', entered).maybeSingle();
    if (error) {
      console.error('[redeem-code] codes read failed:', error.message);
      return json({ error: 'server_error' }, 500);
    }
    const row = data as CodeRow | null;
    if (!row) return refuse('not_found');

    const t = now();
    if (Date.parse(row.valid_from) > t) return refuse('not_yet_valid');
    if (row.valid_until && Date.parse(row.valid_until) <= t) return refuse('expired');

    const isOwner = row.owner_user_id === caller.userId;
    if (row.type === 'influencer' && isOwner) return refuse('own_code');

    const { data: claim, error: claimError } = await db.rpc('code_claim', {
      p_code_id: row.id,
      p_user_id: caller.userId,
    });
    if (claimError) {
      console.error('[redeem-code] code_claim failed:', claimError.message);
      return json({ error: 'server_error' }, 500);
    }
    const outcome = claim as ClaimOutcome;
    if (outcome !== 'claimed') return refuse(outcome);

    try {
      const answer = await apply(deps, db, row, caller, isOwner);
      console.log(`[redeem-code] ${caller.userId} redeemed ${row.type} code ${row.code} → ${answer.kind}`);
      return json({ ok: true, ...answer });
    } catch (e) {
      await release(db, row.id, caller.userId);
      if (e instanceof AfterClaimError) {
        console.error(`[redeem-code] ${row.type} code ${row.code} for ${caller.userId}: ${e.message}`);
        return json({ error: e.error }, e.status);
      }
      console.error('[redeem-code] unexpected failure:', e);
      return json({ error: 'server_error' }, 500);
    }
  };
}

/** Do what the code grants. Throws AfterClaimError when a step fails. */
async function apply(
  deps: RedeemDeps,
  db: Db,
  row: CodeRow,
  caller: Caller,
  isOwner: boolean,
): Promise<Record<string, unknown>> {
  if (row.type === 'giveaway') {
    await grant(deps, caller.userId, row.perk_days);
    return { kind: 'giveaway', pro_days: row.perk_days };
  }

  if (row.type === 'coach' && isOwner) {
    await markCoach(db, caller);
    await grant(deps, caller.userId, row.perk_days);
    return { kind: 'coach', pro_days: row.perk_days };
  }

  // An athlete entering a coach's or an influencer's code. Only a coach code
  // pairs (mp-458 §4: "a pending pairing with the coach"); an influencer is
  // not a coach and never sees the athlete's data.
  const pairsWith = row.type === 'coach' ? row.owner_user_id : null;
  if (pairsWith) await openPendingPairing(db, pairsWith, caller.userId);
  const attribute = row.type === 'coach' ? 'coach_code' : 'influencer_code';
  try {
    await withCustomer(deps.revenueCat(), caller.userId, (rc) =>
      rc.setAttributes(caller.userId, { [attribute]: row.code }));
  } catch (e) {
    throw new AfterClaimError(502, 'store_unavailable', `setAttributes failed: ${(e as Error).message}`);
  }
  return pairsWith ? { kind: 'paired', coach_user_id: pairsWith } : { kind: 'attributed' };
}

async function grant(deps: RedeemDeps, userId: string, days: number): Promise<void> {
  if (!(days > 0)) return;
  try {
    await withCustomer(deps.revenueCat(), userId, (rc) => rc.grantPro(userId, days));
  } catch (e) {
    throw new AfterClaimError(502, 'store_unavailable', `grantPro failed: ${(e as Error).message}`);
  }
}

/**
 * Run a RevenueCat write, creating the customer first when RevenueCat has
 * never seen it (404): an account that only ever used the web build has no
 * RevenueCat customer, and a grant or an attribute needs one.
 */
async function withCustomer(
  rc: RevenueCatClient,
  userId: string,
  write: (rc: RevenueCatClient) => Promise<void>,
): Promise<void> {
  try {
    await write(rc);
  } catch (e) {
    if (!(e instanceof RevenueCatError) || e.status !== 404) throw e;
    await rc.createCustomer(userId);
    await write(rc);
  }
}

/**
 * Mark the caller a coach: an approved `coaches` row, which is what the app
 * reads as "is a coach" (`fetchIsCoachFromSupabase`). An existing application,
 * pending or not, is approved in place; otherwise one is written from the
 * caller's profile. Keyed on `user_id` by read-then-write, not an upsert.
 */
async function markCoach(db: Db, caller: Caller): Promise<void> {
  const stamp = new Date().toISOString();
  const { data: existing, error: readError } = await db
    .from('coaches')
    .select('id, application_status')
    .eq('user_id', caller.userId)
    .maybeSingle();
  if (readError) throw new AfterClaimError(500, 'server_error', `coaches read failed: ${readError.message}`);

  if (existing) {
    const current = existing as { id: string; application_status: string };
    if (current.application_status === 'approved') return;
    const { error } = await db
      .from('coaches')
      .update({ application_status: 'approved', approved_at: stamp, updated_at: stamp })
      .eq('id', current.id);
    if (error) throw new AfterClaimError(500, 'server_error', `coaches update failed: ${error.message}`);
    return;
  }

  const { data: profile, error: profileError } = await db
    .from('users')
    .select('first_name, last_name, email')
    .eq('id', caller.userId)
    .maybeSingle();
  if (profileError) throw new AfterClaimError(500, 'server_error', `users read failed: ${profileError.message}`);
  const p = (profile ?? {}) as { first_name?: string | null; last_name?: string | null; email?: string | null };
  const { error } = await db.from('coaches').insert({
    user_id: caller.userId,
    first_name: p.first_name ?? '',
    last_name: p.last_name ?? '',
    // `coaches.email` is NOT NULL and unique; every signed-in account has one.
    email: caller.email ?? p.email ?? `${caller.userId}@users.invalid`,
    application_status: 'approved',
    submitted_at: stamp,
    approved_at: stamp,
    updated_at: stamp,
  });
  if (error) throw new AfterClaimError(500, 'server_error', `coaches insert failed: ${error.message}`);
}

/**
 * The pending pairing, on the row the app's pairing path writes
 * (`CoachRepository.createRelationship` with requested_by 'athlete'): pending
 * until the coach accepts it. A pairing already pending or active is left as
 * it is; a declined or archived one is asked for again. One row per pair
 * (`unique (coach_user_id, athlete_user_id)`).
 */
async function openPendingPairing(db: Db, coachUserId: string, athleteUserId: string): Promise<void> {
  const { data: existing, error: readError } = await db
    .from('coach_athlete_relationships')
    .select('id, status')
    .eq('coach_user_id', coachUserId)
    .eq('athlete_user_id', athleteUserId)
    .maybeSingle();
  if (readError) throw new AfterClaimError(500, 'server_error', `relationship read failed: ${readError.message}`);

  const stamp = new Date().toISOString();
  const rel = existing as { id: string; status: string } | null;
  if (rel && (rel.status === 'pending' || rel.status === 'active')) return;

  if (rel) {
    const { error } = await db
      .from('coach_athlete_relationships')
      .update({
        status: 'pending',
        requested_by: 'athlete',
        requested_at: stamp,
        accepted_at: null,
        declined_at: null,
        archived_at: null,
        updated_at: stamp,
      })
      .eq('id', rel.id);
    if (error) throw new AfterClaimError(500, 'server_error', `relationship reopen failed: ${error.message}`);
    return;
  }

  const { error } = await db.from('coach_athlete_relationships').insert({
    id: crypto.randomUUID(),
    coach_user_id: coachUserId,
    athlete_user_id: athleteUserId,
    status: 'pending',
    requested_by: 'athlete',
    requested_at: stamp,
    created_at: stamp,
    updated_at: stamp,
  });
  if (error) throw new AfterClaimError(500, 'server_error', `relationship insert failed: ${error.message}`);
}

/** Give a claim back after a failed step, so the code is not spent on nothing. */
async function release(db: Db, codeId: string, userId: string): Promise<void> {
  const { error } = await db.from('code_redemptions').delete().eq('code_id', codeId).eq('user_id', userId);
  if (error) console.error(`[redeem-code] could not release claim on ${codeId} for ${userId}: ${error.message}`);
}
