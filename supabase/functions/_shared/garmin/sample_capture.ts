/**
 * Sample-level capture preparation (real-payload-corpus@v1.2, DI-25).
 *
 * L-7 item 3 graduates full `activityDetails` capture to prod, and Xuan's
 * 2026-09-20 amendment (ruling B) adds the condition that makes it safe:
 * **GPS sample points are STRIPPED AT INGEST, everywhere.** Route-level
 * location must never rest on our servers — not in the raw forensic store,
 * not transiently-committed. What we keep is the physiological curve: heart
 * rate, pace, power, cadence, swim lengths.
 *
 * Two pure functions, both applied BEFORE the row is written:
 *   stripGps   — removes location keys at ANY depth
 *   guardSize  — enforces an explicit byte cap (recon W7: the existing
 *                "size-guarded" note in garmin-push is a comment, not code)
 *
 * WHY THE STRIP MATCHES BY WORD, NOT BY NAME LIST. A blocklist of known GPS
 * field names is exactly the shape that failed the corpus scrubber the same
 * day this was written: real payloads carry more keys than any list, and the
 * one you forget is the one that leaks. So a key is GPS if any of its WORDS
 * is a location word — which catches `latitudeInDegree`,
 * `startingLongitudeInDegree`, `lat`, `start_lon` and whatever Garmin adds
 * next, while leaving `platform`, `pilates` and `Latter` alone (a naive
 * substring match would have destroyed all three).
 */

/** Location words. A key is GPS when any of its words is one of these. */
const GPS_WORDS: ReadonlySet<string> = new Set([
  "lat",
  "lng",
  "lon",
  "latitude",
  "longitude",
  "coordinate",
  "coordinates",
  "geo",
  "position",
  "polyline",
]);

/** Splits camelCase, snake_case and dotted keys into lowercase words. */
export function keyWords(key: string): string[] {
  return key
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_\-.]+/g, " ")
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);
}

export function isGpsKey(key: string): boolean {
  return keyWords(key).some((w) => GPS_WORDS.has(w));
}

/**
 * Removes every GPS-bearing key at any depth. Structure is otherwise kept
 * verbatim: array cardinality survives (a 3600-sample stream stays 3600
 * samples), so the shape remains real while the location does not.
 */
export function stripGps<T>(value: T): T {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) {
    return value.map((v) => stripGps(v)) as unknown as T;
  }
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    if (isGpsKey(k)) continue; // dropped entirely — never fuzzed, never kept
    out[k] = stripGps(v);
  }
  return out as unknown as T;
}

/**
 * Default cap for one captured detail row. Tunable; see guardSize.
 *
 * 8 MiB, raised from 1 MiB on 2026-09-22 (Xuan). The old value was set
 * against a SWIM-shaped payload and silently excluded runs. Measured across
 * 12 real prod captures the per-sample cost splits by sport: swim 117-118
 * B/sample, strength/HIIT ~175, run 279-346. At 1 MiB that bought 69 minutes
 * of swimming but under an hour of running, and the boundary showed up in
 * the data — a 58-minute treadmill run survived with 64,547 B to spare while
 * a 74-minute run was elided to 0 samples. The cap is meant to stop a
 * pathological row, not to exclude an ordinary workout.
 *
 * Why 8 and not 4. 4 MiB covers every payload Garmin demonstrably sends
 * (multisport splits into legs per spec, so the longest single detail is a
 * ~6-7 h bike leg), but only by REDUCING that leg to the forensic core. 8
 * MiB keeps it verbatim: ~6:44 of running at the worst-measured 346
 * B/sample, with the projection fallback reaching ~20:59. The athlete doing
 * the thing this product exists for keeps their whole stream.
 *
 * THE PREMISE THIS RESTS ON. Xuan accepted 8 MiB "assuming [the] daily sweep
 * would alert me if size becomes unmanageable" — i.e. storage growth is a
 * MONITORED risk, not an unbounded one. If that monitoring stops reporting
 * row/table growth, this constant loses its justification and should be
 * revisited, not quietly left at 8 MiB.
 *
 * Untested above ~1 MiB: the largest row ever to survive this insert path in
 * prod is 1,032,998 B. Verify a real over-1-MiB capture lands before prod.
 */
export const SAMPLE_CAPTURE_CAP_BYTES = 8_388_608; // 8 MiB

/**
 * The fields a reduced sample keeps: the physiological curve this capture
 * path exists to preserve. `speedMetersPerSecond` is what pace is derived
 * from, so it is core, not optional — a record without it cannot answer
 * "how fast was this athlete at minute 40", which is half the question the
 * corpus is for. At ~60 B/sample this fits ~4.8 h inside even the old 1 MiB.
 */
export const FORENSIC_SAMPLE_FIELDS: readonly string[] = [
  "startTimeInSeconds",
  "heartRate",
  "speedMetersPerSecond",
  "totalDistanceInMeters",
];

export interface GuardResult {
  /** The payload to persist — samples elided when over cap. */
  payload: unknown;
  /** True when the sample stream was dropped to stay under the cap. */
  samplesDropped: boolean;
  /** True when samples were narrowed to FORENSIC_SAMPLE_FIELDS to fit. */
  samplesProjected: boolean;
  bytes: number;
  sampleCount: number;
}

/**
 * Narrows every sample to the forensic core, dropping the other per-sample
 * fields. Cardinality is preserved exactly as in stripGps: a 3,600-sample
 * stream stays 3,600 samples, so the time base is never distorted — this
 * trades WIDTH for size, never RESOLUTION. Downsampling was rejected for
 * that reason: a 20-second HR spike can fall between retained samples, and
 * a record that can silently lose an event is not a forensic record.
 *
 * A key is kept only when the sample actually carries it, so a projected
 * sample never gains an `undefined` field the provider never sent.
 */
export function projectSamples<T>(payload: T): T {
  const samples = (payload as { samples?: unknown[] })?.samples;
  if (!Array.isArray(samples)) return payload;
  const projected = samples.map((s) => {
    if (s === null || typeof s !== "object") return s;
    const src = s as Record<string, unknown>;
    const out: Record<string, unknown> = {};
    for (const f of FORENSIC_SAMPLE_FIELDS) {
      if (f in src) out[f] = src[f];
    }
    return out;
  });
  return { ...(payload as Record<string, unknown>), samples: projected } as
    unknown as T;
}

/**
 * Enforces an explicit byte cap (W7).
 *
 * Over the cap, the SAMPLES are dropped rather than the whole row: the
 * forensic value of "this activity arrived, and it had N samples" outlives
 * the stream itself, and silently discarding the row would recreate the
 * 2026-08-24 invisible-activity bug this capture path exists to prevent.
 * The elision is recorded IN the row so a reader can never mistake a
 * capped row for an activity that genuinely had no samples.
 */
export function guardSize(
  payload: unknown,
  capBytes: number = SAMPLE_CAPTURE_CAP_BYTES,
): GuardResult {
  const encoded = JSON.stringify(payload) ?? "";
  const bytes = new TextEncoder().encode(encoded).length;
  const samples = (payload as { samples?: unknown[] })?.samples;
  const sampleCount = Array.isArray(samples) ? samples.length : 0;

  if (bytes <= capBytes) {
    return {
      payload,
      samplesDropped: false,
      samplesProjected: false,
      bytes,
      sampleCount,
    };
  }

  const capped = { ...(payload as Record<string, unknown>) };
  delete capped.samples;
  capped._samplesElided = {
    reason: "over_size_cap",
    capBytes,
    originalBytes: bytes,
    sampleCount,
  };
  const cappedBytes =
    new TextEncoder().encode(JSON.stringify(capped) ?? "").length;
  return {
    payload: capped,
    samplesDropped: true,
    samplesProjected: false,
    bytes: cappedBytes,
    sampleCount,
  };
}

/**
 * The ingest preparation: strip location, then fit under the cap.
 *
 * Order matters twice over. The strip runs FIRST so no later stage is ever
 * built from GPS data. Then the fit degrades in steps rather than falling
 * straight to nothing:
 *
 *   1. under cap            — stored verbatim, every field, full rate
 *   2. over cap             — samples narrowed to the forensic core
 *                             (`_samplesReduced` records the narrowing)
 *   3. still over           — samples elided, as before
 *
 * Step 2 exists because step 3 was the whole failure: an ordinary run hit
 * the cap and the row kept its summary and lost every sample, which is the
 * one outcome this capture path was built to prevent.
 */
export function prepareDetailForCapture(
  detail: unknown,
  capBytes: number = SAMPLE_CAPTURE_CAP_BYTES,
): GuardResult {
  const stripped = stripGps(detail);

  const verbatim = guardSize(stripped, capBytes);
  if (!verbatim.samplesDropped) return verbatim;

  // Over the cap: keep the curve, drop the width.
  const reduced = guardSize(projectSamples(stripped), capBytes);
  if (reduced.samplesDropped) return verbatim; // nothing fits — elide (step 3)

  // guardSize already measured the un-reduced payload on its way to deciding
  // it was too big, and recorded it in the elision note — reuse that rather
  // than serialising several megabytes a second time just to report a number.
  const elided = (verbatim.payload as {
    _samplesElided?: { originalBytes?: number };
  })._samplesElided;

  const payload = { ...(reduced.payload as Record<string, unknown>) };
  payload._samplesReduced = {
    reason: "over_size_cap",
    capBytes,
    originalBytes: elided?.originalBytes ?? null,
    keptFields: FORENSIC_SAMPLE_FIELDS,
    sampleCount: reduced.sampleCount,
  };
  return {
    payload,
    samplesDropped: false,
    samplesProjected: true,
    bytes: new TextEncoder().encode(JSON.stringify(payload) ?? "").length,
    sampleCount: reduced.sampleCount,
  };
}
