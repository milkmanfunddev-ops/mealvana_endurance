#!/usr/bin/env node
// The persona-account recipe for judging (eval/accounts.md): makes one account ready for a
// round — Pro through the subscription provider, wallet budget, and a read-back of the state
// the Examiner will meet. Idempotent: a second run grants nothing and only re-prints.
//
// What it does NOT do: shape the persona data (training, diet, plan). That is per-account SQL,
// documented per account in eval/accounts.md — every persona is different, so the recipe stops
// at the two steps every account shares and leaves the shaping to the account's own notes.
//
// Pro goes through RevenueCat (the Gate reads user_entitlements, which only the
// revenuecat-webhook writes — mp-285, mp-454; nothing app-side can grant). A promotional grant
// arrives there as a NON_RENEWING_PURCHASE, so after granting this script waits for the cache
// row to appear before moving on. The dev webhook accepts PROMOTIONAL events
// (REVENUECAT_SANDBOX_ONLY filters only other PRODUCTION events).
//
// The wallet is topped to a target (default $50 of model cost, 50,000,000 micro-dollars)
// through the service-role grant_credits RPC — the same RPC pack purchases use — with the
// ledger reason 'grant_admin' and an eval ref, so the top-up is auditable. The monthly
// allowance window is NOT touched: ai_budget_reserve rolls it by itself while Pro is live.
//
// CLI (secrets from the env, else read from the main clone's secrets/ — never printed):
//   node eval/setup-account.mjs status <email>          read-only: Pro, wallet, persona fields
//   node eval/setup-account.mjs setup <email>           grant + top-up + wait, then print status
// Flags on setup:
//   --days N         days of Pro to grant when the account holds none (default 365)
//   --target MICRO   wallet balance to top up to (default 50000000; 0 skips the top-up)
//   --wait-ms N      how long to wait for the webhook cache (default 60000)
// Dev only: the ref must be vlmtsdzpnjnavdgytcmi.
//
// Env: SUPABASE_ACCESS_TOKEN (Management API), REVENUECAT_SECRET_KEY (v2, one project serves
// dev and prod). Falls back to /Users/leemartin/development/mealvana_endurance/secrets/.

import { readFileSync } from 'node:fs';

const DEV_REF = 'vlmtsdzpnjnavdgytcmi'; // hardcoded: this recipe is dev only
const RC_PROJECT_ID = 'proj77b3c48f'; // one RevenueCat project serves dev and prod
const RC_BASE = `https://api.revenuecat.com/v2/projects/${RC_PROJECT_ID}`;
const DAY_MS = 24 * 60 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAIN_SECRETS = '/Users/leemartin/development/mealvana_endurance/secrets';

function secretFromEnvOrFile(envKey, file, lineKey) {
  const fromEnv = process.env[envKey];
  if (fromEnv) return fromEnv;
  try {
    const line = readFileSync(`${MAIN_SECRETS}/${file}`, 'utf8').split('\n').find(l => l.startsWith(`${lineKey}=`));
    return line ? line.slice(lineKey.length + 1).trim() : null;
  } catch {
    return null;
  }
}

function die(message) {
  console.error(`setup-account: ${message}`);
  process.exit(2);
}

/** The Management API database/query door (same one scripts/testing-wave uses). */
function makeDb(token) {
  const mgmt = `https://api.supabase.com/v1/projects/${DEV_REF}`;
  return {
    async query(sql) {
      const res = await fetch(`${mgmt}/database/query`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: sql }),
      });
      const text = await res.text();
      if (!res.ok) throw new Error(`query failed (${res.status}): ${text.slice(0, 300)}`);
      return JSON.parse(text);
    },
  };
}

/** The RevenueCat v2 calls this recipe needs. Never prints the key. */
function makeRc(secretKey) {
  const headers = { Authorization: `Bearer ${secretKey}`, 'Content-Type': 'application/json', Accept: 'application/json' };
  async function call(method, url, body) {
    const res = await fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
    const text = await res.text();
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`RevenueCat ${method} ${new URL(url).pathname} → ${res.status}: ${text.slice(0, 200)}`);
    return text ? JSON.parse(text) : {};
  }
  let proId;
  return {
    async proEntitlementId() {
      proId ??= (await call('GET', `${RC_BASE}/entitlements?limit=100`)).items?.find(e => e.lookup_key === 'pro')?.id;
      if (!proId) throw new Error(`no 'pro' entitlement in project ${RC_PROJECT_ID}`);
      return proId;
    },
    /** ISO end of the customer's active pro, or null (null expires_at reads as lifetime). */
    async activeProEnd(appUserId) {
      const proId = await this.proEntitlementId();
      const active = await call('GET', `${RC_BASE}/customers/${appUserId}/active_entitlements?limit=100`);
      const row = active?.items?.find(e => e.entitlement_id === proId);
      if (!row) return null;
      return row.expires_at == null ? '9999-12-31T00:00:00.000Z' : new Date(row.expires_at).toISOString();
    },
    async createCustomer(appUserId) {
      await call('POST', `${RC_BASE}/customers`, { id: appUserId });
    },
    async grantPro(appUserId, days) {
      await call('POST', `${RC_BASE}/customers/${appUserId}/actions/grant_entitlement`, {
        entitlement_id: await this.proEntitlementId(),
        expires_at: Date.now() + Math.round(days * DAY_MS),
      });
    },
  };
}

async function resolveUserId(db, email) {
  const rows = await db.query(`select id::text, email from auth.users where email = '${email.replaceAll("'", "''")}'`);
  if (!rows.length) die(`no auth user for ${email} on dev`);
  return rows[0].id;
}

/** { entitlement, wallet, rc, persona } — everything status prints, in four reads. */
async function readState(db, rc, userId) {
  const [entitlement, wallet, persona] = await Promise.all([
    db.query(`select active_until::text, period_type, will_renew from public.user_entitlements where user_id = '${userId}'`),
    db.query(`select balance, allowance, allowance_monthly, allowance_expires_at::text, unit from public.token_wallets where user_id = '${userId}'`),
    db.query(`select first_name, dietary_preference, allergies, gut_training_level, home_city, home_timezone,
        (select count(*)::int from public.activities a where a.user_id = u.id and a.deleted_at is null
           and a.scheduled_date_time >= now() and a.scheduled_date_time < now() + interval '7 days') sessions_next_7d,
        (select e.event_name || ' ' || e.event_date from public.events e where e.user_id = u.id and e.event_date >= current_date
           order by e.event_date limit 1) next_race,
        (select p.status || ' (week ' || p.week_start || ')' from public.meal_plans p where p.user_id = u.id and p.is_deleted = false
           and p.week_start <= current_date order by p.week_start desc, p.updated_at desc limit 1) current_plan
      from public.users u where u.id = '${userId}'`),
  ]);
  return { entitlement: entitlement[0] ?? null, wallet: wallet[0] ?? null, persona: persona[0] ?? null, rc: await rc.activeProEnd(userId) };
}

function printState(userId, s) {
  const e = s.entitlement;
  const w = s.wallet;
  const p = s.persona;
  console.log(`user        ${userId}`);
  console.log(`pro (db)    ${e ? `active_until ${e.active_until} (${e.period_type}, will_renew ${e.will_renew})` : 'no user_entitlements row'}`);
  console.log(`pro (rc)    ${s.rc ?? 'none'}`);
  console.log(`wallet      ${w ? `${w.balance} ${w.unit} (allowance ${w.allowance}/${w.allowance_monthly} to ${w.allowance_expires_at})` : 'no token_wallets row'}`);
  if (p) {
    console.log(`persona     ${p.first_name} · ${p.dietary_preference} · gut ${p.gut_training_level} · allergies ${JSON.stringify(p.allergies)}`);
    console.log(`            home ${p.home_city ?? 'unset'} (${p.home_timezone ?? 'no tz'}) · ${p.sessions_next_7d} sessions next 7d`);
    console.log(`            next race ${p.next_race ?? 'none'} · plan ${p.current_plan ?? 'none'}`);
  }
}

/** Grant only what is missing: Pro when none is live, the wallet's gap to the target. */
async function setup(db, rc, userId, { days, target, waitMs }) {
  const rcEnd = await rc.activeProEnd(userId);
  if (rcEnd && Date.parse(rcEnd) > Date.now()) {
    console.log(`pro         already held in RevenueCat to ${rcEnd}; granting nothing`);
  } else {
    await rc.createCustomer(userId).catch(e => { if (!/404|409/.test(String(e.message))) throw e; }); // exists is fine
    await rc.grantPro(userId, days);
    console.log(`pro         granted ${days} days through RevenueCat (webhook will write user_entitlements)`);
  }

  // The cache the Gate reads: wait for the webhook to land the grant (it is usually seconds).
  const deadline = Date.now() + waitMs;
  let cacheRow = null;
  for (;;) {
    cacheRow = (await db.query(`select active_until::text from public.user_entitlements where user_id = '${userId}'`))[0] ?? null;
    const live = cacheRow && Date.parse(cacheRow.active_until) > Date.now();
    if (live || Date.now() > deadline) {
      if (!live) die(`user_entitlements never went live within ${waitMs}ms (webhook not delivered? last: ${cacheRow?.active_until ?? 'none'})`);
      console.log(`gate        user_entitlements active_until ${cacheRow.active_until}`);
      break;
    }
    await new Promise(r => setTimeout(r, 3000));
  }

  // Wallet: top up only the gap (grant_credits refuses a zero amount, so skip when closed).
  if (target > 0) {
    const wallet = (await db.query(`select balance from public.token_wallets where user_id = '${userId}'`))[0];
    const gap = target - (wallet?.balance ?? 0);
    if (gap <= 0) {
      console.log(`wallet      balance ${wallet?.balance} already at target ${target}; topping nothing`);
    } else {
      const ref = `eval-judging-topup:${target / 1_000_000}usd`;
      await db.query(`select public.grant_credits('${userId}', ${Math.trunc(gap)}, 'grant_admin', '${ref}')`);
      console.log(`wallet      topped ${gap} micro-dollars (reason grant_admin, ref ${ref})`);
    }
  }
}

const args = process.argv.slice(2);
const flag = name => { const i = args.indexOf(name); return i === -1 ? undefined : args.splice(i, 2)[1]; };
const [cmd, email] = args.filter(a => !a.startsWith('--'));
if (cmd !== 'status' && cmd !== 'setup') die('usage: setup-account.mjs status|setup <email> [--days N] [--target MICRO] [--wait-ms N]');
if (!email || !email.includes('@')) die('an email is required');

const token = secretFromEnvOrFile('SUPABASE_ACCESS_TOKEN', 'supabase_management_api.env', 'SUPABASE_MANAGEMENT_TOKEN');
if (!token) die('no SUPABASE_ACCESS_TOKEN (env or main clone secrets)');
const rcKey = secretFromEnvOrFile('REVENUECAT_SECRET_KEY', 'revenuecat.env', 'REVENUECAT_SECRET_KEY');
if (!rcKey) die('no REVENUECAT_SECRET_KEY (env or main clone secrets)');

const db = makeDb(token);
const rc = makeRc(rcKey);
const userId = await resolveUserId(db, email);
if (!UUID.test(userId)) die(`"${userId}" is not a uuid`);

if (cmd === 'setup') {
  await setup(db, rc, userId, {
    days: Number(flag('--days') ?? 365),
    target: Number(flag('--target') ?? 50_000_000),
    waitMs: Number(flag('--wait-ms') ?? 60_000),
  });
  console.log('');
}
printState(userId, await readState(db, rc, userId));
