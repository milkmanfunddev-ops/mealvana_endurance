/**
 * PW-013 backwards-compatibility guard.
 *
 * `pre_run_hydration_tier` is retired, but App Store clients up to 1.22.x
 * still read it. `legacyHydrationTier` reproduces the RETIRED branch so those
 * clients keep receiving exactly what they received before the pre-workout
 * bundle landed. These tests pin that branch — if someone "simplifies" the
 * shim into a regime->tier map, the gate case and the 10-minute boundary
 * break and this suite says so.
 *
 * The retired rule, transcribed from pre-bundle `calculatePreWorkoutHydration`
 * (develop @ e515fa3c):
 *
 *   gate (workoutDurationMin < 60 && tempC < 30) -> 1
 *   timeBeforeWorkoutMin >= 120                  -> 1
 *   timeBeforeWorkoutMin >= 10                   -> 2
 *   otherwise                                    -> 3
 */

import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";
import { legacyHydrationTier } from "./pre-workout.ts";

/** A non-gated base: 90 min workout, temperate. */
function base(timeBeforeWorkoutMin: number, over: Record<string, unknown> = {}) {
  return {
    bodyWeightKg: 70,
    workoutDurationMin: 90,
    timeBeforeWorkoutMin,
    tempC: 22,
    ...over,
  };
}

Deno.test("tier 1 at and above 120 min", () => {
  assertEquals(legacyHydrationTier(base(120)), 1);
  assertEquals(legacyHydrationTier(base(240)), 1);
  assertEquals(legacyHydrationTier(base(480)), 1);
});

Deno.test("tier 2 from 10 up to but not including 120", () => {
  assertEquals(legacyHydrationTier(base(10)), 2);
  assertEquals(legacyHydrationTier(base(30)), 2);
  assertEquals(legacyHydrationTier(base(119)), 2);
});

Deno.test("tier 3 below 10 min", () => {
  assertEquals(legacyHydrationTier(base(9)), 3);
  assertEquals(legacyHydrationTier(base(0)), 3);
});

Deno.test("the boundaries are inclusive at the bottom, as the retired rule was", () => {
  assertEquals(legacyHydrationTier(base(119)), 2);
  assertEquals(legacyHydrationTier(base(120)), 1);
  assertEquals(legacyHydrationTier(base(9)), 3);
  assertEquals(legacyHydrationTier(base(10)), 2);
});

Deno.test("the gate returns 1 regardless of lead time — this is the case a regime map gets wrong", () => {
  // Gate = duration < 60 AND temp < 30. The retired code returned tier 1 here
  // with the comment "tier is irrelevant when gated, but set to what it would
  // have been" — so 1 is what old clients saw, even at t = 0, where the
  // ungated rule would say 3.
  const gated = { workoutDurationMin: 30, tempC: 22 };
  assertEquals(legacyHydrationTier(base(0, gated)), 1);
  assertEquals(legacyHydrationTier(base(45, gated)), 1);
  assertEquals(legacyHydrationTier(base(240, gated)), 1);
});

Deno.test("temp >= 30 bypasses the gate, so the lead-time rule applies again", () => {
  const hot = { workoutDurationMin: 30, tempC: 32 };
  assertEquals(legacyHydrationTier(base(0, hot)), 3);
  assertEquals(legacyHydrationTier(base(45, hot)), 2);
  assertEquals(legacyHydrationTier(base(240, hot)), 1);
});

Deno.test("a null temp defaults to 22, matching the retired default", () => {
  // Null temp + short workout is therefore GATED (22 < 30) -> 1.
  assertEquals(
    legacyHydrationTier(base(0, { workoutDurationMin: 30, tempC: null })),
    1,
  );
  // Null temp + long workout is not gated, so lead time decides.
  assertEquals(legacyHydrationTier(base(45, { tempC: null })), 2);
});
