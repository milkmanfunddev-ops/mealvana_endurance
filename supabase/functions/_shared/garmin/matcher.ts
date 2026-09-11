/**
 * The matcher tier — data-integrations@v1 (spec/integrations/matching.md,
 * RATIFIED Xuan 2026-09-10; M-1.2/M-1.3/M-3 same-day clauses).
 *
 * PURE DECISION LAYER: given an incoming signal and the candidate rows,
 * return what must happen — gate identity AND action — without touching a
 * database. Executors (garmin-push / garmin-ping / the Dart sync services)
 * apply the decision; write-time effects (unique-index 23505, atomic
 * status races) belong to them, never to this layer. The Dart twin is
 * lib/features/integrations/application/matching/match_decider.dart —
 * D-005 discipline: they move together, parity is pinned by the same 41
 * vectors on both sides.
 *
 * Ordered gates (M-1 as re-ruled by M-1.2/M-1.3/M-3, brick per M-5):
 *   0   tombstone T1 (id) — BEFORE the 'other' refusal (ratified asymmetry)
 *   0   tombstone T2 (sport + start ±15 inclusive; skipped for 'other')
 *   1a  'other' refusal — no heuristic matching for sport 'other'
 *   1b  skipped T1 (id — provable fact, no guard) / duplicate check
 *   1b  skipped T2 (sport + ±15 inclusive, guard applies, earliest wins)
 *   brick tiers (B-1 parent / B-2 children / B-2' sequential / B-4
 *       transitions) — attempted when the single-activity tiers miss
 *   1c  planned best-fit (day-wide, guard filters candidates, closest slot
 *       -> duration fit -> earliest slot -> first-created; tz whole-hour
 *       drift scored as probable same-slot, M-1.1)
 *   2   upgrade (M-3/Q-INT24: summary-id-less completed rows, day-wide,
 *       closest start, guard applies)
 *   3   insert ('guard-refused' when the guard alone emptied the tiers)
 *
 * Keyed platform signals (M-1.2 t1/t3, M-1.3): match by plan id with NO
 * threshold; keyed COMPLETION pierces a tombstone (revive-complete) while a
 * keyed PLAN re-import still drops; a late keyed signal on an
 * already-matched day verifies (signature match) or reverts-and-rebinds,
 * the displaced activity re-scoring against remaining open plans.
 *
 * Conventions pinned by the vectors (challengeable only in qa):
 *   ±15 and the 30-min brick gap are INCLUSIVE; the guard refuses
 *   strictly-below (measured < 20% of planned OR < 2 min); full best-fit
 *   tie falls to earliest slot then first-created; times compare as
 *   matcher-resolved instants while STORAGE stays naive local (L-9.2).
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface MatcherIncomingActivity {
  summaryId: string | null;
  sport: string; // our sport enum: running/cycling/swimming/multisport/…/other/transition
  startMs: number; // matcher-resolved instant (naive local parsed as UTC)
  durationMin: number;
  parentSummaryId?: string | null;
  isParent?: boolean;
}

export interface MatcherIncomingGarmin extends MatcherIncomingActivity {
  kind: "garmin";
}

export interface MatcherIncomingSequence {
  kind: "garmin-sequence";
  activities: MatcherIncomingActivity[];
  /** When the MULTI_SPORT parent already matched a brick row (B-2). */
  parentMatchedRowId?: string;
}

export interface MatcherIncomingKeyed {
  kind: "keyed";
  provider: string;
  planId: string; // provider_workout_id
  signalKind: "completion" | "planned-import";
  sport: string;
  startMs: number;
  durationMin: number;
}

export type MatcherIncoming =
  | MatcherIncomingGarmin
  | MatcherIncomingSequence
  | MatcherIncomingKeyed;

export interface MatcherSegment {
  order: number; // 1-based
  sport: string;
  durationMin: number | null;
  /** garmin summary id already stamped on this leg, if any (B-5). */
  stampedSummaryId?: string | null;
  /** projected end instant of the stamped leg (chain-gap checks). */
  stampedEndMs?: number;
}

export interface MatcherCandidate {
  rowId: string;
  status: string; // planned/draft/skipped/completed/deleted/…
  sport: string;
  slotMs: number | null; // scheduled_date_time as instant
  garminSummaryId: string | null;
  providerWorkoutId: string | null;
  deletedAt: boolean; // true when soft-deleted timestamp present
  plannedDurationMin: number | null;
  /** For completed rows: the recorded/matched duration. */
  recordedDurationMin: number | null;
  /** For completed rows matched heuristically: measured start instant. */
  matchedStartMs: number | null;
  createdOrder: number;
  /** Brick rows only. */
  segments: MatcherSegment[] | null;
  totalDurationMin: number | null;
  /** Brick rows: parent summary id already stamped (B-1/B-2'). */
  parentStampSummaryId?: string | null;
}

export interface MatchDecision {
  gate: string;
  action: string;
  matchedRowId?: string;
  insertedSport?: string;
  parentVerified?: boolean;
  legStamps?: Record<string, string>;
  reboundPlanId?: string;
  displacedRescoredTo?: string;
  standaloneRow?: boolean;
  notes?: string[];
}

// ---------------------------------------------------------------------------
// Shared constants + helpers
// ---------------------------------------------------------------------------

const MIN_MS = 60_000;
/** ±15 min tombstone/skipped window — INCLUSIVE (vector-pinned). */
const NARROW_WINDOW_MIN = 15;
/** B-2' inter-leg gap tolerance — INCLUSIVE (vector-pinned). */
const BRICK_GAP_MIN = 30;
/** Measured-signature tolerances (M-1.1): start ~1–2 min, duration a few %. */
const SIGNATURE_START_TOLERANCE_MIN = 2;
const SIGNATURE_DURATION_TOLERANCE_PCT = 0.05;
/** Duration tolerance for the whole-hour timezone-drift heuristic. */
const TZ_DRIFT_DURATION_TOLERANCE_PCT = 0.10;

const MATCHABLE_STATUSES = new Set(["planned", "draft", "skipped"]);
const BRICK_EQUIVALENT_SPORTS = new Set([
  "multisport",
  "triathlon",
  "duathlon",
]);

/**
 * The plausibility guard (M-1.1 / Q-INT21, DI-2): refuse when measured
 * duration < 20% of planned (strictly) OR < 2 min absolute (strictly).
 * Both are independent refusals; a missing planned duration cannot refuse.
 * Applies to planned, skipped-T2 and upgrade tiers — never to id-keyed
 * tiers (the id is provable fact, M-1.3).
 */
export function guardRefuses(
  measuredMin: number,
  plannedMin: number | null,
): boolean {
  if (measuredMin < 2) return true;
  if (plannedMin != null && plannedMin > 0 && measuredMin / plannedMin < 0.2) {
    return true;
  }
  return false;
}

function sameLocalDay(aMs: number, bMs: number): boolean {
  return new Date(aMs).toISOString().slice(0, 10) ===
    new Date(bMs).toISOString().slice(0, 10);
}

function absMin(aMs: number, bMs: number): number {
  return Math.abs(aMs - bMs) / MIN_MS;
}

/**
 * M-1.1 timezone defense: durations match within tolerance and starts
 * differ by an exact whole-hour (or half-hour) multiple -> probable tz
 * drift, scored as a same-slot match rather than rejected.
 */
export function isProbableTzDrift(
  deltaMin: number,
  measuredMin: number,
  candidateMin: number | null,
): boolean {
  if (deltaMin < 29) return false; // a real sub-half-hour delta is just a delta
  if (candidateMin == null || candidateMin <= 0) return false;
  const durationOff = Math.abs(measuredMin - candidateMin) /
    Math.max(measuredMin, candidateMin);
  if (durationOff > TZ_DRIFT_DURATION_TOLERANCE_PCT) return false;
  const remainder = deltaMin % 30;
  return remainder < 1 || remainder > 29;
}

function signatureMatches(
  aStartMs: number,
  aDurationMin: number,
  bStartMs: number | null,
  bDurationMin: number | null,
): boolean {
  if (bStartMs == null || bDurationMin == null) return false;
  if (absMin(aStartMs, bStartMs) > SIGNATURE_START_TOLERANCE_MIN) return false;
  const durOff = Math.abs(aDurationMin - bDurationMin) /
    Math.max(aDurationMin, bDurationMin, 1);
  return durOff <= SIGNATURE_DURATION_TOLERANCE_PCT;
}

// ---------------------------------------------------------------------------
// Garmin single-activity decision
// ---------------------------------------------------------------------------

function decideGarminSingle(
  incoming: MatcherIncomingActivity,
  candidates: MatcherCandidate[],
): MatchDecision {
  const { summaryId, sport, startMs, durationMin } = incoming;
  let guardEliminated = false;

  // Gate 0 — tombstone T1 (id tier runs before the 'other' refusal).
  if (summaryId) {
    const t1 = candidates.find(
      (c) => c.status === "deleted" && c.garminSummaryId === summaryId,
    );
    if (t1) return { gate: "tombstone-T1", action: "drop" };
  }

  // Gate 0 — tombstone T2 (skipped for sport 'other').
  if (sport !== "other" && sport !== "transition") {
    const t2 = candidates.find(
      (c) =>
        c.status === "deleted" &&
        c.sport === sport &&
        c.slotMs != null &&
        absMin(c.slotMs, startMs) <= NARROW_WINDOW_MIN,
    );
    if (t2) return { gate: "tombstone-T2", action: "drop" };
  }

  // B-4 — transitions never become standalone rows.
  if (sport === "transition") {
    const brick = candidates.find((c) => c.sport === "brick");
    if (brick) {
      return {
        gate: "transition-folded",
        action: "fold-metadata",
        matchedRowId: brick.rowId,
        standaloneRow: false,
      };
    }
    return { gate: "transition-dropped", action: "noop", standaloneRow: false };
  }

  // Gate 1a — 'other' refusal: no heuristic matching at all.
  if (sport === "other") {
    const hadMatchableCandidate = candidates.some((c) =>
      MATCHABLE_STATUSES.has(c.status)
    );
    return {
      gate: hadMatchableCandidate ? "other-refusal" : "insert",
      action: "insert",
      insertedSport: "other",
    };
  }

  // Child leg of an already-stamped brick (B-5): the brick owns the leg.
  if (summaryId) {
    const stampedOwner = candidates.find((c) =>
      c.segments?.some((s) => s.stampedSummaryId === summaryId)
    );
    if (stampedOwner) return { gate: "duplicate", action: "noop" };
    // A non-deleted row already carrying this summary id: re-push (executors
    // enrich; the decision is a no-op duplicate). Skipped rows fall through
    // to skipped-T1 below, which completes them (sync beats skip).
    const owner = candidates.find(
      (c) =>
        c.garminSummaryId === summaryId &&
        c.status !== "deleted" &&
        c.status !== "skipped",
    );
    if (owner) return { gate: "duplicate", action: "noop" };
  }

  // Gate 1b — skipped T1 (id = provable fact; no window, no guard).
  if (summaryId) {
    const s1 = candidates.find(
      (c) => c.status === "skipped" && c.garminSummaryId === summaryId,
    );
    if (s1) {
      return { gate: "skipped-T1", action: "complete", matchedRowId: s1.rowId };
    }
  }

  // Gate 1b — skipped T2 (±15 inclusive, guard applies, earliest wins).
  {
    const inWindow = candidates.filter(
      (c) =>
        c.status === "skipped" &&
        c.sport === sport &&
        !c.deletedAt &&
        c.slotMs != null &&
        absMin(c.slotMs, startMs) <= NARROW_WINDOW_MIN,
    );
    const survivors = inWindow.filter((c) => {
      const refused = guardRefuses(durationMin, c.plannedDurationMin);
      if (refused) guardEliminated = true;
      return !refused;
    });
    if (survivors.length > 0) {
      const winner = [...survivors].sort(
        (a, b) => (a.slotMs ?? 0) - (b.slotMs ?? 0),
      )[0];
      return {
        gate: "skipped-T2",
        action: "complete",
        matchedRowId: winner.rowId,
      };
    }
  }

  // B-1 — MULTI_SPORT parent completes a planned brick (sport equivalence,
  // guard vs the brick's total planned duration).
  if (BRICK_EQUIVALENT_SPORTS.has(sport)) {
    const bricks = candidates.filter(
      (c) =>
        c.sport === "brick" &&
        MATCHABLE_STATUSES.has(c.status) &&
        !c.deletedAt &&
        (c.slotMs == null || sameLocalDay(c.slotMs, startMs)),
    );
    const survivors = bricks.filter((c) => {
      const refused = guardRefuses(durationMin, c.totalDurationMin);
      if (refused) guardEliminated = true;
      return !refused;
    });
    if (survivors.length > 0) {
      const winner = survivors[0];
      return {
        gate: "brick-parent",
        action: "complete",
        matchedRowId: winner.rowId,
        parentVerified: false, // verified awaits B-2 leg matches
      };
    }
  }

  // B-2'/B-2 — a single arriving leg may extend (or start) a planned
  // brick's leg chain when the single-activity planned tier has no match.
  // Attempted before 1c only when the leg carries a parentSummaryId (a
  // multisport child is never a standalone session); sequential legs
  // without lineage try the planned tier first (Q-INT22 sequencing:
  // "brick-sequence match is attempted only if the single-activity gates
  // found no match").
  const brickLeg = (): MatchDecision | null => {
    const bricks = candidates.filter(
      (c) =>
        c.sport === "brick" &&
        !c.deletedAt &&
        c.segments != null &&
        (MATCHABLE_STATUSES.has(c.status) || c.status === "completed"),
    );
    for (const brick of bricks) {
      const result = tryExtendBrickChain(brick, incoming);
      if (result) return result;
    }
    return null;
  };

  if (incoming.parentSummaryId) {
    const viaLineage = brickLeg();
    if (viaLineage) return viaLineage;
  }

  // Gate 1c — planned best-fit (day-wide, guard filters candidates).
  {
    const dayCandidates = candidates.filter(
      (c) =>
        (c.status === "planned" || c.status === "draft") &&
        c.sport === sport &&
        !c.deletedAt &&
        c.slotMs != null &&
        sameLocalDay(c.slotMs, startMs),
    );
    const survivors = dayCandidates.filter((c) => {
      const refused = guardRefuses(durationMin, c.plannedDurationMin);
      if (refused) guardEliminated = true;
      return !refused;
    });
    if (survivors.length > 0) {
      const winner = pickBestFit(survivors, startMs, durationMin);
      return {
        gate: "planned",
        action: "complete",
        matchedRowId: winner.rowId,
      };
    }
  }

  // Sequential brick leg without lineage: only now that 1b/1c missed.
  {
    const viaSequence = brickLeg();
    if (viaSequence) return viaSequence;
  }

  // Gate 2 — upgrade (M-3/Q-INT24): summary-id-less completed rows,
  // day-wide, closest start wins, guard vs the recorded duration.
  {
    const upgradeTargets = candidates.filter(
      (c) =>
        c.status === "completed" &&
        c.garminSummaryId == null &&
        c.sport === sport &&
        !c.deletedAt &&
        c.slotMs != null &&
        sameLocalDay(c.slotMs, startMs),
    );
    const survivors = upgradeTargets.filter((c) => {
      const refused = guardRefuses(
        durationMin,
        c.recordedDurationMin ?? c.plannedDurationMin,
      );
      if (refused) guardEliminated = true;
      return !refused;
    });
    if (survivors.length > 0) {
      const winner = [...survivors].sort(
        (a, b) => absMin(a.slotMs!, startMs) - absMin(b.slotMs!, startMs),
      )[0];
      return { gate: "upgrade", action: "upgrade", matchedRowId: winner.rowId };
    }
  }

  // Gate 3 — insert; 'guard-refused' when the guard alone emptied a tier.
  return {
    gate: guardEliminated ? "guard-refused" : "insert",
    action: "insert",
    insertedSport: sport,
  };
}

/**
 * M-1.2 t2 best-fit: closest planned slot to measured start first (with
 * whole-hour tz drift scored as same-slot), duration fit second, then
 * earliest slot, then first-created. Never a user prompt.
 */
function pickBestFit(
  survivors: MatcherCandidate[],
  startMs: number,
  durationMin: number,
): MatcherCandidate {
  const scored = survivors.map((c) => {
    let slotDistance = c.slotMs != null ? absMin(c.slotMs, startMs) : Infinity;
    if (
      c.slotMs != null &&
      isProbableTzDrift(slotDistance, durationMin, c.plannedDurationMin)
    ) {
      slotDistance = 0;
    }
    const durationFit = c.plannedDurationMin != null &&
        c.plannedDurationMin > 0
      ? Math.abs(1 - durationMin / c.plannedDurationMin)
      : Infinity;
    return { c, slotDistance, durationFit };
  });
  scored.sort((a, b) => {
    if (a.slotDistance !== b.slotDistance) {
      return a.slotDistance - b.slotDistance;
    }
    if (a.durationFit !== b.durationFit) return a.durationFit - b.durationFit;
    const aSlot = a.c.slotMs ?? Infinity;
    const bSlot = b.c.slotMs ?? Infinity;
    if (aSlot !== bSlot) return aSlot - bSlot;
    return a.c.createdOrder - b.c.createdOrder;
  });
  return scored[0].c;
}

/**
 * B-2'/B-2 single-leg step: does `incoming` continue this brick's leg
 * chain? The chain state is the stamps already on `segments[]`; the next
 * expected segment is the first unstamped one. Checks, per the ruling:
 * sport equality with the expected segment (R8 positional identity), the
 * ≤30-min inclusive gap from the previous leg's projected end (first leg:
 * same local day instead), and the M-1.1 guard vs the segment's planned
 * duration.
 */
function tryExtendBrickChain(
  brick: MatcherCandidate,
  incoming: MatcherIncomingActivity,
): MatchDecision | null {
  const segments = [...(brick.segments ?? [])].sort(
    (a, b) => a.order - b.order,
  );
  if (segments.length === 0) return null;

  const nextIndex = segments.findIndex((s) => !s.stampedSummaryId);
  if (nextIndex === -1) return null; // fully stamped: dup handled upstream
  const expected = segments[nextIndex];
  if (expected.sport !== incoming.sport) return null;

  // Lineage check for the multisport path: a child leg must reference the
  // parent stamped on this brick (when both sides carry lineage).
  if (
    incoming.parentSummaryId &&
    brick.parentStampSummaryId &&
    incoming.parentSummaryId !== brick.parentStampSummaryId
  ) {
    return null;
  }

  if (nextIndex === 0) {
    if (brick.slotMs != null && !sameLocalDay(brick.slotMs, incoming.startMs)) {
      return null;
    }
  } else {
    const prev = segments[nextIndex - 1];
    const prevEndMs = prev.stampedEndMs;
    if (prevEndMs == null) return null;
    const gapMin = (incoming.startMs - prevEndMs) / MIN_MS;
    if (gapMin < 0 || gapMin > BRICK_GAP_MIN) return null;
  }

  if (guardRefuses(incoming.durationMin, expected.durationMin)) return null;

  // Stamp (decision-level): report the new chain state.
  const stamps: Record<string, string> = {};
  for (const s of segments) {
    if (s.stampedSummaryId) stamps[String(s.order)] = s.stampedSummaryId;
  }
  if (incoming.summaryId) {
    stamps[String(expected.order)] = incoming.summaryId;
  }
  const allStamped = segments.every(
    (s) => s.order === expected.order || s.stampedSummaryId,
  );
  return {
    gate: allStamped ? "brick-sequential" : "brick-partial",
    action: "complete",
    matchedRowId: brick.rowId,
    parentVerified: allStamped,
    legStamps: stamps,
  };
}

// ---------------------------------------------------------------------------
// Garmin sequence decision (B-2' / B-2 over a set of arrivals)
// ---------------------------------------------------------------------------

function decideGarminSequence(
  incoming: MatcherIncomingSequence,
  candidates: MatcherCandidate[],
): MatchDecision {
  const activities = [...incoming.activities].sort(
    (a, b) => a.startMs - b.startMs,
  );

  // B-2: children of an already-matched parent match positionally by sport
  // order via parentSummaryId.
  if (incoming.parentMatchedRowId) {
    const brick = candidates.find(
      (c) => c.rowId === incoming.parentMatchedRowId,
    );
    if (brick?.segments) {
      const segments = [...brick.segments].sort((a, b) => a.order - b.order);
      const endurance = segments.filter((s) => s.sport !== "transition");
      const stamps: Record<string, string> = {};
      let position = 0;
      for (const child of activities) {
        if (position >= endurance.length) break;
        if (endurance[position].sport !== child.sport) {
          return {
            gate: "brick-not-matched",
            action: "per-activity-gates",
            parentVerified: false,
          };
        }
        if (child.summaryId) {
          stamps[String(endurance[position].order)] = child.summaryId;
        }
        position++;
      }
      const allStamped = endurance.every((s) =>
        stamps[String(s.order)] != null || s.stampedSummaryId != null
      );
      return {
        gate: "brick-children",
        action: "complete",
        matchedRowId: brick.rowId,
        parentVerified: allStamped,
        legStamps: stamps,
      };
    }
  }

  // B-2': sequential independent completed activities verify a planned
  // brick when sports-in-start-order equal segment order, every
  // consecutive gap is ≤ 30 min (inclusive), and each leg passes the
  // guard against its segment.
  const bricks = candidates.filter(
    (c) =>
      c.sport === "brick" &&
      MATCHABLE_STATUSES.has(c.status) &&
      !c.deletedAt &&
      c.segments != null,
  );
  for (const brick of bricks) {
    const segments = [...(brick.segments ?? [])].sort(
      (a, b) => a.order - b.order,
    );
    const endurance = segments.filter((s) => s.sport !== "transition");
    if (activities.length > endurance.length) continue;

    let ok = true;
    const stamps: Record<string, string> = {};
    for (let i = 0; i < activities.length; i++) {
      const leg = activities[i];
      const segment = endurance[i];
      if (segment.sport !== leg.sport) {
        ok = false;
        break;
      }
      if (i === 0) {
        if (brick.slotMs != null && !sameLocalDay(brick.slotMs, leg.startMs)) {
          ok = false;
          break;
        }
      } else {
        const prev = activities[i - 1];
        const gapMin =
          (leg.startMs - (prev.startMs + prev.durationMin * MIN_MS)) / MIN_MS;
        if (gapMin < 0 || gapMin > BRICK_GAP_MIN) {
          ok = false;
          break;
        }
      }
      if (guardRefuses(leg.durationMin, segment.durationMin)) {
        ok = false;
        break;
      }
      if (leg.summaryId) stamps[String(segment.order)] = leg.summaryId;
    }

    if (!ok) continue;

    const allMatched = activities.length === endurance.length;
    return {
      gate: allMatched ? "brick-sequential" : "brick-partial",
      action: "complete",
      matchedRowId: brick.rowId,
      parentVerified: allMatched,
      legStamps: stamps,
    };
  }

  // No brick chain: each activity belongs to the normal single gates.
  return {
    gate: "brick-not-matched",
    action: "per-activity-gates",
    parentVerified: false,
  };
}

// ---------------------------------------------------------------------------
// Keyed platform signals (M-1.2 t1/t3, M-1.3)
// ---------------------------------------------------------------------------

function decideKeyed(
  incoming: MatcherIncomingKeyed,
  candidates: MatcherCandidate[],
): MatchDecision {
  const keyed = candidates.find(
    (c) => c.providerWorkoutId === incoming.planId,
  );

  if (!keyed) {
    // No row carries the plan id: a planned import is a normal new import;
    // a completion signal with no plan row inserts its own completed row.
    return { gate: "insert", action: "insert", insertedSport: incoming.sport };
  }

  if (keyed.status === "deleted") {
    // M-1.3 provable-fact primacy: only proven completion pierces the
    // tombstone; a plan re-import (keyed or not) still drops.
    if (incoming.signalKind === "completion") {
      return {
        gate: "keyed-over-tombstone",
        action: "revive-complete",
        matchedRowId: keyed.rowId,
      };
    }
    return { gate: "tombstone-T1", action: "drop" };
  }

  if (MATCHABLE_STATUSES.has(keyed.status)) {
    // t1: the id is certainty — NO plausibility threshold.
    return {
      gate: "platform-keyed",
      action: "complete",
      matchedRowId: keyed.rowId,
    };
  }

  if (keyed.status === "completed") {
    // t3: late keyed signal on an already-matched day — verification.
    if (
      signatureMatches(
        incoming.startMs,
        incoming.durationMin,
        keyed.matchedStartMs,
        keyed.recordedDurationMin,
      )
    ) {
      return {
        gate: "verify-confirm",
        action: "noop",
        matchedRowId: keyed.rowId,
      };
    }
    // Mismatch: revert the heuristic match and rebind per the keyed
    // evidence; the displaced measured activity re-scores against the
    // remaining open plans (best-fit, guard applies).
    const displacedStartMs = keyed.matchedStartMs;
    const displacedDurationMin = keyed.recordedDurationMin;
    let displacedRescoredTo: string | undefined;
    if (displacedStartMs != null && displacedDurationMin != null) {
      const open = candidates.filter(
        (c) =>
          c.rowId !== keyed.rowId &&
          (c.status === "planned" || c.status === "draft") &&
          c.sport === keyed.sport &&
          !c.deletedAt &&
          c.slotMs != null &&
          sameLocalDay(c.slotMs, displacedStartMs) &&
          !guardRefuses(displacedDurationMin, c.plannedDurationMin),
      );
      if (open.length > 0) {
        displacedRescoredTo = pickBestFit(
          open,
          displacedStartMs,
          displacedDurationMin,
        ).rowId;
      }
    }
    return {
      gate: "revert-rebind",
      action: "rebind",
      reboundPlanId: incoming.planId,
      displacedRescoredTo,
    };
  }

  return { gate: "insert", action: "insert", insertedSport: incoming.sport };
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export function decideMatch(
  incoming: MatcherIncoming,
  candidates: MatcherCandidate[],
): MatchDecision {
  switch (incoming.kind) {
    case "garmin":
      return decideGarminSingle(incoming, candidates);
    case "garmin-sequence":
      return decideGarminSequence(incoming, candidates);
    case "keyed":
      return decideKeyed(incoming, candidates);
  }
}
