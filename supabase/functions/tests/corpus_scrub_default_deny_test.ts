/**
 * Default-deny on content (ruled Xuan 2026-09-20, samples de-id erratum,
 * fix shape A) — regression built from the ACTUAL leak.
 *
 * The permissive default let any key missing from the per-key census through
 * verbatim. Real payloads are far wider than any census (TP 48 keys / 8
 * classified), so the promoted exemplar
 * vectors/integrations/samples/training_peaks/4e7fc4a111e9.json carried
 * `AthleteId: 6626647` and a deep-link `Url` containing that athlete id
 * twice plus the real workout id. The input below is that shape.
 *
 * qa-70 owns the ratified corpus-deid regeneration; this is the
 * implementation-side proof that the specific leak cannot recur.
 */
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  GARMIN_SCRUB_CENSUS,
  newScrubContext,
  scrub,
  TEXT_PLACEHOLDER,
  TP_KEEP_ENUM,
  TP_SCRUB_CENSUS,
} from "../_shared/corpus/scrub.ts";
import type { Json } from "../_shared/corpus/fingerprint.ts";

// The leaked exemplar's shape, values as they actually appeared.
const LEAKED_SHAPE = {
  AthleteId: 6626647,
  Url:
    "https://bnc.lt/JVxd/Z3Y12w9bOq?user=6626647&athlete=6626647&workout=3951921247&op=viewWorkout&env=uat",
  DistancePlanned: 9977.935546875,
  VelocityPlanned: 3.3259786289779645,
  TssCalculationMethod: "Undefined",
  WorkoutType: "Run",
  Completed: false,
  HeartRateAverage: null,
  TssPlanned: 65,
} as unknown as Json;

function scrubbed(): Record<string, Json> {
  return scrub(
    LEAKED_SHAPE,
    TP_SCRUB_CENSUS,
    newScrubContext(() => 0.5),
    TP_KEEP_ENUM,
  ) as Record<string, Json>;
}

Deno.test("the athlete identifier is gone entirely (ruled DROP row)", () => {
  const out = scrubbed();
  assert(!("AthleteId" in out), "AthleteId must be dropped, not merely fuzzed");
});

Deno.test("an identifier-bearing URL is placeholdered, not kept", () => {
  const out = scrubbed();
  assertEquals(out.Url, TEXT_PLACEHOLDER);
  const serialized = JSON.stringify(out);
  assert(!serialized.includes("6626647"), "athlete id survived somewhere");
  assert(!serialized.includes("3951921247"), "workout id survived somewhere");
  assert(!serialized.includes("bnc.lt"), "deep link survived");
});

Deno.test("unclassified numeric measurements are fuzzed, type kept", () => {
  const out = scrubbed();
  for (const k of ["DistancePlanned", "VelocityPlanned"] as const) {
    assertEquals(typeof out[k], "number", `${k} type`);
    assert(
      out[k] !== (LEAKED_SHAPE as Record<string, Json>)[k],
      `${k} must not survive verbatim`,
    );
  }
});

Deno.test("KEEP-ENUM members survive verbatim — the parser branches", () => {
  const out = scrubbed();
  assertEquals(out.WorkoutType, "Run");
  assertEquals(out.TssCalculationMethod, "Undefined");
  assertEquals(out.Completed, false);
});

Deno.test("structure survives: key set and null-pattern verbatim", () => {
  const out = scrubbed();
  // Every key except the dropped identifier.
  assertEquals(
    Object.keys(out).sort(),
    Object.keys(LEAKED_SHAPE as Record<string, Json>)
      .filter((k) => k !== "AthleteId")
      .sort(),
  );
  // A null is never invented into a value.
  assertEquals(out.HeartRateAverage, null);
});

Deno.test("an unclassified string with no allowlist entry is placeholdered", () => {
  const out = scrub(
    { SomeFutureProviderField: "whatever the provider adds next" } as Json,
    TP_SCRUB_CENSUS,
    newScrubContext(() => 0.5),
    TP_KEEP_ENUM,
  ) as Record<string, Json>;
  // The point of default-deny: a field nobody has classified yet is content.
  assertEquals(out.SomeFutureProviderField, TEXT_PLACEHOLDER);
});

Deno.test("GPS is DROPPED, never fuzzed — including names no census lists", () => {
  // The real Garmin field names. The census lists `startLatitude`, which is
  // NOT what Garmin sends; under default-deny these would have been fuzzed
  // into plausible-looking coordinates instead of removed.
  const out = scrub(
    {
      startingLatitudeInDegree: 33.5186,
      startingLongitudeInDegree: -86.8104,
      samples: [{ latitudeInDegree: 33.52, longitudeInDegree: -86.81, hr: 150 }],
      averageHeartRateInBeatsPerMinute: 148,
      activityType: "RUNNING",
    } as unknown as Json,
    GARMIN_SCRUB_CENSUS,
    newScrubContext(() => 0.5),
  ) as Record<string, Json>;

  const blob = JSON.stringify(out).toLowerCase();
  assert(!blob.includes("latitude"), "a latitude key survived");
  assert(!blob.includes("longitude"), "a longitude key survived");
  assert(!blob.includes("33.5"), "a coordinate value survived (fuzzed counts)");
  assert(!blob.includes("86.8"), "a coordinate value survived (fuzzed counts)");
  // Everything else still behaves: structure kept, physiology fuzzed.
  assert("samples" in out, "sample array must survive as structure");
  assertEquals((out.samples as Json[]).length, 1);
});
