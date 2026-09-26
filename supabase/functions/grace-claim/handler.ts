/**
 * The grace-claim request handler (mp-455 §4-5, mp-417 §1; paywall ticket 09),
 * built with its dependencies injected so the seam tests (handler.test.ts) run
 * this exact code against a fake caller and RevenueCat faked at the wire.
 * index.ts wires it to the caller's JWT, the flip date and the one RevenueCat
 * REST client (_shared/revenuecat).
 *
 * An install still anonymous from before the paywall signs up onto its old
 * user (the uid survives the link) and then posts here with no body. The
 * caller gets the grace month the flip-day run gave every registered account,
 * 30 days of `pro` and `founding_member`, when:
 *
 *   the flip has happened        before it, a grant would end before the grace
 *                                month does (the flip-day run refuses too)
 *   it is signed up now          an anonymous caller is refused: the claim is
 *                                made by registering (mp-417 §1)
 *   it was created before the flip and was still anonymous at the flip
 *                                (claimsGrace); an account registered at the
 *                                flip is the flip-day run's
 *
 * "Once" is RevenueCat's own record, read by applyGrace: a caller already
 * holding a covering grant and the attribute gets nothing more. A grant made
 * here is recorded in `pro_grants` as source 'grace' (mp-615), which the
 * Subscription screen labels from.
 *
 * Answers:
 *   200 { ok: true, status: 'granted' | 'marked' | 'already', pro_days }
 *   200 { ok: false, reason: 'before_flip' | 'not_eligible' }
 *   401 unauthenticated · 403 sign_in_required (still anonymous)
 *   405 method_not_allowed · 502 store_unavailable · 503 grace_not_configured
 *
 * A refusal is a 200: it is an answer, and the app carries on to the paywall.
 */
import { corsHeaders } from '../_shared/cors.ts';
import { applyGrace, type AuthUser, claimsGrace, GRACE_DAYS } from '../_shared/grace/grace.ts';
import type { RecordGrant } from '../_shared/grants/record.ts';
import type { RevenueCatClient } from '../_shared/revenuecat/client.ts';

/** The caller as GoTrue's getUser returns it (the fields the claim reads). */
export interface ClaimCaller {
  /** auth.users id: the same id RevenueCat knows the customer by. */
  userId: string;
  anonymous: boolean;
  createdAt: string;
  identities: { provider?: string; created_at?: string | null }[];
}

export interface GraceClaimDeps {
  caller: (req: Request) => Promise<ClaimCaller | null>;
  /** The flip, or null when the function has not been given one. */
  flipAt: () => Date | null;
  /** RevenueCat's REST API; throws when the secret key is not configured. */
  revenueCat: () => RevenueCatClient;
  /** Records the grant as the grace month in `pro_grants` (mp-615); never throws. */
  recordGrant?: RecordGrant;
  now?: () => number;
  sleep?: (ms: number) => Promise<void>;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function makeGraceClaimHandler(deps: GraceClaimDeps) {
  const now = deps.now ?? Date.now;

  return async function handle(req: Request): Promise<Response> {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

    const caller = await deps.caller(req);
    if (!caller) return json({ error: 'unauthenticated' }, 401);
    if (caller.anonymous) return json({ error: 'sign_in_required' }, 403);

    const flipAt = deps.flipAt();
    if (!flipAt) {
      console.error('[grace-claim] GRACE_FLIP_AT is not set');
      return json({ error: 'grace_not_configured' }, 503);
    }
    if (now() < flipAt.getTime()) return json({ ok: false, reason: 'before_flip' });

    const user: AuthUser = {
      id: caller.userId,
      created_at: caller.createdAt,
      is_anonymous: false,
      identities: caller.identities,
    };
    if (!claimsGrace(user, flipAt)) {
      console.log(`[grace-claim] ${caller.userId} not eligible (created ${caller.createdAt})`);
      return json({ ok: false, reason: 'not_eligible' });
    }

    let rc: RevenueCatClient;
    try {
      rc = deps.revenueCat();
    } catch (e) {
      console.error('[grace-claim] RevenueCat client unavailable:', (e as Error).message);
      return json({ error: 'store_unavailable' }, 502);
    }
    const outcome = await applyGrace(rc, caller.userId, {
      flipAt,
      write: true,
      sleep: deps.sleep,
      recordGrant: deps.recordGrant,
    });
    console.log(`[grace-claim] ${caller.userId} → ${outcome.status}${outcome.error ? `: ${outcome.error}` : ''}`);
    switch (outcome.status) {
      case 'granted':
        return json({ ok: true, status: 'granted', pro_days: GRACE_DAYS });
      case 'marked':
        return json({ ok: true, status: 'marked', pro_days: 0 });
      case 'already':
        return json({ ok: true, status: 'already', pro_days: 0 });
      default:
        return json({ error: 'store_unavailable' }, 502);
    }
  };
}
