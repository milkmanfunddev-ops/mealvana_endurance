/** Which opener a new planning conversation gets (plan Phase 3 — the relationship loop). Pure: no DB, no AI SDK, so it is
 *  unit-tested with the local runner flags. chat.ts loads the inputs and applies the result. */
import type { MealPlan } from './contracts.ts';
import { addDays } from './env.ts';

export type OpenerVariant = { kind: 'plan' } | { kind: 'checkin'; plan: MealPlan; cookDate: string; session: string } | { kind: 'debrief'; plan: MealPlan };
/** Cook dates for a plan's sessions: the week starts on Sunday (env.weekStartFor) — cook-sun = weekStart, topup-wed = +3, fresh-fri = +5. */
export const sessionDates = (weekStart: string) => ({ 'cook-sun': weekStart, 'topup-wed': addDays(weekStart, 3), 'fresh-fri': addDays(weekStart, 5) } as const);
/** Pure: which opener a new planning conversation gets. Debrief wins (a finished week nobody debriefed, ≤14 days old), then the
 *  check-in (this week's confirmed plan has a cook session today/tomorrow and no check-in yet), else the normal plan opener. */
export function pickOpener(input: { today: string; current: (MealPlan & { checkinDoneAt?: string | null }) | null; previous: (MealPlan & { debriefDoneAt?: string | null }) | null }): OpenerVariant {
  const { today: t, current, previous } = input;
  if (previous && previous.status === 'confirmed' && previous.meals.length && !previous.debriefDoneAt && addDays(previous.weekStart, 7) <= t && addDays(previous.weekStart, 21) > t) return { kind: 'debrief', plan: previous };
  if (current && current.status === 'confirmed' && current.meals.length && !current.checkinDoneAt) {
    const dates = sessionDates(current.weekStart);
    const upcoming = (['cook-sun', 'topup-wed', 'fresh-fri'] as const).filter((s) => current.meals.some((m) => m.session === s)).map((s) => ({ session: s, date: dates[s] })).filter((x) => x.date === t || x.date === addDays(t, 1)).sort((a, b) => a.date.localeCompare(b.date))[0];
    if (upcoming) return { kind: 'checkin', plan: current, cookDate: upcoming.date, session: upcoming.session };
  }
  return { kind: 'plan' };
}

/** The plan a debrief would record against: last week's confirmed, undebriefed plan (same rule as pickOpener, without the age cap
 *  so an in-progress debrief conversation can still land it). */
export function pendingDebrief(input: { today: string; previous: (MealPlan & { debriefDoneAt?: string | null }) | null }): MealPlan | null {
  const p = input.previous;
  return p && p.status === 'confirmed' && p.meals.length && !p.debriefDoneAt && addDays(p.weekStart, 7) <= input.today ? p : null;
}
