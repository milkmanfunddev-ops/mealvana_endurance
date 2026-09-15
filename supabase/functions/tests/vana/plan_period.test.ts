/**
 * Ticket 29 (mp-269) at the server seam: the week start and the period length are keyed settings, and the week the
 * plan belongs to, the cook-day dates, coverage and the check-in / debrief opener all read them.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { weekStartFor } from '../../_shared/vana/env.ts';
import { coverageOf, sessionOffsets } from '../../_shared/vana/plan-math.ts';
import { pickOpener, sessionDates } from '../../_shared/vana/opener.ts';
import { getPlanPeriod, SETTING_DEFAULTS } from '../../_shared/vana/memory.ts';
import { getOrCreatePlan } from '../../_shared/vana/plan.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const setting = (key: string, value: unknown) => ({ id: `s-${key}`, user_id: U, kind: 'setting', key, fact: key, value, source: 'settings', is_deleted: false });

Deno.test('defaults: the week starts on Sunday and runs seven days', async () => {
  assertEquals(SETTING_DEFAULTS.week_start, 'sun');
  assertEquals(SETTING_DEFAULTS.period_days, 7);
  assertEquals(await getPlanPeriod(testCtx()), { weekStart: 'sun', periodDays: 7 });
  assertEquals(weekStartFor('2026-09-16'), '2026-09-13'); // a Wednesday → the Sunday before
});

Deno.test('weekStartFor reads the start day: a Monday start puts the week on the Monday on or before the day', () => {
  assertEquals(weekStartFor('2026-09-16', 'mon'), '2026-09-14');
  assertEquals(weekStartFor('2026-09-14', 'mon'), '2026-09-14');
  assertEquals(weekStartFor('2026-09-13', 'mon'), '2026-09-07'); // a Sunday belongs to the week that began the Monday before
  assertEquals(weekStartFor('2026-09-19', 'sat'), '2026-09-19');
});

Deno.test('cook days derive from the period: seven days keeps +0/+3/+5, ten days moves top-up and fresh', () => {
  assertEquals(sessionOffsets(7), { 'cook-sun': 0, 'topup-wed': 3, 'fresh-fri': 5 });
  assertEquals(sessionOffsets(10), { 'cook-sun': 0, 'topup-wed': 4, 'fresh-fri': 7 });
  assertEquals(sessionOffsets(3), { 'cook-sun': 0, 'topup-wed': 1, 'fresh-fri': 2 });
  // A Monday start moves the cook, top-up and fresh days with it: Mon, Thu, Sat.
  assertEquals(sessionDates('2026-09-14'), { 'cook-sun': '2026-09-14', 'topup-wed': '2026-09-17', 'fresh-fri': '2026-09-19' });
  assertEquals(sessionDates('2026-09-14', 10), { 'cook-sun': '2026-09-14', 'topup-wed': '2026-09-18', 'fresh-fri': '2026-09-21' });
});

Deno.test('coverage counts slots across the period and averages per day of it', () => {
  const meal = { id: 'x', planId: 'p', source: 'library' as const, libraryMealId: 'D-001', savedMealId: null, name: 'n', mealType: 'dinner' as const, session: null, servings: 10, servingsLeft: 10, kcal: 700, carbsG: 70, proteinG: 35, fatG: 10, swapsApplied: [], comments: [], position: 0 };
  const week = coverageOf([meal]);
  assertEquals(week.periodDays, 7); assertEquals(week.lunchDinnerSlots, 14); assertEquals(week.perDay.kcal, 1000);
  const ten = coverageOf([meal], null, 10);
  assertEquals(ten.periodDays, 10); assertEquals(ten.lunchDinnerSlots, 20); assertEquals(ten.covered, 10); assertEquals(ten.perDay.kcal, 700);
  assertEquals(coverageOf([meal], 'dinners', 10).lunchDinnerSlots, 10);
});

const confirmed = (weekStart: string, over: object = {}) => ({ id: 'p1', weekStart, status: 'confirmed' as const, batchCooking: true, conversationId: null, brief: null, days: {}, rules: [], meals: [{ id: 'm', planId: 'p1', source: 'library' as const, libraryMealId: 'D-1', savedMealId: null, name: 'n', mealType: 'dinner' as const, session: 'topup-wed' as const, servings: 4, servingsLeft: 4, kcal: null, carbsG: null, proteinG: null, fatG: null, swapsApplied: [], comments: [], position: 0 }], shopping: [], dayNotes: {}, dayNotesStale: false, coverage: coverageOf([]), ...over });

Deno.test('the check-in opener follows the period: a ten-day top-up lands on day four, not Wednesday', () => {
  const current = confirmed('2026-09-14');
  assertEquals(pickOpener({ today: '2026-09-16', current, previous: null }).kind, 'checkin');          // the day before Thu 09-17 (7 days)
  assertEquals(pickOpener({ today: '2026-09-16', current, previous: null, periodDays: 10 }).kind, 'plan'); // top-up is Fri 09-18 over 10 days
  const ten = pickOpener({ today: '2026-09-17', current, previous: null, periodDays: 10 });
  assertEquals(ten.kind, 'checkin'); if (ten.kind === 'checkin') assertEquals(ten.cookDate, '2026-09-18');
});

Deno.test('the debrief waits for the whole period to finish', () => {
  const previous = confirmed('2026-09-07', { id: 'p0' });
  assertEquals(pickOpener({ today: '2026-09-14', current: null, previous }).kind, 'debrief');
  assertEquals(pickOpener({ today: '2026-09-14', current: null, previous, periodDays: 10 }).kind, 'plan');
  assertEquals(pickOpener({ today: '2026-09-17', current: null, previous, periodDays: 10 }).kind, 'debrief');
});

Deno.test('settings seam: a Monday start and ten days put a new plan on the Monday with a ten-day coverage', async () => {
  const v = testCtx({ user_memories: [setting('week_start', 'mon'), setting('period_days', 10)], meal_plans: [], plan_meals: [] });
  assertEquals(await getPlanPeriod(v), { weekStart: 'mon', periodDays: 10 });
  const today = new Date().toISOString().slice(0, 10);
  const plan = await getOrCreatePlan(v);
  assertEquals(plan.weekStart, weekStartFor(today, 'mon'));
  assertEquals(new Date(plan.weekStart + 'T00:00:00Z').getUTCDay(), 1);
  assertEquals(plan.coverage.periodDays, 10);
  assertEquals(plan.coverage.lunchDinnerSlots, 20);
});

Deno.test('settings seam: a stored value outside the contract reads as the default', async () => {
  const v = testCtx({ user_memories: [setting('week_start', 'someday'), setting('period_days', 99)] });
  assertEquals(await getPlanPeriod(v), { weekStart: 'sun', periodDays: 7 });
});
