/** Pure plan arithmetic — no DB, no AI SDK imports — so it can be unit-tested with the runner's local flags.
 *  Coverage, the walk and the servings a batch needs are computed here, never by the model (mp-231). Re-exported by plan.ts. */
import type { MealPlan, MealType, PlanMeal, Session } from './contracts.ts';

/** Every meal type a walk may visit, in the order a plan is usually built. The athlete's own order wins (walkFor). */
export const WALK_TYPES: readonly MealType[] = ['dinner', 'lunch', 'breakfast', 'snack'];
export const isMealType = (x: unknown): x is MealType => typeof x === 'string' && (WALK_TYPES as readonly string[]).includes(x);

/** A batch is "a few meals at one sitting" (mp-231 clause 3), and a period has three cooking sessions, so a batch is three
 *  meals per type and the servings scale to cover the days (servingsToCover). */
export const BATCH_MEALS_PER_TYPE = 3;

/** The meal types this athlete plans, in the order they chose (mp-231 clause 1: the order is not fixed and any type may be
 *  skipped). `mealTypes` = the `meal_types` setting; when it was never chosen the coverage scope stands in — dinners only, else
 *  dinners and lunches, which is what coverage counted before the setting existed. Duplicates and unknown values are dropped. */
export function walkFor(mealTypes?: readonly string[] | null, scope: string | null = null): MealType[] {
  const out: MealType[] = [];
  for (const t of mealTypes ?? []) if (isMealType(t) && !out.includes(t)) out.push(t);
  if (out.length) return out;
  return scope === 'dinners' ? ['dinner'] : ['dinner', 'lunch'];
}

/** How many servings one meal of a batch needs for the batch to cover the period (mp-231 clause 3): a period's days split over
 *  the meals cooked at one sitting, rounded up, so ten days over three meals is four servings each. Per-day cooking is one
 *  serving — the meal is made the night of and eaten that night (mp-232 clause 1). */
export function servingsToCover(periodDays = 7, batchCooking = true, mealsInBatch = BATCH_MEALS_PER_TYPE): number {
  if (!batchCooking) return 1;
  const n = Math.ceil(Math.max(1, periodDays) / Math.max(1, mealsInBatch));
  return Math.max(1, Math.min(12, n));
}

/** A meal has its numbers when kcal, carbs, protein and fat are all there (`null` is not `0`: 0 g fat is a number). A plan
 *  never picks a meal without them (Lee's ruling on mp-678, testing-wave 61): it stays browsable, but plan build, the
 *  picker, Browse's add, swap and same-as-last-time all pass it by, so a gap in the library never reaches a plan. */
export function hasNutritionNumbers(m: { kcal: number | null; carbsG: number | null; proteinG: number | null; fatG: number | null }): boolean {
  return m.kcal != null && m.carbsG != null && m.proteinG != null && m.fatG != null;
}

/** `batchCooking` = the plan's mode. `mealTypes` = the athlete's chosen walk, when they have one. */
export interface CoverageOpts { batchCooking?: boolean; mealTypes?: readonly string[] | null }

/** How much of the cooking period the plan covers (mp-231 clauses 2–4).
 *
 *  The denominator is one slot per day of the period for each type the athlete plans (`walkFor`): the `period_days` setting
 *  (mp-269) times the walk's length, so a ten-day period of dinners and lunches is 20, never a fixed 14. The numerator follows
 *  the mode — a batch is cooked once and eaten across the days, so its SERVINGS fill the slots; an athlete who cooks the night
 *  of fills one night per meal, so the MEALS are counted instead. Types outside the walk still weigh on `perDay`, which averages
 *  every meal over the period. `lunchDinnerSlots` keeps its wire name from the seven-day week it was born in.
 *  The Dart local-first recompute (PlanCoverageService) reads `mealTypes` and the plan's `batchCooking` back — keep in lockstep. */
export function coverageOf(meals: PlanMeal[], scope: string | null = null, periodDays = 7, opts: CoverageOpts = {}): MealPlan['coverage'] {
  const batchCooking = opts.batchCooking !== false;
  const counted = walkFor(opts.mealTypes, scope);
  const slots = periodDays * counted.length;
  const inWalk = meals.filter((m) => counted.includes(m.mealType));
  const filled = batchCooking ? inWalk.reduce((s, m) => s + m.servings, 0) : inWalk.length;
  const tot = meals.reduce((a, m) => ({ kcal: a.kcal + (m.kcal ?? 0) * m.servings, c: a.c + (m.carbsG ?? 0) * m.servings, p: a.p + (m.proteinG ?? 0) * m.servings }), { kcal: 0, c: 0, p: 0 });
  return { lunchDinnerSlots: slots, covered: Math.min(slots, filled), periodDays, mealTypes: counted, perDay: { kcal: Math.round(tot.kcal / periodDays), carbsG: Math.round(tot.c / periodDays), proteinG: Math.round(tot.p / periodDays) } };
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
