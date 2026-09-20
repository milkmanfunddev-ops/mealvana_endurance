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
 * time cadence stay verbatim). The vector-pinned exemplar keys below are
 * RATIFIED classifications: the per-provider census may be EXTENDED by
 * category as the key inventory grows, but these entries are never
 * re-classified (vector-file note).
 *
 * DEFAULT-DENY ON CONTENT (ruled Xuan 2026-09-20, samples de-id erratum —
 * fix shape A). An unclassified key keeps its KEY, its TYPE and its
 * null-pattern — the structure that is the whole test value — but its
 * VALUE is destroyed: numbers fuzzed, strings and booleans replaced.
 * Verbatim values survive ONLY via the deliberate KEEP-ENUM allowlist
 * below, added by name. This replaces the original permissive default
 * ("unknown key → keep as-is"), which leaked `AthleteId` and an
 * identifier-bearing `Url` into a promoted exemplar: real payloads carry
 * far more keys than any census (TP 48, FS 21), so a blocklist with a
 * permissive default cannot hold the ruled line "destroy the CONTENT,
 * keep the STRUCTURE". Identifier-bearing composites like a deep-link URL
 * are values like any other — placeholdered by the default.
 *
 * Deterministic when given a seeded rng — the harness uses that; production
 * callers may pass Math.random.
 */

import type { Json } from "./fingerprint.ts";

export type KeyCategory = "drop" | "fuzz" | "text" | "link" | "shift";
export type ScrubCensus = Readonly<Record<string, KeyCategory>>;

/**
 * KEEP-ENUM allowlist: the only way an unclassified value survives verbatim.
 *
 * Membership is by NAME and by judgement — never by a cardinality heuristic.
 * This census run proves why: across the same five TP payloads, `WorkoutType`
 * (3 distinct) and `Url` (4 distinct) are equally "low-cardinality", but one
 * is an enum and the other is a deep link carrying the athlete id twice.
 *
 * Admission test: the field names a CLOSED SET the provider chose from, it
 * drives a parser branch we want exercised, and it can never carry athlete
 * text. Anything else is content.
 */
export type KeepEnum = ReadonlySet<string>;

/** TrainingPeaks enum-class fields (48-key inventory, 2026-09-20). */
export const TP_KEEP_ENUM: KeepEnum = new Set([
  "WorkoutType", // "Run" | "Bike" | "Strength" — drives sport mapping
  "TssCalculationMethod", // "Undefined" | … — drives the TSS/hr rung
  "Completed", // boolean state flag — drives the planned/actual split
]);

/** Final Surge enum-class fields (21-key inventory, 2026-09-20). */
export const FS_KEEP_ENUM: KeepEnum = new Set([
  "WorkoutTypeName", // "Run" | "Bike" | "Swim" | … — sport mapping
  "PlannedDistanceType", // unit enum — drives distance conversion
  "PlannedPaceType", // unit enum — drives pace conversion
  "HasStructuredWorkout", // boolean — drives the structured-detail fetch
  "WorkoutCompleted", // boolean — drives completion handling
  "WorkoutRace", // boolean — drives race-flag prefill
  "WorkoutIcon", // NUMERIC enum (icon code, not a measurement)
  // DELIBERATELY ABSENT — WorkoutSubTypeName: the "subtype-is-title" erratum
  // says FS puts title-like free text in this field, so it is content.
]);

/** Garmin: seeded when Garmin promotion starts; empty is the safe default. */
export const GARMIN_KEEP_ENUM: KeepEnum = new Set<string>();

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

/** Final Surge raw-payload census — ruled-table categories over the FS wire
 * keys observed in docs/integration/api-exploration/final-surge. */
export const FS_SCRUB_CENSUS: ScrubCensus = {
  WorkoutKey: "link",
  WorkoutTitle: "text",
  WorkoutDescription: "text",
  Firstname: "drop",
  Lastname: "drop",
  PlannedDistance: "fuzz",
  PlannedDuration: "fuzz",
  PlannedTime: "fuzz",
  WorkoutDate: "shift",
};

/** TrainingPeaks raw-payload census — exemplar keys from the ruled table. */
export const TP_SCRUB_CENSUS: ScrubCensus = {
  // The ruled DROP row names "user_id, athlete id, …" — an athlete id is
  // removed, not merely fuzzed. (Leaked verbatim before the 2026-09-20
  // erratum; default-deny would now fuzz it, but DROP is the ruling.)
  AthleteId: "drop",
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
  keepEnum: KeepEnum = new Set<string>(),
): Json {
  return walk(payload, census, ctx, keepEnum);
}

function walk(
  v: Json,
  census: ScrubCensus,
  ctx: ScrubContext,
  keepEnum: KeepEnum,
): Json {
  if (v === null || typeof v !== "object") return v;
  if (Array.isArray(v)) {
    // Cardinality is structure: same length, elements walked.
    return v.map((e) => walk(e, census, ctx, keepEnum));
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
        } else out[key] = walk(value, census, ctx, keepEnum);
        break;
      case "text":
        if (value === null) out[key] = null;
        else if (typeof value === "string") out[key] = TEXT_PLACEHOLDER;
        else out[key] = walk(value, census, ctx, keepEnum);
        break;
      case "link":
        if (value === null) out[key] = null;
        else if (typeof value === "string" || typeof value === "number") {
          out[key] = syntheticId(value, ctx);
        } else out[key] = walk(value, census, ctx, keepEnum);
        break;
      case "shift":
        out[key] = value === null ? null : shiftTimestamp(value, ctx);
        break;
      default: {
        // DEFAULT-DENY on content (ruled 2026-09-20). Key, type and
        // null-pattern survive — the structure. The value does not,
        // unless the key is a deliberate KEEP-ENUM member.
        if (value === null) {
          out[key] = null; // null-pattern IS structure
        } else if (typeof value === "object") {
          out[key] = walk(value, census, ctx, keepEnum); // recurse
        } else if (keepEnum.has(key)) {
          out[key] = value; // closed-set enum, allowlisted by name
        } else if (typeof value === "number") {
          out[key] = fuzzNumber(value, ctx.rng);
        } else if (typeof value === "boolean") {
          // No "plausible synthetic" exists for one bit; a fixed constant
          // destroys the value while keeping key + type. Flags worth
          // exercising belong on the allowlist by name.
          out[key] = false;
        } else {
          out[key] = TEXT_PLACEHOLDER;
        }
        break;
      }
    }
  }
  return out;
}
