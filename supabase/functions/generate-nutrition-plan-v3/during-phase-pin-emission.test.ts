/**
 * Locks the wire contract for `pin_decision` emission on the During section.
 *
 * Formula Kit PR 2 #18 — fixes the scenario-4 server bug surfaced in the
 * 2026-05-24 smoke test: a user with Before pins only would receive a plan
 * where the During section silently omitted `pin_decision`, causing the
 * activity-detail banner to skip the During row.
 *
 * The pre-fix contract derived `pinsSupplied` from the LOCAL pinned-set
 * size — so an empty During pin set looked identical to "user has no pins
 * anywhere" and `pin_decision` was omitted. The new contract takes an
 * orchestrator-supplied `pinsActive` flag meaning "user has any pin in any
 * scope", so the During section can emit an honest "no pin for scope"
 * decision when the user has Before-only pins.
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/generate-nutrition-plan-v3/during-phase-pin-emission.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { initialDuringPinDecision } from "./during-phase.ts";

// ─── Emission contract (Path A — orchestrator-driven) ────────────────────────

Deno.test("pinsSupplied=true → emits skeleton with no_pin_for_scope + set_size 0", () => {
  // This is the load-bearing case for scenario 4: the orchestrator sets
  // pinsSupplied=true because the user has Before pins, even though the
  // During scope has zero pins. The skeleton must be emitted so the
  // client banner can render a "No pin found" row for During.
  const decision = initialDuringPinDecision(true);
  assert(decision !== undefined, "expected pin_decision to be emitted");
  assertEquals(decision.used_pin, false);
  assertEquals(decision.pinned_template_id, null);
  assertEquals(decision.pinned_template_name, null);
  assertEquals(decision.fallthrough_reason, "no_pin_for_scope");
  assertEquals(decision.pin_set_size, 0);
});

Deno.test("pinsSupplied=false → returns undefined (omitted from wire)", () => {
  // No pins anywhere → pin_decision must be entirely absent from the
  // response, byte-identical to pre-pin v3. The caller spreads
  // `...(decision && { pin_decision: decision })` so undefined drops it.
  const decision = initialDuringPinDecision(false);
  assertEquals(
    decision,
    undefined,
    "no-pins case must omit pin_decision entirely",
  );
});

// ─── Shape guard (forward-compat) ────────────────────────────────────────────

Deno.test("skeleton uses null (not undefined) for nullable telemetry fields", () => {
  // The client (PinDecision Dart model) treats `null` and missing as
  // equivalent for nullable fields, but the wire format consistently uses
  // `null` for "intentionally absent". Lock this so a future refactor
  // doesn't accidentally start emitting `undefined` (which JSON-encodes
  // to a missing key — semantically OK but inconsistent with sibling
  // honored decisions that emit `null`).
  const decision = initialDuringPinDecision(true);
  assert(decision !== undefined);
  assertEquals(decision.pinned_template_id, null);
  assertEquals(decision.pinned_template_name, null);
});
