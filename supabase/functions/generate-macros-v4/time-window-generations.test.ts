/**
 * Catalog-generation guard for `pre_workout_templates.time_window` matching.
 *
 * The window labels moved with the 120-minute ruling (D-017): dev's catalog
 * was bulk-migrated on 2026-08-05 to `2-4 hours` / `30-120 min`, while prod
 * still carries `1.5-3 hours` / `30-90 min`. The SAME function code deploys
 * to both projects, so matching only one generation of strings zeroes out the
 * meal and snack slots on the other catalog. That is exactly what shipped to
 * dev on 2026-08-05: every athlete's before-phase collapsed to the top-off
 * slot's ceiling — a flat 50 g regardless of body weight — while 80/80
 * fixture-based tests stayed green, because every fixture used the old
 * strings.
 *
 * These tests run the real selection entry points against a catalog of EACH
 * generation and assert the meal/snack slots actually engage. If someone
 * "cleans up" timeWindowToPhase back to a single generation, one of the two
 * catalogs goes dark and this file says which.
 */

import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  getEligibleTemplates,
  templatePhase,
  timeWindowToPhase,
} from "./pre-workout.ts";
import type { PreWorkoutTemplate } from "./types.ts";

// ---------------------------------------------------------------------------
// The classifier itself
// ---------------------------------------------------------------------------

Deno.test("timeWindowToPhase accepts both generations of every window", () => {
  // Current generation (dev catalog, post 2026-08-05 migration).
  assertEquals(timeWindowToPhase("2-4 hours"), "meal");
  assertEquals(timeWindowToPhase("30-120 min"), "snack");
  // Previous generation (prod catalog).
  assertEquals(timeWindowToPhase("1.5-3 hours"), "meal");
  assertEquals(timeWindowToPhase("30-90 min"), "snack");
  // Unchanged across generations.
  assertEquals(timeWindowToPhase("< 30 min"), "top_up");
});

Deno.test("timeWindowToPhase returns null for unknown windows, never a guess", () => {
  assertEquals(timeWindowToPhase("2-4 hrs"), null);
  assertEquals(timeWindowToPhase("30–120 min"), null); // en-dash, not hyphen
  assertEquals(timeWindowToPhase(""), null);
});

// ---------------------------------------------------------------------------
// The selection path, per catalog generation
// ---------------------------------------------------------------------------

function template(
  name: string,
  timeWindow: string,
): PreWorkoutTemplate {
  return {
    id: `tpl-${name}`,
    name,
    time_window: timeWindow,
    template_type: "food",
    digestion_speed: "medium",
    carbs_per_serving: 30,
    protein_per_serving: 5,
    fat_per_serving: 2,
    sodium_mg: 100,
    fluid_ml: 0,
    serving_unit: "serving",
    min_servings: 1,
    max_servings: 4,
    allergens: [],
    excluded_diets: [],
  } as unknown as PreWorkoutTemplate;
}

/** One meal + one snack + one top-off template in the given generation. */
function catalog(gen: "old" | "new"): PreWorkoutTemplate[] {
  const meal = gen === "new" ? "2-4 hours" : "1.5-3 hours";
  const snack = gen === "new" ? "30-120 min" : "30-90 min";
  return [
    template("oatmeal", meal),
    template("toast", snack),
    template("gel", "< 30 min"),
  ];
}

for (const gen of ["old", "new"] as const) {
  Deno.test(`getEligibleTemplates fills every slot on a ${gen}-generation catalog`, () => {
    const templates = catalog(gen);
    const meal = getEligibleTemplates(templates, "meal", "none");
    const snack = getEligibleTemplates(templates, "snack", "none");
    const topUp = getEligibleTemplates(templates, "top_up", "none");

    assertEquals(meal.map((t) => t.name), ["oatmeal"]);
    assertEquals(snack.map((t) => t.name), ["toast"]);
    assertEquals(topUp.map((t) => t.name), ["gel"]);
  });
}

Deno.test("a MIXED catalog (mid-migration) still fills every slot", () => {
  // The realistic worst case: a migration ran on some rows and not others,
  // or old rows were re-seeded next to new ones. Both spellings of the same
  // window must land in the same slot rather than splitting or vanishing.
  const templates = [...catalog("old"), ...catalog("new")];
  const meal = getEligibleTemplates(templates, "meal", "none");
  const snack = getEligibleTemplates(templates, "snack", "none");
  assertEquals(meal.length, 2);
  assertEquals(snack.length, 2);
  assert(meal.every((t) => t.name === "oatmeal"));
  assert(snack.every((t) => t.name === "toast"));
});

// ---------------------------------------------------------------------------
// Category-first classification (`sub_phase`, 2026-08-06)
// ---------------------------------------------------------------------------
//
// Lee's ruling: selection keys on the template's CATEGORY (sub_phase column),
// not the time period, so the display windows can move freely without another
// coordinated data + code release. `timeWindowToPhase` survives only as the
// fallback for catalogs that predate the sub_phase migration (prod, until it
// replays there).

Deno.test("templatePhase: sub_phase wins over a NOVEL future time_window string", () => {
  // The whole point of the column: a display-label change alone must not move
  // (or drop) a template from its tier. '90 min - 2.5 hours' matches neither
  // string generation, yet the template stays a snack because it SAYS so.
  const t = {
    ...template("pretzels", "90 min - 2.5 hours"),
    sub_phase: "snack" as const,
  };
  assertEquals(templatePhase(t), "snack");
  // And it is actually eligible for selection in that phase.
  assertEquals(
    getEligibleTemplates([t], "snack", "none").map((x) => x.name),
    ["pretzels"],
  );
  // The window string alone would have classified to nothing at all.
  assertEquals(timeWindowToPhase(t.time_window), null);
});

Deno.test("templatePhase: full sub_phase mapping + null fallback to the window", () => {
  assertEquals(
    templatePhase({ ...template("m", "junk"), sub_phase: "full_meal" }),
    "meal",
  );
  assertEquals(
    templatePhase({ ...template("s", "junk"), sub_phase: "snack" }),
    "snack",
  );
  assertEquals(
    templatePhase({ ...template("t", "junk"), sub_phase: "top_up" }),
    "top_up",
  );
  // Pre-migration rows (prod): sub_phase absent → window fallback, both
  // generations.
  assertEquals(templatePhase(template("m", "1.5-3 hours")), "meal");
  assertEquals(templatePhase(template("m", "2-4 hours")), "meal");
  assertEquals(templatePhase(template("x", "junk")), null);
});
