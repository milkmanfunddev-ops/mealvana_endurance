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
  GARMIN_SCRUB_CENSUS,
  newScrubContext,
  scrub,
  type ScrubCensus,
  TP_SCRUB_CENSUS,
} from "../_shared/corpus/scrub.ts";

const vectorsPath = Deno.env.get("QA_VECTORS");

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
    for (const v of file!.vectors) {
      const input = v.inputs.rawPayload as { [k: string]: Json };
      const census = censusFor(v.id);
      const ctx = newScrubContext(seededRng(0xc0ffee));
      const out = scrub(input, census, ctx) as { [k: string]: Json };
      const e = v.expected;

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
    }
  },
});
