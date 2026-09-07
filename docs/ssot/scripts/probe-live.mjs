#!/usr/bin/env node
// probe-live.mjs — the LIVE half of the conformance story: a 60-second,
// read-mostly verification that the DEPLOYED dev (or prod, read-only) cloud
// actually carries what the bundle needs. This is the evidence generator for
// `land-bundle` Step 2b and for the deploy playbook's post-deploy step.
//
// What it checks (each prints PASS / FAIL / SKIP with a reason):
//   1. schema/columns   — activities.planned_time/actual_time selectable (42703 tripwire)
//   2. schema/table     — plan_recalc_log exists (PGRST205 tripwire)
//   3. engine/version   — POST the deployed engine fn; algorithm_version == expected
//   4. tz/round-trip    — insert a row with a naive-local planned_time as a REAL
//                         signed-in user, read it back, byte-compare (the 2026-08-19
//                         timestamptz regression tripwire)
//   5. garmin/g6-wire   — POST a synthetic Garmin webhook at the DEPLOYED garmin-push
//                         for a seeded skipped workout of the MAPPED user; assert the
//                         row upgrades (status completed, garmin_summary_id linked,
//                         actual_time = naive-local measured start). Sync beats skip,
//                         on the real wire. Runs only when the signed-in user has a
//                         garmin_user_mappings row (SKIP otherwise, with the reason).
//
// Checks 4–5 WRITE rows (as the signed-in user, RLS-scoped) and clean up after
// themselves: probe rows are renamed PROBE-*, tombstoned, and moved 10 years
// into the past so the ±15-min tombstone matcher can never collide with a
// later run. NEVER point the write checks at prod: pass --read-only there.
//
// Config (same resolution as seed-athletes.mjs):
//   SUPABASE_URL / SUPABASE_ANON_KEY  ← env, else app/.env.dev.local
//   PROBE_EMAIL / PROBE_PASSWORD      ← env, else the keychain wrapper
//                                        probe-live.sh, else SKIP the auth'd checks
//   ENGINE_FN (default calculate-daily-macros-v6), EXPECT_ALGO (default v6.0.0)
//   --read-only  → checks 1–3 only
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const findWorkspace = (d) => {
  while (d !== '/') {
    try { readFileSync(join(d, 'workspace.env')); return d; } catch { d = dirname(d); }
  }
  return null;
};
const MV = findWorkspace(here);
const readEnv = (file, key) => {
  try {
    const m = readFileSync(file, 'utf8').match(new RegExp(`^${key}=(.*)$`, 'm'));
    return m ? m[1].trim() : null;
  } catch { return null; }
};
const devEnv = MV ? join(MV, 'app', '.env.dev.local') : null;

const URL_ = process.env.SUPABASE_URL || (devEnv && readEnv(devEnv, 'SUPABASE_URL'));
const ANON = process.env.SUPABASE_ANON_KEY || (devEnv && readEnv(devEnv, 'SUPABASE_ANON_KEY'));
const EMAIL = process.env.PROBE_EMAIL || null;
const PW = process.env.PROBE_PASSWORD || null;
const ENGINE_FN = process.env.ENGINE_FN || 'calculate-daily-macros-v6';
const EXPECT_ALGO = process.env.EXPECT_ALGO || 'v6.0.0';
const READ_ONLY = process.argv.includes('--read-only');

if (!URL_ || !ANON) {
  console.error('ABORT: SUPABASE_URL / SUPABASE_ANON_KEY unresolved (env or app/.env.dev.local)');
  process.exit(2);
}
const isProd = URL_.includes('wvmvsodrvbkxfydabqed');
if (isProd && !READ_ONLY) {
  console.error('ABORT: target looks like PROD — write checks refused. Re-run with --read-only.');
  process.exit(2);
}

const results = [];
const report = (name, status, detail) => {
  results.push({ name, status });
  console.log(`${status.padEnd(4)} ${name}${detail ? ` — ${detail}` : ''}`);
};

const rest = async (path, opts = {}, token = ANON) => {
  const res = await fetch(`${URL_}/rest/v1/${path}`, {
    ...opts,
    headers: {
      apikey: ANON,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { status: res.status, body };
};

// ── 1 & 2: schema tripwires (anon is enough — column errors surface pre-RLS) ──
{
  const r = await rest('activities?select=id,planned_time,actual_time&limit=1');
  if (r.status === 200) report('schema/columns', 'PASS', 'planned_time/actual_time selectable');
  else report('schema/columns', 'FAIL', `${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
}
{
  const r = await rest('plan_recalc_log?select=id&limit=1');
  // 200 (RLS-empty) proves the table exists; PGRST205 = missing.
  if (r.status === 200) report('schema/plan_recalc_log', 'PASS', 'table exists (RLS-scoped read)');
  else report('schema/plan_recalc_log', 'FAIL', `${r.status} ${JSON.stringify(r.body).slice(0, 120)}`);
}

// ── 3: deployed engine version ──
{
  const res = await fetch(`${URL_}/functions/v1/${ENGINE_FN}`, {
    method: 'POST',
    headers: { apikey: ANON, Authorization: `Bearer ${ANON}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      sex: 'male', age: 34, weight_kg: 75, height_cm: 180, body_fat_pct: 14.67,
      lifestyle: 'desk', training_phase: 'base', mode: 'prospective',
      sessions: [{ sport: 'running', duration_hr: 1, pct_conversational: 0.7, pct_tempo: 0.2, pct_allout: 0.1 }],
    }),
  });
  const body = await res.json().catch(() => null);
  const plan = body?.data ?? body;
  if (res.ok && plan?.algorithm_version === EXPECT_ALGO) {
    report('engine/version', 'PASS', `${ENGINE_FN} → ${plan.algorithm_version}`);
  } else {
    report('engine/version', 'FAIL', `${res.status} algorithm_version=${plan?.algorithm_version}`);
  }
}

// ── auth for the write checks ──
let token = null, userId = null;
if (!READ_ONLY && EMAIL && PW) {
  const res = await fetch(`${URL_}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: ANON, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PW }),
  });
  const body = await res.json().catch(() => null);
  if (res.ok && body?.access_token) { token = body.access_token; userId = body.user?.id; }
  else report('auth/sign-in', 'FAIL', `${res.status} — checks 4–5 skipped`);
} else if (!READ_ONLY) {
  report('auth/sign-in', 'SKIP', 'no PROBE_EMAIL/PROBE_PASSWORD (use scripts/probe-live.sh)');
}

const naive = (d) => {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}:00`;
};
const cleanup = async (id) => {
  // Tombstone AND banish 10 years into the past: the ±15-min tombstone
  // matcher can never collide with a later probe run.
  const past = new Date(); past.setFullYear(past.getFullYear() - 10);
  await rest(`activities?id=eq.${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ status: 'deleted', deleted_at: new Date().toISOString(), scheduled_date_time: naive(past) }),
  }, token);
};

if (token) {
  // ── 4: TZ round-trip ──
  const t = new Date(); t.setMinutes(t.getMinutes() - 90, 0, 0);
  const plannedNaive = naive(t);
  const ins = await rest('activities', {
    method: 'POST',
    body: JSON.stringify({
      // The table has no server-side id default — the app generates UUIDs
      // client-side, and so does the probe.
      id: crypto.randomUUID(),
      user_id: userId, title: `PROBE-tz-${Date.now()}`, activity_type: 'running',
      status: 'planned', scheduled_date_time: plannedNaive, planned_time: plannedNaive, duration_minutes: 45,
    }),
  }, token);
  const row = Array.isArray(ins.body) ? ins.body[0] : null;
  if (!row) {
    report('tz/round-trip', 'FAIL', `insert ${ins.status} ${JSON.stringify(ins.body).slice(0, 120)}`);
  } else {
    const back = await rest(`activities?id=eq.${row.id}&select=planned_time`, {}, token);
    const got = back.body?.[0]?.planned_time?.slice(0, 19);
    if (got === plannedNaive) report('tz/round-trip', 'PASS', `${plannedNaive} → intact`);
    else report('tz/round-trip', 'FAIL', `sent ${plannedNaive}, read ${got} (timezone shift!)`);
    await cleanup(row.id);
  }

  // ── 5: G6 on the real wire — sync beats skip through the DEPLOYED garmin-push ──
  const map = await rest(`garmin_user_mappings?user_id=eq.${userId}&select=garmin_user_id`, {}, token);
  const gid = map.body?.[0]?.garmin_user_id;
  if (!gid) {
    report('garmin/g6-wire', 'SKIP', 'signed-in user has no garmin_user_mappings row');
  } else {
    const start = new Date(); start.setMinutes(start.getMinutes() - 30, 0, 0);
    const startNaive = naive(start);
    const ins2 = await rest('activities', {
      method: 'POST',
      body: JSON.stringify({
        id: crypto.randomUUID(),
        user_id: userId, title: `PROBE-g6-${Date.now()}`, activity_type: 'running',
        status: 'skipped', scheduled_date_time: startNaive, planned_time: startNaive, duration_minutes: 30,
      }),
    }, token);
    const skipRow = Array.isArray(ins2.body) ? ins2.body[0] : null;
    if (!skipRow) {
      report('garmin/g6-wire', 'FAIL', `seed insert ${ins2.status}`);
    } else {
      const offsetSec = -start.getTimezoneOffset() * 60;
      const startEpoch = Math.floor(start.getTime() / 1000);
      const push = await fetch(`${URL_}/functions/v1/garmin-push`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          activities: [{
            userId: gid, userAccessToken: 'probe', summaryId: `probe-${Date.now()}`,
            activityType: 'RUNNING', durationInSeconds: 1800,
            startTimeInSeconds: startEpoch, startTimeOffsetInSeconds: offsetSec,
            activeKilocalories: 300, distanceInMeters: 5000,
          }],
        }),
      });
      // poll up to 15 s for the upgrade
      let upgraded = null;
      for (let i = 0; i < 15 && !upgraded; i++) {
        await new Promise((r) => setTimeout(r, 1000));
        const back = await rest(`activities?id=eq.${skipRow.id}&select=status,garmin_summary_id,actual_time,planned_time`, {}, token);
        const r2 = back.body?.[0];
        if (r2?.status === 'completed' && r2.garmin_summary_id) upgraded = r2;
      }
      if (!upgraded) {
        report('garmin/g6-wire', 'FAIL', `push HTTP ${push.status}; row never upgraded (check garmin-push logs)`);
      } else if (upgraded.actual_time?.slice(0, 16) !== startNaive.slice(0, 16)) {
        report('garmin/g6-wire', 'FAIL', `upgraded but actual_time=${upgraded.actual_time} (expected naive-local ${startNaive})`);
      } else if (upgraded.planned_time?.slice(0, 19) !== startNaive) {
        report('garmin/g6-wire', 'FAIL', `planned_time moved: ${upgraded.planned_time}`);
      } else {
        report('garmin/g6-wire', 'PASS', 'skipped row → completed, summary linked, actual_time naive-local, planned_time untouched');
      }
      await cleanup(skipRow.id);
    }
  }
}

const fails = results.filter((r) => r.status === 'FAIL').length;
const skips = results.filter((r) => r.status === 'SKIP').length;
console.log(`\n${fails === 0 ? 'LIVE PROBE GREEN' : 'LIVE PROBE RED'} — ${results.length - fails - skips} pass, ${fails} fail, ${skips} skip`);
process.exit(fails === 0 ? 0 : 1);
