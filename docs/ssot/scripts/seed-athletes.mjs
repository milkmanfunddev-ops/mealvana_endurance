// QA — seed the 20 test athletes into DEV Supabase (NO service_role needed).
//
// Uses only the public ANON key + the normal sign-up endpoint: for each persona in
// qa/profiles/athletes.json it signs up an email/password account, then writes that
// athlete's public.users profile row using the new user's OWN session (RLS lets a user
// write their own row — same as the app's onboarding).
//
// RUN IT YOURSELF (it creates accounts):
//   node qa/scripts/seed-athletes.mjs
//
// Zero setup — it auto-reads from the sibling app repo:
//   • SUPABASE_URL + anon key  ← app/.env.dev.local  (the LIVE keys the app loads)
//   • password                 ← app/secrets/integration_test.env (INTEGRATION_TEST_PASSWORD)
// Override any of them with env vars SUPABASE_URL / SUPABASE_ANON_KEY / QA_TEST_PASSWORD.
//
// Node 18+ (built-in fetch). No npm install. Idempotent: re-running logs in existing
// accounts and updates their profile row.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dir = dirname(fileURLToPath(import.meta.url));
const APP = join(__dir, '..', '..', 'app'); // sibling department

function fromApp(relPath) {
  try { return readFileSync(join(APP, relPath), 'utf8'); } catch { return ''; }
}

// Live keys come from .env.dev.local (what the app actually loads) — NOT test_config.dart,
// whose committed anon key is stale (project keys were rotated).
const devEnv = fromApp('.env.dev.local');
const secretsEnv = fromApp('secrets/integration_test.env');
const readEnv = (s, k) => (s.match(new RegExp('^' + k + "\\s*=\\s*['\"]?([^'\"\\n]+)", 'm')) || [])[1];

const URL = process.env.SUPABASE_URL || readEnv(devEnv, 'SUPABASE_URL');
const ANON = process.env.SUPABASE_ANON_KEY || readEnv(devEnv, 'SUPABASE_ANON_KEY');
const PW = process.env.QA_TEST_PASSWORD || readEnv(secretsEnv, 'INTEGRATION_TEST_PASSWORD');

if (!URL || !ANON || !PW) {
  console.error('Could not resolve URL / anon key / password.');
  console.error(`  URL=${!!URL} ANON=${!!ANON} PW=${!!PW}`);
  console.error('  Fix: run from the repo (auto-reads app/), or set SUPABASE_URL / SUPABASE_ANON_KEY / QA_TEST_PASSWORD.');
  process.exit(1);
}

const { athletes } = JSON.parse(readFileSync(join(__dir, '..', 'profiles', 'athletes.json'), 'utf8'));
const anonHeaders = { apikey: ANON, 'Content-Type': 'application/json' };
const pgArray = (arr) => `{${(arr || []).join(',')}}`;

// Get a session token + uid: sign up if new, else log in.
async function getSession(email) {
  let r = await fetch(`${URL}/auth/v1/signup`, {
    method: 'POST', headers: anonHeaders, body: JSON.stringify({ email, password: PW }),
  });
  let j = await r.json().catch(() => ({}));
  if (r.ok && j.access_token) return { token: j.access_token, uid: j.user?.id || j.id };

  // Existing account (or signup returned no session) → password login.
  r = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
    method: 'POST', headers: anonHeaders, body: JSON.stringify({ email, password: PW }),
  });
  j = await r.json().catch(() => ({}));
  if (r.ok && j.access_token) return { token: j.access_token, uid: j.user?.id };

  const hint = /confirm/i.test(JSON.stringify(j))
    ? ' — dev has EMAIL CONFIRMATION ON; ask Lee to disable it (Auth > Providers > Email) or run the service_role variant.'
    : '';
  throw new Error(`no session (${r.status})${hint}`);
}

async function upsertProfile(token, uid, a) {
  const row = {
    id: uid, device_id: `qa-seed-${a.id}`, auth_user_id: uid,
    auth_provider: 'email', is_anonymous: false, onboarding_completed: true, email: a.email,
    gender: a.gender, birthday: `${a.birthday}T00:00:00Z`,
    height_feet: a.heightFeet, height_inches: a.heightInches, weight_pounds: a.weightPounds,
    body_fat_pct: a.bodyFatPct ?? null, lifestyle: a.lifestyle,
    typical_weekly_hours: a.typicalWeeklyHours ?? null, training_phase: a.trainingPhase,
    carb_cycle_opt_in: !!a.carbCycleOptIn, gut_training_level: a.gutTrainingLevel,
    sweat_rate: a.sweatRate, sweat_sodium: a.sweatSodium ?? null,
    dietary_preference: a.dietaryPreference ?? null, allergies: pgArray(a.allergies),
    runs_with_water_bottle: !!a.runsWithWaterBottle,
    known_sweat_rate_ml_per_hour: a.knownSweatRateMlPerHour ?? null,
    known_sodium_concentration_mg_per_liter: a.knownSodiumConcentrationMgPerLiter ?? null,
  };
  const r = await fetch(`${URL}/rest/v1/users?on_conflict=id`, {
    method: 'POST',
    headers: { ...anonHeaders, Authorization: `Bearer ${token}`, Prefer: 'resolution=merge-duplicates,return=minimal' },
    body: JSON.stringify(row),
  });
  if (!r.ok) throw new Error(`profile upsert ${r.status}: ${(await r.text()).slice(0, 240)}`);
}

let ok = 0;
for (const a of athletes) {
  try {
    const { token, uid } = await getSession(a.email);
    await upsertProfile(token, uid, a);
    ok++;
    console.log(`  ✓ ${a.email.padEnd(20)} ${a.id}  (${a.covers})`);
  } catch (e) {
    console.error(`  ✗ ${a.email.padEnd(20)} ${e.message}`);
  }
}
console.log(`\nSeeded ${ok}/${athletes.length}. Log in on the sim as e.g. maya@test.com / <the test password>.`);
