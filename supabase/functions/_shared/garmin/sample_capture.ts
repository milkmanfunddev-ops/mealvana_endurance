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

/** Default cap for one captured detail row. Tunable; see guardSize. */
export const SAMPLE_CAPTURE_CAP_BYTES = 1_048_576; // 1 MiB

export interface GuardResult {
  /** The payload to persist — samples elided when over cap. */
  payload: unknown;
  /** True when the sample stream was dropped to stay under the cap. */
  samplesDropped: boolean;
  bytes: number;
  sampleCount: number;
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
    return { payload, samplesDropped: false, bytes, sampleCount };
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
    bytes: cappedBytes,
    sampleCount,
  };
}

/** The ingest preparation: strip location, then cap. Order matters — the
 * strip must happen first so a capped row was never built from GPS data. */
export function prepareDetailForCapture(
  detail: unknown,
  capBytes: number = SAMPLE_CAPTURE_CAP_BYTES,
): GuardResult {
  return guardSize(stripGps(detail), capBytes);
}
