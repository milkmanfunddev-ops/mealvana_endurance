/**
 * Cross-language parity test: runs the SAME fixture file the Flutter side
 * pins its DailyBaselineCalculator with
 * (test/features/onboarding/fixtures/plan_preview_parity.json) through the
 * real TS formulas. If either implementation drifts from the fixtures, its
 * own test fails — keeping the onboarding plan preview honest against the
 * server pipeline.
 *
 * Run with:
 *   deno test --allow-read --allow-env --node-modules-dir=none \
 *     supabase/functions/calculate-daily-macros/parity-fixtures.test.ts
 */

import {
  assertAlmostEquals,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { calculateRMR } from "./formulas/rmr.ts";
import { baselineMacros, clampMacros } from "./formulas/baseline.ts";
import {
  carbDemand,
  sessionCost,
  zoneDistributionToIF,
} from "./formulas/session.ts";
import { calculateTDEE } from "./formulas/neat-tef.ts";
import type { Sex } from "./types.ts";

const fixturePath = new URL(
  "../../../test/features/onboarding/fixtures/plan_preview_parity.json",
  import.meta.url,
);
const fixtures = JSON.parse(Deno.readTextFileSync(fixturePath));

describe("RMR parity", () => {
  for (const c of fixtures.rmr) {
    it(c.name, () => {
      const result = calculateRMR(
        c.weight_kg,
        c.height_cm,
        c.age,
        c.sex as Sex,
        c.body_fat_pct,
      );
      assertAlmostEquals(result, c.expected, 1e-9);
    });
  }
});

describe("baseline macros parity", () => {
  for (const c of fixtures.baseline) {
    it(c.name, () => {
      const result = baselineMacros(c.weight_kg, c.lbm_kg, c.age);
      assertAlmostEquals(result.carb_g, c.expected_carb_g, 1e-9);
      assertAlmostEquals(result.prot_g, c.expected_prot_g, 1e-9);
    });
  }
});

describe("macro clamps parity", () => {
  for (const c of fixtures.clamp) {
    it(c.name, () => {
      const result = clampMacros(c.carb_g, c.prot_g, c.weight_kg);
      assertAlmostEquals(result.carb_g, c.expected_carb_g, 1e-9);
      assertAlmostEquals(result.prot_g, c.expected_prot_g, 1e-9);
    });
  }
});

describe("session parity", () => {
  for (const c of fixtures.session) {
    it(c.name, () => {
      const intensityFactor = zoneDistributionToIF(
        c.pct_conversational,
        c.pct_tempo,
        c.pct_allout,
      );
      assertAlmostEquals(intensityFactor, c.expected_if, c.if_tolerance);

      const kcal = sessionCost(
        c.sport,
        c.duration_hr,
        intensityFactor,
        c.weight_kg,
      );
      assertAlmostEquals(kcal, c.expected_kcal, c.kcal_tolerance);

      const carb = carbDemand(intensityFactor, c.duration_hr, c.weight_kg);
      assertAlmostEquals(carb, c.expected_carb_g, c.carb_tolerance);
    });
  }
});

describe("TDEE convergence parity", () => {
  for (const c of fixtures.tdee) {
    it(c.name, () => {
      const result = calculateTDEE(
        c.rmr,
        c.neat,
        c.session_kcal,
        c.carb_g,
        c.prot_g,
        c.weight_kg,
      );
      assertEquals(result.tdee, c.expected_tdee);
      assertEquals(result.fat_g, c.expected_fat_g);
    });
  }
});
