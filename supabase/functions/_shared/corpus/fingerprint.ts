/**
 * Corpus sampler — structural fingerprint (real-payload-corpus@v1).
 *
 * Contract: corpus intake Addendum 2 as RATIFIED 2026-09-20 + ruling A
 * (qa vectors/integrations/corpus-fingerprint.json, mirrored in docs/ssot).
 *
 * Identity = (endpoint × WorkoutType stratum)
 *          + top-level JSON type
 *          + per-key three-state map (ABSENT / NULL / VALUE:type) over
 *            NON-OPTIONAL keys only.
 *
 * Ruling A: stratum-classed OPTIONAL keys drop out of identity ENTIRELY —
 * value, null, or absent are all one shape, and (ruled convention) an
 * optional key's value TYPE is also outside identity. Before a key is
 * optional-classed (observed both absent and non-absent within one stratum),
 * ABSENT vs NULL is a real difference — TP emits both forms per instance
 * (probe 2026-09-18), and basic-vs-premium NULL vs VALUE never collapses.
 *
 * ABSENT is encoded as absence from the key map (never a sentinel entry), so
 * two payloads differ on a key exactly when one has an entry the other lacks
 * or the entries disagree.
 *
 * Array values carry a CARDINALITY BUCKET (0 / 1 / few / many) instead of a
 * length: the intake's "array cardinality-bucket" knob, so 3 vs 4 samples is
 * one shape but 0 vs 300 is not. Bucket boundaries (few = 2–10) are an
 * implementation convention the vectors do not pin; the convergence criterion
 * (Addendum 2 §4) is the arbiter if they need tuning.
 *
 * Pure function: no I/O, no clock, no randomness.
 */

export interface Stratum {
  endpoint: string;
  workoutType: string;
}

export type Json =
  | null
  | boolean
  | number
  | string
  | Json[]
  | { [key: string]: Json };

type KeyState = "NULL" | `VALUE:${string}`;

function jsonType(v: Json): string {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  return typeof v; // "boolean" | "number" | "string" | "object"
}

function cardinalityBucket(n: number): string {
  if (n === 0) return "0";
  if (n === 1) return "1";
  if (n <= 10) return "few";
  return "many";
}

function keyState(v: Json): KeyState {
  if (v === null) return "NULL";
  if (Array.isArray(v)) return `VALUE:array:${cardinalityBucket(v.length)}`;
  return `VALUE:${jsonType(v)}`;
}

/**
 * Canonical fingerprint string for one payload observed in one stratum.
 * Two payloads share a shape iff their fingerprint strings are equal.
 *
 * [optionalKeysInStratum] is the stratum's optional-classed key set — the
 * caller (the sampler's stratum ledger) maintains it; this function only
 * applies the ruled exclusion.
 */
export function fingerprint(
  payload: Json,
  stratum: Stratum,
  optionalKeysInStratum: readonly string[],
): string {
  const topType = jsonType(payload);
  const optional = new Set(optionalKeysInStratum);

  let keys: Record<string, KeyState> = {};
  if (topType === "object") {
    const obj = payload as { [key: string]: Json };
    for (const key of Object.keys(obj).sort()) {
      if (optional.has(key)) continue; // ruling A: out of identity entirely
      keys[key] = keyState(obj[key]);
    }
  }

  // Canonical: fixed field order, sorted keys — string equality IS identity.
  return JSON.stringify({
    endpoint: stratum.endpoint,
    workoutType: stratum.workoutType,
    top: topType,
    keys,
  });
}
