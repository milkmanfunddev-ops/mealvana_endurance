/**
 * The context block, line by line, from fixture rows.
 *
 * This is the seam every later server ticket tests through: producer-shaped rows go into the fake
 * database, `buildAthleteContext` reads them the way the deployed function does, and `contextBlock`
 * renders the text the model actually sees. Nothing here asserts on prompt wording outside the
 * block, on tool-call order, or on a private helper.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { testCtx, offlineDeps, fixedWeather, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09'; // a Wednesday; its Sunday-start week is 2026-09-06

const PLAN_ID = 'aaaaaaaa-0000-4000-8000-000000000001';

/** One athlete's week as the tables return it. */
function fixture(): Tables {
  return {
    users: [{ id: U, first_name: 'Lee', dietary_preference: 'vegetarian', allergies: ['peanuts'], gut_training_level: 'moderate' }],
    activities: [
      { id: 'act-1', user_id: U, scheduled_date_time: '2026-09-10T06:00:00', title: 'Tempo run', activity_type: 'running', duration_minutes: 60, intensity_level: 'high', distance_miles: 8, distance_meters: null, status: 'planned', deleted_at: null },
      { id: 'act-2', user_id: U, scheduled_date_time: '2026-09-12T07:00:00', title: 'Long ride', activity_type: 'cycling', duration_minutes: 180, intensity_level: 'moderate', distance_miles: 55, distance_meters: null, status: 'planned', deleted_at: null },
      // two days back, done and long — the RECENT line's "notable session"
      { id: 'act-0', user_id: U, scheduled_date_time: '2026-09-07T07:00:00', title: 'Century ride', activity_type: 'cycling', duration_minutes: 300, intensity_level: 'moderate', distance_miles: 100, distance_meters: null, status: 'completed', deleted_at: null },
    ],
    // 11 days: the WEEK line shows the first 7, the last three feed the race-week carb ceiling
    daily_macro_targets: Array.from({ length: 11 }, (_, i) => ({
      user_id: U,
      target_date: new Date(Date.UTC(2026, 8, 9 + i)).toISOString().slice(0, 10),
      carb_g: 400 + i * 10, prot_g: 140, fat_g: 70, tdee: 3000 + i * 50, session_kcal: 600, mode: 'fuel',
    })),
    events: [{ user_id: U, event_name: 'Chattanooga 70.3', event_date: '2026-09-20', location: 'Chattanooga, TN', event_type: 'triathlon' }],
    meal_logs: [
      { user_id: U, log_date: ANCHOR, carbs_g: 85, calories: 620, is_deleted: false },
      { user_id: U, log_date: ANCHOR, carbs_g: 40, calories: 300, is_deleted: false },
    ],
    meal_plans: [{ id: PLAN_ID, user_id: U, week_start: '2026-09-06', status: 'confirmed', batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], day_notes: {}, day_notes_stale: false, is_deleted: false, updated_at: '2026-09-06T12:00:00Z' }],
    plan_meals: [
      { id: 'pm-1', plan_id: PLAN_ID, user_id: U, source: 'library', library_meal_id: 'D-001', saved_meal_id: null, name: 'Lentil bolognese', meal_type: 'dinner', session: 'cook-sun', servings: 4, servings_left: 3, kcal: 650, carbs_g: 90, protein_g: 32, fat_g: 14, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-06T12:00:00Z' },
      { id: 'pm-2', plan_id: PLAN_ID, user_id: U, source: 'library', library_meal_id: 'D-002', saved_meal_id: null, name: 'Chickpea curry', meal_type: 'dinner', session: 'cook-sun', servings: 4, servings_left: 2, kcal: 700, carbs_g: 95, protein_g: 28, fat_g: 18, swaps_applied: [], comments: [], position: 1, icon: null, created_at: '2026-09-06T12:01:00Z' },
    ],
    user_memories: [
      { id: 'mem-1', user_id: U, kind: 'preference', key: null, fact: 'Hates cilantro', value: null, confidence: 0.9, last_confirmed_at: '2026-09-05T10:00:00Z', source: 'conversation', is_deleted: false },
      { id: 'mem-2', user_id: U, kind: 'setting', key: 'coverage_scope', fact: 'Plans dinners only', value: 'dinners', confidence: 1, last_confirmed_at: '2026-09-04T10:00:00Z', source: 'settings', is_deleted: false },
      { id: 'mem-3', user_id: U, kind: 'setting', key: 'batch_cooking', fact: 'Cooks in batches (cook once, eat across the week)', value: true, confidence: 1, last_confirmed_at: '2026-09-03T10:00:00Z', source: 'settings', is_deleted: false },
    ],
    plan_debriefs: [{ user_id: U, plan_id: PLAN_ID, completed: 5, planned: 7, skip_reason: 'travel', created_at: '2026-09-06T09:00:00Z' }],
    holidays: [],
  };
}

const build = async (tables = fixture()) => {
  const v = testCtx(tables);
  const c = await buildAthleteContext(v, undefined, ANCHOR, offlineDeps({ weatherLine: fixedWeather({ 'Chattanooga, TN': 'Chattanooga, TN · 84°F, 10% rain' }) }));
  return { v, c, lines: contextBlock(c).split('\n') };
};

const lineStartingWith = (lines: string[], prefix: string) => lines.find((l) => l.startsWith(prefix)) ?? `«no ${prefix} line»`;

Deno.test('context block: every line, from producer-shaped rows', async () => {
  const { lines } = await build();

  assertEquals(lineStartingWith(lines, 'ATHLETE'), 'ATHLETE Lee · diet vegetarian · allergies peanuts');
  assertEquals(lineStartingWith(lines, 'WEEK'), 'WEEK 2026-09-06 · easy / recovery · 09-10 Tempo run 60m; 09-12 Long ride 180m');
  assertEquals(lineStartingWith(lines, 'RACE'), 'RACE Chattanooga 70.3 2026-09-20 (11d)');
  assertEquals(lineStartingWith(lines, 'HOLIDAYS'), 'HOLIDAYS none in the next 2 weeks');
  assertEquals(
    lineStartingWith(lines, 'TARGETS'),
    'TARGETS (daily-macros service) today 3000kcal ≥400C ≥140P 70F · formulas 600kcal · meal budget 2400kcal (lunch+dinner ≈1320) · week 09-09:400C/140P/3000kcal 09-10:410C/140P/3050kcal 09-11:420C/140P/3100kcal 09-12:430C/140P/3150kcal 09-13:440C/140P/3200kcal 09-14:450C/140P/3250kcal 09-15:460C/140P/3300kcal · race-week ≥500C',
  );
  // Today's weather is keyed off the race venue, not where the athlete lives — the gap ticket 07 closes.
  assertEquals(lineStartingWith(lines, 'WEATHER'), 'WEATHER Chattanooga, TN · 84°F, 10% rain · race day Chattanooga, TN · 84°F, 10% rain');
  assertEquals(lineStartingWith(lines, 'LOGGED TODAY'), 'LOGGED TODAY 2 meals 125C · PLAN confirmed, 5 servings left · batch on · coverage dinners only');
  assertEquals(lineStartingWith(lines, 'RECENT'), 'RECENT 09-07 Century ride 300m moderate — done');
  assertEquals(lineStartingWith(lines, 'LAST WEEK'), 'LAST WEEK 5 of 7 planned meals happened (skipped: travel)');
  assertEquals(
    lineStartingWith(lines, 'MEMORIES'),
    'MEMORIES Hates cilantro (conversation · 2026-09-05) | Plans dinners only (settings · 2026-09-04) | Cooks in batches (cook once, eat across the week) (settings · 2026-09-03)',
  );
});

Deno.test('context block: an athlete with nothing on file still renders every line', async () => {
  const { lines } = await build({ users: [{ id: U, first_name: null, dietary_preference: null, allergies: null, gut_training_level: null }] });

  assertEquals(lineStartingWith(lines, 'ATHLETE'), 'ATHLETE  · diet any · allergies none');
  assertEquals(lineStartingWith(lines, 'RACE'), 'RACE none');
  assertEquals(lineStartingWith(lines, 'WEATHER'), 'WEATHER n/a');
  assertEquals(lineStartingWith(lines, 'RECENT'), 'RECENT no notable session in the last 2 days');
  assertEquals(lineStartingWith(lines, 'LAST WEEK'), 'LAST WEEK no debrief yet');
  assertEquals(lineStartingWith(lines, 'MEMORIES'), 'MEMORIES none');
  assertEquals(
    lineStartingWith(lines, 'LOGGED TODAY'),
    'LOGGED TODAY 0 meals 0C · PLAN none · batch never chosen · coverage never chosen',
  );
});

Deno.test('context block: reads the athlete, and writes nothing', async () => {
  const { v } = await build();
  assertEquals(v.fake.writes, []);
});
