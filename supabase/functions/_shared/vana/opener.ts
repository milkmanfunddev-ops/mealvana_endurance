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

// ---- The opener's question (Lee, 2026-09-16: every "New meal plan" and every + opened on the same "What sounds good for
// dinners this week?" with the same four chips, because the prompt named that question and those labels as its example and the
// model copied them). The server now hands the model one ANGLE per opener — the question to ask and the shape of its options —
// chosen at random from these and never the angle the athlete's last opener used, so two openers in a row never ask the same
// thing. The labels here are shapes, not chips: the prompt tells the model to write its own, specific to the week.
export interface OpenerAngle { key: string; ask: string; shape: string }
export const OPENER_ANGLES: readonly OpenerAngle[] = [
  { key: 'dinners', ask: 'what they want dinners to be like this week', shape: 'a cooking style each: batch staples, quick weeknights, something new, use what is in the kitchen' },
  { key: 'rhythm', ask: 'how much cooking is realistic this week', shape: 'an amount of cooking each: one big cook, two short cooks, cook most nights, mostly assemble' },
  { key: 'fuel_day', ask: 'which session or day they want the plan built around', shape: 'a named day or session from the WEEK line each, e.g. "Saturday long ride", "Tuesday intervals", plus "spread it evenly"' },
  { key: 'craving', ask: 'what they are craving', shape: 'a flavour or mood each: warm and hearty, fresh and light, spicy, comfort classics' },
  { key: 'constraints', ask: 'what the week has to work around', shape: 'a real-life constraint each: eating out once, guests, a travel day, plus "nothing, plan it all"' },
  { key: 'last_time', ask: 'whether to build on last time or change it up', shape: 'a distance from last time each: same as last time, half new, all new — only when the CONTEXT shows a LAST WEEK plan or LIKES; otherwise pick another angle' },
  { key: 'one_meal', ask: 'one meal they already know they want in', shape: 'a dish from their LIKES or saved meals each, plus "surprise me"' },
] as const;

/** One angle at random, never one in `exclude` (the athlete's last openers). With everything excluded, anything goes. */
export function pickAngle(exclude: readonly string[] = [], random: () => number = Math.random): OpenerAngle {
  const pool = OPENER_ANGLES.filter((a) => !exclude.includes(a.key));
  const from = pool.length ? pool : OPENER_ANGLES;
  return from[Math.min(from.length - 1, Math.floor(random() * from.length))];
}

/** The line appended to a plan opener's instruction. */
export const angleLine = (a: OpenerAngle) => `\n[ANGLE for the askChoice: ask ${a.ask}. Options: 3–4 short label-only chips, ${a.shape}. Write the question and the labels in your own words for THIS athlete and week — never the words in this instruction. The question is asked ONCE, by askChoice: the prose before it must not contain the question or any version of it.]`;
