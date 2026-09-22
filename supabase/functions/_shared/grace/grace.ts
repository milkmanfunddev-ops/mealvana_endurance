/**
 * The grace month (mp-455, mp-429 §5): every account that exists when the
 * paywall switches on gets 30 days of granted `pro` and founding-member status.
 *
 *   selectGraceAccounts  who qualifies: registered, created strictly before the flip
 *   applyGrace           one account: read RevenueCat, then grant and/or mark as needed
 *   runGrace             every selected account, dry run unless `write`
 *   listAuthUsers        the accounts, from GoTrue's admin API (service role key)
 *
 * `scripts/grace-grant.mjs` is the flip-day runner around runGrace. The claim
 * for old anonymous installs (ticket 09) calls applyGrace from an edge function
 * after its own check that the anonymous user predates the flip (predatesFlip).
 *
 * "Already granted" is read from RevenueCat, never from a marker of our own:
 * an account holds its grace when it has a live promotional `pro` grant ending
 * no earlier than the grace month does (flip + 30 days), and is a founding
 * member when its `founding_member` attribute is "true". A run grants only
 * what is missing, so a second run, or a run after one that failed halfway,
 * does nothing twice. The grant is made before the attribute: a grant without
 * the attribute is finished by the next run, while an attribute without the
 * grant would read as done to nobody but still leave the account without its
 * days, which mp-429 §10 rules out.
 *
 * Pure of Deno globals: fetch, the clock and sleep are injected.
 */

import { type RevenueCatClient, RevenueCatError } from '../revenuecat/client.ts';

export const GRACE_DAYS = 30;
export const FOUNDING_MEMBER_ATTRIBUTE = 'founding_member';

const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_ATTEMPTS = 3;

/** A user as GoTrue's admin API lists it (the fields this module reads). */
export interface AuthUser {
  id: string;
  email?: string | null;
  created_at: string;
  is_anonymous?: boolean;
  deleted_at?: string | null;
}

export function predatesFlip(user: AuthUser, flipAt: Date): boolean {
  const created = Date.parse(user.created_at);
  return Number.isFinite(created) && created < flipAt.getTime();
}

export function isRegistered(user: AuthUser): boolean {
  return user.is_anonymous !== true && !user.deleted_at;
}

/** Registered accounts created strictly before the flip, oldest first. */
export function selectGraceAccounts(users: AuthUser[], flipAt: Date): AuthUser[] {
  return users
    .filter((u) => isRegistered(u) && predatesFlip(u, flipAt))
    .sort((a, b) => Date.parse(a.created_at) - Date.parse(b.created_at));
}

/** The earliest end a grant may have and still cover the grace month. */
export function graceEndsNoEarlierThan(flipAt: Date): number {
  return flipAt.getTime() + GRACE_DAYS * DAY_MS;
}

export type GraceStatus =
  | 'would_grant' // dry run: needs the grant (and the attribute, if missing)
  | 'would_mark' // dry run: holds a covering grant, needs only the attribute
  | 'granted' // write: granted (and marked, if it was missing)
  | 'marked' // write: set the attribute only
  | 'already' // holds a covering grant and is a founding member
  | 'failed';

export interface GraceOutcome {
  userId: string;
  status: GraceStatus;
  /** The live promotional grant's end before this run, if any. */
  grantEndBefore: string | null;
  error?: string;
}

export interface GraceOptions {
  flipAt: Date;
  write: boolean;
  sleep?: (ms: number) => Promise<void>;
}

const defaultSleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** Retry rate limits, server errors and network failures; anything else is final. */
async function withRetry<T>(sleep: (ms: number) => Promise<void>, fn: () => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (e) {
      const status = e instanceof RevenueCatError ? e.status : undefined;
      const retryable = status === 429 || (typeof status === 'number' && status >= 500) || e instanceof TypeError;
      if (!retryable || attempt >= MAX_ATTEMPTS) throw e;
      await sleep(1000 * 2 ** (attempt - 1));
    }
  }
}

/** One account: read what RevenueCat holds, then write only what is missing. */
export async function applyGrace(rc: RevenueCatClient, userId: string, opts: GraceOptions): Promise<GraceOutcome> {
  const sleep = opts.sleep ?? defaultSleep;
  let grantEndBefore: string | null = null;
  try {
    const attributes = await withRetry(sleep, () => rc.getAttributes(userId));
    grantEndBefore = attributes === null ? null : await withRetry(sleep, () => rc.promotionalProEnd(userId));
    const covered = grantEndBefore !== null && Date.parse(grantEndBefore) >= graceEndsNoEarlierThan(opts.flipAt);
    const founding = attributes?.[FOUNDING_MEMBER_ATTRIBUTE] === 'true';

    if (covered && founding) return { userId, status: 'already', grantEndBefore };
    if (!opts.write) return { userId, status: covered ? 'would_mark' : 'would_grant', grantEndBefore };

    if (attributes === null) await withRetry(sleep, () => rc.createCustomer(userId));
    if (!covered) await withRetry(sleep, () => rc.grantPro(userId, GRACE_DAYS));
    if (!founding) await withRetry(sleep, () => rc.setAttributes(userId, { [FOUNDING_MEMBER_ATTRIBUTE]: 'true' }));
    return { userId, status: covered ? 'marked' : 'granted', grantEndBefore };
  } catch (e) {
    return { userId, status: 'failed', grantEndBefore, error: e instanceof Error ? e.message : String(e) };
  }
}

export interface GraceSummary {
  write: boolean;
  flipAt: string;
  /** Accounts the selection chose (after the user filter, if any). */
  selected: number;
  outcomes: GraceOutcome[];
  counts: Record<GraceStatus, number>;
  /** Ids named in the filter that the selection did not choose. */
  notSelected: string[];
}

export interface RunGraceOptions extends GraceOptions {
  users: AuthUser[];
  rc: RevenueCatClient;
  /** When set, only these ids (still subject to the selection). */
  onlyIds?: string[];
  log?: (line: string, user?: AuthUser, outcome?: GraceOutcome) => void;
  now?: () => number;
}

export async function runGrace(opts: RunGraceOptions): Promise<GraceSummary> {
  const now = opts.now ?? Date.now;
  if (opts.write && now() < opts.flipAt.getTime()) {
    throw new Error(
      `refusing to write before the flip (${opts.flipAt.toISOString()}): a grant made now would end before the grace month does`,
    );
  }
  let selected = selectGraceAccounts(opts.users, opts.flipAt);
  const notSelected: string[] = [];
  if (opts.onlyIds) {
    const wanted = new Set(opts.onlyIds);
    selected = selected.filter((u) => wanted.has(u.id));
    const chosen = new Set(selected.map((u) => u.id));
    notSelected.push(...opts.onlyIds.filter((id) => !chosen.has(id)));
  }
  const counts: Record<GraceStatus, number> = { would_grant: 0, would_mark: 0, granted: 0, marked: 0, already: 0, failed: 0 };
  const outcomes: GraceOutcome[] = [];
  for (const user of selected) {
    const outcome = await applyGrace(opts.rc, user.id, opts);
    outcomes.push(outcome);
    counts[outcome.status]++;
    opts.log?.(formatOutcome(user, outcome), user, outcome);
  }
  return { write: opts.write, flipAt: opts.flipAt.toISOString(), selected: selected.length, outcomes, counts, notSelected };
}

export function formatOutcome(user: AuthUser, o: GraceOutcome): string {
  const held = o.grantEndBefore ? ` (grant to ${o.grantEndBefore})` : '';
  const err = o.error ? `  ${o.error}` : '';
  return `${o.status.padEnd(11)} ${user.id}  ${user.email ?? ''}  created ${user.created_at}${held}${err}`;
}

export interface ListAuthUsersOptions {
  url: string;
  serviceRoleKey: string;
  fetch?: typeof globalThis.fetch;
  perPage?: number;
}

/** Every user, paged through GoTrue's admin list until a short page. */
export async function listAuthUsers(opts: ListAuthUsersOptions): Promise<AuthUser[]> {
  const doFetch = opts.fetch ?? globalThis.fetch;
  const perPage = opts.perPage ?? 1000;
  const base = opts.url.replace(/\/$/, '');
  const out: AuthUser[] = [];
  for (let page = 1; ; page++) {
    const res = await doFetch(`${base}/auth/v1/admin/users?page=${page}&per_page=${perPage}`, {
      headers: { apikey: opts.serviceRoleKey, Authorization: `Bearer ${opts.serviceRoleKey}` },
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`GoTrue admin users page ${page} → ${res.status}: ${text.slice(0, 200)}`);
    const users = (JSON.parse(text) as { users?: AuthUser[] }).users ?? [];
    out.push(...users);
    if (users.length < perPage) return out;
  }
}
