// @vitest-environment node
/** Meal-planning SSOT conformance — PROTOTYPE arm.
 *
 *  Lives in docs/new_mealplanning/ssot/conformance/; copied into <prototype>/packages/web/tests/ by
 *  run_prototype.sh and run with SSOT_VECTORS=<abs path to ssot/vectors>. Feeds every executable
 *  vector to the prototype's REAL functions and diffs actual vs expected. Never edits a vector to
 *  make a test pass — red means raise (DEVIATIONS.md / OPEN-QUESTIONS.md).
 *
 *  Arms here: week-character · plan-coverage (scope vectors are EXPECTED-RED on this twin, D-11) ·
 *  cooking-sessions (defaultSession only — no sessionDates here, D-12) · shopping-list · meal-icon ·
 *  week-contexts · attribution-short · clamp-sentences. */
import { describe, it, expect } from "vitest";
import fs from "node:fs";
import path from "node:path";
import { deriveWeekCharacter } from "@/lib/derive-week-character";
import { mealIconFor, resolveMealIcon } from "@/lib/vana/meal-icon";
import { buildItems, parseQty, aggregate, classifyAisle, canonicalName } from "@/server/vana/grocery";
import { coverageOf, defaultSession } from "@/server/vana/plan";
import { attributionShort } from "@/server/vana/meals";
import { clampSentences } from "@/server/vana/chat";
import { weekContexts } from "@/server/vana/tools";

const ROOT = process.env.SSOT_VECTORS ?? "";
if (!ROOT) throw new Error("SSOT_VECTORS must point at docs/new_mealplanning/ssot/vectors");
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const load = (rel: string): any => JSON.parse(fs.readFileSync(path.join(ROOT, rel), "utf8"));
const label = (v: { id: string; status: string }) => `${v.id} [${v.status}]`;
const isoOffset = (n: number) => new Date(Date.now() + n * 86400_000).toISOString().slice(0, 10) + "T07:00:00";
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const planMeal = (m: any, i: number) => ({ id: `m${i}`, planId: "p", source: "library" as const, libraryMealId: `L-${i}`, savedMealId: null, name: `meal ${i}`, mealType: m.mealType, session: m.session ?? null, servings: m.servings, servingsLeft: m.servings, kcal: m.kcal ?? null, carbsG: m.carbsG ?? null, proteinG: m.proteinG ?? null, fatG: null, swapsApplied: [], comments: [], position: i });

describe("ssot vectors: week-character", () => {
  const f = load("planning/week-character.json");
  for (const v of f.vectors) it(label(v), () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const acts = v.inputs.activities.map((a: any) => ({ ...a, scheduled_date_time: isoOffset(a.dayOffset) }));
    const w = deriveWeekCharacter(acts, v.inputs.macros);
    expect({ weekCharacter: w.weekCharacter, totalLoad: w.totalLoad, workoutDays: w.workoutDays, restDays: w.restDays, isRaceWeek: w.isRaceWeek, anchorTitle: w.anchor?.title ?? null, avgCarbG: w.avgCarbG }).toEqual(v.expected);
  });
});

describe("ssot vectors: plan-coverage", () => {
  const f = load("planning/plan-coverage.json");
  for (const v of f.vectors) it(label(v) + (v.inputs.scope === "dinners" ? " — EXPECTED-RED on the prototype (D-11: no scope arg)" : ""), () => {
    // The prototype's coverageOf takes no scope; the extra argument is ignored (that IS the deviation being pinned).
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const c = (coverageOf as any)(v.inputs.meals.map(planMeal), v.inputs.scope);
    expect(c).toEqual(v.expected);
  });
});

describe("ssot vectors: cooking-sessions", () => {
  const f = load("planning/cooking-sessions.json");
  for (const v of f.vectors) {
    if (v.fn !== "defaultSession") { it.skip(label(v) + " — edge-only (sessionDates has no prototype twin, D-12)", () => {}); continue; }
    it(label(v), () => {
      const existing = v.inputs.existing.map((s: string, i: number) => planMeal({ mealType: "dinner", servings: 1, session: s }, i));
      expect(defaultSession(v.inputs.batchCooking, { batch: v.inputs.mealBatch }, existing)).toBe(v.expected);
    });
  }
});

describe("ssot vectors: shopping-list", () => {
  const f = load("planning/shopping-list.json");
  for (const v of f.vectors) it(label(v), () => {
    switch (v.fn) {
      case "buildItems": {
        const items = buildItems(v.inputs.meals, new Set(v.inputs.have)).map((i) => ({ aisle: i.aisle, name: i.name, qty: i.qty, have: i.have, fromMealIds: i.fromMealIds }));
        expect(items).toEqual(v.expected);
        expect(buildItems(v.inputs.meals, new Set(v.inputs.have)).every((i) => i.checked === false)).toBe(true);
        break;
      }
      case "parseQty": expect(parseQty(v.inputs)).toEqual(v.expected); break;
      case "aggregate": expect(aggregate(v.inputs)).toBe(v.expected); break;
      case "classifyAisle": expect(classifyAisle(v.inputs)).toBe(v.expected); break;
      case "canonicalName": expect(canonicalName(v.inputs)).toBe(v.expected); break;
      default: throw new Error(`unknown fn ${v.fn}`);
    }
  });
});

describe("ssot vectors: meal-icon", () => {
  const f = load("planning/meal-icon.json");
  for (const v of f.vectors) it(label(v), () => {
    const { stored, ...input } = v.inputs;
    expect(stored !== undefined ? resolveMealIcon(stored, input) : mealIconFor(input)).toBe(v.expected);
  });
});

describe("ssot vectors: week-contexts", () => {
  const f = load("selection/week-contexts.json");
  for (const v of f.vectors) it(label(v), () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const ctx: any = { race: v.inputs.race ? { name: "r", date: "2026-01-01", daysOut: v.inputs.race.daysOut, location: null } : null, week: { start: "2026-01-01", character: v.inputs.character, anchor: null, loadScore: 0, workouts: [] } };
    expect(weekContexts(ctx)).toEqual(v.expected);
  });
});

describe("ssot vectors: attribution-short", () => {
  const f = load("selection/attribution-short.json");
  for (const v of f.vectors) it(label(v), () => { expect(attributionShort(v.inputs)).toBe(v.expected); });
});

describe("ssot vectors: clamp-sentences", () => {
  const f = load("agent/clamp-sentences.json");
  for (const v of f.vectors) it(label(v), () => { expect(clampSentences(v.inputs.text, v.inputs.n)).toBe(v.expected); });
});
