/**
 * QA conformance — food-recommendation (selection contract), TS engine side.
 *
 * Twin of `qa/conformance/food_recommendation_conformance_test.dart` (§8: the
 * Dart client solvers are a MIRROR, not a fork — every vector runs on BOTH
 * engines and the canonical outputs must be byte-equal). Invoked by
 * `qa/conformance/run_dart.sh food-recommendation`, which sets:
 *   QA_VECTORS   absolute path to the ratified vector file
 *   QA_DIFF_OUT  where to write the canonical selection-result lines
 * Without QA_VECTORS the suite self-skips so the local auto-discovery runner
 * (run-algorithm-tests.sh) stays green outside the QA harness.
 *
 * Engine entry points driven (the same code the production solvers call):
 *   §3/§3a  resolveFuelingWindow           (_shared/nutrition/fueling-window.ts)
 *   §4      pickBestElectrolyte            (_shared/nutrition/during-utils.ts)
 *   §4.5    sortSodiumBackfillCandidates   (_shared/nutrition/pin-backfill.ts)
 *   §6(a)   mealTierCandidateCheck         (_shared/nutrition/practicality.ts)
 *   §6(e)   solvent requirement arithmetic + solventConstraintApplies
 *   §1/§1a  selection-precedence kernels
 *
 * Harness conventions mirror the Dart side exactly (whole-unit pool items,
 * carryable:false → liquid supplement, lower = target×0.9 fallback,
 * ceil-to-cover backfill servings, W1 Oatmeal fixture 27 g / [gluten]).
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import { resolveFuelingWindow } from "../_shared/nutrition/fueling-window.ts";
import { pickBestElectrolyte } from "../_shared/nutrition/during-utils.ts";
import { sortSodiumBackfillCandidates } from "../_shared/nutrition/pin-backfill.ts";
import {
  mealTierCandidateCheck,
  solventConstraintApplies,
} from "../_shared/nutrition/practicality.ts";
import {
  pinConflictLabelRequired,
  resolveSelectionStep,
  scalePinnedServings,
  unrenderablePinDowngrade,
} from "../_shared/nutrition/selection-precedence.ts";
import type { Food } from "../_shared/nutrition/types.ts";
import type { FuelingSessionClass } from "../_shared/nutrition/fueling-window.ts";

const OATMEAL_CARBS_PER_SERVING = 27.0;
const OATMEAL_ALLERGENS = ["gluten"];

function fmtNum(v: number): string {
  const r = Math.round(v);
  if (Math.abs(v - r) < 1e-9) return String(r);
  return v.toFixed(1);
}

// deno-lint-ignore no-explicit-any
function poolFood(e: Record<string, any>): Food {
  const carryable = e.carryable ?? false;
  return {
    id: e.name,
    name: e.name,
    display_name: e.name,
    display_name_plural: null,
    description: null,
    image_address: null,
    per_serving: {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: e.sodium_mg,
      water_ml: 0,
      calories: 0,
    },
    serving_amount: 1,
    min_servings: 1,
    max_servings: e.max_servings ?? 10,
    preference_score: 0,
    is_electrolyte: true,
    is_liquid: !carryable,
    is_essential: false,
    is_user_food: false,
    is_indivisible: true,
    product_type: "supplement",
  };
}

const vectorsPath = Deno.env.get("QA_VECTORS");
const diffOut = Deno.env.get("QA_DIFF_OUT");

if (!vectorsPath) {
  Deno.test("food-recommendation vectors (skipped — QA_VECTORS not set)", () => {
    console.log(
      "[QA] food_recommendation_vectors: QA_VECTORS not set — run via " +
        "qa/conformance/run_dart.sh food-recommendation",
    );
  });
} else {
  const doc = JSON.parse(Deno.readTextFileSync(vectorsPath));
  // deno-lint-ignore no-explicit-any
  const vectors: Record<string, any>[] = doc.vectors;
  const diffLines: string[] = [];

  Deno.test("vector count sanity", () => {
    assert(vectors.length >= 26, "expected the full ratified vector set");
  });

  for (const v of vectors) {
    const id = v.id as string;
    const status = (v.status as string) ?? "ratified";
    const i = v.inputs;
    const e = v.expected;
    const why = (v.why as string) ?? "";

    Deno.test(`[${status}] ${id}`, () => {
      // ── §3/§3a window authority ──────────────────────────────────────
      if ("session_class" in i) {
        const res = resolveFuelingWindow({
          sessionClass: i.session_class as FuelingSessionClass,
          startHour: i.start_hour,
          isRace: i.race ?? false,
          minutesUntilStart: i.minutes_until_start,
        });
        assertEquals(res.windowMin, e.default_window_min, why);
        assertEquals(res.activePhases, e.active_phases, why);
        diffLines.push(
          `${id}|window=${fmtNum(res.windowMin)}|phases=${
            res.activePhases.join(",")
          }`,
        );
        return;
      }

      // ── §4 electrolyte source policy ─────────────────────────────────
      if ("pool" in i) {
        const pool = i.pool.map(poolFood);
        const target = i.sodium_target_mg as number;
        const upper = i.sodium_upper_mg as number;
        const current = (i.current_sodium_mg as number) ?? 0;
        const pick = pickBestElectrolyte(pool, current, 0, 0, {
          sodiumTarget: target,
          sodiumLower: target * 0.9, // engines' shared bounds fallback
          sodiumUpper: upper,
          fluidTarget: 0,
          fluidUpper: Number.POSITIVE_INFINITY,
          carbTarget: 0,
          carbUpper: Number.POSITIVE_INFINITY,
        });
        assert(pick !== null, why);
        const delivered = pick!.sodium - current;
        assertEquals(pick!.food.name, e.pick, why);
        assert(Math.abs(pick!.servings - e.servings) < 1e-9, why);
        assert(Math.abs(delivered - e.delivered_mg) < 1e-6, why);
        diffLines.push(
          `${id}|pick=${pick!.food.name}|servings=${fmtNum(pick!.servings)}` +
            `|delivered=${fmtNum(delivered)}`,
        );
        return;
      }

      // ── §4.5 sodium backfill preference ──────────────────────────────
      if ("essentials" in i) {
        const deficit = i.deficit_mg as number;
        const pool = i.essentials.map(poolFood).filter(
          (f: Food) => f.per_serving.sodium_mg > 0 && f.per_serving.carbs_g <= 0,
        );
        const ranked = sortSodiumBackfillCandidates(pool);
        assert(ranked.length > 0, why);
        const best = ranked[0];
        const servings = Math.ceil(deficit / best.per_serving.sodium_mg);
        const delivered = servings * best.per_serving.sodium_mg;
        assertEquals(best.name, e.pick, why);
        assert(Math.abs(servings - e.servings) < 1e-9, why);
        assert(Math.abs(delivered - e.delivered_mg) < 1e-6, why);
        diffLines.push(
          `${id}|pick=${best.name}|servings=${fmtNum(servings)}` +
            `|delivered=${fmtNum(delivered)}`,
        );
        return;
      }

      // ── §6(a) meal-tier practicality ─────────────────────────────────
      if ("candidate" in i && "tier" in i) {
        const c = i.candidate;
        const check = mealTierCandidateCheck({
          componentCount: c.components ?? 1,
          singleFoodSufficient: c.single_food_sufficient ?? false,
          carbsPerServingG: c.carbs_g ?? null,
          carbTargetG: i.carb_target_g ?? null,
        });
        assertEquals(check.allowed, e.allowed, why);
        assertEquals(check.reason, e.reason ?? null, why);
        diffLines.push(
          `${id}|allowed=${check.allowed}|reason=${check.reason ?? "none"}`,
        );
        return;
      }

      // ── §6(e) solvent session-total ──────────────────────────────────
      if ("scheduled" in i) {
        const path = i.path as string | undefined;
        const applies = solventConstraintApplies(path ?? "template");
        if (!applies) {
          assertEquals(e.constraint_applies, false, why);
          diffLines.push(`${id}|applies=false`);
          return;
        }
        let required = 0;
        for (const s of i.scheduled) {
          required += (s.solvent_min_ml ?? 250) * s.servings;
        }
        const plainWater = (i.plain_water_ml as number) ?? 0;
        const satisfied = plainWater + 1e-9 >= required;
        assertEquals(satisfied, e.satisfied, why);
        assert(Math.abs(required - e.required_water_ml) < 1e-6, why);
        diffLines.push(
          `${id}|applies=true|satisfied=${satisfied}|required=${
            fmtNum(required)
          }`,
        );
        return;
      }

      // ── §1/§1a precedence & honesty ──────────────────────────────────
      if ("personal_formula" in i) {
        const pf = i.personal_formula;
        const step = resolveSelectionStep({
          hasInScopePersonalFormula: pf.scope_match ?? false,
          hasInScopePinnedTemplate: i.pinned_system_template?.scope_match ??
            false,
          hasEligibleTemplates: true,
        });
        const selected = step === 1 ? pf.name : i.pinned_system_template.name;
        assertEquals(selected, e.selected, why);
        assertEquals(step, e.step, why);
        diffLines.push(`${id}|selected=${selected}|step=${step}`);
        return;
      }

      if ("pins" in i) {
        // deno-lint-ignore no-explicit-any
        const pins: Record<string, any>[] = i.pins;
        const renderable = pins.every((p) => p.renderable ?? true);
        if (!renderable) {
          const downgrade = unrenderablePinDowngrade();
          assertEquals(downgrade.used_pin, e.used_pin, why);
          assertEquals(downgrade.fallthrough_reason, e.fallthrough_reason, why);
          diffLines.push(
            `${id}|used_pin=${downgrade.used_pin}` +
              `|fallthrough=${downgrade.fallthrough_reason}`,
          );
          return;
        }
        const pin = pins[0];
        assertEquals(pin.scope_match, true, why);
        const selected = pin.template as string;
        const servings = scalePinnedServings(
          i.meal_carb_target_g,
          OATMEAL_CARBS_PER_SERVING,
        );
        const conflict = pinConflictLabelRequired(
          OATMEAL_ALLERGENS,
          i.athlete_allergies ?? [],
        );
        assertEquals(selected, e.selected, why);
        assert(Math.abs(servings - e.servings) < 1e-9, why);
        assertEquals(conflict, e.conflict_label, why);
        diffLines.push(
          `${id}|selected=${selected}|servings=${fmtNum(servings)}` +
            `|conflict=${conflict}`,
        );
        return;
      }

      throw new Error(
        `unrecognized vector shape for ${id} — harness needs a new arm`,
      );
    });
  }

  Deno.test("write differential output", () => {
    if (!diffOut) return;
    Deno.writeTextFileSync(diffOut, diffLines.join("\n") + "\n");
  });
}
