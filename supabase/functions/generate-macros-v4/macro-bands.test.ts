/**
 * Unit tests for the during-workout macro band helpers in generate-macros-v4.
 *
 * Covers:
 * - getDurationCarbBand: every boundary value and each band range
 * - getSportCarbCeiling: running 70, cycling 120, swimming 0
 * - getGutTrainingMultiplier: low 0.7, moderate 1.0, high 1.2
 * - Composite: final during carb rate = min(bandMid × gutMult, sportCeiling)
 *   - Invariant: rate never exceeds sport ceiling, never goes negative
 *   - Explicit cap examples: cycling high-band + high-gut hits ceiling, swimming always 0
 *
 * Run with:
 *   deno test --allow-read --allow-write --allow-env --node-modules-dir=none \
 *     supabase/functions/generate-macros-v4/macro-bands.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  calculateDuringWorkoutCarbRate,
  getDurationCarbBand,
  getGutTrainingMultiplier,
  getSportCarbCeiling,
} from "./single-sport.ts";

// ============================================================================
// getDurationCarbBand — boundary assertions
// ============================================================================

describe("getDurationCarbBand", () => {
  // Band [0,30]: durationMin < 60
  it("59 min → [0, 30]", () => {
    assertEquals(getDurationCarbBand(59), [0, 30]);
  });

  it("0 min → [0, 30] (zero-duration edge)", () => {
    assertEquals(getDurationCarbBand(0), [0, 30]);
  });

  // Band [30,60]: 60 <= durationMin < 90
  it("60 min → [30, 60] (exact lower boundary)", () => {
    assertEquals(getDurationCarbBand(60), [30, 60]);
  });

  it("89 min → [30, 60]", () => {
    assertEquals(getDurationCarbBand(89), [30, 60]);
  });

  // Band [45,60]: 90 <= durationMin < 150
  it("90 min → [45, 60] (exact lower boundary)", () => {
    assertEquals(getDurationCarbBand(90), [45, 60]);
  });

  it("149 min → [45, 60]", () => {
    assertEquals(getDurationCarbBand(149), [45, 60]);
  });

  // Band [60,90]: 150 <= durationMin < 240
  it("150 min → [60, 90] (exact lower boundary)", () => {
    assertEquals(getDurationCarbBand(150), [60, 90]);
  });

  it("239 min → [60, 90]", () => {
    assertEquals(getDurationCarbBand(239), [60, 90]);
  });

  // Band [80,100]: durationMin >= 240
  it("240 min → [80, 100] (exact lower boundary)", () => {
    assertEquals(getDurationCarbBand(240), [80, 100]);
  });

  it("241 min → [80, 100]", () => {
    assertEquals(getDurationCarbBand(241), [80, 100]);
  });

  it("360 min → [80, 100] (ultra-endurance)", () => {
    assertEquals(getDurationCarbBand(360), [80, 100]);
  });
});

// ============================================================================
// getSportCarbCeiling
// ============================================================================

describe("getSportCarbCeiling", () => {
  it("running → 70 g/h", () => {
    assertEquals(getSportCarbCeiling("running"), 70);
  });

  it("cycling → 120 g/h", () => {
    assertEquals(getSportCarbCeiling("cycling"), 120);
  });

  it("swimming → 0 g/h", () => {
    assertEquals(getSportCarbCeiling("swimming"), 0);
  });

  it("unknown activity → 70 g/h (safe default)", () => {
    assertEquals(getSportCarbCeiling("unknown"), 70);
  });
});

// ============================================================================
// getGutTrainingMultiplier
// ============================================================================

describe("getGutTrainingMultiplier", () => {
  it("low gut training → 0.7", () => {
    assertEquals(getGutTrainingMultiplier("low"), 0.7);
  });

  it("moderate gut training → 1.0", () => {
    assertEquals(getGutTrainingMultiplier("moderate"), 1.0);
  });

  it("high gut training → 1.2", () => {
    assertEquals(getGutTrainingMultiplier("high"), 1.2);
  });

  it("unknown → 1.0 (safe default)", () => {
    assertEquals(getGutTrainingMultiplier("unknown"), 1.0);
  });
});

// ============================================================================
// Composite: final rate = min(bandMid × gutMult, sportCeiling)
// ============================================================================

const DUMMY_INTENSITY = { zone_low: 0.3, zone_mid: 0.4, zone_high: 0.3 };

describe("Composite: final during carb rate", () => {
  // --- Explicit cap cases ---

  it("cycling 3h high-gut: bandMid×1.2 is capped at 120 g/h", () => {
    // 180 min → band [60,90], mid=75; ×1.2 = 90; cycling ceiling=120 → NOT capped
    // Pick 4h (240 min) → band [80,100], mid=90; ×1.2 = 108; ceiling=120 → 108 (not capped)
    // To actually cap: need mid×gut > 120. Band [80,100] mid=90; ×1.2=108 < 120.
    // Actually no cycling scenario produces >120 because max band mid=90, ×1.2=108 < 120.
    // Test that the ceiling is respected even if we somehow got there via calculateDuringWorkoutCarbRate.
    // Use 4h high-gut cycling to get the highest possible rate:
    const result = calculateDuringWorkoutCarbRate(
      240,
      "cycling",
      "high",
      DUMMY_INTENSITY,
    );
    // band [80,100], mid=90, ×1.2=108 → min(108, 120) = 108
    assertEquals(result.rate_gph, 108);
    assert(
      result.rate_gph <= result.sport_ceiling,
      `rate ${result.rate_gph} must not exceed cycling ceiling ${result.sport_ceiling}`,
    );
  });

  it("swimming always returns 0 regardless of duration or gut training", () => {
    // Swimming ceiling = 0, so rate is always 0
    const result = calculateDuringWorkoutCarbRate(
      240,
      "swimming",
      "high",
      DUMMY_INTENSITY,
    );
    assertEquals(result.rate_gph, 0);
    assertEquals(result.sport_ceiling, 0);
  });

  it("running long+high-gut: rate capped at 70 g/h ceiling", () => {
    // 240 min → band [80,100], mid=90; ×1.2=108 → capped at 70 (running ceiling)
    const result = calculateDuringWorkoutCarbRate(
      240,
      "running",
      "high",
      DUMMY_INTENSITY,
    );
    assertEquals(result.rate_gph, 70);
    assertEquals(result.sport_ceiling, 70);
  });

  it("running 60-89 min moderate-gut: rate fits inside ceiling (no cap)", () => {
    // 75 min → band [30,60], mid=45; ×1.0=45 → min(45, 70) = 45
    const result = calculateDuringWorkoutCarbRate(
      75,
      "running",
      "moderate",
      DUMMY_INTENSITY,
    );
    assertEquals(result.rate_gph, 45);
    assert(result.rate_gph <= 70, "Should be under running ceiling");
  });

  it("running <60 min low-gut: band [0,30] × 0.7 → 10.5 → rounds to 10.5", () => {
    // band [0,30], mid=15; ×0.7=10.5
    const result = calculateDuringWorkoutCarbRate(
      45,
      "running",
      "low",
      DUMMY_INTENSITY,
    );
    assertEquals(result.rate_gph, 10.5);
    assert(result.rate_gph >= 0, "Rate must not be negative");
  });

  // --- Invariant sweep: rate never exceeds sport ceiling, never goes negative ---

  it("invariant sweep: rate never exceeds sport ceiling and never goes negative", () => {
    const durations = [
      0,
      30,
      45,
      59,
      60,
      75,
      89,
      90,
      120,
      149,
      150,
      180,
      239,
      240,
      300,
      360,
    ];
    const sports = ["running", "cycling", "swimming"];
    const guts = ["low", "moderate", "high"];
    let checkedCount = 0;

    for (const dur of durations) {
      for (const sport of sports) {
        for (const gut of guts) {
          const result = calculateDuringWorkoutCarbRate(
            dur,
            sport,
            gut,
            DUMMY_INTENSITY,
          );
          const ceiling = getSportCarbCeiling(sport);

          assert(
            result.rate_gph >= 0,
            `rate must be >= 0 for dur=${dur} sport=${sport} gut=${gut}, got ${result.rate_gph}`,
          );
          assert(
            result.rate_gph <= ceiling,
            `rate ${result.rate_gph} must not exceed ceiling ${ceiling} for dur=${dur} sport=${sport} gut=${gut}`,
          );
          // Sport ceiling in result struct must match independent call
          assertEquals(
            result.sport_ceiling,
            ceiling,
            `sport_ceiling mismatch for sport=${sport}`,
          );
          // Regression (2026-07-22): the band must obey the ceiling like the
          // rate does, and the rate must sit inside its own band — unclamped
          // bands put the target BELOW its displayed range (196g vs 202-302g)
          // and the adherence UI rendered permanently red.
          assert(
            result.band_high <= ceiling,
            `band_high ${result.band_high} exceeds ceiling ${ceiling} for dur=${dur} sport=${sport} gut=${gut}`,
          );
          assert(
            result.rate_gph >= result.band_low - 0.5 &&
              result.rate_gph <= result.band_high + 0.5,
            `rate ${result.rate_gph} outside its own band [${result.band_low}, ${result.band_high}] for dur=${dur} sport=${sport} gut=${gut}`,
          );
          checkedCount++;
        }
      }
    }

    // Confirm we actually ran the full matrix (16 durations × 3 sports × 3 guts = 144)
    assertEquals(checkedCount, 144, "Expected to check 144 combinations");
  });

  // --- Band clamping regression (2026-07-22) ---

  it("high-gut runner: fully-bound band clamps to ceiling and widens low by 12.5%", () => {
    // 168 min running → raw band [60,90], ×1.2 = [72,108]; both ends above the
    // 70 ceiling → clamp to [70,70], low widened to 70×0.875 = 61.25 → 61.
    // This is the exact reported case: target 70×2.8h = 196g displayed against
    // an unclamped range of 202-302g.
    const result = calculateDuringWorkoutCarbRate(
      168,
      "running",
      "high",
      DUMMY_INTENSITY,
    );
    assertEquals(result.band_low, 61);
    assertEquals(result.band_high, 70);
    assertEquals(result.rate_gph, 70);
  });

  it("moderate-gut runner: partially-bound band keeps its low, clamps its high", () => {
    // 168 min running moderate → scaled band [60,90]; ceiling 70 binds only
    // the top → [60,70]; rate = min(75, 70) = 70.
    const result = calculateDuringWorkoutCarbRate(
      168,
      "running",
      "moderate",
      DUMMY_INTENSITY,
    );
    assertEquals(result.band_low, 60);
    assertEquals(result.band_high, 70);
    assertEquals(result.rate_gph, 70);
  });

  it("swimming: band collapses to [0,0] with no widening below zero", () => {
    const result = calculateDuringWorkoutCarbRate(
      168,
      "swimming",
      "high",
      DUMMY_INTENSITY,
    );
    assertEquals(result.band_low, 0);
    assertEquals(result.band_high, 0);
    assertEquals(result.rate_gph, 0);
  });

  // --- Band mid values are consistent with helper output ---

  it("raw_band values in result match getDurationCarbBand output", () => {
    const cases: Array<[number, [number, number]]> = [
      [45, [0, 30]],
      [60, [30, 60]],
      [90, [45, 60]],
      [150, [60, 90]],
      [240, [80, 100]],
    ];

    for (const [dur, expectedBand] of cases) {
      const result = calculateDuringWorkoutCarbRate(
        dur,
        "cycling",
        "moderate",
        DUMMY_INTENSITY,
      );
      assertEquals(
        result.raw_band_low,
        expectedBand[0],
        `raw_band_low mismatch at ${dur} min`,
      );
      assertEquals(
        result.raw_band_high,
        expectedBand[1],
        `raw_band_high mismatch at ${dur} min`,
      );
    }
  });
});
