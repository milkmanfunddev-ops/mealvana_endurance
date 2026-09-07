// QA — seed one test athlete (default ravi@test.com) with a month of
// producer-shaped ACTIVITIES + MEAL LOGS on DEV Supabase, so device sweeps and
// design reviews can demo populated states (timeline cards, calendar dots +
// tint, dissolve/collapse under scroll).
//
// Column shapes were copied from live rows the app itself wrote (avery@test.com,
// 2026-09-07); the calendar resolver's channels are all exercised: completed
// (some garmin-verified), one skipped, today's mixed day, planned days ahead,
// meals on most training days.
//
//   node qa/scripts/seed-activities.mjs [email]
//
// Same zero-setup credential pattern as seed-athletes.mjs (anon key + the
// account's own session; RLS-scoped). Idempotent: rows are tagged in `notes`
// (qa-seed-home-shell) and the tag-batch is deleted before re-insert. Row ids
// are DETERMINISTIC (hash of uid+kind+slot), so a re-run on the same calendar
// day upserts the same ids and devices holding earlier pulls never double up.
//
// KNOWN APP GAP (2026-09-07): meal_logs never DOWNLOAD to a device — the
// sync-all-data edge fn omits them and no client path calls the repository's
// syncFromRemote. Activities arrive via login/staleness sync; meal logs must be
// mirrored into the sim's local Drift DB by hand until that's fixed.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { createHash } from 'node:crypto';

const __dir = dirname(fileURLToPath(import.meta.url));
const APP = join(__dir, '..', '..', 'app');
const EMAIL = process.argv[2] || 'ravi@test.com';

const TAG = 'qa-seed-home-shell';
const readEnv = (s, k) => (s.match(new RegExp('^' + k + "\\s*=\\s*['\"]?([^'\"\\n]+)", 'm')) || [])[1];
const devEnv = readFileSync(join(APP, '.env.dev.local'), 'utf8');
const secretsEnv = readFileSync(join(APP, 'secrets/integration_test.env'), 'utf8');
const URL = readEnv(devEnv, 'SUPABASE_URL');
const ANON = readEnv(devEnv, 'SUPABASE_ANON_KEY');
const PW = readEnv(secretsEnv, 'INTEGRATION_TEST_PASSWORD');
const anonHeaders = { apikey: ANON, 'Content-Type': 'application/json' };

// Deterministic UUID from a stable key (sha1 → uuid-v5-shaped).
const stableId = (key) => {
  const h = createHash('sha1').update(key).digest('hex');
  return `${h.slice(0,8)}-${h.slice(8,12)}-5${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`;
};

const r0 = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
  method: 'POST', headers: anonHeaders, body: JSON.stringify({ email: 'ravi@test.com', password: PW }),
});
const sess = await r0.json();
if (!sess.access_token) { console.error(EMAIL + ' login failed', r0.status, JSON.stringify(sess).slice(0, 200)); process.exit(1); }
const uid = sess.user.id;
const h = { ...anonHeaders, Authorization: `Bearer ${sess.access_token}` };
console.log(EMAIL, 'uid:', uid);

// Naive local-style timestamps, matching what the app writes (no zone suffix).
const naive = (y, m, d, hh, mm) =>
  `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00`;
const dayKey = (dt) => dt.slice(0, 10);

const now = new Date(); // 2026-09-07 local
const day = (offset) => {
  const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset);
  return { y: d.getFullYear(), m: d.getMonth() + 1, d: d.getDate() };
};

function activity({ offset, hour, min = 0, type, title, durMin, intensity = 'moderate', done = false, skipped = false, garmin = false, actualHourShift = 0 }) {
  const dd = day(offset);
  const sched = naive(dd.y, dd.m, dd.d, hour, min);
  const actual = done ? naive(dd.y, dd.m, dd.d, hour + actualHourShift, min + 4) : null;
  const nowIso = new Date().toISOString().replace(/\.\d+Z$/, '');
  return {
    id: stableId(`${uid}:act:${offset}:${hour}:${title}`),
    user_id: uid,
    activity_type: type,
    title,
    scheduled_date_time: sched,
    status: skipped ? 'skipped' : done ? 'completed' : 'planned',
    duration_minutes: durMin,
    intensity_level: intensity,
    time_before_minutes: 45,
    planned_time: sched,
    actual_time: actual,
    completed_at: actual,
    actual_duration_minutes: done ? durMin + 3 : null,
    calories_burned: done ? Math.round(durMin * 9.5) : null,
    garmin_summary_id: garmin ? `qa-garmin-${Math.abs(offset)}-${hour}` : null,
    garmin_device_name: garmin ? 'Forerunner 965' : null,
    notes: TAG,
    created_at: naive(dd.y, dd.m, dd.d, 6, 0),
    updated_at: nowIso,
  };
}

const activities = [
  // Past three weeks: a training rhythm of completed sessions.
  activity({ offset: -21, hour: 7, type: 'running', title: 'Easy Run', durMin: 45, intensity: 'easy', done: true, garmin: true }),
  activity({ offset: -19, hour: 18, type: 'cycling', title: 'Tempo Ride', durMin: 75, done: true }),
  activity({ offset: -17, hour: 6, min: 30, type: 'swimming', title: 'Pool Swim', durMin: 50, intensity: 'easy', done: true }),
  activity({ offset: -15, hour: 7, type: 'running', title: 'Long Run', durMin: 110, done: true, garmin: true }),
  activity({ offset: -13, hour: 18, type: 'running', title: 'Interval Session', durMin: 55, intensity: 'hard', done: true }),
  activity({ offset: -12, hour: 17, type: 'cycling', title: 'Recovery Spin', durMin: 40, intensity: 'easy', skipped: true }),
  activity({ offset: -10, hour: 7, type: 'cycling', title: 'Endurance Ride', durMin: 120, done: true, garmin: true }),
  activity({ offset: -8, hour: 6, min: 30, type: 'swimming', title: 'Technique Swim', durMin: 45, intensity: 'easy', done: true }),
  activity({ offset: -7, hour: 7, type: 'running', title: 'Progression Run', durMin: 65, done: true }),
  activity({ offset: -5, hour: 18, type: 'running', title: 'Hill Repeats', durMin: 50, intensity: 'hard', done: true, garmin: true }),
  activity({ offset: -4, hour: 7, type: 'cycling', title: 'Sweet Spot Ride', durMin: 90, done: true }),
  activity({ offset: -2, hour: 7, type: 'running', title: 'Long Run', durMin: 120, done: true, garmin: true }),
  activity({ offset: -1, hour: 6, min: 30, type: 'swimming', title: 'Open Water Swim', durMin: 55, done: true }),
  // Today: one done this morning, one still planned this evening → a live timeline.
  activity({ offset: 0, hour: 7, type: 'running', title: 'Easy Run', durMin: 45, intensity: 'easy', done: true, garmin: true }),
  activity({ offset: 0, hour: 18, min: 30, type: 'cycling', title: 'Evening Spin', durMin: 60 }),
  // The week ahead: planned sessions → hollow orange calendar dots.
  activity({ offset: 1, hour: 18, type: 'running', title: 'Interval Session', durMin: 55, intensity: 'hard' }),
  activity({ offset: 3, hour: 7, type: 'cycling', title: 'Endurance Ride', durMin: 105 }),
  activity({ offset: 4, hour: 6, min: 30, type: 'swimming', title: 'Pool Swim', durMin: 50, intensity: 'easy' }),
  activity({ offset: 6, hour: 7, type: 'running', title: 'Long Run', durMin: 130 }),
];

function mealLog({ offset, hour, name, cal, carb, prot, fat }) {
  const dd = day(offset);
  const eaten = new Date(dd.y, dd.m - 1, dd.d, hour, 0).toISOString();
  return {
    id: stableId(`${uid}:meal:${offset}:${hour}:${name}`),
    user_id: uid,
    log_date: dayKey(naive(dd.y, dd.m, dd.d, 0, 0)),
    slot: null,
    name,
    source: 'saved',
    items: [{ name, portion: '1 serving', calories: cal, carb_g: carb, protein_g: prot, fat_g: fat, sodium_mg: 120 }],
    calories: cal, carbs_g: carb, protein_g: prot, fat_g: fat, sodium_mg: 120,
    notes: TAG,
    eaten_at: eaten,
    is_deleted: false,
  };
}

const MEALS = [
  ['Rolled oats and Raisins', 204, 41, 5.6, 2.6],
  ['Greek yogurt and Honey', 164, 23, 17.1, 0.7],
  ['Banana and Peanut butter', 199, 30.2, 5.3, 8.4],
  ['Rice bowl with Chicken', 520, 68, 34, 11],
  ['Pasta with Marinara', 480, 82, 15, 8],
];
const meals = [];
// Meals on most training days + today → calendar tint coverage.
for (const off of [-21, -19, -17, -15, -13, -10, -8, -7, -5, -4, -2, -1, 0]) {
  const [n1, ...m1] = MEALS[(off + 30) % MEALS.length];
  const [n2, ...m2] = MEALS[(off + 32) % MEALS.length];
  meals.push(mealLog({ offset: off, hour: 8, name: n1, cal: m1[0], carb: m1[1], prot: m1[2], fat: m1[3] }));
  meals.push(mealLog({ offset: off, hour: 13, name: n2, cal: m2[0], carb: m2[1], prot: m2[2], fat: m2[3] }));
}

async function wipe(table) {
  const r = await fetch(`${URL}/rest/v1/${table}?notes=eq.${TAG}&user_id=eq.${uid}`, { method: 'DELETE', headers: h });
  console.log(`wipe ${table}: ${r.status}`);
}
async function insert(table, rows) {
  const r = await fetch(`${URL}/rest/v1/${table}`, {
    method: 'POST', headers: { ...h, Prefer: 'return=minimal' }, body: JSON.stringify(rows),
  });
  if (!r.ok) { console.error(`insert ${table} ${r.status}: ${(await r.text()).slice(0, 400)}`); process.exit(1); }
  console.log(`insert ${table}: ${rows.length} rows OK`);
}

await wipe('activities');
await wipe('meal_logs');
await insert('activities', activities);
await insert('meal_logs', meals);
console.log('Done. ' + EMAIL + ' now has', activities.length, 'activities and', meals.length, 'meal logs.');
