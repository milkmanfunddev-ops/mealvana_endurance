/** Pure plan arithmetic — no DB, no AI SDK imports — so it can be unit-tested with the runner's local flags.
 *  Coverage and sessions are computed here, never by the model. Re-exported by plan.ts. */
import type { MealPlan, PlanMeal, Session } from './contracts.ts';

/** `scope` = the athlete's coverage_scope setting: 'dinners' counts one dinner slot per day of the period; anything else (incl.
 *  never chosen) counts a lunch and a dinner per day. `periodDays` = the period_days setting (mp-269, 7 by default → 7 / 14 slots).
 *  Breakfast/snacks are never slots — 'all' widens what the persona offers, not the denominator. perDay averages over the period.
 *  The Dart local-first recompute (PlanCoverageService) reads the mode back from `lunchDinnerSlots` vs `periodDays` — keep in lockstep. */
export function coverageOf(meals: PlanMeal[], scope: string | null = null, periodDays = 7): MealPlan['coverage'] {
  const dinnersOnly = scope === 'dinners';
  const slots = dinnersOnly ? periodDays : periodDays * 2;
  const ld = meals.filter((m) => m.mealType === 'dinner' || (!dinnersOnly && m.mealType === 'lunch'));
  const servings = ld.reduce((s, m) => s + m.servings, 0);
  const tot = meals.reduce((a, m) => ({ kcal: a.kcal + (m.kcal ?? 0) * m.servings, c: a.c + (m.carbsG ?? 0) * m.servings, p: a.p + (m.proteinG ?? 0) * m.servings }), { kcal: 0, c: 0, p: 0 });
  return { lunchDinnerSlots: slots, covered: Math.min(slots, servings), periodDays, perDay: { kcal: Math.round(tot.kcal / periodDays), carbsG: Math.round(tot.c / periodDays), proteinG: Math.round(tot.p / periodDays) } };
}

/** Days after the period start each cooking session falls on (mp-269: cook days derive from the settings, not fixed offsets).
 *  The session names are wire roles kept from the Sunday week: cook = the first day, top-up = 3/7 of the way in, fresh = 5/7,
 *  so seven days keeps +0/+3/+5 and ten days gives +0/+4/+7. Each stays inside the period. Dart port: `sessionOffsets` in
 *  domain/week_start.dart. */
export function sessionOffsets(periodDays = 7): Record<Exclude<Session, null>, number> {
  const inside = (n: number) => Math.max(0, Math.min(periodDays - 1, n));
  return { 'cook-sun': 0, 'topup-wed': inside(Math.round((periodDays * 3) / 7)), 'fresh-fri': inside(Math.round((periodDays * 5) / 7)) };
}

/** Default session for a meal given batch-cooking on. Library meals with batch=true go to the period's cook day; a third batch meal tops up (sessionOffsets); non-batch meals are made fresh. */
export function defaultSession(batchCooking: boolean, meal: { batch: boolean }, existing: PlanMeal[]): Session {
  if (!batchCooking) return null;
  if (!meal.batch) return 'fresh-fri';
  const sundayCount = existing.filter((m) => m.session === 'cook-sun').length;
  return sundayCount >= 2 ? 'topup-wed' : 'cook-sun';
}
