#!/usr/bin/env node
// Testing-wave start states on DEV (IMPROVEMENTS #87, #96): one command writes the state a check
// starts from onto a throwaway account the run itself made, in a second or two, so no run plans its
// start on another run's account (runbook step 9 deletes those). Only `lee+e2e-*` accounts; prod
// refuses. Nothing else is written: the pairing row, or the RevenueCat grant (and whatever
// RevenueCat's webhook then writes to `user_entitlements`).
//
// CLI (Supabase token as sweep-accounts.mjs reads it; RevenueCat key from the main clone's
// secrets/revenuecat.env; neither printed). <account> is the user id or the lee+e2e-* address.
//   node seed-states.mjs pairing <account> [--status active|pending|declined|archived]
//                                          [--coach <email>] [--requested-by athlete|coach]
//        a pairing with the coach (default test@test.com, owner of DEVCOACH30), status `active` by
//        default. Since ticket 140 a coach code pairs at once, so no retest needs `pending` (checked
//        2026-09-26: 11-009 is moot, 100-008 needs `declined`/`archived`); the other statuses are
//        there for the accept and decline screens. Upserts on (coach, athlete); goes with the account.
//   node seed-states.mjs grant <account> [--minutes 2]
//        a free `pro` grant in RevenueCat ending <minutes> from now: the lapse fixture that replaces
//        the Test Store monthly, which keeps renewing while signed out (117-015). ONE grant per
//        account: RevenueCat answers 200 to a second one and writes nothing, so the command reads
//        the grant back and exits 2 when it did not land. Measured once on 2026-09-26 (ticket 142):
//        a 2-minute grant written in 1.00 s, RevenueCat's webhook set user_entitlements
//        (PROMOTIONAL, active_until = the end) within a second; the app, open on the timeline, showed
//        the lapsed paywall 0-5 s after the end (end 12:51:23.172Z, seen 12:51:28Z polling every
//        ~4 s). RevenueCat took the 2 minutes as given (no rounding). A pairing is written in 0.93 s.
//   node seed-states.mjs show <account>   the account's pairings, user_entitlements row and
//                                         RevenueCat's active pro, read only
// Every command takes --ref <project ref>, which must be dev, and prints how long the write took.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEV_REF, assertDev, isSweepable, devAdmin } from './sweep-accounts.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const lit = s => `'${String(s).replaceAll("'", "''")}'`;
export const STATUSES = ['active', 'pending', 'declined', 'archived'];
export const DEFAULT_COACH = 'test@test.com';
export const RC_API = 'https://api.revenuecat.com/v2';

/** The account a command names (id or address), refused unless it is a throwaway on dev. */
export async function throwaway(api, account) {
  const where = UUID.test(String(account)) ? `u.id = ${lit(account)}` : `lower(u.email) = lower(${lit(account)})`;
  const [user] = await api.query(`select u.id::text as id, u.email from auth.users u where ${where}`);
  if (!user) throw new Error(`no account ${account} on dev`);
  if (!isSweepable(user.email)) throw new Error(`${user.email} is not a lee+e2e-* account; start states go on throwaway accounts only`);
  return user;
}

/** One statement: the pairing between coach and athlete, with the timestamps its status implies. */
export function pairingSql(athleteId, coachEmail, { status = 'active', requestedBy = 'athlete' } = {}) {
  if (!UUID.test(String(athleteId))) throw new Error(`"${athleteId}" is not a uuid`);
  if (!STATUSES.includes(status)) throw new Error(`--status must be one of ${STATUSES.join(', ')}, not "${status}"`);
  if (!['athlete', 'coach'].includes(requestedBy)) throw new Error(`--requested-by must be athlete or coach, not "${requestedBy}"`);
  const at = s => (status === s ? 'now()' : 'null');
  return `insert into public.coach_athlete_relationships (coach_user_id, athlete_user_id, status, requested_by, requested_at, accepted_at, declined_at, archived_at)
select c.id, ${lit(athleteId)}, ${lit(status)}, ${lit(requestedBy)}, now(), ${status === 'archived' ? 'now()' : at('active')}, ${at('declined')}, ${at('archived')}
from auth.users c where lower(c.email) = lower(${lit(coachEmail)})
on conflict (coach_user_id, athlete_user_id) do update set status = excluded.status, requested_by = excluded.requested_by,
  requested_at = excluded.requested_at, accepted_at = excluded.accepted_at, declined_at = excluded.declined_at,
  archived_at = excluded.archived_at, updated_at = now()
returning id::text, status, requested_by, coach_user_id::text as coach`;
}

/** The grant body: `pro` until [minutes] from [now] (epoch ms, as RevenueCat v2 takes it). */
export function grantBody(entitlementId, now, minutes) {
  const m = Number(minutes);
  if (!Number.isFinite(m) || m <= 0 || m > 60 * 24) throw new Error(`--minutes must be above 0 and at most a day, not "${minutes}"`);
  return { entitlement_id: entitlementId, expires_at: Math.round(now + m * 60_000) };
}

function revenueCatEnv() {
  const text = readFileSync('/Users/leemartin/development/mealvana_endurance/secrets/revenuecat.env', 'utf8');
  const get = k => text.split('\n').find(l => l.startsWith(`${k}=`))?.slice(k.length + 1).trim().replace(/^["']|["']$/g, '');
  const key = process.env.REVENUECAT_SECRET_KEY || get('REVENUECAT_SECRET_KEY');
  const project = process.env.REVENUECAT_PROJECT_ID || get('REVENUECAT_PROJECT_ID');
  if (!key || !project) throw new Error('no REVENUECAT_SECRET_KEY / REVENUECAT_PROJECT_ID in secrets/revenuecat.env');
  return { key, project };
}

/** RevenueCat v2 for one project: the calls a grant needs. `fetch` is injectable for tests. */
export function revenueCat({ key, project, fetch: doFetch = globalThis.fetch } = revenueCatEnv()) {
  const base = `${RC_API}/projects/${encodeURIComponent(project)}`;
  async function call(method, path, body) {
    const res = await doFetch(`${base}${path}`, {
      method,
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', Accept: 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`RevenueCat ${method} ${path.split('?')[0]} -> ${res.status}: ${text.slice(0, 200)}`);
    return text ? JSON.parse(text) : {};
  }
  const customer = id => `/customers/${encodeURIComponent(id)}`;
  return {
    async proId() {
      const list = await call('GET', '/entitlements?limit=100');
      const pro = list?.items?.find(e => e.lookup_key === 'pro');
      if (!pro) throw new Error(`no 'pro' entitlement in RevenueCat project`);
      return pro.id;
    },
    /**
     * Grants, then reads it back. A customer RevenueCat has not met yet (never signed in) is
     * created first. RevenueCat answers 200 to a second grant on a customer that already had one
     * and writes nothing (2026-09-26, ticket 142), so a grant that does not read back throws.
     */
    async grant(userId, body, { sleep = ms => new Promise(r => setTimeout(r, ms)) } = {}) {
      let res = await call('POST', `${customer(userId)}/actions/grant_entitlement`, body);
      if (res === null) {
        await call('POST', '/customers', { id: userId });
        res = await call('POST', `${customer(userId)}/actions/grant_entitlement`, body);
      }
      if (res === null) throw new Error(`RevenueCat has no customer ${userId}`);
      for (let i = 0; i < 4; i++) {
        const pro = (await call('GET', `${customer(userId)}/active_entitlements?limit=100`))?.items?.find(e => e.entitlement_id === body.entitlement_id);
        if (pro && (pro.expires_at === null || pro.expires_at >= body.expires_at - 1000)) return pro;
        await sleep(500);
      }
      throw new Error(`RevenueCat took the grant but holds no pro until ${new Date(body.expires_at).toISOString()}: it drops a second grant on an account that had one. Make a new lee+e2e-* account for each lapse check.`);
    },
    activePro: async (userId, proId) =>
      (await call('GET', `${customer(userId)}/active_entitlements?limit=100`))?.items?.find(e => e.entitlement_id === proId) ?? null,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const flag = name => { const i = args.indexOf(name); return i === -1 ? undefined : args.splice(i, 2)[1]; };
  const ref = flag('--ref') ?? DEV_REF;
  const status = flag('--status') ?? 'active';
  const coach = flag('--coach') ?? DEFAULT_COACH;
  const requestedBy = flag('--requested-by') ?? 'athlete';
  const minutes = flag('--minutes') ?? 2;
  const [cmd, account] = args;
  const out = s => process.stdout.write(`${s}\n`);
  const t0 = Date.now();
  const took = () => `${((Date.now() - t0) / 1000).toFixed(2)} s`;
  try {
    assertDev(ref);
    if (!['pairing', 'grant', 'show'].includes(cmd) || !account) {
      process.stderr.write('usage: seed-states.mjs pairing <account> [--status S] [--coach EMAIL] [--requested-by athlete|coach] | grant <account> [--minutes N] | show <account>   [--ref <dev ref>]\n');
      process.exit(64);
    }
    if (cmd === 'pairing') pairingSql('00000000-0000-0000-0000-000000000000', coach, { status, requestedBy }); // flags checked before any call
    if (cmd === 'grant') grantBody('x', 0, minutes);
    const db = devAdmin(ref);
    const user = await throwaway(db, account);
    if (cmd === 'pairing') {
      const [row] = await db.query(pairingSql(user.id, coach, { status, requestedBy }));
      if (!row) throw new Error(`no coach account ${coach} on dev`);
      out(JSON.stringify({ athlete: user.email, ...row }));
      out(`pairing written in ${took()}`);
    } else if (cmd === 'grant') {
      const rc = revenueCat();
      const body = grantBody(await rc.proId(), Date.now(), minutes);
      await rc.grant(user.id, body);
      out(JSON.stringify({ account: user.email, id: user.id, pro_until: new Date(body.expires_at).toISOString() }));
      out(`grant written in ${took()}`);
    } else {
      const rc = revenueCat();
      const pro = await rc.activePro(user.id, await rc.proId());
      out(JSON.stringify({ account: user.email, revenuecat_pro_until: pro ? (pro.expires_at ? new Date(pro.expires_at).toISOString() : 'never') : null }));
      for (const r of await db.query(`select period_type, active_until, will_renew, event_at from public.user_entitlements where user_id = ${lit(user.id)}`)) out(JSON.stringify({ user_entitlements: r }));
      for (const r of await db.query(`select r.status, r.requested_by, u.email as coach, r.accepted_at, r.declined_at, r.archived_at from public.coach_athlete_relationships r join auth.users u on u.id = r.coach_user_id where r.athlete_user_id = ${lit(user.id)}`)) out(JSON.stringify({ pairing: r }));
    }
  } catch (e) {
    process.stderr.write(`${e.message}\n`);
    process.exit(2);
  }
}
