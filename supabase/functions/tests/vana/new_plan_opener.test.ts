/**
 * "New meal plan" from the Plan tab (Lee, 2026-09-16). The button opens a fresh planning conversation while the week may
 * already hold a confirmed plan. Without an intent the opener could be that plan's check-in or last week's debrief, and the
 * screen's Situation ("looking at the Plan tab; the week of … is confirmed", plus its DAY PLAN meals) rode on the opener
 * message — so Vana opened with "I can see you've got this week's plan already confirmed … are you here to log a meal, swap
 * something, or adjust the week ahead?". With `new_plan: true` on the opener request: the plan opener wins outright, the
 * opener text forbids raising the old plan, and the Situation is the fixed NEW_PLAN_SITUATION line. Nothing here calls a model.
 */
import { assert, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { NEW_PLAN_SITUATION, pickOpener } from '../../_shared/vana/opener.ts';
import { NEW_PLAN_OPENER, OPENERS } from '../../_shared/vana/persona.ts';
import { withSituation } from '../../_shared/vana/chat.ts';
import type { MealPlan } from '../../_shared/vana/contracts.ts';

/** A confirmed week with a top-up cook (+3 into the period) and no check-in yet. */
const confirmed = (weekStart: string, extra: Record<string, unknown> = {}): MealPlan & { checkinDoneAt?: string | null; debriefDoneAt?: string | null } =>
  ({
    id: `plan-${weekStart}`, weekStart, status: 'confirmed', batchCooking: true, conversationId: null, brief: null, rules: [], shopping: [], dayNotes: {},
    coverage: { lunchDinnerSlots: 14, covered: 6, periodDays: 7, perDay: { kcal: 0, carbsG: 0, proteinG: 0 } },
    meals: [
      { id: 'pm-1', planId: `plan-${weekStart}`, source: 'library', libraryMealId: 'lib-1', savedMealId: null, name: 'Turkey chili', mealType: 'dinner', session: 'cook-sun', servings: 3, servingsLeft: 3, kcal: null, carbsG: null, proteinG: null, fatG: null, swapsApplied: [], comments: [], position: 0 },
      { id: 'pm-2', planId: `plan-${weekStart}`, source: 'library', libraryMealId: 'lib-2', savedMealId: null, name: 'Salmon rice bowl', mealType: 'dinner', session: 'topup-wed', servings: 3, servingsLeft: 3, kcal: null, carbsG: null, proteinG: null, fatG: null, swapsApplied: [], comments: [], position: 1 },
    ],
    checkinDoneAt: null, debriefDoneAt: null, ...extra,
  }) as unknown as MealPlan & { checkinDoneAt?: string | null; debriefDoneAt?: string | null };

Deno.test('a confirmed plan with a cook tomorrow still gets the check-in on a plain open', () => {
  // Week of Sunday 09-13; the top-up cook is Wednesday 09-16; today is Tuesday.
  const v = pickOpener({ today: '2026-09-15', current: confirmed('2026-09-13'), previous: null });
  assertEquals(v.kind, 'checkin');
});

Deno.test('new_plan: the plan opener wins over the check-in', () => {
  const v = pickOpener({ today: '2026-09-15', current: confirmed('2026-09-13'), previous: null, newPlan: true });
  assertEquals(v, { kind: 'plan' });
});

Deno.test('new_plan: the plan opener wins over a pending debrief', () => {
  const previous = confirmed('2026-09-06');
  assertEquals(pickOpener({ today: '2026-09-15', current: null, previous }).kind, 'debrief');
  assertEquals(pickOpener({ today: '2026-09-15', current: null, previous, newPlan: true }), { kind: 'plan' });
});

Deno.test('the new-plan opener is the plan opener with the old plan ruled out of the first message', () => {
  assertStringIncludes(NEW_PLAN_OPENER, OPENERS.meal_planning);
  assertStringIncludes(NEW_PLAN_OPENER, 'do NOT mention the existing plan');
  assertStringIncludes(NEW_PLAN_OPENER, 'do NOT ask whether they meant to log a meal, swap something or adjust it');
  assertStringIncludes(NEW_PLAN_OPENER, 'do NOT open a check-in or a debrief');
  // Nothing about the old plan's contents travels: the instruction is fixed text, never built from the plan row (no id, no
  // week, no meal list — compare checkinOpener / debriefOpener, which carry all three).
  const rule = NEW_PLAN_OPENER.replace(OPENERS.meal_planning, '');
  assert(!/\(id |week of|×\d/.test(rule), rule);
});

Deno.test('the new-plan situation names the choice, not the plan on screen', () => {
  const [m] = withSituation([{ role: 'user', content: NEW_PLAN_OPENER }], NEW_PLAN_SITUATION, null);
  const text = String(m.content);
  assertStringIncludes(text, `[SITUATION right now they are ${NEW_PLAN_SITUATION}]`);
  assert(!text.includes('DAY PLAN'), 'no in-view section on a new-plan opener');
  // situation.ts's Plan tab sentence is "looking at the Plan tab…; the week of <date> is confirmed" — it must not be the one carried.
  assert(!/looking at the Plan tab|; the week of/.test(text), 'the screen sentence about the confirmed week is not carried');
});

// ---- the intent outlives the opener (Lee, 2026-09-16, second sighting: one turn in, Vana pointed him back at the old plan)
import { conversationIsNewPlan } from '../../_shared/vana/chat.ts';
import { NEW_PLAN_STANDING } from '../../_shared/vana/persona.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

Deno.test('a conversation whose opener row carries new_plan is a new-plan conversation on every later turn', async () => {
  const v = testCtx({
    vana_messages: [
      { id: 'o1', conversation_id: 'conv-fresh', user_id: TEST_USER_ID, role: 'assistant', content: 'Fresh start.', metadata: { opener: true, new_plan: true } },
      { id: 'o2', conversation_id: 'conv-plain', user_id: TEST_USER_ID, role: 'assistant', content: 'Check-in.', metadata: { opener: true } },
    ],
  } as never);
  assertEquals(await conversationIsNewPlan(v, 'conv-fresh'), true);
  assertEquals(await conversationIsNewPlan(v, 'conv-plain'), false);
  assertEquals(await conversationIsNewPlan(v, 'conv-none'), false);
});

Deno.test('the standing rule tells the model, every turn, that the old plan is being replaced', () => {
  for (const phrase of ['FRESH plan', 'being replaced', 'Never tell them they are set', 'never suggest eating from the old plan']) assertStringIncludes(NEW_PLAN_STANDING, phrase);
});
