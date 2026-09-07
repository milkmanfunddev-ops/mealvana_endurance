/** Pure plan arithmetic — no DB, no AI SDK imports — so it can be unit-tested with the runner's local flags.
 *  Coverage and sessions are computed here, never by the model. Re-exported by plan.ts. */
import type { MealPlan, PlanMeal, Session } from './contracts.ts';

/** `scope` = the athlete's coverage_scope setting: 'dinners' counts 7 dinner slots; anything else (incl. never chosen)
 *  counts the 14 lunch+dinner slots. Breakfast/snacks are never slots — 'all' widens what the persona offers, not the denominator.
 *  The Dart local-first recompute (PlanCoverageService) reads the mode back from `lunchDinnerSlots` (7 vs 14) — keep in lockstep. */
export function coverageOf(meals: PlanMeal[], scope: string | null = null): MealPlan['coverage'] {
  const dinnersOnly = scope === 'dinners';
  const slots = dinnersOnly ? 7 : 14;
  const ld = meals.filter((m) => m.mealType === 'dinner' || (!dinnersOnly && m.mealType === 'lunch'));
  const servings = ld.reduce((s, m) => s + m.servings, 0);
  const tot = meals.reduce((a, m) => ({ kcal: a.kcal + (m.kcal ?? 0) * m.servings, c: a.c + (m.carbsG ?? 0) * m.servings, p: a.p + (m.proteinG ?? 0) * m.servings }), { kcal: 0, c: 0, p: 0 });
  return { lunchDinnerSlots: slots, covered: Math.min(slots, servings), perDay: { kcal: Math.round(tot.kcal / 7), carbsG: Math.round(tot.c / 7), proteinG: Math.round(tot.p / 7) } };
}

/** Default session for a meal given batch-cooking on. Library meals with batch=true cook Sunday; a second batch meal added later tops up Wednesday; non-batch meals are made fresh Friday. */
export function defaultSession(batchCooking: boolean, meal: { batch: boolean }, existing: PlanMeal[]): Session {
  if (!batchCooking) return null;
  if (!meal.batch) return 'fresh-fri';
  const sundayCount = existing.filter((m) => m.session === 'cook-sun').length;
  return sundayCount >= 2 ? 'topup-wed' : 'cook-sun';
}
