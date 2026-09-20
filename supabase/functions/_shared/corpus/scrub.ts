/**
 * Corpus scrubber — server-side de-identification (real-payload-corpus@v1).
 *
 * Contract: the corpus intake's de-id standard + Q8 additions, RULED as
 * written with timestamps shifted (Xuan, 2026-09-20); property vectors in
 * qa vectors/integrations/corpus-deid.json (mirrored in docs/ssot).
 *
 * The guarantee: every scalar is fake, every structural feature is real.
 * Structure (keys present, types, null-pattern, array cardinality) is KEPT
 * VERBATIM; content is destroyed by category:
 *
 *   DROP   — key removed entirely (identifiers, GPS: never fuzzed, removed)
 *   FUZZ   — numeric physiology/load scalars replaced with a plausible
 *            synthetic value of the SAME type. A NULL IS NEVER FUZZED —
 *            null-pattern is structure; fuzzing a null invents data
 *            (vector tp-basic-nulls-never-invented).
 *   TEXT   — free text replaced with a neutral placeholder (null stays null)
 *   LINK   — ids replaced with synthetic ids, REFERENTIAL LINKS PRESERVED:
 *            the same original id maps to the same synthetic id across every
 *            payload scrubbed with one ScrubContext (parentSummaryId of a
 *            child equals summaryId of its scrubbed parent).
 *   SHIFT  — timestamps moved to a fixed synthetic epoch by ONE delta per
 *            context, so relative offsets survive exactly (multisport gaps,
 *            tz/DST behaviour). First shifted value anchors the delta.
 *
 * The census maps key → category and applies AT ANY DEPTH (Q8: sample
 * streams fuzz their physiological scalars while array cardinality and
 * time cadence stay verbatim). Keys not in the census are kept as-is
 * (structure), recursing into objects/arrays. The vector-pinned exemplar
 * keys below are RATIFIED classifications: the per-provider census may be
 * EXTENDED by category as the key inventory grows, but these entries are
 * never re-classified (vector-file note).
 *
 * Deterministic when given a seeded rng — the harness uses that; production
 * callers may pass Math.random.
 */

import type { Json } from "./fingerprint.ts";

export type KeyCategory = "drop" | "fuzz" | "text" | "link" | "shift";
export type ScrubCensus = Readonly<Record<string, KeyCategory>>;

export const TEXT_PLACEHOLDER = "corpus placeholder";

/** Fixed synthetic epoch all shifted timestamps anchor to (2026-01-01 UTC). */
export const SYNTHETIC_EPOCH_SECONDS = 1767225600;

export interface ScrubContext {
  /** original id → synthetic id; shared across a scrub batch. */
  idMap: Map<string | number, string | number>;
  /** seconds added to every shifted timestamp; anchored by the first one. */
  timeDeltaSeconds: number | null;
  nextSyntheticId: number;
  rng: () => number;
}

export function newScrubContext(rng: () => number = Math.random): ScrubContext {
  return { idMap: new Map(), timeDeltaSeconds: null, nextSyntheticId: 1, rng };
}

/** Garmin raw-payload census — exemplar keys from the ruled table. */
export const GARMIN_SCRUB_CENSUS: ScrubCensus = {
  // identifiers / device / GPS — DROP
  userId: "drop",
  userAccessToken: "drop",
  deviceName: "drop",
  startLatitude: "drop",
  startLongitude: "drop",
  // physiology scalars — FUZZ (incl. per-sample stream scalars, Q8)
  averageHeartRateInBeatsPerMinute: "fuzz",
  activeKilocalories: "fuzz",
  hr: "fuzz",
  // free text — TEXT
  activityName: "text",
  // ids — LINK
  summaryId: "link",
  parentSummaryId: "link",
  // timestamps — SHIFT
  startTimeInSeconds: "shift",
  endTimeInSeconds: "shift",
};

/** TrainingPeaks raw-payload census — exemplar keys from the ruled table. */
export const TP_SCRUB_CENSUS: ScrubCensus = {
  Id: "link",
  Title: "text",
  Description: "text",
  IFPlanned: "fuzz",
  TssPlanned: "fuzz",
  TotalTimePlanned: "fuzz",
  WorkoutDay: "shift",
  LastModifiedDate: "shift",
};

function fuzzNumber(v: number, rng: () => number): number {
  const isInt = Number.isInteger(v);
  // Plausible: same order of magnitude; guaranteed different.
  const jitter = 0.8 + rng() * 0.4; // ±20%
  let out = v * jitter;
  if (isInt) {
    out = Math.round(out);
    if (out === v) out = v + (v >= 0 ? 1 : -1);
  } else if (out === v) {
    out = v + Math.max(Math.abs(v) * 1e-3, 1e-3);
  }
  return out;
}

function syntheticId(
  original: string | number,
  ctx: ScrubContext,
): string | number {
  const existing = ctx.idMap.get(original);
  if (existing !== undefined) return existing;
  const n = ctx.nextSyntheticId++;
  // Type-preserving: numeric ids stay numeric, string ids stay strings.
  const synth = typeof original === "number" ? 900000000 + n : `syn-${n}`;
  ctx.idMap.set(original, synth);
  return synth;
}

function shiftTimestamp(v: Json, ctx: ScrubContext): Json {
  if (typeof v === "number") {
    if (ctx.timeDeltaSeconds === null) {
      ctx.timeDeltaSeconds = SYNTHETIC_EPOCH_SECONDS - v;
    }
    return v + ctx.timeDeltaSeconds;
  }
  if (typeof v === "string") {
    // Provider timestamps can be ISO-ish strings (naive local, L-9). Shift
    // the parsed instant by the context delta, keep the string's shape
    // (with/without zone suffix) as best as ISO round-tripping allows.
    const ms = Date.parse(v);
    if (Number.isNaN(ms)) return v; // unparseable: structure kept verbatim
    const seconds = Math.floor(ms / 1000);
    if (ctx.timeDeltaSeconds === null) {
      ctx.timeDeltaSeconds = SYNTHETIC_EPOCH_SECONDS - seconds;
    }
    const shifted = new Date((seconds + ctx.timeDeltaSeconds) * 1000);
    const iso = shifted.toISOString();
    return v.endsWith("Z") ? iso : iso.replace(/\.\d{3}Z$/, "");
  }
  return v;
}

/**
 * Scrubs one payload. Never mutates the input; never throws on shape
 * surprises (unknown structure is kept verbatim — it IS the test value).
 */
export function scrub(
  payload: Json,
  census: ScrubCensus,
  ctx: ScrubContext,
): Json {
  return walk(payload, census, ctx);
}

function walk(v: Json, census: ScrubCensus, ctx: ScrubContext): Json {
  if (v === null || typeof v !== "object") return v;
  if (Array.isArray(v)) {
    // Cardinality is structure: same length, elements walked.
    return v.map((e) => walk(e, census, ctx));
  }
  const out: { [key: string]: Json } = {};
  for (const [key, value] of Object.entries(v)) {
    const category = census[key];
    switch (category) {
      case "drop":
        break; // removed entirely
      case "fuzz":
        if (value === null) out[key] = null; // NEVER fuzz a null
        else if (typeof value === "number") {
          out[key] = fuzzNumber(value, ctx.rng);
        } else out[key] = walk(value, census, ctx);
        break;
      case "text":
        if (value === null) out[key] = null;
        else if (typeof value === "string") out[key] = TEXT_PLACEHOLDER;
        else out[key] = walk(value, census, ctx);
        break;
      case "link":
        if (value === null) out[key] = null;
        else if (typeof value === "string" || typeof value === "number") {
          out[key] = syntheticId(value, ctx);
        } else out[key] = walk(value, census, ctx);
        break;
      case "shift":
        out[key] = value === null ? null : shiftTimestamp(value, ctx);
        break;
      default:
        out[key] = walk(value, census, ctx); // structure kept verbatim
    }
  }
  return out;
}
