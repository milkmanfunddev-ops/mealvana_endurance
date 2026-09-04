/** Meal-planning SSOT conformance — EDGE-FUNCTION arm (the Deno twin in supabase/functions/_shared/vana/).
 *
 *  Run by run_edge.sh:  SSOT_VECTORS=<ssot/vectors> VANA_SHARED=<app>/supabase/functions/_shared/vana deno test -A <this file>
 *  Imports the pure modules only (derive-week-character, plan-math, opener, season, grocery, meal-icon); the modules that
 *  import npm:ai (tools, meals, chat) are covered by the prototype arm. Never edit a vector to make a test pass. */
import { assertEquals } from "https://deno.land/std@0.177.1/testing/asserts.ts";

const ROOT = Deno.env.get("SSOT_VECTORS") ?? "";
const SHARED = Deno.env.get("VANA_SHARED") ?? "";
if (!ROOT || !SHARED) throw new Error("SSOT_VECTORS and VANA_SHARED are required");
// deno-lint-ignore no-explicit-any
const load = (rel: string): any => JSON.parse(Deno.readTextFileSync(`${ROOT}/${rel}`));
const mod = (name: string) => import(`file://${SHARED}/${name}.ts`);
const label = (v: { id: string; status: string }) => `${v.id} [${v.status}]`;
const isoOffset = (n: number) => new Date(Date.now() + n * 86400_000).toISOString().slice(0, 10) + "T07:00:00";
// deno-lint-ignore no-explicit-any
const planMeal = (m: any, i: number) => ({ id: `m${i}`, planId: "p", source: "library", libraryMealId: `L-${i}`, savedMealId: null, name: `meal ${i}`, mealType: m.mealType, session: m.session ?? null, servings: m.servings, servingsLeft: m.servings, kcal: m.kcal ?? null, carbsG: m.carbsG ?? null, proteinG: m.proteinG ?? null, fatG: null, swapsApplied: [], comments: [], position: i });
// deno-lint-ignore no-explicit-any
const planOf = (p: any) => p ? { id: `plan-${p.weekStart}`, weekStart: p.weekStart, status: p.status, batchCooking: true, brief: null, rules: [], meals: (p.sessions as string[]).map((s, i) => planMeal({ mealType: "dinner", servings: 1, session: s }, i)), shopping: [], dayNotes: {}, coverage: { lunchDinnerSlots: 14, covered: 0, perDay: { kcal: 0, carbsG: 0, proteinG: 0 } }, checkinDoneAt: p.checkinDoneAt ?? null, debriefDoneAt: p.debriefDoneAt ?? null } : null;

const { deriveWeekCharacter } = await mod("derive-week-character");
const { coverageOf, defaultSession } = await mod("plan-math");
const { pickOpener, pendingDebrief, sessionDates } = await mod("opener");
const { seasonalProduce } = await mod("season");
const { buildItems, parseQty, aggregate, classifyAisle, canonicalName } = await mod("grocery");
const { mealIconFor, resolveMealIcon } = await mod("meal-icon");

for (const v of load("planning/week-character.json").vectors) Deno.test(`vectors: week-character · ${label(v)}`, () => {
  // deno-lint-ignore no-explicit-any
  const acts = v.inputs.activities.map((a: any) => ({ ...a, scheduled_date_time: isoOffset(a.dayOffset) }));
  const w = deriveWeekCharacter(acts, v.inputs.macros);
  assertEquals({ weekCharacter: w.weekCharacter, totalLoad: w.totalLoad, workoutDays: w.workoutDays, restDays: w.restDays, isRaceWeek: w.isRaceWeek, anchorTitle: w.anchor?.title ?? null, avgCarbG: w.avgCarbG }, v.expected);
});
for (const v of load("planning/plan-coverage.json").vectors) Deno.test(`vectors: plan-coverage · ${label(v)}`, () => {
  assertEquals(coverageOf(v.inputs.meals.map(planMeal), v.inputs.scope), v.expected);
});
for (const v of load("planning/cooking-sessions.json").vectors) Deno.test(`vectors: cooking-sessions · ${label(v)}`, () => {
  if (v.fn === "defaultSession") assertEquals(defaultSession(v.inputs.batchCooking, { batch: v.inputs.mealBatch }, v.inputs.existing.map((s: string, i: number) => planMeal({ mealType: "dinner", servings: 1, session: s }, i))), v.expected);
  else if (v.fn === "sessionDates") assertEquals({ ...sessionDates(v.inputs.weekStart) }, v.expected);
  else throw new Error(`unknown fn ${v.fn}`);
});
for (const v of load("planning/opener-selection.json").vectors) Deno.test(`vectors: opener-selection · ${label(v)}`, () => {
  if (v.fn === "pickOpener") {
    const r = pickOpener({ today: v.inputs.today, current: planOf(v.inputs.current), previous: planOf(v.inputs.previous) });
    const got = r.kind === "checkin" ? { kind: "checkin", cookDate: r.cookDate, session: r.session } : r.kind === "debrief" ? { kind: "debrief", planWeekStart: r.plan.weekStart } : { kind: "plan" };
    assertEquals(got, v.expected);
  } else if (v.fn === "pendingDebrief") {
    const r = pendingDebrief({ today: v.inputs.today, previous: planOf(v.inputs.previous) });
    assertEquals(r ? { planWeekStart: r.weekStart } : null, v.expected);
  } else throw new Error(`unknown fn ${v.fn}`);
});
for (const v of load("planning/season.json").vectors) Deno.test(`vectors: season · ${label(v)}`, () => { assertEquals(seasonalProduce(v.inputs.iso), v.expected); });
for (const v of load("planning/shopping-list.json").vectors) Deno.test(`vectors: shopping-list · ${label(v)}`, () => {
  switch (v.fn) {
    // deno-lint-ignore no-explicit-any
    case "buildItems": assertEquals(buildItems(v.inputs.meals, new Set(v.inputs.have)).map((i: any) => ({ aisle: i.aisle, name: i.name, qty: i.qty, have: i.have, fromMealIds: i.fromMealIds })), v.expected); break;
    case "parseQty": assertEquals(parseQty(v.inputs), v.expected); break;
    case "aggregate": assertEquals(aggregate(v.inputs), v.expected); break;
    case "classifyAisle": assertEquals(classifyAisle(v.inputs), v.expected); break;
    case "canonicalName": assertEquals(canonicalName(v.inputs), v.expected); break;
    default: throw new Error(`unknown fn ${v.fn}`);
  }
});
for (const v of load("planning/meal-icon.json").vectors) Deno.test(`vectors: meal-icon · ${label(v)}`, () => {
  const { stored, ...input } = v.inputs;
  assertEquals(stored !== undefined ? resolveMealIcon(stored, input) : mealIconFor(input), v.expected);
});
