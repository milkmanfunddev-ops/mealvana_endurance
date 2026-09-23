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
  projectSamples,
  SAMPLE_CAPTURE_CAP_BYTES,
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

// ---------------------------------------------------------------------------
// Over-cap reduction (2026-09-22). The 1 MiB cap was set against a swim-shaped
// payload (~118 B/sample) and silently excluded runs (~324 B/sample, a ~54 min
// ceiling): the first real run to reach this code lost all 3,886 samples. The
// fix degrades in steps — verbatim, then narrowed to the forensic core, then
// elided — so an ordinary run keeps its heart-rate AND pace curve.
// ---------------------------------------------------------------------------

/** A run-shaped sample: wider than a swim's, which is the whole problem. */
function runDetail(sampleCount: number) {
  return {
    summary: {
      summaryId: "g-run",
      activityType: "RUNNING",
      durationInSeconds: sampleCount,
      averageHeartRateInBeatsPerMinute: 172,
    },
    samples: Array.from({ length: sampleCount }, (_, i) => ({
      startTimeInSeconds: 1790074170 + i,
      latitudeInDegree: 33.4497 + i * 0.00001,
      longitudeInDegree: -86.8096 + i * 0.00001,
      heartRate: 150 + (i % 30),
      speedMetersPerSecond: 3.1 + (i % 10) / 100,
      totalDistanceInMeters: i * 3.1,
      elevationInMeters: 180 + (i % 40),
      runCadenceInStepsPerMinute: 180 + (i % 8),
      airTemperatureCelcius: 21,
      movingDurationInSeconds: i,
      timerDurationInSeconds: i,
      clockDurationInSeconds: i,
    })),
  };
}

Deno.test("the default cap fits an ordinary run verbatim", () => {
  // ~48 minutes, the length of the run that was lost. It must not be reduced.
  const out = prepareDetailForCapture(runDetail(2902));
  assertEquals(out.samplesDropped, false);
  assertEquals(out.samplesProjected, false, "an ordinary run is kept verbatim");
  const p = out.payload as Record<string, unknown>;
  assertEquals((p.samples as unknown[]).length, 2902);
  assertEquals(p._samplesReduced, undefined);
  assert(out.bytes <= SAMPLE_CAPTURE_CAP_BYTES);
});

Deno.test("the cap keeps a multisport bike leg VERBATIM — the reason for 8 MiB", () => {
  // Multisport splits into legs per the Garmin spec, so the longest single
  // detail an athlete can produce is the bike leg of a long-course race,
  // ~6-7 h. At 4 MiB that leg was REDUCED — the athlete doing the thing this
  // product exists for would have lost cadence, elevation and power on the
  // longest effort of their season. 8 MiB keeps it whole.
  const sixHours = 6 * 3600;
  const out = prepareDetailForCapture(runDetail(sixHours));
  assertEquals(out.samplesDropped, false);
  assertEquals(out.samplesProjected, false, "a 6 h leg must stay verbatim");
  const p = out.payload as { samples: Record<string, number>[] };
  assertEquals(p.samples.length, sixHours);
  // Every field present, not just the forensic core.
  assertEquals(p.samples[0].elevationInMeters, 180);
  assertEquals(p.samples[0].runCadenceInStepsPerMinute, 180);
  assert(
    out.bytes <= SAMPLE_CAPTURE_CAP_BYTES,
    `6 h leg is ${out.bytes} B against a ${SAMPLE_CAPTURE_CAP_BYTES} B cap`,
  );
});

Deno.test("over the cap, PACE and heart rate survive at full resolution", () => {
  // A cap small enough to force reduction but not elision.
  const out = prepareDetailForCapture(runDetail(2000), 300_000);
  assertEquals(out.samplesDropped, false, "samples must NOT be dropped");
  assertEquals(out.samplesProjected, true);

  const p = out.payload as {
    samples: Record<string, number>[];
    _samplesReduced: Record<string, unknown>;
  };
  assertEquals(p.samples.length, 2000, "resolution is never traded for size");
  // The two the record exists for.
  assertEquals(p.samples[0].heartRate, 150);
  assertEquals(p.samples[0].speedMetersPerSecond, 3.1);
  assertEquals(p.samples[0].startTimeInSeconds, 1790074170);
  assertEquals(p.samples[0].totalDistanceInMeters, 0);
  // The width that paid for them.
  assertEquals(p.samples[0].elevationInMeters, undefined);
  assertEquals(p.samples[0].runCadenceInStepsPerMinute, undefined);
  assertEquals(p.samples[0].airTemperatureCelcius, undefined);

  assertEquals(p._samplesReduced.reason, "over_size_cap");
  assertEquals(p._samplesReduced.sampleCount, 2000);
  assert(out.bytes <= 300_000, "the reduced row is actually under the cap");
});

Deno.test("reduction never invents a field the provider did not send", () => {
  const sparse = {
    summary: { summaryId: "g-swim", activityType: "LAP_SWIMMING" },
    // Swim samples carry no speed at all — the projection must not add one.
    samples: Array.from({ length: 1500 }, (_, i) => ({
      startTimeInSeconds: 1789989941 + i,
      heartRate: 120 + (i % 20),
      timerDurationInSeconds: i,
      clockDurationInSeconds: i,
    })),
  };
  const out = prepareDetailForCapture(sparse, 100_000);
  assertEquals(out.samplesProjected, true);
  const s = (out.payload as { samples: Record<string, unknown>[] }).samples[0];
  assert(!("speedMetersPerSecond" in s), "absent stays absent, never null");
  assertEquals(s.heartRate, 120);
});

Deno.test("GPS is stripped before reduction, so a reduced row is clean", () => {
  const out = prepareDetailForCapture(runDetail(2000), 300_000);
  assertEquals(out.samplesProjected, true);
  const blob = JSON.stringify(out.payload).toLowerCase();
  for (const leak of ["latitude", "longitude", "33.4497", "-86.8096"]) {
    assert(!blob.includes(leak.toLowerCase()), `'${leak}' survived`);
  }
});

Deno.test("when even the forensic core will not fit, elision still applies", () => {
  const out = prepareDetailForCapture(runDetail(2000), 300);
  assertEquals(out.samplesDropped, true, "the last resort is unchanged");
  assertEquals(out.samplesProjected, false);
  const p = out.payload as Record<string, unknown>;
  assertEquals(p.samples, undefined);
  assertEquals(
    (p._samplesElided as Record<string, unknown>).reason,
    "over_size_cap",
  );
  // The elided row reports the ORIGINAL count, not a reduced one.
  assertEquals((p._samplesElided as Record<string, unknown>).sampleCount, 2000);
});

Deno.test("projectSamples leaves a payload with no sample array alone", () => {
  const summaryOnly = { summary: { summaryId: "g-2" } };
  assertEquals(projectSamples(summaryOnly), summaryOnly);
  assertEquals(projectSamples(null), null);
});
