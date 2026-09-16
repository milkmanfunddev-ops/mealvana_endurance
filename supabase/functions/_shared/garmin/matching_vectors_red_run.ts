/**
 * Stage B red-first run — data-integrations@v1 (MANDATORY, per the bundle
 * manifest: "building it and proving it RED against today's earliest-first
 * matcher is Stage B's first task").
 *
 * Drives TODAY'S matcher code — the real exported functions from
 * activity_completion.ts, orchestrated exactly as garmin-push does per
 * activity (tombstone gate -> planned/skipped match -> atomic completion
 * update -> auto-insert) — against the 41 ratified matching vectors, and
 * reports which contract clauses today's code already satisfies (GREEN)
 * and which it cannot (RED). A harness born green proves nothing; this run
 * is the evidence that the harness sees current behavior.
 *
 * The observed gate vocabulary is derived from OBSERVABLE effects only:
 *   - tombstone reason string  -> tombstone-T1 / tombstone-T2
 *   - matched row's prior state -> skipped-T1 / skipped-T2 / planned
 *   - insert with sport 'other' while a matchable candidate existed
 *                              -> other-refusal (1a refusal is what stopped it)
 *   - insert outcomes          -> insert / duplicate
 *   - triggers today's code has NO path for (platform-keyed, upgrade,
 *     brick, guard) simply produce whatever the legacy pipeline does —
 *     that is the point of the run.
 *
 * Usage:
 *   deno run --allow-read supabase/functions/_shared/garmin/matching_vectors_red_run.ts
 */

import {
  buildGarminCompletionUpdate,
  findMatchingPlannedActivity,
  findMatchingTombstone,
  GARMIN_COMPLETABLE_STATUSES,
  insertGarminActivityIfMissing,
} from "./activity_completion.ts";
import { mapGarminActivityToActivity, mapGarminSportType } from "./mappers.ts";
import type { GarminActivitySummary } from "./types.ts";
import {
  compareDecision,
  defaultVectorsPath,
  FAKE_USER_ID,
  FakeDb,
  formatResult,
  loadMatchingVectors,
  naiveLocalToEpochSeconds,
  type ObservedDecision,
  rowsFromCandidates,
  type VectorIncomingActivity,
} from "./matching_vectors_harness.ts";

/** Vector sport -> a Garmin activityType string that today's map resolves
 * to that sport (or, for 'other', to the unmapped fallback). */
const SPORT_TO_GARMIN_TYPE: Record<string, string> = {
  running: "running",
  cycling: "cycling",
  swimming: "lap_swimming",
  multisport: "multi_sport",
  other: "strength_training", // any unmapped type -> 'other'
};

function toGarminSummary(a: VectorIncomingActivity): GarminActivitySummary {
  const activityType = a.activityType ??
    SPORT_TO_GARMIN_TYPE[a.sport ?? "other"] ?? "strength_training";
  return {
    userId: "garmin-user-1",
    userAccessToken: "",
    summaryId: a.summaryId ?? "no-summary-id",
    activityType,
    startTimeInSeconds: naiveLocalToEpochSeconds(a.startLocal),
    startTimeOffsetInSeconds: 0,
    durationInSeconds: Math.round(a.durationMin * 60),
    parentSummaryId: a.parentSummaryId,
    isParent: a.isParent,
  } as GarminActivitySummary;
}

/** One activity through today's garmin-push per-activity pipeline. */
async function legacyPipelineOne(
  db: FakeDb,
  a: VectorIncomingActivity,
): Promise<ObservedDecision> {
  const activity = toGarminSummary(a);
  const sportType = mapGarminSportType(activity.activityType);
  const summaryId = activity.summaryId != null
    ? String(activity.summaryId)
    : null;

  const tombstone = await findMatchingTombstone(
    db,
    FAKE_USER_ID,
    sportType,
    activity,
    summaryId,
  );
  if (tombstone) {
    return {
      gate: tombstone.reason.includes("summary id")
        ? "tombstone-T1"
        : "tombstone-T2",
      action: "drop",
    };
  }

  const matched = await findMatchingPlannedActivity(
    db,
    FAKE_USER_ID,
    sportType,
    activity,
    summaryId,
  );

  if (matched) {
    const row = db.get(matched.id);
    const priorStatus = row?.status;
    const priorSummary = row?.garmin_summary_id;
    const gate = priorStatus === "skipped"
      ? (priorSummary === summaryId ? "skipped-T1" : "skipped-T2")
      : "planned";

    const mapped = mapGarminActivityToActivity(activity, FAKE_USER_ID);
    const updateFields = buildGarminCompletionUpdate(activity, mapped);
    updateFields.garmin_summary_id = summaryId;
    const { data: updatedRows } = await db
      .from("activities")
      .update(updateFields)
      .eq("id", matched.id)
      .in("status", GARMIN_COMPLETABLE_STATUSES)
      .select("id");
    if (!updatedRows || updatedRows.length === 0) {
      return { gate: "duplicate", action: "noop" };
    }
    return { gate, action: "complete", matchedRowId: matched.id };
  }

  // Fall-through: auto-insert, exactly as garmin-push does.
  const hadMatchableCandidate = db.rows.some((r) =>
    ["planned", "draft", "skipped"].includes(r.status)
  );
  const mapped = mapGarminActivityToActivity(activity, FAKE_USER_ID);
  const outcome = await insertGarminActivityIfMissing(db, activity, mapped);
  switch (outcome.kind) {
    case "inserted":
      return {
        gate: sportType === "other" && hadMatchableCandidate
          ? "other-refusal"
          : "insert",
        action: "insert",
        insertedSport: sportType,
      };
    case "duplicate":
      return { gate: "duplicate", action: "noop" };
    case "skipped_non_endurance":
      return {
        gate: "transition-skipped",
        action: "noop",
        notes: [`legacy skipped non-endurance sport ${outcome.sportType}`],
      };
    default:
      return { gate: "error", action: "none", notes: [outcome.kind] };
  }
}

async function runVector(
  db: FakeDb,
  incoming: import("./matching_vectors_harness.ts").VectorIncoming,
): Promise<ObservedDecision> {
  if (incoming.source === "platform") {
    // Today's matcher tier has NO platform-keyed path at all: TP/FS imports
    // land planned via change detection; no completion signal is consumed.
    return {
      gate: "none",
      action: "none",
      notes: ["no keyed-completion path exists in today's matcher tier"],
    };
  }
  if (incoming.sequence) {
    // Legacy has no sequence concept: each activity runs the single pipeline
    // in arrival order; report the first activity's decision (the vectors
    // expect ONE brick decision, so any per-activity outcome is a mismatch).
    const decisions: ObservedDecision[] = [];
    for (const a of incoming.sequence) {
      decisions.push(await legacyPipelineOne(db, a));
    }
    const first = decisions[0];
    first.notes = [
      ...(first.notes ?? []),
      `legacy processed ${decisions.length} activities independently: ${
        decisions.map((d) => `${d.gate}/${d.action}`).join(", ")
      }`,
    ];
    return first;
  }
  return await legacyPipelineOne(db, incoming);
}

if (import.meta.main) {
  const vectors = loadMatchingVectors(defaultVectorsPath());
  let green = 0;
  let red = 0;
  const lines: string[] = [];
  for (const v of vectors) {
    const db = new FakeDb(rowsFromCandidates(v.inputs.candidates));
    const observed = await runVector(db, v.inputs.incoming);
    const mismatches = compareDecision(v.expected, observed);
    if (mismatches.length === 0) green++;
    else red++;
    lines.push(formatResult(v.id, mismatches, observed.notes));
  }
  console.log(
    `Stage B red-first run — matching vectors vs TODAY'S matcher tier`,
  );
  console.log(
    `vectors: ${vectors.length}  GREEN: ${green}  RED: ${red}\n`,
  );
  for (const l of lines) console.log(l);
}
