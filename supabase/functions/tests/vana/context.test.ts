/** Port of the prototype's context.test.ts — week character + the deterministic plan math. */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { deriveWeekCharacter } from '../../_shared/vana/derive-week-character.ts';
import { coverageOf, defaultSession } from '../../_shared/vana/plan-math.ts';
import { pickOpener, sessionDates } from '../../_shared/vana/opener.ts';
import { seasonalProduce } from '../../_shared/vana/season.ts';

const d = (n: number) => new Date(Date.now() + n * 86400_000).toISOString().slice(0, 10) + 'T07:00:00';

Deno.test('week character: flags race week from a title and picks the longest session as anchor', () => {
  const w = deriveWeekCharacter([{ scheduled_date_time: d(1), title: 'Easy run', activity_type: 'run', duration_minutes: 40, intensity_level: 'low' }, { scheduled_date_time: d(5), title: 'Ironman Florida', activity_type: 'triathlon', duration_minutes: 600, intensity_level: 'race' }]);
  assertEquals(w.isRaceWeek, true); assertEquals(w.weekCharacter, 'race week'); assertEquals(w.anchor?.title, 'Ironman Florida');
});

Deno.test('week character: scores load and rest days', () => {
  const w = deriveWeekCharacter([{ scheduled_date_time: d(1), title: 'Intervals', activity_type: 'run', duration_minutes: 60, intensity_level: 'high' }]);
  assertEquals(w.totalLoad, 180); assertEquals(w.restDays, 6); assertEquals(w.weekCharacter, 'easy / recovery');
});

const meal = (over: object) => ({ id: 'x', planId: 'p', source: 'library' as const, libraryMealId: 'D-001', savedMealId: null, name: 'n', mealType: 'dinner' as const, session: null, servings: 5, servingsLeft: 5, kcal: 650, carbsG: 90, proteinG: 45, fatG: 12, swapsApplied: [], comments: [], position: 0, ...over });

Deno.test('plan math: coverage caps at 14 lunch+dinner slots and averages per day', () => {
  const c = coverageOf([meal({}), meal({ servings: 4, kcal: 620, carbsG: 75, proteinG: 40 }), meal({ servings: 4, kcal: 700, carbsG: 95, proteinG: 36 }), meal({ servings: 1, kcal: 600, carbsG: 85, proteinG: 42 })]);
  assertEquals(c.covered, 14); assertEquals(c.perDay.carbsG, 174); assertEquals(c.perDay.kcal, 1304);
});

Deno.test('plan math: coverage_scope dinners counts 7 dinner slots and ignores lunches; other scopes keep 14', () => {
  const meals = [meal({ servings: 4 }), meal({ mealType: 'lunch', servings: 5 })];
  const dinners = coverageOf(meals, 'dinners');
  assertEquals(dinners.lunchDinnerSlots, 7); assertEquals(dinners.covered, 4);
  assertEquals(coverageOf([meal({ servings: 9 })], 'dinners').covered, 7);
  for (const scope of ['dinners_lunches', 'all', null, 'garbage']) { const c = coverageOf(meals, scope); assertEquals(c.lunchDinnerSlots, 14); assertEquals(c.covered, 9); }
});

Deno.test('plan math: sessions — none when batch off; Sunday then Wednesday top-up; fresh Friday for non-batch meals', () => {
  assertEquals(defaultSession(false, { batch: true }, []), null);
  assertEquals(defaultSession(true, { batch: true }, []), 'cook-sun');
  assertEquals(defaultSession(true, { batch: true }, [meal({ session: 'cook-sun' }), meal({ session: 'cook-sun' })]), 'topup-wed');
  assertEquals(defaultSession(true, { batch: false }, []), 'fresh-fri');
});

// ---- Phase 3: which opener a new planning conversation gets (pure)
const planOf = (over: object) => ({ id: 'p1', weekStart: '2026-09-06', status: 'confirmed' as const, batchCooking: true, brief: null, rules: [], meals: [meal({ session: 'cook-sun' })], shopping: [], dayNotes: {}, coverage: coverageOf([]), ...over });
Deno.test('opener: check-in fires the day before / the day of a cook session, once', () => {
  assertEquals(sessionDates('2026-09-06')['topup-wed'], '2026-09-09');
  assertEquals(pickOpener({ today: '2026-09-05', current: null, previous: planOf({ weekStart: '2026-08-30', checkinDoneAt: null }) }).kind, 'plan'); // last week's plan is not "current"; not finished either → plan
  assertEquals(pickOpener({ today: '2026-09-05', current: planOf({ weekStart: '2026-09-06' }), previous: null }).kind, 'checkin');
  assertEquals(pickOpener({ today: '2026-09-06', current: planOf({ weekStart: '2026-09-06' }), previous: null }).kind, 'checkin');
  assertEquals(pickOpener({ today: '2026-09-07', current: planOf({ weekStart: '2026-09-06' }), previous: null }).kind, 'plan');
  assertEquals(pickOpener({ today: '2026-09-05', current: planOf({ weekStart: '2026-09-06', checkinDoneAt: '2026-09-05T10:00:00Z' }), previous: null }).kind, 'plan');
  assertEquals(pickOpener({ today: '2026-09-05', current: planOf({ weekStart: '2026-09-06', status: 'draft' }), previous: null }).kind, 'plan');
});
Deno.test('opener: debrief wins for a finished, undebriefed week (≤14 days after it ended)', () => {
  const prev = planOf({ id: 'p0', weekStart: '2026-08-30' });
  assertEquals(pickOpener({ today: '2026-09-06', current: planOf({ weekStart: '2026-09-06' }), previous: prev }).kind, 'debrief');
  assertEquals(pickOpener({ today: '2026-09-05', current: null, previous: prev }).kind, 'plan');          // week not over yet
  assertEquals(pickOpener({ today: '2026-09-06', current: null, previous: planOf({ ...prev, debriefDoneAt: '2026-09-06T09:00:00Z' }) }).kind, 'plan');
  assertEquals(pickOpener({ today: '2026-09-21', current: null, previous: prev }).kind, 'plan');          // too old to nag
});
Deno.test('season: every month has produce', () => { for (let m = 1; m <= 12; m++) assert(seasonalProduce(`2026-${String(m).padStart(2, '0')}-10`).length >= 4); });
