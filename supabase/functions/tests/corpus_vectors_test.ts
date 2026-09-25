/**
 * QA conformance — corpus-fingerprint + corpus-deid (real-payload-corpus@v1).
 *
 * Invoked by `qa/conformance/run_dart.sh corpus-fingerprint` /
 * `... corpus-deid`, which set QA_VECTORS to the ratified vector file. The
 * file's `section` field selects which suite runs. Without QA_VECTORS the
 * suite self-skips (same convention as food_recommendation_vectors.test.ts).
 *
 * Engines driven (the same modules production capture will call):
 *   fingerprint  _shared/corpus/fingerprint.ts
 *   scrub        _shared/corpus/scrub.ts
 *
 * corpus-deid vectors are PROPERTY vectors: fuzz is random, so expectations
 * are constraints, not literals. The suite runs the scrubber with a seeded
 * rng for reproducible failures, but no assertion depends on the seed.
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import { fingerprint, type Json, type Stratum } from "../_shared/corpus/fingerprint.ts";
import {
  GARMIN_KEEP_ENUM,
  GARMIN_SCRUB_CENSUS,
  type KeepEnum,
  newScrubContext,
  scrub,
  type ScrubCensus,
  TP_KEEP_ENUM,
  TP_SCRUB_CENSUS,
} from "../_shared/corpus/scrub.ts";

const vectorsPath = Deno.env.get("QA_VECTORS");

/**
 * Every `expected` key this suite knows how to assert.
 *
 * A vector key that is NOT in this set fails the run (see the guard at the top
 * of the corpus-deid loop). That guard exists because the opposite —
 * silently ignoring an unrecognised expectation — let the ratified contract
 * grow assertions the gate never evaluated: `timestampOffsetsPreserved` rode
 * in all six vectors from @v1 and was never once checked, and the three
 * sample-stream kinds landed with @v1.3 the same way. A gate that reports
 * green on a contract it did not read is worse than no gate.
 */
const HANDLED_EXPECTATION_KEYS = new Set([
  "droppedKeys",
  "keptKeySetVerbatim",
  "nullStaysNull",
  "scalarsMustDiffer",
  "textPlaceholder",
  "idsReplacedLinksPreserved",
  "timestampPairOffsetsSeconds",
  "timestampOffsetsPreserved",
  "arrayCardinalityVerbatim",
  "allowlistVerbatim",
  "unclassifiedNotVerbatim",
  "mustNotContainAnywhere",
  "gpsDroppedAtAnyDepth",
  "elapsedClocksVerbatim",
  "cumulativeMonotoneFuzz",
  "instantaneousSampleFuzz",
]);

/**
 * Resolves a vector path to the column of values it names.
 * "samples[].heartRate" -> every sample's heartRate, in order.
 * A path with no "[]" names a single value (returned as a 1-element column).
 * Missing keys contribute nothing, so an empty column means "absent".
 */
function columnAt(root: Json, path: string): Json[] {
  let cursor: Json[] = [root];
  for (const part of path.split(".")) {
    const spread = part.endsWith("[]");
    const key = spread ? part.slice(0, -2) : part;
    const next: Json[] = [];
    for (const node of cursor) {
      if (node === null || typeof node !== "object" || Array.isArray(node)) {
        continue;
      }
      const v = (node as { [k: string]: Json })[key];
      if (v === undefined) continue;
      if (spread) {
        if (Array.isArray(v)) next.push(...v);
      } else next.push(v);
    }
    cursor = next;
  }
  return cursor;
}

/** A shifted timestamp as epoch seconds — numbers as-is, ISO-ish strings
 * parsed. Returns null for anything that is not a timestamp. */
function asEpochSeconds(v: Json): number | null {
  if (typeof v === "number") return v;
  if (typeof v === "string") {
    const ms = Date.parse(v);
    return Number.isNaN(ms) ? null : Math.floor(ms / 1000);
  }
  return null;
}

/** Collects every value under a census-"shift" key, at any depth, in a stable
 * traversal order so input and output columns line up. */
function shiftedValues(v: Json, census: ScrubCensus, acc: Json[] = []): Json[] {
  if (v === null || typeof v !== "object") return acc;
  if (Array.isArray(v)) {
    for (const e of v) shiftedValues(e, census, acc);
    return acc;
  }
  for (const [key, value] of Object.entries(v)) {
    if (census[key] === "shift" && value !== null) acc.push(value);
    else shiftedValues(value, census, acc);
  }
  return acc;
}

interface VectorFile {
  section: string;
  // deno-lint-ignore no-explicit-any
  vectors: any[];
}

const file: VectorFile | null = vectorsPath
  ? JSON.parse(Deno.readTextFileSync(vectorsPath))
  : null;

function seededRng(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    // xorshift32 — deterministic, plenty for fuzz jitter
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    s >>>= 0;
    return s / 0xffffffff;
  };
}

function censusFor(vectorId: string): ScrubCensus {
  if (vectorId.startsWith("garmin-")) return GARMIN_SCRUB_CENSUS;
  return TP_SCRUB_CENSUS;
}

function keepEnumFor(vectorId: string): KeepEnum {
  if (vectorId.startsWith("garmin-")) return GARMIN_KEEP_ENUM;
  return TP_KEEP_ENUM;
}

Deno.test({
  name: "vectors: corpus-fingerprint",
  ignore: !file || file.section !== "corpus-fingerprint",
  fn() {
    for (const v of file!.vectors) {
      const { payloadA, payloadB, stratumA, stratumB, optionalKeysInStratum } =
        v.inputs;
      const fpA = fingerprint(
        payloadA as Json,
        stratumA as Stratum,
        optionalKeysInStratum,
      );
      const fpB = fingerprint(
        payloadB as Json,
        stratumB as Stratum,
        optionalKeysInStratum,
      );
      assertEquals(
        fpA === fpB,
        v.expected.sameFingerprint,
        `${v.id}: expected sameFingerprint=${v.expected.sameFingerprint}\n A=${fpA}\n B=${fpB}`,
      );
    }
  },
});

Deno.test({
  name: "vectors: corpus-deid",
  ignore: !file || file.section !== "corpus-deid",
  fn() {
    let checked = 0;
    const vacuousOffsetClauses: string[] = [];
    for (const v of file!.vectors) {
      const input = v.inputs.rawPayload as { [k: string]: Json };
      const census = censusFor(v.id);
      const ctx = newScrubContext(seededRng(0xc0ffee));
      const out = scrub(input, census, ctx, keepEnumFor(v.id)) as {
        [k: string]: Json;
      };
      const e = v.expected;

      // Read the whole contract or fail — never silently skip a clause.
      const unknown = Object.keys(e).filter(
        (k) => !HANDLED_EXPECTATION_KEYS.has(k),
      );
      assertEquals(
        unknown,
        [],
        `${v.id}: expectation key(s) this harness cannot assert — the gate ` +
          `would report green without checking them. Implement them here.`,
      );

      for (const k of e.droppedKeys ?? []) {
        assert(!(k in out), `${v.id}: dropped key '${k}' present in output`);
      }
      assertEquals(
        Object.keys(out).sort(),
        [...(e.keptKeySetVerbatim ?? [])].sort(),
        `${v.id}: kept key set differs`,
      );
      for (const k of e.nullStaysNull ?? []) {
        assertEquals(out[k], null, `${v.id}: '${k}' must stay null`);
      }
      for (const k of e.scalarsMustDiffer ?? []) {
        assertEquals(typeof out[k], typeof input[k], `${v.id}: '${k}' type`);
        assert(out[k] !== input[k], `${v.id}: '${k}' must differ from input`);
      }
      for (const k of e.textPlaceholder ?? []) {
        if (input[k] === null) continue; // null-pattern wins; asserted above
        assertEquals(typeof out[k], "string", `${v.id}: '${k}' placeholder`);
        assert(out[k] !== input[k], `${v.id}: '${k}' must not keep free text`);
      }
      for (const k of e.idsReplacedLinksPreserved ?? []) {
        assertEquals(typeof out[k], typeof input[k], `${v.id}: id '${k}' type`);
        assert(out[k] !== input[k], `${v.id}: id '${k}' must be replaced`);
      }
      // Referential link check: scrub a synthetic parent carrying the child's
      // original parentSummaryId as its own summaryId, with the SAME context —
      // the scrubbed link must land on the same synthetic id.
      if ((e.idsReplacedLinksPreserved ?? []).includes("parentSummaryId")) {
        const parent = scrub(
          { summaryId: input["parentSummaryId"] },
          census,
          ctx,
        ) as { [k: string]: Json };
        assertEquals(
          parent["summaryId"],
          out["parentSummaryId"],
          `${v.id}: parent/child link broken by scrub`,
        );
      }
      for (const pair of e.timestampPairOffsetsSeconds ?? []) {
        // Vector convention: offsetSeconds = between[1] − between[0]
        // (provable from the vectors' own input values).
        const [a, b] = pair.between;
        assertEquals(
          (out[b] as number) - (out[a] as number),
          pair.offsetSeconds,
          `${v.id}: offset ${b}-${a} not preserved`,
        );
        // And the shift actually moved the values off the real epoch.
        assert(out[a] !== input[a], `${v.id}: '${a}' not shifted`);
      }
      for (
        const [k, len] of Object.entries(e.arrayCardinalityVerbatim ?? {})
      ) {
        assertEquals(
          (out[k] as Json[]).length,
          len as number,
          `${v.id}: array '${k}' cardinality`,
        );
      }

      // Default-deny amendment (ruled 2026-09-20, @v1.1).
      for (const k of e.allowlistVerbatim ?? []) {
        assertEquals(
          out[k],
          input[k],
          `${v.id}: KEEP-ENUM '${k}' must survive verbatim`,
        );
      }
      for (const k of e.unclassifiedNotVerbatim ?? []) {
        // A dropped key is trivially not verbatim; a present one must differ.
        if (!(k in out)) continue;
        assert(
          out[k] !== input[k],
          `${v.id}: unclassified '${k}' survived verbatim — default-deny breached`,
        );
      }
      const serialized = JSON.stringify(out);
      for (const needle of e.mustNotContainAnywhere ?? []) {
        assert(
          !serialized.includes(needle),
          `${v.id}: '${needle}' survived somewhere in the scrubbed output`,
        );
      }

      // ---- timestamp shift: ONE context delta, applied to every shifted
      // value at any depth. This is what makes sample cadence survive: if
      // each timestamp moved by its own amount, the stream's spacing would
      // be invented rather than preserved.
      if (e.timestampOffsetsPreserved) {
        const before = shiftedValues(input, census).map(asEpochSeconds);
        const after = shiftedValues(out, census).map(asEpochSeconds);
        assertEquals(
          after.length,
          before.length,
          `${v.id}: shifted-value count changed`,
        );
        // Some vectors carry this clause with no timestamp in the payload —
        // it is trivially satisfied there. Not a failure (the vector is
        // testing something else), but it IS reported, so a clause that
        // checks nothing can never be mistaken for a clause that passed.
        if (before.length === 0) vacuousOffsetClauses.push(v.id);
        const deltas = before.map((b, i) =>
          b === null || after[i] === null ? null : after[i]! - b
        ).filter((d): d is number => d !== null);
        if (before.length > 0) {
          assert(deltas.length > 0, `${v.id}: no parseable timestamps`);
        }
        for (const d of deltas) {
          assertEquals(
            d,
            deltas[0],
            `${v.id}: timestamps moved by DIFFERENT deltas — spacing invented`,
          );
        }
        assert(deltas[0] !== 0, `${v.id}: timestamps were not shifted at all`);
      }

      // ---- GPS is removed at any depth, never fuzzed.
      for (const p of e.gpsDroppedAtAnyDepth ?? []) {
        assert(
          columnAt(input, p).length > 0,
          `${v.id}: vector names '${p}' but the input has none — the check ` +
            `would pass vacuously`,
        );
        assertEquals(
          columnAt(out, p),
          [],
          `${v.id}: GPS path '${p}' survived the scrub`,
        );
      }

      // ---- Q8 sample-stream classes (ruled 2026-09-21).
      // Elapsed clocks ARE the ruled cadence: offsets from start, kept whole.
      for (const p of e.elapsedClocksVerbatim ?? []) {
        const got = columnAt(out, p);
        const want = columnAt(input, p);
        assert(want.length > 0, `${v.id}: '${p}' missing from the input`);
        assertEquals(got, want, `${v.id}: elapsed clock '${p}' was altered`);
      }

      // A cumulative counter loses its magnitude but keeps its ordering —
      // monotone WITHIN a source run, so a genuine reset survives as a reset.
      for (const p of e.cumulativeMonotoneFuzz ?? []) {
        const got = columnAt(out, p) as number[];
        const want = columnAt(input, p) as number[];
        assert(want.length > 1, `${v.id}: '${p}' needs a run to check order`);
        assertEquals(got.length, want.length, `${v.id}: '${p}' cardinality`);
        assertEquals(
          got.map((x) => typeof x),
          want.map((x) => typeof x),
          `${v.id}: '${p}' type not preserved`,
        );
        for (let i = 1; i < want.length; i++) {
          if (want[i] >= want[i - 1]) {
            assert(
              got[i] >= got[i - 1],
              `${v.id}: '${p}' ran backwards at ${i} (${got[i - 1]} -> ${
                got[i]
              }) where the source rose`,
            );
          } else {
            assert(
              got[i] < got[i - 1],
              `${v.id}: '${p}' reset at ${i} was smoothed away — resets are ` +
                `structure`,
            );
          }
        }
        // Magnitude is real disclosure (route length) and must be destroyed.
        // Not element-wise: a legitimately-zero first value emits 0.
        assert(
          JSON.stringify(got) !== JSON.stringify(want),
          `${v.id}: '${p}' survived verbatim — magnitude not destroyed`,
        );
      }

      // Instantaneous readings keep the ordinary random fuzz: every value
      // destroyed, type preserved, no ordering promised.
      for (const p of e.instantaneousSampleFuzz ?? []) {
        const got = columnAt(out, p);
        const want = columnAt(input, p);
        assert(want.length > 0, `${v.id}: '${p}' missing from the input`);
        assertEquals(got.length, want.length, `${v.id}: '${p}' cardinality`);
        for (let i = 0; i < want.length; i++) {
          if (want[i] === null) {
            assertEquals(got[i], null, `${v.id}: '${p}'[${i}] null invented`);
            continue;
          }
          assertEquals(
            typeof got[i],
            typeof want[i],
            `${v.id}: '${p}'[${i}] type not preserved`,
          );
          assert(
            got[i] !== want[i],
            `${v.id}: '${p}'[${i}] survived verbatim (${want[i]})`,
          );
        }
      }
      checked++;
    }
    assertEquals(
      checked,
      file!.vectors.length,
      "every vector must be checked",
    );
    console.log(`   corpus-deid: ${checked}/${file!.vectors.length} vectors`);
    if (vacuousOffsetClauses.length > 0) {
      console.log(
        `   NOTE: timestampOffsetsPreserved is trivially true (no timestamp ` +
          `in the payload) for: ${vacuousOffsetClauses.join(", ")}`,
      );
    }
  },
});
