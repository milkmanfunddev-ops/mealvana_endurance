/**
 * R8 producer-shaped SEAM TEST — brick.md R8 / D-008 (qa rule 8b12b9d).
 *
 * The mismatch this guards lives BETWEEN two processes: generate-macros-v4
 * writes the transition payload, generate-nutrition-plan-v3 looks it up. A
 * single-engine vector cannot see that seam — under the old sport-pair
 * naming a plain bike→run brick emitted `T2`, the plan function looked up
 * `T1`, and transition fuel silently fell to zero-defaults.
 *
 * Discipline (app docs/test/README.md §"Seam tests: stored ≠ recomputed"):
 * the stored side is built with the PRODUCER's own code and constants (the
 * real calculateBrickMacrosV4, round-tripped through JSON like the wire) —
 * never with the consumer's math. Key equality is the gate; numeric
 * passthrough is checked with a tolerance and logged.
 *
 * Three shapes per the bundle manifest: bike→run, swim→bike→run, and the
 * repeat-leg bike→run→bike (the collision case).
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { calculateBrickMacrosV4 } from "../generate-macros-v4/brick-workout.ts";
import type { PreWorkoutOverlaidTargets } from "../generate-macros-v4/pre-workout.ts";
import { collectTransitionTargets } from "./brick-handler.ts";
import type { PlanInputV2 } from "./types.ts";

function preTargets(): PreWorkoutOverlaidTargets {
  return {
    carbs_g: 60,
    protein_g: 15,
    fat_g: 5,
    sodium_mg: null,
    water_ml: 500,
    meal_type: "snack",
    carbs_low_g: 50,
    carbs_high_g: 70,
    protein_low_g: 10,
    protein_high_g: 20,
    sodium_low_mg: null,
    sodium_high_mg: null,
    water_low_ml: 400,
    water_high_ml: 600,
    water_tiers: null,
  } as unknown as PreWorkoutOverlaidTargets;
}

type Segment = { sport: string; minutes: number };

/** The real producer, then the wire: JSON round-trip like an HTTP body. */
function producerTransitions(segments: Segment[]) {
  const result = calculateBrickMacrosV4(
    {
      weight: 72,
      weight_unit: "kg",
      activity_type: "brick",
      hours_before: 2,
      is_fasted: false,
      gut_training: "moderate",
      sweat_rate_category: "medium",
      sweat_sodium: "average",
      brick_segments: segments.map((s, i) => ({
        sport: s.sport,
        order: i + 1,
        duration_minutes: s.minutes,
        intensity: "moderate",
      })),
      // deno-lint-ignore no-explicit-any
    } as any,
    preTargets(),
  );
  return JSON.parse(JSON.stringify(result.phases.transitions)) as Array<
    Record<string, unknown>
  >;
}

/** The consumer's lookup keys: brick-handler generates `T{i+1}` per gap. */
function consumerLookupKeys(segments: Segment[]): string[] {
  const keys: string[] = [];
  for (let i = 0; i < segments.length - 1; i++) keys.push(`T${i + 1}`);
  return keys;
}

function checkSeam(label: string, segments: Segment[]) {
  const transitions = producerTransitions(segments);

  const input = {
    macro_targets: { phases: { transitions } },
    // deno-lint-ignore no-explicit-any
  } as any as PlanInputV2;
  const collected = collectTransitionTargets(input);

  const lookupKeys = consumerLookupKeys(segments);

  // THE GATE — key equality, both directions. A producer key the consumer
  // never reads, or a consumer lookup the producer never wrote, is D-008.
  assertEquals(
    [...collected.keys()].sort(),
    [...lookupKeys].sort(),
    `${label}: producer transition keys must equal plan-side lookup keys`,
  );

  // Numeric passthrough — tolerance + log, per seam discipline.
  for (let i = 0; i < lookupKeys.length; i++) {
    const key = lookupKeys[i];
    const stored = collected.get(key)!;
    const wire = transitions[i];
    for (const field of ["carbs_g", "water_ml", "sodium_mg"] as const) {
      const wireVal = Number(wire[field] ?? 0);
      const storedVal = Number(
        (stored as unknown as Record<string, unknown>)[field] ?? 0,
      );
      const diff = Math.abs(wireVal - storedVal);
      console.log(
        `[SEAM] ${label} ${key} ${field}: wire=${wireVal} collected=${storedVal}`,
      );
      assert(
        diff <= 1,
        `${label} ${key}: ${field} drifted across the seam (wire ${wireVal} vs collected ${storedVal})`,
      );
    }
  }
}

describe("R8 seam: generate-macros-v4 keys == generate-nutrition-plan-v3 lookups", () => {
  it("2-leg bike→run (the D-008 zero-default shape)", () => {
    checkSeam("bike→run", [
      { sport: "cycling", minutes: 90 },
      { sport: "running", minutes: 45 },
    ]);
  });

  it("3-leg swim→bike→run (classic triathlon)", () => {
    checkSeam("swim→bike→run", [
      { sport: "swimming", minutes: 25 },
      { sport: "cycling", minutes: 65 },
      { sport: "running", minutes: 50 },
    ]);
  });

  it("3-leg bike→run→bike (repeat legs — the collision shape)", () => {
    checkSeam("bike→run→bike", [
      { sport: "cycling", minutes: 40 },
      { sport: "running", minutes: 30 },
      { sport: "cycling", minutes: 40 },
    ]);
  });
});
