/**
 * During Phase — Real-Catalog Invariant Suite
 *
 * Runs the full during cascade against a SNAPSHOT OF THE REAL DEV CATALOG
 * (fixtures/catalog-snapshot-dev.json: every active during_workout_template
 * and template_food, dumped 2026-07-21). Where the synthetic matrix test
 * proves the architecture, this suite proves the actual catalog: for every
 * real template, activity, duration bracket, gut level, and body-size target
 * scale, the plan must land in band — or say so — for ALL THREE during
 * macros: carbs, sodium, AND fluid.
 *
 * Invariant per macro: delivered ≥ 90% of target OR a shortfall for that
 * macro is reported. Overshoot guard: delivered ≤ 135% of target for
 * non-tiny targets (tiny targets can legitimately overshoot on a single
 * minimum serving).
 *
 * To refresh the snapshot after a catalog change:
 *   supabase db query --linked "select ... from during_workout_templates ..."
 *   (see docs/daily/2026-07-21.md; keep the same JSON shape)
 *
 * Run with:
 *   deno test --allow-read --allow-write --node-modules-dir=none \
 *     supabase/functions/generate-nutrition-plan-v3/during-invariant-real-catalog.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { generateDuringPhase } from "./during-phase.ts";
import { fakeSupabase } from "../_shared/nutrition/test-fake-supabase.ts";
import { calculateTotals } from "../_shared/nutrition/food-utils.ts";
import type { ActivityType, MacroTargets } from "../_shared/nutrition/types.ts";
import type { PersonalFormulaPin } from "../_shared/nutrition/pins.ts";

// ============================================================================
// Snapshot loading
// ============================================================================

interface CatalogSnapshot {
  snapshot_date: string;
  source: string;
  during_workout_templates: Record<string, unknown>[];
  template_foods: Record<string, unknown>[];
}

const snapshot: CatalogSnapshot = JSON.parse(
  Deno.readTextFileSync(
    new URL("./fixtures/catalog-snapshot-dev.json", import.meta.url),
  ),
);

/** Essential foods in the `foods`-table shape used by getEssentialFoods
 * (personal-formula fluid/sodium backfill). Derived from the snapshot's
 * essential template_foods so the backfill pool matches the catalog. */
function essentialFoodsRows(): Record<string, unknown>[] {
  return snapshot.template_foods
    .filter((f) => f.is_essential === true)
    .map((f) => ({
      id: f.id,
      name: f.name,
      display_name: f.display_name,
      display_name_plural: f.display_name_plural,
      image_address: f.image_address,
      description: f.description,
      calories_per_serving: f.calories,
      carbs_per_serving: f.carbs_g,
      protein_per_serving: f.protein_g,
      fat_per_serving: f.fat_g,
      sodium_mg: f.sodium_mg,
      fluid_ml_per_serving: f.fluid_ml,
      serving_amount: f.serving_amount,
      serving_size: f.serving_size,
      serving_unit: f.serving_unit,
      serving_qualifier: f.serving_qualifier,
      is_electrolyte: f.is_electrolyte,
      is_essential: true,
    }));
}

function catalogClient() {
  return fakeSupabase({
    during_workout_templates: snapshot.during_workout_templates,
    // The snapshot query selected WHERE is_active = true but didn't include
    // the column itself — restore it so the fake's eq() filter passes.
    template_foods: snapshot.template_foods.map((f) => ({
      ...f,
      is_active: true,
    })),
    foods: essentialFoodsRows(),
  });
}

// ============================================================================
// Target profiles ("gender"/body-size proxy: target magnitude is what the
// solver sees — these span a 45 kg female to a gut-trained 90 kg male)
// ============================================================================

interface TargetScale {
  key: string;
  carbsPerHr: number;
  sodiumPerHr: number;
  fluidPerHr: number;
}

const SCALES: TargetScale[] = [
  { key: "light-45kg", carbsPerHr: 40, sodiumPerHr: 400, fluidPerHr: 400 },
  { key: "average-70kg", carbsPerHr: 60, sodiumPerHr: 500, fluidPerHr: 500 },
  { key: "heavy-90kg", carbsPerHr: 90, sodiumPerHr: 800, fluidPerHr: 750 },
  { key: "ultra-gut-trained", carbsPerHr: 110, sodiumPerHr: 1000, fluidPerHr: 800 },
];

function targetsFor(scale: TargetScale, durationMinutes: number): MacroTargets {
  const h = durationMinutes / 60;
  return {
    carbs_g: Math.round(scale.carbsPerHr * h),
    sodium_mg: Math.round(scale.sodiumPerHr * h),
    water_ml: Math.round(scale.fluidPerHr * h),
  };
}

// ============================================================================
// The three-macro invariant
// ============================================================================

const MACROS = [
  { macro: "carbs", target: "carbs_g", total: "carbs_g", tiny: 30 },
  { macro: "sodium", target: "sodium_mg", total: "sodium_mg", tiny: 400 },
  { macro: "fluid", target: "water_ml", total: "water_ml", tiny: 400 },
] as const;

function assertThreeMacroInvariant(
  // deno-lint-ignore no-explicit-any
  result: any,
  targets: MacroTargets,
  label: string,
) {
  const totals = calculateTotals(result.foods);
  // deno-lint-ignore no-explicit-any
  const reported = new Set((result.shortfalls ?? []).map((s: any) => s.macro));
  for (const m of MACROS) {
    // deno-lint-ignore no-explicit-any
    const target = (targets as any)[m.target] as number;
    if (!target || target <= 0) continue;
    // deno-lint-ignore no-explicit-any
    const delivered = (totals as any)[m.total] as number;
    assert(
      delivered >= target * 0.9 - 1e-6 || reported.has(m.macro),
      `${label}: SILENT ${m.macro} miss — ${delivered.toFixed(1)} of ` +
        `${target} with no ${m.macro} shortfall reported ` +
        `(shortfalls=${JSON.stringify(result.shortfalls ?? [])})`,
    );
    if (target >= m.tiny) {
      assert(
        delivered <= target * 1.35 + 1e-6,
        `${label}: ${m.macro} overshoot — ${delivered.toFixed(1)} > 135% of ${target}`,
      );
    }
  }
}

// ============================================================================
// Suite A — free selection across the whole space
// ============================================================================

describe("Real catalog — free selection matrix", () => {
  const activities: ActivityType[] = ["running", "cycling", "triathlon"];
  const durations = [45, 90, 150, 240, 330];
  const gutLevels: (string | undefined)[] = [
    undefined,
    "low",
    "moderate",
    "high",
    "medium", // legacy invalid literal — must behave as moderate
  ];

  for (const activity of activities) {
    for (const duration of durations) {
      for (const gut of gutLevels) {
        for (const scale of SCALES) {
          it(`${activity}/${duration}min/gut=${gut ?? "null"}/${scale.key}`, async () => {
            const targets = targetsFor(scale, duration);
            const result = await generateDuringPhase(
              catalogClient(),
              targets,
              activity,
              undefined,
              undefined,
              undefined,
              undefined,
              undefined,
              undefined,
              gut,
              duration,
            );
            assertThreeMacroInvariant(
              result,
              targets,
              `${activity}/${duration}min/gut=${gut ?? "null"}/${scale.key}`,
            );
            // A positive-duration workout must NEVER produce a zero-carb plan
            // without saying so — the exact prod failure from bug 3a3e3fdb.
            const totals = calculateTotals(result.foods);
            if (targets.carbs_g >= 30 && totals.carbs_g < 10) {
              const carbShortfall = (result.shortfalls ?? []).find(
                (s) => s.macro === "carbs",
              );
              assertExists(
                carbShortfall,
                `${activity}/${duration}min: near-zero carbs must be reported`,
              );
            }
          });
        }
      }
    }
  }
});

// ============================================================================
// Suite B — every real template, pinned, across its own declared scope
// ============================================================================

/** Map a template's storage activity_types back to solver ActivityTypes. */
function solverActivitiesFor(templateActivities: string[]): ActivityType[] {
  const out = new Set<ActivityType>();
  for (const at of templateActivities) {
    if (at === "running") out.add("running");
    if (at === "cycling") out.add("cycling");
    if (at.startsWith("triathlon")) out.add("triathlon");
  }
  return [...out];
}

const BRACKET_REPRESENTATIVE: Record<string, number> = {
  "< 90 min": 60,
  "90-150 min": 120,
  "150-240 min": 200,
  "> 240 min": 300,
};

describe("Real catalog — every template pinned, in scope", () => {
  for (const tplRow of snapshot.during_workout_templates) {
    // deno-lint-ignore no-explicit-any
    const tpl = tplRow as any;
    const activities = solverActivitiesFor(tpl.activity_types ?? []);
    for (const activity of activities) {
      for (const bracket of tpl.duration_brackets ?? []) {
        const duration = BRACKET_REPRESENTATIVE[bracket as string];
        if (!duration) continue;
        for (const gut of ["low", "moderate"] as const) {
          it(`pin tpl ${tpl.template_number} "${tpl.name}" / ${activity} / ${bracket} / gut=${gut}`, async () => {
            const targets = targetsFor(SCALES[1], duration);
            const result = await generateDuringPhase(
              catalogClient(),
              targets,
              activity,
              undefined,
              undefined,
              undefined,
              undefined,
              undefined,
              undefined,
              gut,
              duration,
              new Set([tpl.id as string]),
              true,
            );
            const label =
              `pin tpl ${tpl.template_number}/${activity}/${bracket}/gut=${gut}`;
            // The pin must be honored: this template renders, or the wire
            // says exactly why not (pinned_template_unrenderable) — never a
            // silent substitute claiming used_pin.
            assertExists(result.pin_decision, `${label}: pin_decision missing`);
            if (result.pin_decision!.used_pin) {
              assertEquals(
                result.template_metadata?.template_id,
                tpl.id,
                `${label}: used_pin=true but a different template rendered`,
              );
            } else {
              assertEquals(
                result.pin_decision!.fallthrough_reason,
                "pinned_template_unrenderable",
                `${label}: pin not used and reason is not unrenderable`,
              );
            }
            assertThreeMacroInvariant(result, targets, label);
          });
        }
      }
    }
  }
});

// ============================================================================
// Suite C — personal formulas (scaling + fluid/sodium backfill)
// ============================================================================

function personalPin(
  over: Partial<PersonalFormulaPin> & { id: string; name: string },
): PersonalFormulaPin {
  return {
    phase: "during",
    activities: null,
    durations: null,
    subPhase: null,
    components: [],
    ...over,
  };
}

describe("Real catalog — personal formulas", () => {
  const gelComponent = {
    food_id: "pf-gel",
    food_name: "My Gel",
    quantity: 2,
    serving_unit: "gel",
    carbs_per_serving: 25,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 50,
    fluid_ml_per_serving: 0,
    calories_per_serving: 100,
  };
  const drinkComponent = {
    food_id: "pf-drink",
    food_name: "My Mix",
    quantity: 1,
    serving_unit: "bottle",
    carbs_per_serving: 40,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 400,
    fluid_ml_per_serving: 500,
    calories_per_serving: 160,
  };

  it("gel+drink formula scales to the carb target; fluid/sodium backfilled or reported", async () => {
    const targets = targetsFor(SCALES[1], 180);
    const result = await generateDuringPhase(
      catalogClient(),
      targets,
      "cycling",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      "moderate",
      180,
      undefined,
      true,
      [personalPin({
        id: "pf-1",
        name: "My Long Ride Mix",
        components: [gelComponent, drinkComponent],
      })],
    );
    assertEquals(result.generation_path, "personal_formula");
    assertEquals(result.pin_decision?.used_pin, true);
    assertEquals(result.pin_decision?.pinned_template_name, "My Long Ride Mix");
    assertThreeMacroInvariant(result, targets, "personal gel+drink");
  });

  it("drink-only formula on a short run still satisfies the invariant", async () => {
    const targets = targetsFor(SCALES[0], 60);
    const result = await generateDuringPhase(
      catalogClient(),
      targets,
      "running",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      "low",
      60,
      undefined,
      true,
      [personalPin({
        id: "pf-2",
        name: "Bottle Only",
        components: [drinkComponent],
      })],
    );
    assertEquals(result.generation_path, "personal_formula");
    assertThreeMacroInvariant(result, targets, "personal drink-only");
  });

  it("empty-components formula falls through to the template tier, invariant intact", async () => {
    const targets = targetsFor(SCALES[1], 120);
    const result = await generateDuringPhase(
      catalogClient(),
      targets,
      "running",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      "moderate",
      120,
      undefined,
      true,
      [personalPin({ id: "pf-3", name: "Corrupt", components: [] })],
    );
    assert(result.generation_path !== "personal_formula");
    assertEquals(
      result.pin_decision?.fallthrough_reason === "personal_formula_empty" ||
        result.pin_decision?.used_pin === true,
      true,
      "empty formula must surface personal_formula_empty (or a real pin later)",
    );
    assertThreeMacroInvariant(result, targets, "personal empty fallthrough");
  });
});

// ============================================================================
// Suite D — restrictive profiles (diet / allergy / dislikes)
// ============================================================================

describe("Real catalog — restrictive profiles", () => {
  const cases: Array<{
    key: string;
    dislikes?: string[];
    allergies?: string[];
    diet?: string;
  }> = [
    { key: "vegan", diet: "vegan" },
    { key: "gluten-free", diet: "gluten-free" },
    { key: "dairy-free", diet: "dairy-free" },
    { key: "allergy-gluten+dairy", allergies: ["gluten", "dairy"] },
    { key: "allergy-peanut", allergies: ["peanut"] },
    {
      key: "dislikes-heavy",
      dislikes: (snapshot.template_foods.slice(0, 40).map((f) =>
        f.name
      )) as string[],
    },
  ];

  const allergensByFoodId = new Map(
    snapshot.template_foods.map(
      (f) => [f.id as string, (f.allergens ?? []) as string[]],
    ),
  );

  for (const c of cases) {
    for (const duration of [90, 240]) {
      it(`${c.key} / ${duration}min`, async () => {
        const targets = targetsFor(SCALES[1], duration);
        const result = await generateDuringPhase(
          catalogClient(),
          targets,
          "running",
          undefined,
          undefined,
          c.dislikes,
          undefined,
          c.allergies,
          c.diet,
          "moderate",
          duration,
        );
        assertThreeMacroInvariant(result, targets, `${c.key}/${duration}min`);
        // Hard safety: no allergen-bearing food may appear in the output.
        if (c.allergies?.length) {
          for (const food of result.foods) {
            const allergens = allergensByFoodId.get(food.food_id) ?? [];
            const hit = allergens.find((a) =>
              c.allergies!.some((ua) => ua.toLowerCase() === a.toLowerCase())
            );
            assertEquals(
              hit,
              undefined,
              `${c.key}: allergen-bearing food ${food.food_id} (${hit}) in output`,
            );
          }
        }
      });
    }
  }
});
