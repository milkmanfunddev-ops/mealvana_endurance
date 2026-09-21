/**
 * DI-25 — sample capture prepares payloads safely at ingest.
 *
 * The load-bearing assertion is the GPS strip (Xuan's ruling B, 2026-09-20):
 * route-level location must never rest on our servers, so it is removed
 * before the row is written, at any depth, including inside per-second
 * sample streams. The second is the real byte cap (recon W7).
 */
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  guardSize,
  isGpsKey,
  prepareDetailForCapture,
  stripGps,
} from "../_shared/garmin/sample_capture.ts";

// A realistically-shaped Garmin activityDetails payload.
function detail(sampleCount = 3) {
  return {
    summary: {
      summaryId: "g-1",
      activityType: "CYCLING",
      startingLatitudeInDegree: 33.5186,
      startingLongitudeInDegree: -86.8104,
      durationInSeconds: 3600,
      averageHeartRateInBeatsPerMinute: 148,
    },
    samples: Array.from({ length: sampleCount }, (_, i) => ({
      startTimeInSeconds: 1789000000 + i,
      latitudeInDegree: 33.5186 + i * 0.0001,
      longitudeInDegree: -86.8104 + i * 0.0001,
      heartRate: 140 + i,
      powerInWatts: 200 + i,
      elevationInMeters: 180 + i,
    })),
  };
}

Deno.test("GPS keys are recognised by WORD, not by substring", () => {
  for (const k of [
    "latitudeInDegree",
    "longitudeInDegree",
    "startingLatitudeInDegree",
    "lat",
    "start_lon",
    "geoPosition",
  ]) {
    assert(isGpsKey(k), `${k} should be treated as GPS`);
  }
  // The substring trap: these contain "lat"/"lon" but are not location.
  for (const k of ["platform", "pilates", "Latter", "alongDuration"]) {
    assert(!isGpsKey(k), `${k} must NOT be stripped`);
  }
});

Deno.test("no location survives anywhere in the prepared payload", () => {
  const out = prepareDetailForCapture(detail(5));
  const blob = JSON.stringify(out.payload);
  for (const leak of ["33.5186", "-86.8104", "latitude", "longitude"]) {
    assert(
      !blob.toLowerCase().includes(leak.toLowerCase()),
      `'${leak}' survived the strip`,
    );
  }
});

Deno.test("the physiological curve and array cardinality survive", () => {
  const out = prepareDetailForCapture(detail(5));
  const p = out.payload as {
    samples: Record<string, number>[];
    summary: Record<string, unknown>;
  };
  assertEquals(p.samples.length, 5, "cardinality is shape — it must survive");
  assertEquals(p.samples[0].heartRate, 140);
  assertEquals(p.samples[0].powerInWatts, 200);
  assertEquals(p.samples[0].elevationInMeters, 180);
  // Non-GPS summary content is untouched.
  assertEquals(p.summary.averageHeartRateInBeatsPerMinute, 148);
  assertEquals(p.summary.summaryId, "g-1");
});

Deno.test("the strip runs BEFORE the cap, so a capped row was never built "
  + "from location data", () => {
  // Cap low enough to force elision; the surviving row must still be clean.
  const out = prepareDetailForCapture(detail(500), 200);
  assert(out.samplesDropped, "expected elision at this cap");
  const blob = JSON.stringify(out.payload).toLowerCase();
  assert(!blob.includes("latitude") && !blob.includes("33.5186"));
});

Deno.test("over the cap, samples are elided and the elision is RECORDED", () => {
  const out = prepareDetailForCapture(detail(500), 200);
  const p = out.payload as Record<string, unknown>;
  assertEquals(p.samples, undefined, "samples dropped to stay under cap");
  const note = p._samplesElided as Record<string, unknown>;
  assert(note, "the elision must be visible in the row");
  assertEquals(note.reason, "over_size_cap");
  assertEquals(note.sampleCount, 500);
  // The summary — the forensic value — survives.
  assert((p.summary as Record<string, unknown>).summaryId === "g-1");
});

Deno.test("under the cap, nothing is elided", () => {
  const out = prepareDetailForCapture(detail(3));
  const p = out.payload as Record<string, unknown>;
  assertEquals(out.samplesDropped, false);
  assertEquals((p.samples as unknown[]).length, 3);
  assertEquals(p._samplesElided, undefined);
});

Deno.test("guardSize reports honest byte counts and sample counts", () => {
  const under = guardSize(detail(2), 10_000_000);
  assertEquals(under.samplesDropped, false);
  assertEquals(under.sampleCount, 2);
  assert(under.bytes > 0);
  const over = guardSize(detail(500), 200);
  assertEquals(over.samplesDropped, true);
  assertEquals(over.sampleCount, 500, "the original count is still reported");
  assert(over.bytes < 10_000, "the stored row is actually small now");
});

Deno.test("stripGps leaves non-object values and empty structures alone", () => {
  assertEquals(stripGps(null), null);
  assertEquals(stripGps(42), 42);
  assertEquals(stripGps("lat"), "lat"); // a VALUE, not a key
  assertEquals(stripGps([]), []);
});
