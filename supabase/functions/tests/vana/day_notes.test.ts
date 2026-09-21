/**
 * Day notes are written again only for the days a plan edit touched (ai-cost ticket 13, mp-432 / mp-478).
 *
 * The seam is `generateDayNotes`: producer-shaped `meal_plans` / `plan_meals` / `activities` /
 * `daily_macro_targets` rows go into the fake database, the plan comes back out of `getPlanById` — the notes are
 * never computed from this test's own idea of a MealPlan — and the one model call is injected, so what is asserted
 * is which dates reached the model and what reached the table.
 *
 * The claim row is exercised for real: the `vana_claim_day_notes` / `vana_release_day_notes` handlers below are the
 * migration's semantics in TypeScript (first insert wins, a fresh claim refuses, a TTL-expired one is taken over),
 * and two requests run against one database at the same time.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { getPlanById } from '../../_shared/vana/plan.ts';
import { buildAthleteContext } from '../../_shared/vana/context.ts';
import { dayNoteInputs, dayNoteKeys, generateDayNotes, noteDates, CLAIM_TTL_SECONDS } from '../../_shared/vana/daynotes.ts';
import type { DayNotesDeps } from '../../_shared/vana/daynotes.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import { fakeDb, type Row, type Tables } from './support/fake_db.ts';
import { VANA_COLUMN_DEFAULTS } from './support/vana_ctx.ts';
import type { VanaCtx } from '../../_shared/vana/env.ts';
import type { MealPlan } from '../../_shared/vana/contracts.ts';

const U = TEST_USER_ID;
const PLAN = 'aaaaaaaa-0000-4000-8000-000000000013';
const ANCHOR = '2026-09-21';              // Monday
const DATES = noteDates(ANCHOR);          // 2026-09-21 … 2026-09-27

// ---------------------------------------------------------------- producer-shaped fixtures
const slot = (name: string) => ({ source: 'plan', id: `p-${name}`, name });
/** Every one of the seven days has a dinner assigned, so each day's note has inputs of its own. */
const days = (over: Record<string, Row> = {}) => {
  const out: Record<string, Row> = {};
  DATES.forEach((d, i) => { out[d] = { dinner: slot(`Dinner ${i + 1}`) }; });
  return { ...out, ...over };
};
const planRow = (over: Record<string, unknown> = {}) => ({
  id: PLAN, user_id: U, week_start: '2026-09-20', status: 'confirmed', batch_cooking: true, conversation_id: null,
  brief: null, rules: [], shopping: [], days: days(), day_notes: {}, day_notes_keys: {}, day_notes_stale: true,
  day_notes_at: null, is_deleted: false, updated_at: '2026-09-21T12:00:00Z', ...over,
});
const mealRow = (id: string, name: string, mealType = 'dinner') => ({
  id, plan_id: PLAN, user_id: U, source: 'library', library_meal_id: `D-${id}`, saved_meal_id: null, name,
  meal_type: mealType, session: null, servings: 4, servings_left: 4, kcal: 700, carbs_g: 70, protein_g: 35,
  fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-21T12:00:00Z',
});
const activityRow = (date: string, title: string, minutes: number) => ({
  id: `a-${date}`, user_id: U, scheduled_date_time: `${date}T07:00:00`, title, activity_type: 'run',
  duration_minutes: minutes, intensity_level: 'moderate', distance_miles: 8, distance_meters: null,
  status: 'planned', deleted_at: null,
});
const macroRow = (date: string, carbs: number) => ({
  id: `m-${date}`, user_id: U, target_date: date, carb_g: carbs, prot_g: 140, fat_g: 70, tdee: 2900,
  session_kcal: 500, mode: 'performance',
});

const baseTables = (over: Partial<Tables> = {}): Tables => ({
  users: [{ id: U, first_name: 'Lee', allergies: [], dietary_preference: null }],
  meal_plans: [planRow()],
  plan_meals: [mealRow('m1', 'Rice bowl'), mealRow('m2', 'Chili'), mealRow('m3', 'Salmon traybake')],
  activities: [activityRow(DATES[2], 'Long run', 120)],
  daily_macro_targets: DATES.map((d, i) => macroRow(d, 400 + i * 10)),
  ...over,
});

// ---------------------------------------------------------------- the claim row, as the migration defines it
interface Claim { plan_id: string; claimed_at: number }
interface ClaimArgs { p_plan_id: string; p_ttl_seconds: number }
interface ReleaseArgs { p_plan_id: string; p_claimed_at: string }
/** The claim answers its `claimed_at` (the token a release must carry), or null when someone else holds it. */
type Rpc = { vana_claim_day_notes: (a: ClaimArgs) => string | null; vana_release_day_notes: (a: ReleaseArgs) => null };
function claimHandlers(now = () => Date.now()): { held: Map<string, Claim>; rpc: Rpc } {
  const held = new Map<string, Claim>();
  return {
    held,
    rpc: {
      vana_claim_day_notes: ({ p_plan_id, p_ttl_seconds }: ClaimArgs) => {
        const row = held.get(p_plan_id);
        if (row && row.claimed_at >= now() - (p_ttl_seconds ?? CLAIM_TTL_SECONDS) * 1000) return null;
        held.set(p_plan_id, { plan_id: p_plan_id, claimed_at: now() });
        return String(now());
      },
      vana_release_day_notes: ({ p_plan_id, p_claimed_at }: ReleaseArgs) => {
        if (String(held.get(p_plan_id)?.claimed_at) === p_claimed_at) held.delete(p_plan_id);
        return null;
      },
    },
  };
}

/** Two VanaCtx over ONE fake database, the way two isolates share one Postgres. */
function twoCtx(tables: Tables, rpc: Rpc): [VanaCtx, VanaCtx, ReturnType<typeof fakeDb>] {
  // deno-lint-ignore no-explicit-any
  const fake = fakeDb(tables, { rpc: rpc as any, defaults: VANA_COLUMN_DEFAULTS });
  // deno-lint-ignore no-explicit-any
  const db = fake as any;
  const of = (): VanaCtx => ({ db, admin: db, userId: U, token: 'test-token' });
  return [of(), of(), fake];
}

interface Recorder { calls: { dates: string[]; prompt: string }[] }
function deps(rec: Recorder, over: Partial<DayNotesDeps> = {}): DayNotesDeps {
  return {
    generate: ({ prompt, dates }) => {
      rec.calls.push({ dates, prompt });
      return Promise.resolve({ notes: dates.map((d) => ({ date: d, text: `note v${rec.calls.length} for ${d}` })), inputTokens: 1200, outputTokens: 240 });
    },
    buildContext: (v, anchor) => buildAthleteContext(v, anchor, offlineDeps()),
    claim: () => Promise.resolve(true),
    release: () => Promise.resolve(),
    waitMs: 2_000,
    pollMs: 5,
    sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
    ...over,
  };
}

/** Seed `day_notes` / `day_notes_keys` so the plan starts with seven current notes, the way a generation leaves it. */
async function seedCurrentNotes(v: VanaCtx, plan: MealPlan): Promise<Record<string, string>> {
  const ctx = await buildAthleteContext(v, ANCHOR, offlineDeps());
  const keys = await dayNoteKeys(plan, ctx, DATES);
  const notes: Record<string, string> = {};
  for (const d of DATES) notes[d] = `stored note for ${d}`;
  await v.db.from('meal_plans').update({ day_notes: notes, day_notes_keys: keys, day_notes_stale: false, day_notes_at: '2026-09-21T13:00:00Z' }).eq('id', PLAN);
  return notes;
}

// ================================================================ the fingerprint
Deno.test('a day\'s fingerprint covers its own meals, its own training and its own target — and the pool only when nothing is assigned', async () => {
  const v = testCtx(baseTables());
  const plan = (await getPlanById(v, PLAN))!;
  const ctx = await buildAthleteContext(v, ANCHOR, offlineDeps());

  const wed = dayNoteInputs(plan, ctx, DATES[2]);
  assert(wed.includes('slots=dinner=Dinner 3'), wed);
  assert(wed.includes('Long run'), 'the day\'s workout is an input');
  assert(wed.includes('t=420/2900/500'), 'the day\'s macro target is an input');
  assert(wed.includes('pool=assigned'), 'an assigned day does not depend on the rest of the pool');

  // An unassigned day may name any meal in the plan, so the pool IS one of its inputs.
  const loose = { ...plan, days: { ...plan.days, [DATES[2]]: {} } };
  assert(dayNoteInputs(loose, ctx, DATES[2]).includes('Rice bowl'), 'an unassigned day carries the pool');
});

// ================================================================ criterion 1
Deno.test('a plan edit regenerates only the days it touched', async () => {
  const v = testCtx(baseTables());
  const before = (await getPlanById(v, PLAN))!;
  const stored = await seedCurrentNotes(v, before);

  // The edit: Wednesday's dinner becomes another meal. Nothing else about the week moves.
  await v.db.from('meal_plans').update({ days: days({ [DATES[2]]: { dinner: slot('Salmon traybake') } }), day_notes_stale: true }).eq('id', PLAN);
  const edited = (await getPlanById(v, PLAN))!;

  const rec: Recorder = { calls: [] };
  const notes = await generateDayNotes(v, edited, ANCHOR, deps(rec));

  assertEquals(rec.calls.length, 1, 'one model call');
  assertEquals(rec.calls[0].dates, [DATES[2]], 'and it asked for Wednesday alone');
  assertEquals(notes[DATES[2]], `note v1 for ${DATES[2]}`);
  for (const d of DATES.filter((x) => x !== DATES[2])) assertEquals(notes[d], stored[d], `${d} kept its stored note`);

  const write = v.fake.writesTo('meal_plans', 'update').at(-1)!.values;
  // The flag came down before the model ran (so an edit mid-generation can raise it again), not in the notes' write.
  assertEquals('day_notes_stale' in write, false);
  assertEquals((await getPlanById(v, PLAN))!.dayNotesStale, false);
  assertEquals(Object.keys(write.day_notes).sort(), DATES.slice().sort(), 'all seven notes are still on the plan');
});

Deno.test('a meal leaving the pool rewrites the unassigned days and leaves the assigned ones alone', async () => {
  // Wednesday and Thursday have nothing assigned; the other five do.
  const loose = days({ [DATES[2]]: {}, [DATES[3]]: {} });
  const v = testCtx(baseTables({ meal_plans: [planRow({ days: loose })] }));
  const before = (await getPlanById(v, PLAN))!;
  const stored = await seedCurrentNotes(v, before);

  await v.db.from('plan_meals').delete().eq('id', 'm3');           // the athlete drops a meal
  await v.db.from('meal_plans').update({ day_notes_stale: true }).eq('id', PLAN);
  const edited = (await getPlanById(v, PLAN))!;

  const rec: Recorder = { calls: [] };
  const notes = await generateDayNotes(v, edited, ANCHOR, deps(rec));
  assertEquals(rec.calls.length, 1);
  assertEquals(rec.calls[0].dates, [DATES[2], DATES[3]]);
  for (const d of [DATES[0], DATES[1], DATES[4], DATES[5], DATES[6]]) assertEquals(notes[d], stored[d]);
});

// ================================================================ criterion 2
Deno.test('an unchanged plan returns the stored notes and calls no model', async () => {
  const v = testCtx(baseTables());
  const plan = (await getPlanById(v, PLAN))!;
  const stored = await seedCurrentNotes(v, plan);

  // The flag says "look again" — a shopping toggle flips it too — but no note input moved.
  await v.db.from('meal_plans').update({ day_notes_stale: true }).eq('id', PLAN);
  const flagged = (await getPlanById(v, PLAN))!;
  assertEquals(flagged.dayNotesStale, true);

  const rec: Recorder = { calls: [] };
  const notes = await generateDayNotes(v, flagged, ANCHOR, deps(rec));
  assertEquals(rec.calls.length, 0, 'no model call');
  assertEquals(notes, stored, 'the stored notes come back unchanged');
  assertEquals(v.fake.writesTo('vana_calls', 'insert').length, 0, 'nothing was billed');
  assertEquals(v.fake.writesTo('meal_plans', 'update').at(-1)!.values, { day_notes_stale: false }, 'only the flag is cleared');
});

Deno.test('a second request right after a generation calls nothing either', async () => {
  const v = testCtx(baseTables());
  const plan = (await getPlanById(v, PLAN))!;
  const rec: Recorder = { calls: [] };
  await generateDayNotes(v, plan, ANCHOR, deps(rec));
  assertEquals(rec.calls.length, 1);
  assertEquals(rec.calls[0].dates, DATES, 'the first generation writes all seven days');

  await generateDayNotes(v, (await getPlanById(v, PLAN))!, ANCHOR, deps(rec));
  assertEquals(rec.calls.length, 1, 'the repeat invocation is free');
});

Deno.test('over the rate-limit bucket nothing is generated and the stored notes stand', async () => {
  const calls = Array.from({ length: 4 }, (_, i) => ({ id: `c${i}`, user_id: U, function_name: 'vana.daynotes', model: 'anthropic/claude-haiku-4.5', created_at: new Date().toISOString() }));
  const v = testCtx(baseTables({ vana_calls: calls }));
  const plan = (await getPlanById(v, PLAN))!;
  const rec: Recorder = { calls: [] };
  assertEquals(await generateDayNotes(v, plan, ANCHOR, deps(rec)), {});
  assertEquals(rec.calls.length, 0);
});

// ================================================================ criterion 3
Deno.test('a claim row makes two simultaneous requests share one model call', async () => {
  const { rpc, held } = claimHandlers();
  const [a, b, fake] = twoCtx(baseTables(), rpc);
  const plan = (await getPlanById(a, PLAN))!;

  const rec: Recorder = { calls: [] };
  // The winner is held inside the model call until both requests have raced for the claim.
  let release!: () => void;
  const gate = new Promise<void>((r) => { release = r; });
  const slow = deps(rec, {
    claim: (_v, id) => Promise.resolve(rpc.vana_claim_day_notes({ p_plan_id: id, p_ttl_seconds: CLAIM_TTL_SECONDS }) ?? false),
    release: (_v, id, token) => { rpc.vana_release_day_notes({ p_plan_id: id, p_claimed_at: token }); return Promise.resolve(); },
    generate: async ({ dates }) => { rec.calls.push({ dates, prompt: '' }); await gate; return { notes: dates.map((d) => ({ date: d, text: `shared note for ${d}` })), inputTokens: 1200, outputTokens: 240 }; },
  });

  const both = Promise.all([generateDayNotes(a, plan, ANCHOR, slow), generateDayNotes(b, plan, ANCHOR, slow)]);
  await new Promise((r) => setTimeout(r, 30));   // both have raced for the claim by now
  release();
  const [first, second] = await both;

  assertEquals(rec.calls.length, 1, 'one model call for two simultaneous requests');
  assertEquals(first, second, 'and both requests answer with the same notes');
  assertEquals(first[DATES[0]], `shared note for ${DATES[0]}`);
  assertEquals(fake.writesTo('vana_calls', 'insert').length, 1, 'one billed call');
  assertEquals(held.size, 0, 'the claim was released');
});

Deno.test('a claim left behind by a dead isolate expires, it never blocks the plan for good', () => {
  let clock = 1_000_000;
  const { rpc } = claimHandlers(() => clock);
  const args = { p_plan_id: PLAN, p_ttl_seconds: CLAIM_TTL_SECONDS };
  const first = rpc.vana_claim_day_notes(args);
  assertEquals(typeof first, 'string');
  assertEquals(rpc.vana_claim_day_notes(args), null, 'a fresh claim is refused');
  clock += (CLAIM_TTL_SECONDS + 1) * 1000;
  assertEquals(typeof rpc.vana_claim_day_notes(args), 'string', 'past the TTL the next request takes it over');
});

Deno.test('a generation that outlived its claim cannot release the claim of whoever took it over', () => {
  let clock = 1_000_000;
  const { rpc, held } = claimHandlers(() => clock);
  const args = { p_plan_id: PLAN, p_ttl_seconds: CLAIM_TTL_SECONDS };
  const slow = rpc.vana_claim_day_notes(args)!;
  clock += (CLAIM_TTL_SECONDS + 1) * 1000;
  const taker = rpc.vana_claim_day_notes(args)!;
  rpc.vana_release_day_notes({ p_plan_id: PLAN, p_claimed_at: slow });
  assertEquals(held.size, 1, "the slow winner's release leaves the taker's claim alone");
  rpc.vana_release_day_notes({ p_plan_id: PLAN, p_claimed_at: taker });
  assertEquals(held.size, 0);
});

Deno.test('a claim that failed open releases nothing: it never held a row', async () => {
  const [a] = twoCtx(baseTables(), claimHandlers().rpc);
  const plan = (await getPlanById(a, PLAN))!;
  let released = 0;
  await generateDayNotes(a, plan, ANCHOR, deps({ calls: [] }, { claim: () => Promise.resolve(true), release: () => { released++; return Promise.resolve(); } }));
  assertEquals(released, 0);
});

Deno.test('an edit that lands while the notes are being written keeps the plan marked stale', async () => {
  const { rpc } = claimHandlers();
  const [a, , fake] = twoCtx(baseTables(), rpc);
  const plan = (await getPlanById(a, PLAN))!;
  const rec: Recorder = { calls: [] };
  await generateDayNotes(a, plan, ANCHOR, deps(rec, {
    generate: async ({ dates }) => {
      // The athlete edits the plan mid-generation: every plan mutation raises the flag.
      // deno-lint-ignore no-explicit-any
      await (fake as any).from('meal_plans').update({ day_notes_stale: true }).eq('id', PLAN);
      return { notes: dates.map((d) => ({ date: d, text: `note for ${d}` })), inputTokens: 1, outputTokens: 1 };
    },
  }));
  const after = (await getPlanById(a, PLAN))!;
  assertEquals(after.dayNotesStale, true, "the winner's write did not lower the flag over the edit");
});
