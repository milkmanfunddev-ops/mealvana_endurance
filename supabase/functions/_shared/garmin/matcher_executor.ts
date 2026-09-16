/**
 * Matcher-tier executor — data-integrations@v1 Stage B.
 *
 * Bridges the pure decision layer (matcher.ts) to the database: fetches
 * the candidate rows for an inbound Garmin activity, asks decideMatch()
 * what must happen, and applies it. garmin-push and garmin-ping both call
 * runGarminActivityPipeline() — one pipeline, one contract, no drift.
 *
 * Write-time semantics preserved from the legacy pipeline:
 *   - completion updates are atomic win-the-race writes guarded on the
 *     completable statuses; race losers enrich metric gaps only
 *   - inserts rely on UNIQUE(user_id, garmin_summary_id) for idempotency
 *   - Q-INT11: completion overwrites scheduled_date_time with measured
 *     start (naive local); planned/actual double-write is untouched here
 *     and is removed by Stage C (L-2 split)
 *
 * New per the ratified contract:
 *   - M-1.1 guard + best-fit selection (decided, not queried)
 *   - M-3 upgrade tier: summary-id-less completed rows get stamped
 *     in place instead of duplicated
 *   - M-5 brick paths: parent completion (B-1), sequential/positional leg
 *     stamping into brick_metadata (B-2'/B-2), transition folding (B-4),
 *     no double import (B-5)
 */

import {
  decideMatch,
  type MatchDecision,
  type MatcherCandidate,
  type MatcherIncomingGarmin,
  type MatcherSegment,
} from "./matcher.ts";
import {
  buildGarminCompletionUpdate,
  enrichCompletedGarminActivity,
  GARMIN_COMPLETABLE_STATUSES,
  getGarminLocalDayBounds,
  insertGarminActivityIfMissing,
} from "./activity_completion.ts";
import {
  garminTimestampToLocalNaiveISO,
  mapGarminActivityToActivity,
  mapGarminSportType,
} from "./mappers.ts";
import type { GarminActivitySummary } from "./types.ts";
import {
  buildGarminProviderLabel,
  sendActivityUploadedPush,
} from "./onesignal.ts";
import { getGarminScheduledDate } from "./activity_completion.ts";

const CANDIDATE_COLUMNS =
  "id, status, activity_type, scheduled_date_time, garmin_summary_id, " +
  "provider_workout_id, deleted_at, duration_minutes, " +
  "actual_duration_minutes, brick_metadata, created_at, is_parent";

export type PipelineOutcome =
  | { kind: "dropped"; gate: string }
  | { kind: "completed"; activityId: string; gate: string; title?: string }
  | { kind: "upgraded"; activityId: string }
  | { kind: "brick"; activityId: string; gate: string; verified: boolean }
  | { kind: "transition_folded"; activityId: string | null }
  | { kind: "inserted"; activityId: string; gate: string }
  | { kind: "duplicate" }
  | { kind: "skipped"; reason: string }
  | { kind: "error"; error: unknown };

/** Parse a naive-local timestamp (space or T separated) as a UTC instant,
 * matching how the decision tier resolves vector times. */
function naiveToMs(ts: string | null | undefined): number | null {
  if (!ts) return null;
  let s = String(ts).replace(" ", "T");
  if (s.length === 16) s = `${s}:00`;
  // strip an accidental zone/fraction; storage is naive local (L-9.2)
  s = s.slice(0, 19);
  const ms = Date.parse(`${s}Z`);
  return Number.isFinite(ms) ? ms : null;
}

function msToNaive(ms: number): string {
  return new Date(ms).toISOString().slice(0, 19);
}

// deno-lint-ignore no-explicit-any
type SupabaseLike = any;

interface BrickSegmentMeta {
  order?: number;
  sport?: string;
  duration_minutes?: number;
  garmin?: {
    summary_id?: string;
    start?: string;
    duration_minutes?: number;
  };
  [key: string]: unknown;
}

interface BrickMetadata {
  segments?: BrickSegmentMeta[];
  total_duration_minutes?: number;
  transitions?: Record<
    string,
    { duration_minutes?: number; summary_id?: string; start?: string }
  >;
  [key: string]: unknown;
}

// deno-lint-ignore no-explicit-any
function rowToCandidate(row: Record<string, any>): MatcherCandidate {
  const meta = (row.brick_metadata ?? null) as BrickMetadata | null;
  let segments: MatcherSegment[] | null = null;
  if (meta?.segments && Array.isArray(meta.segments)) {
    segments = meta.segments
      .filter((s) => (s.sport ?? "") !== "transition")
      .map((s, i) => {
        const stampedStartMs = naiveToMs(s.garmin?.start ?? null);
        const stampedDuration = s.garmin?.duration_minutes;
        return {
          order: s.order ?? i + 1,
          sport: String(s.sport ?? ""),
          durationMin: typeof s.duration_minutes === "number"
            ? s.duration_minutes
            : null,
          stampedSummaryId: s.garmin?.summary_id ?? null,
          stampedEndMs: stampedStartMs != null &&
              typeof stampedDuration === "number"
            ? stampedStartMs + stampedDuration * 60_000
            : undefined,
        };
      });
  }
  const status = String(row.status ?? "");
  return {
    rowId: String(row.id),
    status,
    sport: String(row.activity_type ?? ""),
    slotMs: naiveToMs(row.scheduled_date_time),
    garminSummaryId: row.garmin_summary_id != null
      ? String(row.garmin_summary_id)
      : null,
    providerWorkoutId: row.provider_workout_id != null
      ? String(row.provider_workout_id)
      : null,
    // Tombstones (status='deleted') stay matchable — that is their purpose;
    // any OTHER row carrying a deleted_at is excluded from the live tiers.
    deletedAt: row.deleted_at != null && status !== "deleted",
    plannedDurationMin: typeof row.duration_minutes === "number"
      ? row.duration_minutes
      : null,
    recordedDurationMin: typeof row.actual_duration_minutes === "number"
      ? row.actual_duration_minutes
      : typeof row.duration_minutes === "number"
      ? row.duration_minutes
      : null,
    matchedStartMs: null, // keyed verification is a client-side concern
    createdOrder: row.created_at ? Date.parse(String(row.created_at)) || 0 : 0,
    segments,
    totalDurationMin: typeof meta?.total_duration_minutes === "number"
      ? meta.total_duration_minutes
      : null,
    parentStampSummaryId: String(row.activity_type ?? "") === "brick"
      ? (row.garmin_summary_id != null ? String(row.garmin_summary_id) : null)
      : null,
  };
}

async function fetchCandidates(
  supabase: SupabaseLike,
  userId: string,
  activity: GarminActivitySummary,
  summaryId: string | null,
  // deno-lint-ignore no-explicit-any
): Promise<Record<string, any>[]> {
  const { startOfDayNaive, endOfDayNaiveExclusive } = getGarminLocalDayBounds(
    activity,
  );
  // Widen one day each way: the ±15-min tombstone/skipped windows can cross
  // midnight, and the day-wide tiers stay filtered inside the decision.
  const fromMs = naiveToMs(startOfDayNaive)! - 24 * 3600_000;
  const toMs = naiveToMs(endOfDayNaiveExclusive)! + 24 * 3600_000;

  const { data: windowRows, error } = await supabase
    .from("activities")
    .select(CANDIDATE_COLUMNS)
    .eq("user_id", userId)
    .gte("scheduled_date_time", msToNaive(fromMs).replace("T", " "))
    .lt("scheduled_date_time", msToNaive(toMs).replace("T", " "));
  if (error) {
    console.error("[garmin-matcher] Candidate window query error:", error);
  }

  // deno-lint-ignore no-explicit-any
  const rows: Record<string, any>[] = [...(windowRows ?? [])];

  if (summaryId) {
    const { data: idRows } = await supabase
      .from("activities")
      .select(CANDIDATE_COLUMNS)
      .eq("user_id", userId)
      .eq("garmin_summary_id", summaryId);
    for (const r of idRows ?? []) {
      if (!rows.some((x) => String(x.id) === String(r.id))) rows.push(r);
    }
  }
  return rows;
}

/**
 * Run one inbound Garmin activity through the ratified matcher tier.
 */
export async function runGarminActivityPipeline(
  supabase: SupabaseLike,
  userId: string,
  activity: GarminActivitySummary,
  logPrefix: string,
): Promise<PipelineOutcome> {
  const sportType = mapGarminSportType(activity.activityType);
  const summaryId = activity.summaryId != null
    ? String(activity.summaryId)
    : ((activity as { activityId?: string }).activityId ?? null) as
      | string
      | null;

  const startNaive = garminTimestampToLocalNaiveISO(
    activity.startTimeInSeconds,
    activity.startTimeOffsetInSeconds,
  );
  const incoming: MatcherIncomingGarmin = {
    kind: "garmin",
    summaryId,
    sport: sportType,
    startMs: naiveToMs(startNaive)!,
    durationMin: (activity.durationInSeconds ?? 0) / 60,
    parentSummaryId: activity.parentSummaryId ?? null,
    isParent: activity.isParent,
  };

  // deno-lint-ignore no-explicit-any
  let rawRows: Record<string, any>[];
  try {
    rawRows = await fetchCandidates(supabase, userId, activity, summaryId);
  } catch (err) {
    console.error(`${logPrefix} Candidate fetch failed:`, err);
    return { kind: "error", error: err };
  }
  const byId = new Map(rawRows.map((r) => [String(r.id), r]));
  const candidates = rawRows.map(rowToCandidate);

  const decision = decideMatch(incoming, candidates);
  const mappedActivity = mapGarminActivityToActivity(activity, userId);

  console.log(
    `${logPrefix} matcher decision for ${summaryId ?? "?"} (${sportType}): ` +
      `${decision.gate}/${decision.action}` +
      (decision.matchedRowId ? ` -> ${decision.matchedRowId}` : ""),
  );

  switch (decision.action) {
    case "drop":
      return { kind: "dropped", gate: decision.gate };

    case "noop": {
      // duplicate re-push: fill metric gaps from this payload (legacy enrich)
      if (decision.gate === "duplicate" && summaryId) {
        await enrichCompletedGarminActivity(
          supabase,
          userId,
          summaryId,
          mappedActivity,
          logPrefix,
        );
        return { kind: "duplicate" };
      }
      return { kind: "skipped", reason: decision.gate };
    }

    case "complete": {
      if (
        decision.gate === "brick-partial" ||
        decision.gate === "brick-sequential"
      ) {
        return await executeBrickLegStamp(
          supabase,
          userId,
          activity,
          mappedActivity,
          decision,
          byId.get(decision.matchedRowId!),
          logPrefix,
        );
      }
      if (decision.gate === "brick-parent") {
        return await executeBrickParentComplete(
          supabase,
          activity,
          mappedActivity,
          decision,
          logPrefix,
        );
      }
      return await executeCompletion(
        supabase,
        userId,
        activity,
        mappedActivity,
        decision,
        summaryId,
        logPrefix,
      );
    }

    case "upgrade":
      return await executeUpgrade(
        supabase,
        activity,
        mappedActivity,
        decision,
        summaryId,
        logPrefix,
      );

    case "fold-metadata":
      return await executeTransitionFold(
        supabase,
        activity,
        decision,
        byId.get(decision.matchedRowId ?? ""),
        logPrefix,
      );

    case "insert": {
      const outcome = await insertGarminActivityIfMissing(
        supabase,
        activity,
        mappedActivity,
      );
      switch (outcome.kind) {
        case "inserted":
          return {
            kind: "inserted",
            activityId: outcome.activityId,
            gate: decision.gate,
          };
        case "duplicate": {
          if (summaryId) {
            await enrichCompletedGarminActivity(
              supabase,
              userId,
              summaryId,
              mappedActivity,
              logPrefix,
            );
          }
          return { kind: "duplicate" };
        }
        case "skipped_non_endurance":
          return { kind: "skipped", reason: `sport ${outcome.sportType}` };
        case "skipped_enum_not_ready":
          return { kind: "skipped", reason: "enum_not_ready" };
        case "skipped_no_summary_id":
          return { kind: "skipped", reason: "no_summary_id" };
        default:
          return { kind: "error", error: outcome };
      }
    }

    default:
      return { kind: "skipped", reason: decision.gate };
  }
}

async function executeCompletion(
  supabase: SupabaseLike,
  userId: string,
  activity: GarminActivitySummary,
  mappedActivity: Record<string, unknown>,
  decision: MatchDecision,
  summaryId: string | null,
  logPrefix: string,
): Promise<PipelineOutcome> {
  if (!summaryId) return { kind: "skipped", reason: "no_summary_id" };
  const updateFields = buildGarminCompletionUpdate(activity, mappedActivity);
  updateFields.garmin_summary_id = summaryId;

  const { data: updatedRows, error } = await supabase
    .from("activities")
    .update(updateFields)
    .eq("id", decision.matchedRowId)
    .in("status", GARMIN_COMPLETABLE_STATUSES)
    .select("id");

  if (error) {
    console.error(`${logPrefix} Matched activity update error:`, error);
    return { kind: "error", error };
  }
  if (!updatedRows || updatedRows.length === 0) {
    await enrichCompletedGarminActivity(
      supabase,
      userId,
      summaryId,
      mappedActivity,
      logPrefix,
    );
    return { kind: "duplicate" };
  }
  return {
    kind: "completed",
    activityId: String(decision.matchedRowId),
    gate: decision.gate,
  };
}

async function executeUpgrade(
  supabase: SupabaseLike,
  activity: GarminActivitySummary,
  mappedActivity: Record<string, unknown>,
  decision: MatchDecision,
  summaryId: string | null,
  logPrefix: string,
): Promise<PipelineOutcome> {
  if (!summaryId) return { kind: "skipped", reason: "no_summary_id" };
  const updateFields = buildGarminCompletionUpdate(activity, mappedActivity);
  updateFields.garmin_summary_id = summaryId;

  // Atomic: only a still-unstamped completed row upgrades (M-3); a
  // concurrent stamp turns this into a duplicate-style no-op.
  const { data: updatedRows, error } = await supabase
    .from("activities")
    .update(updateFields)
    .eq("id", decision.matchedRowId)
    .eq("status", "completed")
    .is("garmin_summary_id", null)
    .select("id");

  if (error) {
    console.error(`${logPrefix} Upgrade update error:`, error);
    return { kind: "error", error };
  }
  if (!updatedRows || updatedRows.length === 0) {
    return { kind: "duplicate" };
  }
  console.log(
    `${logPrefix} Upgraded mark-done activity ${decision.matchedRowId} ` +
      `with Garmin measured data (M-3)`,
  );
  return { kind: "upgraded", activityId: String(decision.matchedRowId) };
}

async function executeBrickParentComplete(
  supabase: SupabaseLike,
  activity: GarminActivitySummary,
  mappedActivity: Record<string, unknown>,
  decision: MatchDecision,
  logPrefix: string,
): Promise<PipelineOutcome> {
  const summaryId = activity.summaryId != null
    ? String(activity.summaryId)
    : null;
  if (!summaryId) return { kind: "skipped", reason: "no_summary_id" };
  const updateFields = buildGarminCompletionUpdate(activity, mappedActivity);
  updateFields.garmin_summary_id = summaryId;
  updateFields.is_parent = true;
  // The brick row keeps its own sport ('brick'), title and metadata.
  delete updateFields.activity_type;

  const { data: updatedRows, error } = await supabase
    .from("activities")
    .update(updateFields)
    .eq("id", decision.matchedRowId)
    .in("status", GARMIN_COMPLETABLE_STATUSES)
    .select("id");
  if (error) {
    console.error(`${logPrefix} Brick parent completion error:`, error);
    return { kind: "error", error };
  }
  if (!updatedRows || updatedRows.length === 0) return { kind: "duplicate" };
  console.log(
    `${logPrefix} MULTI_SPORT parent ${summaryId} completed planned brick ${decision.matchedRowId} (B-1)`,
  );
  return {
    kind: "brick",
    activityId: String(decision.matchedRowId),
    gate: decision.gate,
    verified: decision.parentVerified ?? false,
  };
}

async function executeBrickLegStamp(
  supabase: SupabaseLike,
  _userId: string,
  activity: GarminActivitySummary,
  mappedActivity: Record<string, unknown>,
  decision: MatchDecision,
  // deno-lint-ignore no-explicit-any
  brickRow: Record<string, any> | undefined,
  logPrefix: string,
): Promise<PipelineOutcome> {
  if (!brickRow) return { kind: "error", error: "brick row missing" };
  const summaryId = activity.summaryId != null
    ? String(activity.summaryId)
    : null;
  if (!summaryId) return { kind: "skipped", reason: "no_summary_id" };

  const meta = ((brickRow.brick_metadata ?? {}) as BrickMetadata);
  const segments = Array.isArray(meta.segments) ? meta.segments : [];
  const stamps = decision.legStamps ?? {};
  const startNaive = garminTimestampToLocalNaiveISO(
    activity.startTimeInSeconds,
    activity.startTimeOffsetInSeconds,
  );
  for (const segment of segments) {
    const order = String(segment.order ?? "");
    if (stamps[order] === summaryId) {
      segment.garmin = {
        summary_id: summaryId,
        start: startNaive,
        duration_minutes: (activity.durationInSeconds ?? 0) / 60,
      };
    }
  }

  const updateFields: Record<string, unknown> = {
    brick_metadata: { ...meta, segments },
    updated_at: new Date().toISOString(),
    last_synced_at: new Date().toISOString(),
    garmin_last_synced_at: new Date().toISOString(),
  };

  // First stamped leg completes the parent and stamps it with the first
  // leg's summary id (B-2'); later legs only extend the metadata.
  const isFirstStamp = brickRow.garmin_summary_id == null;
  if (isFirstStamp) {
    const completion = buildGarminCompletionUpdate(activity, mappedActivity);
    delete completion.activity_type;
    // The parent's schedule reflects the first leg's measured start; totals
    // stay the planned brick totals (per-leg measurements live in metadata).
    delete completion.duration_minutes;
    delete completion.distance_meters;
    delete completion.distance_miles;
    Object.assign(updateFields, completion);
    updateFields.garmin_summary_id = summaryId;
  }

  const query = supabase
    .from("activities")
    .update(updateFields)
    .eq("id", decision.matchedRowId);
  const { error } = isFirstStamp
    ? await query.in("status", [...GARMIN_COMPLETABLE_STATUSES, "completed"])
    : await query;

  if (error) {
    console.error(`${logPrefix} Brick leg stamp error:`, error);
    return { kind: "error", error };
  }
  console.log(
    `${logPrefix} Stamped brick leg ${summaryId} onto ${decision.matchedRowId} ` +
      `(${decision.gate}; verified=${decision.parentVerified ?? false})`,
  );
  return {
    kind: "brick",
    activityId: String(decision.matchedRowId),
    gate: decision.gate,
    verified: decision.parentVerified ?? false,
  };
}

async function executeTransitionFold(
  supabase: SupabaseLike,
  activity: GarminActivitySummary,
  decision: MatchDecision,
  // deno-lint-ignore no-explicit-any
  brickRow: Record<string, any> | undefined,
  logPrefix: string,
): Promise<PipelineOutcome> {
  if (!brickRow) {
    // No brick to fold into: the ruled outcome is still "never a
    // standalone row" — drop with a log.
    console.log(
      `${logPrefix} Transition ${activity.summaryId} had no brick to fold into — dropped (B-4)`,
    );
    return { kind: "transition_folded", activityId: null };
  }
  const meta = ((brickRow.brick_metadata ?? {}) as BrickMetadata);
  const segments = Array.isArray(meta.segments) ? meta.segments : [];
  const startNaive = garminTimestampToLocalNaiveISO(
    activity.startTimeInSeconds,
    activity.startTimeOffsetInSeconds,
  );
  const startMs = naiveToMs(startNaive)!;

  // Positional identity (R8): T{i} is the gap after leg i — count the
  // stamped legs whose measured end precedes this transition's start.
  let position = 0;
  for (const segment of segments) {
    const stampStart = naiveToMs(segment.garmin?.start ?? null);
    const stampDuration = segment.garmin?.duration_minutes;
    if (
      stampStart != null &&
      typeof stampDuration === "number" &&
      stampStart + stampDuration * 60_000 <= startMs
    ) {
      position++;
    }
  }
  const key = `T${Math.max(position, 1)}`;

  const transitions = { ...(meta.transitions ?? {}) };
  transitions[key] = {
    duration_minutes: (activity.durationInSeconds ?? 0) / 60,
    summary_id: activity.summaryId != null
      ? String(activity.summaryId)
      : undefined,
    start: startNaive,
  };

  const { error } = await supabase
    .from("activities")
    .update({
      brick_metadata: { ...meta, transitions },
      updated_at: new Date().toISOString(),
    })
    .eq("id", decision.matchedRowId);
  if (error) {
    console.error(`${logPrefix} Transition fold error:`, error);
    return { kind: "error", error };
  }
  console.log(
    `${logPrefix} Folded transition ${activity.summaryId} into ${decision.matchedRowId} as ${key} (B-4)`,
  );
  return {
    kind: "transition_folded",
    activityId: String(decision.matchedRowId),
  };
}

/**
 * Pipeline + the caller-side ceremony both webhooks shared: the
 * activity-uploaded push (completed / inserted / brick outcomes; an M-3
 * upgrade stays silent — the athlete already marked it done) and the
 * stats tally. garmin-push and garmin-ping call this and nothing else.
 */
export async function processInboundGarminActivity(
  supabase: SupabaseLike,
  userId: string,
  activity: GarminActivitySummary,
  logPrefix: string,
): Promise<PipelineOutcome> {
  const outcome = await runGarminActivityPipeline(
    supabase,
    userId,
    activity,
    logPrefix,
  );
  if (
    outcome.kind === "completed" ||
    outcome.kind === "inserted" ||
    (outcome.kind === "brick" && outcome.activityId)
  ) {
    await sendActivityUploadedPush({
      userId,
      activityId: outcome.activityId,
      scheduledDate: getGarminScheduledDate(activity),
      provider: buildGarminProviderLabel(activity.deviceName),
      logPrefix,
    });
  }
  return outcome;
}

export interface ActivityStats {
  processed: number;
  errors: number;
  matched?: number;
  inserted?: number;
  skipped?: number;
}

export function tallyOutcome(
  outcome: PipelineOutcome,
  stats: ActivityStats,
): void {
  switch (outcome.kind) {
    case "completed":
    case "upgraded":
    case "brick":
      stats.matched = (stats.matched ?? 0) + 1;
      stats.processed++;
      break;
    case "transition_folded":
      stats.processed++;
      break;
    case "inserted":
      stats.inserted = (stats.inserted ?? 0) + 1;
      stats.processed++;
      break;
    case "dropped":
    case "duplicate":
    case "skipped":
      stats.skipped = (stats.skipped ?? 0) + 1;
      break;
    case "error":
      stats.errors++;
      break;
  }
}
