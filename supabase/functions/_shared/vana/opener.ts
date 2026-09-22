/** Which opener a new planning conversation gets (plan Phase 3 — the relationship loop). Pure: no DB, no AI SDK, so it is
 *  unit-tested with the local runner flags. chat.ts loads the inputs and applies the result. */
import type { MealPlan } from './contracts.ts';
import { addDays } from './env.ts';
import { sessionOffsets } from './plan-math.ts';

export type OpenerVariant = { kind: 'plan' } | { kind: 'checkin'; plan: MealPlan; cookDate: string; session: string } | { kind: 'debrief'; plan: MealPlan };
/** Cook dates for a plan's sessions: the week starts on the athlete's start day (env.weekStartFor) and each session sits at its
 *  offset into the period (plan-math.sessionOffsets) — seven days gives +0 / +3 / +5. */
export const sessionDates = (weekStart: string, periodDays = 7) => { const o = sessionOffsets(periodDays); return { 'cook-sun': addDays(weekStart, o['cook-sun']), 'topup-wed': addDays(weekStart, o['topup-wed']), 'fresh-fri': addDays(weekStart, o['fresh-fri']) } as const; };
/** Pure: which opener a new planning conversation gets. Debrief wins (a finished period nobody debriefed, ≤14 days old), then the
 *  check-in (this week's confirmed plan has a cook session today/tomorrow and no check-in yet), else the normal plan opener.
 *  `periodDays` = the period_days setting (7 when omitted).
 *  `newPlan` = the athlete tapped "New meal plan" (chat.ts ChatBody.new_plan): they asked for a fresh plan, so the plan opener
 *  wins outright — a check-in or a debrief would be about the plan they just chose to leave behind (Lee, 2026-09-16). The
 *  check-in stays unstamped, so a later plain open can still ask it. */
export function pickOpener(input: { today: string; current: (MealPlan & { checkinDoneAt?: string | null }) | null; previous: (MealPlan & { debriefDoneAt?: string | null }) | null; periodDays?: number; newPlan?: boolean }): OpenerVariant {
  if (input.newPlan) return { kind: 'plan' };
  const { today: t, current, previous } = input; const days = input.periodDays ?? 7;
  if (previous && previous.status === 'confirmed' && previous.meals.length && !previous.debriefDoneAt && addDays(previous.weekStart, days) <= t && addDays(previous.weekStart, days + 14) > t) return { kind: 'debrief', plan: previous };
  if (current && current.status === 'confirmed' && current.meals.length && !current.checkinDoneAt) {
    const dates = sessionDates(current.weekStart, days);
    const upcoming = (['cook-sun', 'topup-wed', 'fresh-fri'] as const).filter((s) => current.meals.some((m) => m.session === s)).map((s) => ({ session: s, date: dates[s] })).filter((x) => x.date === t || x.date === addDays(t, 1)).sort((a, b) => a.date.localeCompare(b.date))[0];
    if (upcoming) return { kind: 'checkin', plan: current, cookDate: upcoming.date, session: upcoming.session };
  }
  return { kind: 'plan' };
}

/** The id prefix of the opener's hidden first message when a stored conversation is read back (chat.ts
 *  conversationMessages): it is not a row, it is the opener row's `metadata.opener_prompt` put back in front of it so
 *  the replay is the bytes first sent (mp-420 clause 5). The summariser skips it by this prefix. */
export const OPENER_REPLAY_ID_PREFIX = 'opener:';

/** The Situation a "New meal plan" opener carries in place of the screen's. The athlete tapped the button on the Plan tab, so
 *  the screen's own sentence says "the week of … is confirmed" and its DAY PLAN section lists that plan's meals — the very plan
 *  the opener must not raise. Ids the client sent are dropped for that one turn; later turns resolve the screen as usual. */
export const NEW_PLAN_SITUATION = 'starting a new meal plan they chose from the Plan tab';

/** The plan a debrief would record against: the previous period's confirmed, undebriefed plan (same rule as pickOpener, without the age cap
 *  so an in-progress debrief conversation can still land it). */
export function pendingDebrief(input: { today: string; previous: (MealPlan & { debriefDoneAt?: string | null }) | null; periodDays?: number }): MealPlan | null {
  const p = input.previous;
  return p && p.status === 'confirmed' && p.meals.length && !p.debriefDoneAt && addDays(p.weekStart, input.periodDays ?? 7) <= input.today ? p : null;
}
