/**
 * Matcher-tier conformance — the 41 ratified matching vectors against the
 * decision tier (matcher.ts). Stage B green gate for data-integrations@v1.
 *
 * The vectors are the authority (docs/ssot/vectors/integrations/
 * matching.json @ tag data-integrations@v1); this file only translates
 * vector JSON into MatcherIncoming/MatcherCandidate shapes. Harness
 * co-evolution is expected by the vectors' own note; the single
 * interpretation this translation adds is the `context` line on
 * brick-b5-no-double-import ("parent gbP already matched BR1 and leg 1
 * already stamped gbC1"), which becomes stamp state on the brick
 * candidate — the stamp storage itself is implementation freedom
 * (Q-INT23: column or brick_metadata).
 */

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  decideMatch,
  type MatcherCandidate,
  type MatcherIncoming,
  type MatcherIncomingActivity,
} from "./matcher.ts";
import {
  compareDecision,
  defaultVectorsPath,
  loadMatchingVectors,
  naiveLocalToEpochSeconds,
  type MatchingVector,
  type VectorCandidate,
  type VectorIncoming,
  type VectorIncomingActivity,
} from "./matching_vectors_harness.ts";

function toMs(naive: string): number {
  return naiveLocalToEpochSeconds(naive) * 1000;
}

function toIncomingActivity(
  a: VectorIncomingActivity,
): MatcherIncomingActivity {
  return {
    summaryId: a.summaryId ?? null,
    sport: a.sport ?? "other",
    startMs: toMs(a.startLocal),
    durationMin: a.durationMin,
    parentSummaryId: a.parentSummaryId ?? null,
    isParent: a.isParent,
  };
}

function toIncoming(incoming: VectorIncoming): MatcherIncoming {
  if (incoming.source === "platform") {
    return {
      kind: "keyed",
      provider: incoming.provider ?? "unknown",
      planId: incoming.planId ?? "",
      signalKind: incoming.signalKind ?? "completion",
      sport: incoming.sport ?? "other",
      startMs: toMs(incoming.startLocal),
      durationMin: incoming.durationMin,
    };
  }
  if (incoming.sequence) {
    return {
      kind: "garmin-sequence",
      activities: incoming.sequence.map(toIncomingActivity),
      parentMatchedRowId: incoming.parentMatchedRowId,
    };
  }
  return { kind: "garmin", ...toIncomingActivity(incoming) };
}

function toCandidate(c: VectorCandidate): MatcherCandidate {
  return {
    rowId: c.rowId,
    status: c.status,
    sport: c.sport,
    slotMs: c.slotLocal
      ? toMs(c.slotLocal)
      : c.segments
      ? toMs("2026-09-10T07:00") // brick vectors omit the slot; same-day default
      : c.matchedStartLocal
      ? toMs(c.matchedStartLocal)
      : null,
    garminSummaryId: c.garminSummaryId ?? null,
    providerWorkoutId: c.providerWorkoutId ?? null,
    deletedAt: c.status === "deleted",
    plannedDurationMin: c.plannedDurationMin ?? null,
    recordedDurationMin: c.recordedDurationMin ?? c.matchedDurationMin ?? null,
    matchedStartMs: c.matchedStartLocal ? toMs(c.matchedStartLocal) : null,
    createdOrder: c.createdOrder ?? 0,
    segments: c.segments
      ? c.segments.map((s) => ({
        order: s.order,
        sport: s.sport,
        durationMin: s.durationMin,
      }))
      : null,
    totalDurationMin: c.totalDurationMin ?? null,
  };
}

/** Translate a vector `context` prose line into candidate state. */
function applyContext(
  vector: MatchingVector,
  candidates: MatcherCandidate[],
): void {
  const context = vector.inputs.incoming.context;
  if (!context) return;
  const parentMatch = context.match(/parent (\S+) already matched (\S+)/);
  const legMatch = context.match(/leg (\d+) already stamped (\S+)/);
  if (!parentMatch) return;
  const [, parentSummaryId, rowId] = parentMatch;
  const brick = candidates.find((c) => c.rowId === rowId);
  if (!brick) return;
  brick.parentStampSummaryId = parentSummaryId;
  if (legMatch && brick.segments) {
    const [, orderStr, stamp] = legMatch;
    const segment = brick.segments.find((s) => s.order === Number(orderStr));
    if (segment) segment.stampedSummaryId = stamp;
  }
}

const vectors = loadMatchingVectors(defaultVectorsPath());

Deno.test("matching vectors — 41 present at the pinned tag", () => {
  assertEquals(vectors.length, 41);
});

for (const vector of vectors) {
  Deno.test(`matching vector: ${vector.id}`, () => {
    const candidates = vector.inputs.candidates.map(toCandidate);
    applyContext(vector, candidates);
    const observed = decideMatch(toIncoming(vector.inputs.incoming), candidates);
    const mismatches = compareDecision(vector.expected, observed);
    assertEquals(
      mismatches,
      [],
      `${vector.id}: ${mismatches.join("; ")}\nwhy: ${vector.why}`,
    );
  });
}
