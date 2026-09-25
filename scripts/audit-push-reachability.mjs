#!/usr/bin/env node
/**
 * Push reachability audit — which athletes can actually receive a push?
 *
 * WHY THIS EXISTS. `garmin-push` calls OneSignal and OneSignal answers 200
 * even when it reached nobody, so a broken device looks identical to a
 * delivered notification from the server's side. The edge-function log does
 * distinguish the cases, but Supabase only serves recent log windows — by the
 * time an athlete says "I never got a notification" the line is gone. This
 * asks OneSignal directly and reports the state that actually matters:
 * does this athlete have at least one ENABLED push subscription?
 *
 * Found on 2026-09-22 with this script: 5 of 14 Garmin-active prod athletes
 * were unreachable — one with no subscription at all and four whose
 * subscriptions had all gone disabled. The root cause was the client calling
 * OneSignal.logout() whenever the Supabase session had not finished restoring
 * (fixed in notification_service.dart — see clearRemotePushUserId).
 *
 * TWO DIRECTIONS, AND YOU NEED BOTH.
 *   Athlete-first (default): walk Supabase athletes and ask OneSignal about each.
 *     Catches "this athlete cannot receive a push".
 *   Fleet-first (--fleet): enumerate every OneSignal subscription and look for
 *     aliases that are wrong rather than missing. The athlete-first pass is blind
 *     to all of these by construction, because it only ever looks up ids it
 *     already knows:
 *       - DUPLICATE alias: two user records carry one external_id, so sends fail
 *         with invalid_aliases while a GET still resolves (this stranded an
 *         athlete on 2026-09-22 and the athlete-first pass reported them fine).
 *       - NO external_id: the subscription exists but nothing can address it.
 *       - NON-UUID alias: an external_id that is not a Supabase user id. Found in
 *         the wild: Android build fingerprints shared by up to 20 devices, which
 *         would fan a single push out to 20 strangers.
 *
 * USAGE
 *   node scripts/audit-push-reachability.mjs            # prod, Garmin-active, 7d
 *   node scripts/audit-push-reachability.mjs --days 30
 *   node scripts/audit-push-reachability.mjs --all      # every athlete, not just Garmin
 *   node scripts/audit-push-reachability.mjs --fleet    # OneSignal-side integrity scan
 *   node scripts/audit-push-reachability.mjs --json     # machine-readable
 *
 * CREDENTIALS (never hardcode, never commit)
 *   ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY  — read from .env.prod.local
 *   SUPABASE_PAT                               — defaults to ~/.supabase/pat
 *
 * Read-only. It never sends a notification.
 */

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const PROD_REF = 'wvmvsodrvbkxfydabqed';
const args = process.argv.slice(2);
const asJson = args.includes('--json');
const everyone = args.includes('--all');
const fleet = args.includes('--fleet');
const days = Number(args[args.indexOf('--days') + 1]) || 7;

function readEnvFile(file) {
  const out = {};
  if (!fs.existsSync(file)) return out;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) out[m[1]] = m[2].trim();
  }
  return out;
}

const env = readEnvFile('.env.prod.local');
const APP_ID = process.env.ONESIGNAL_APP_ID || env.ONESIGNAL_APP_ID;
const REST_KEY = process.env.ONESIGNAL_REST_API_KEY || env.ONESIGNAL_REST_API_KEY;
const patPath = process.env.SUPABASE_PAT_FILE || path.join(os.homedir(), '.supabase', 'pat');
const PAT = process.env.SUPABASE_PAT || (fs.existsSync(patPath) ? fs.readFileSync(patPath, 'utf8').trim() : '');

if (!APP_ID || !REST_KEY) {
  console.error('Missing ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY (.env.prod.local or env).');
  process.exit(1);
}
if (!PAT) {
  console.error(`Missing Supabase PAT (looked in ${patPath}).`);
  process.exit(1);
}


const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function osGet(url) {
  const r = await fetch(url, { headers: { Authorization: `Key ${REST_KEY}` } });
  if (!r.ok) return { _http: r.status };
  return r.json();
}

// Fleet-first integrity scan. Enumerates OneSignal rather than Supabase, so it
// sees subscriptions no athlete lookup would ever reach.
async function runFleetScan() {
  const players = [];
  let offset = 0;
  let total = null;
  for (;;) {
    const d = await osGet(`https://api.onesignal.com/players?app_id=${APP_ID}&limit=300&offset=${offset}`);
    const batch = d.players ?? [];
    total = d.total_count ?? total;
    if (batch.length === 0) break;
    players.push(...batch);
    offset += batch.length;
    if (total && offset >= total) break;
  }

  // A short batch used to end the loop early, which once produced a confident
  // "no duplicates" verdict after reading 200 of 778 records. Never report a
  // clean fleet without proving the scan actually covered it.
  const covered = total === null || players.length >= total;

  const byExt = new Map();
  let noExternalId = 0;
  for (const p of players) {
    const e = (p.external_user_id ?? '').trim();
    if (!e) { noExternalId++; continue; }
    if (!byExt.has(e)) byExt.set(e, []);
    byExt.get(e).push(p);
  }

  const nonUuid = [...byExt.entries()].filter(([e]) => !UUID_RE.test(e));
  const candidates = [...byExt.entries()].filter(([e, v]) => UUID_RE.test(e) && v.length > 1);

  const duplicates = [];
  for (const [ext, plist] of candidates) {
    const u = await osGet(`https://api.onesignal.com/apps/${APP_ID}/users/by/external_id/${ext}`);
    if (u._http) { duplicates.push({ ext, subscriptions: plist.length, note: `lookup ${u._http}`, orphaned: plist.length }); continue; }
    const owned = new Set((u.subscriptions ?? []).map((s) => s.id));
    const orphaned = plist.filter((p) => !owned.has(p.id));
    // A subscription that carries the alias but is not owned by the record the
    // alias resolves to can only belong to a SECOND user with the same alias.
    if (orphaned.length) duplicates.push({ ext, subscriptions: plist.length, note: `user owns ${owned.size}`, orphaned: orphaned.length });
  }

  const result = { scanned: players.length, total, covered, noExternalId, duplicates,
                   nonUuid: nonUuid.map(([e, v]) => ({ externalId: e, subscriptions: v.length,
                     deviceModels: new Set(v.map((p) => p.device_model)).size })) };

  if (asJson) { console.log(JSON.stringify(result, null, 2)); }
  else {
    console.log(`\nOneSignal fleet integrity — ${players.length} of ${total} subscriptions scanned\n`);
    if (!covered) console.log('!! INCOMPLETE SCAN — verdict below is not trustworthy\n');
    console.log(`  no external_id at all : ${noExternalId}  (registered but unaddressable)`);
    console.log(`  duplicate aliases     : ${duplicates.length}  (sends fail invalid_aliases)`);
    console.log(`  non-UUID aliases      : ${result.nonUuid.length}  (not a Supabase user id)`);
    for (const d of duplicates) console.log(`      DUP ${d.ext} subs=${d.subscriptions} ${d.note} orphaned=${d.orphaned}`);
    for (const n of result.nonUuid.sort((a, b) => b.subscriptions - a.subscriptions)) {
      console.log(`      BAD ${n.externalId.slice(0, 34).padEnd(36)} subscriptions=${String(n.subscriptions).padStart(3)} deviceModels=${n.deviceModels}`);
    }
    console.log('');
  }
  const clean = covered && duplicates.length === 0 && result.nonUuid.length === 0 && noExternalId === 0;
  process.exit(clean ? 0 : 1);
}

if (fleet) { await runFleetScan(); }

const garminClause = everyone ? '' : 'and a.garmin_summary_id is not null';
const sql = `select distinct a.user_id::text uid, coalesce(au.email, '(anonymous)') email
             from activities a join auth.users au on au.id = a.user_id
             where a.created_at >= now() - interval '${days} days' ${garminClause}`;

const dbRes = await fetch(`https://api.supabase.com/v1/projects/${PROD_REF}/database/query`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${PAT}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: sql }),
});
const users = await dbRes.json();
if (!Array.isArray(users)) {
  console.error('Supabase query failed:', JSON.stringify(users).slice(0, 300));
  process.exit(1);
}

const rows = [];
for (const { uid, email } of users) {
  const r = await fetch(`https://api.onesignal.com/apps/${APP_ID}/users/by/external_id/${uid}`, {
    headers: { Authorization: `Key ${REST_KEY}` },
  });
  if (!r.ok) {
    rows.push({ uid, email, subs: 0, enabled: 0, stale: 0, verdict: 'ALIAS NOT FOUND' });
    continue;
  }
  const body = await r.json();
  const subs = body.subscriptions ?? [];
  // A subscription only counts if OneSignal will actually target it: enabled
  // AND a positive notification_types. Negative values are opt-out states.
  const enabled = subs.filter((s) => s.enabled && (s.notification_types ?? 0) > 0);
  const stale = subs.length - enabled.length;
  let verdict = 'healthy';
  if (subs.length === 0) verdict = 'NO SUBSCRIPTION';
  else if (enabled.length === 0) verdict = 'ALL DISABLED';
  // More than one record for the same device is registration churn: each app
  // reinstall or OS upgrade can strand the previous subscription.
  else if (stale > 0) verdict = `DRIFT (${stale} stale)`;
  rows.push({ uid, email, subs: subs.length, enabled: enabled.length, stale, verdict });
}

const unreachable = rows.filter((r) => r.verdict !== 'healthy');

if (asJson) {
  console.log(JSON.stringify({ scanned: rows.length, unreachable: unreachable.length, rows }, null, 2));
} else {
  console.log(`\nPush reachability — prod, ${everyone ? 'all' : 'Garmin-active'} athletes, last ${days}d\n`);
  console.log(`${'account'.padEnd(36)} ${'subs'.padEnd(5)} ${'ok'.padEnd(4)} ${'stale'.padEnd(6)} verdict`);
  console.log('-'.repeat(88));
  for (const r of rows) {
    console.log(`${r.email.slice(0, 35).padEnd(36)} ${String(r.subs).padEnd(5)} ${String(r.enabled).padEnd(4)} ${String(r.stale).padEnd(6)} ${r.verdict}`);
  }
  console.log('-'.repeat(88));
  const pct = rows.length ? Math.round((unreachable.length / rows.length) * 100) : 0;
  console.log(`${unreachable.length} of ${rows.length} athletes cannot receive a push (${pct}%)\n`);
}

// Non-zero exit when anyone is unreachable, so this can gate a scheduled job.
process.exit(unreachable.length > 0 ? 1 : 0);
