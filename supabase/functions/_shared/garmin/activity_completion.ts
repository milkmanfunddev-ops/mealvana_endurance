/**
 * Shared Garmin activity matching and completion helpers.
 *
 * Both garmin-push and garmin-ping should use the same matching
 * strategy and completion field updates so the app observes a
 * consistent completed state.
 */

import {
  garminTimestampToDateString,
  garminTimestampToISO,
  garminTimestampToLocalNaiveISO,
} from "./mappers.ts";
import { isEnduranceSportType } from "./types.ts";
import type { GarminActivitySummary } from "./types.ts";

/** Postgres unique-violation error code surfaced by PostgREST. */
const PG_UNIQUE_VIOLATION = "23505";

/**
 * Postgres "invalid text representation" error code — surfaced when
 * inserting a value that isn't a member of a target enum type. Used to
 * detect an `activity_type_enum` that hasn't been migrated to include
 * 'other' yet, so we can degrade gracefully instead of a hard failure.
 */
const PG_INVALID_ENUM_VALUE = "22P02";

type GarminActivityTiming = Pick<
  GarminActivitySummary,
  "startTimeInSeconds" | "startTimeOffsetInSeconds" | "durationInSeconds"
>;

export type MatchingPlannedActivity = {
  id: string;
  title?: string;
} | null;

export function getGarminScheduledDate(activity: GarminActivityTiming): string {
  return garminTimestampToDateString(
    activity.startTimeInSeconds,
    activity.startTimeOffsetInSeconds,
  );
}

export function getGarminLocalDayBounds(activity: GarminActivityTiming): {
  scheduledDate: string;
  nextDate: string;
  startOfDayNaive: string;
  endOfDayNaiveExclusive: string;
} {
  const scheduledDate = getGarminScheduledDate(activity);

  const [y, m, d] = scheduledDate.split("-").map(Number);
  const nextLocal = new Date(Date.UTC(y, m - 1, d + 1));
  const nextYear = nextLocal.getUTCFullYear();
  const nextMonth = String(nextLocal.getUTCMonth() + 1).padStart(2, "0");
  const nextDay = String(nextLocal.getUTCDate()).padStart(2, "0");
  const nextDate = `${nextYear}-${nextMonth}-${nextDay}`;

  return {
    scheduledDate,
    nextDate,
    startOfDayNaive: `${scheduledDate} 00:00:00`,
    endOfDayNaiveExclusive: `${nextDate} 00:00:00`,
  };
}

/**
 * Tombstone check — MUST run before any completion match or insert.
 *
 * Soft-delete ruling (Xuan 2026-08-14, docs/ssot/spec/daily-macros/
 * platform-resolution.md): a deleted activity keeps its row with
 * status='deleted', and the sync import matcher must match against those
 * rows too — an incoming platform activity that hits a tombstone is
 * DROPPED, not re-imported. Filtering deleted rows out before matching is
 * exactly the bug the tombstone exists to prevent (deleted workouts
 * reappearing after every sync).
 *
 * Match key (ruled): platform activity id (garmin_summary_id) first; else
 * same sport with start time within ±15 minutes. The window is deliberately
 * NARROW — a genuine second session 30 minutes away must import normally —
 * unlike the day-wide window findMatchingPlannedActivity uses for
 * completion matching (a 5:30 PM plan done at 3 PM should still complete).
 */
export async function findMatchingTombstone(
  supabase: any,
  userId: string,
  sportType: string,
  activity: GarminActivityTiming,
  summaryId: string | null | undefined,
): Promise<{ id: string; reason: string } | null> {
  try {
    // Tier 1: platform activity id.
    if (summaryId) {
      const { data } = await supabase
        .from("activities")
        .select("id")
        .eq("user_id", userId)
        .eq("status", "deleted")
        .eq("garmin_summary_id", summaryId)
        .limit(1);
      if (data && data.length > 0) {
        return { id: String(data[0].id), reason: "matched tombstone (summary id)" };
      }
    }

    // Tier 2: same sport, start within ±15 minutes (naive local time,
    // matching how scheduled_date_time is stored).
    if (!sportType || sportType === "other") return null;
    const startNaive = garminTimestampToLocalNaiveISO(
      activity.startTimeInSeconds,
      activity.startTimeOffsetInSeconds,
    );
    const startMs = new Date(startNaive.replace(" ", "T") + "Z").getTime();
    const windowMs = 15 * 60 * 1000;
    const toNaive = (ms: number) =>
      new Date(ms).toISOString().slice(0, 19).replace("T", " ");

    const { data } = await supabase
      .from("activities")
      .select("id")
      .eq("user_id", userId)
      .eq("status", "deleted")
      .eq("activity_type", sportType)
      .gte("scheduled_date_time", toNaive(startMs - windowMs))
      .lte("scheduled_date_time", toNaive(startMs + windowMs))
      .limit(1);
    if (data && data.length > 0) {
      return {
        id: String(data[0].id),
        reason: "matched tombstone (sport + start ±15 min)",
      };
    }
    return null;
  } catch (err) {
    console.error("[garmin] Tombstone lookup error:", err);
    return null;
  }
}

/**
 * Statuses a Garmin completion may land on. `skipped` is the athlete's
 * "didn't happen" write (workout-card v2, Q-D6 — platform-resolution.md
 * SKIPPED addition, 2026-08-17): SYNC BEATS SKIP, so a skipped row is a
 * legitimate completion target and the matcher MUST NOT filter it out —
 * for the same reason it must not filter tombstones. Every atomic
 * "win-the-race" completion update uses this same list, so the match and
 * the write cannot drift.
 */
export const GARMIN_COMPLETABLE_STATUSES = ["planned", "draft", "skipped"];

/**
 * Sync beats skip (G6): a platform activity matching a `status = 'skipped'`
 * row upgrades it to DONE_VERIFIED. The match key is the RULED one
 * (platform-resolution.md, 2026-08-14 — the same key the tombstone matcher
 * uses): platform activity id first, else same sport with start within
 * ±15 minutes. Deliberately narrower than the day-wide planned window
 * below: a skipped 5:30 PM run and a genuine 3:00 PM session are two
 * different facts, and the athlete's skip stands unless the measured
 * session is the one they skipped.
 */
export async function findMatchingSkippedActivity(
  supabase: any,
  userId: string,
  sportType: string,
  activity: GarminActivityTiming,
  summaryId: string | null | undefined,
): Promise<MatchingPlannedActivity> {
  try {
    if (summaryId) {
      const { data } = await supabase
        .from("activities")
        .select("id, title")
        .eq("user_id", userId)
        .eq("status", "skipped")
        .eq("garmin_summary_id", summaryId)
        .limit(1);
      if (data && data.length > 0) {
        return { id: String(data[0].id), title: data[0].title?.toString() };
      }
    }

    if (!sportType || sportType === "other") return null;
    const startNaive = garminTimestampToLocalNaiveISO(
      activity.startTimeInSeconds,
      activity.startTimeOffsetInSeconds,
    );
    const startMs = new Date(startNaive.replace(" ", "T") + "Z").getTime();
    const windowMs = 15 * 60 * 1000;
    const toNaive = (ms: number) =>
      new Date(ms).toISOString().slice(0, 19).replace("T", " ");

    const { data } = await supabase
      .from("activities")
      .select("id, title")
      .eq("user_id", userId)
      .eq("status", "skipped")
      .eq("activity_type", sportType)
      .is("deleted_at", null)
      .gte("scheduled_date_time", toNaive(startMs - windowMs))
      .lte("scheduled_date_time", toNaive(startMs + windowMs))
      .order("scheduled_date_time", { ascending: true })
      .limit(1);
    if (data && data.length > 0) {
      return { id: String(data[0].id), title: data[0].title?.toString() };
    }
    return null;
  } catch (err) {
    console.error("[garmin] Skipped-row lookup error:", err);
    return null;
  }
}

/**
 * Find an existing planned/draft activity that matches the Garmin upload.
 *
 * Matching is based on:
 * - same user
 * - same sport type
 * - same local Garmin calendar date
 * - activity not deleted (tombstones are handled FIRST, by
 *   findMatchingTombstone — never skip that call)
 * - activity not already completed
 *
 * Runs the SKIPPED tier first (findMatchingSkippedActivity — the ruled
 * ±15 min key), then the day-wide planned/draft window.
 */
export async function findMatchingPlannedActivity(
  supabase: any,
  userId: string,
  sportType: string,
  activity: GarminActivityTiming,
  summaryId?: string | null,
): Promise<MatchingPlannedActivity> {
  // Refuse to match unknown/unmapped sport types. Falling back to "other"
  // would let any generic planned activity get silently completed by an
  // unrelated Garmin upload.
  if (!sportType || sportType === "other") {
    console.log(
      `[garmin] Skipping match — unsupported sport type "${sportType}"`,
    );
    return null;
  }

  // Sync beats skip: a skipped row that this activity matches under the
  // ruled key is completed (and un-skipped) before any planned match.
  const skipped = await findMatchingSkippedActivity(
    supabase,
    userId,
    sportType,
    activity,
    summaryId,
  );
  if (skipped) return skipped;

  try {
    const { startOfDayNaive, endOfDayNaiveExclusive } =
      getGarminLocalDayBounds(activity);

    // scheduled_date_time is `timestamp without time zone`, so we match using
    // naive local-date bounds. Using tz-aware ISO strings would cause Postgres
    // to strip the zone and bleed into the next day.
    const { data, error } = await supabase
      .from("activities")
      .select("id, title, scheduled_date_time")
      .eq("user_id", userId)
      .eq("activity_type", sportType)
      .in("status", ["planned", "draft"])
      .gte("scheduled_date_time", startOfDayNaive)
      .lt("scheduled_date_time", endOfDayNaiveExclusive)
      .is("deleted_at", null)
      .order("scheduled_date_time", { ascending: true })
      .limit(1);

    if (error) {
      console.error("[garmin] Match query error:", error);
      return null;
    }

    if (!data || data.length === 0) {
      return null;
    }

    const first = data[0] as Record<string, unknown>;
    const id = first.id?.toString() ?? "";
    const title = first.title?.toString();

    if (!id) return null;
    return { id, title };
  } catch (err) {
    console.error("[garmin] Match lookup error:", err);
    return null;
  }
}

/**
 * Build the activity update payload used when a Garmin upload completes
 * an existing planned activity.
 */
export function buildGarminCompletionUpdate(
  activity: GarminActivityTiming,
  mappedActivity: Record<string, unknown>,
): Record<string, unknown> {
  const syncedAt = new Date().toISOString();
  const completionTimestamp = garminTimestampToISO(
    activity.startTimeInSeconds +
      Math.max(0, activity.durationInSeconds ?? 0),
  );

  const durationMinutes = typeof mappedActivity.duration_minutes === "number"
    ? mappedActivity.duration_minutes
    : null;
  const distanceMeters = typeof mappedActivity.distance_meters === "number"
    ? mappedActivity.distance_meters
    : null;
  const explicitDistanceMiles =
    typeof mappedActivity.distance_miles === "number"
      ? mappedActivity.distance_miles
      : null;
  const derivedDistanceMiles = explicitDistanceMiles ??
    (typeof distanceMeters === "number" ? distanceMeters / 1609.34 : null);

  const updateFields: Record<string, unknown> = {
    status: "completed",
    // Replace the planned start time with the ACTUAL Garmin start time
    // (bug 3a6e3fdb: a run scheduled for 1:30 PM but started at 12:30 PM
    // kept showing 1:30 PM). Local-naive form — see garminTimestampToLocalNaiveISO.
    scheduled_date_time: garminTimestampToLocalNaiveISO(
      activity.startTimeInSeconds,
      activity.startTimeOffsetInSeconds,
    ),
    // Two-time model (ruled 2026-08-14): actual_time carries the measured
    // start — this also upgrades a mark-done (MANUAL) actual_time to the
    // GARMIN one. planned_time is deliberately untouched, so the athlete's
    // scheduled time survives completion (unlike scheduled_date_time above).
    actual_time: garminTimestampToISO(activity.startTimeInSeconds),
    completed_at: completionTimestamp,
    updated_at: syncedAt,
    last_synced_at: syncedAt,
    garmin_last_synced_at: syncedAt,
    average_heart_rate: typeof mappedActivity.average_heart_rate === "number"
      ? mappedActivity.average_heart_rate
      : null,
    max_heart_rate: typeof mappedActivity.max_heart_rate === "number"
      ? mappedActivity.max_heart_rate
      : null,
    calories_burned: typeof mappedActivity.calories_burned === "number"
      ? mappedActivity.calories_burned
      : null,
  };

  if (durationMinutes !== null) {
    updateFields.duration_minutes = durationMinutes;
    updateFields.actual_duration_minutes = durationMinutes;
  }

  if (distanceMeters !== null) {
    updateFields.distance_meters = distanceMeters;
  }

  // Reconcile the *displayed* mileage to what actually happened. When Garmin
  // completes a planned activity we must replace the planned distance with the
  // synced activity's actual distance (feature request 390e3fdb…6916): a run
  // that was started and immediately stopped reports ~0 mi and must not keep
  // showing the planned 12 mi (which also inflates any distance-derived
  // calorie estimate). We only overwrite when Garmin actually reported a
  // distance (a number, including 0). When Garmin omits distance entirely
  // (e.g. some indoor activities) we leave the planned value untouched rather
  // than zeroing out a legitimate workout.
  if (derivedDistanceMiles !== null) {
    updateFields.actual_distance_miles = derivedDistanceMiles;
    updateFields.distance_miles = derivedDistanceMiles;
  }

  if (typeof mappedActivity.average_pace_minutes_per_mile === "number") {
    updateFields.average_pace_minutes_per_mile =
      mappedActivity.average_pace_minutes_per_mile;
  }
  if (typeof mappedActivity.cycling_power_watts === "number") {
    updateFields.cycling_power_watts = mappedActivity.cycling_power_watts;
  }
  if (typeof mappedActivity.cycling_speed_mph === "number") {
    updateFields.cycling_speed_mph = mappedActivity.cycling_speed_mph;
  }
  if (typeof mappedActivity.cycling_elevation_gain_ft === "number") {
    updateFields.cycling_elevation_gain_ft =
      mappedActivity.cycling_elevation_gain_ft;
  }
  if (typeof mappedActivity.swimming_pace_per_100m_seconds === "number") {
    updateFields.swimming_pace_per_100m_seconds =
      mappedActivity.swimming_pace_per_100m_seconds;
  }

  if (typeof mappedActivity.garmin_device_name === "string") {
    updateFields.garmin_device_name = mappedActivity.garmin_device_name;
  }

  return updateFields;
}

export type GarminEnrichOutcome =
  | { kind: "enriched"; activityId: string; fields: string[] }
  | { kind: "no_gaps" }
  | { kind: "not_found" }
  | { kind: "error"; error: unknown };

/** Metric is absent when it was never written or was written as a zero by a
 * preliminary payload. (A legitimate 0-mi start/stop run also reads as
 * "absent" here — enrichment only ever fills such a value with richer data
 * for the SAME garmin_summary_id, so a real abandoned run stays 0.) */
function metricAbsent(value: unknown): boolean {
  return value === null || value === undefined || value === 0;
}

/**
 * Upgrade an already-completed Garmin activity with richer metrics.
 *
 * Garmin fires the `activities` and `activityDetails` webhooks for the same
 * workout near-simultaneously. Whichever request completes the planned
 * activity first wins the race; the loser used to be silently discarded —
 * so when the FIRST payload was preliminary (0 duration / 0 distance) the
 * richer second payload never landed and the app showed "0 minutes, 0 miles"
 * forever (bug 3a6e3fdb). This fills metric gaps (null/0) on the completed
 * row from the losing payload. It never flips status, never touches
 * scheduled_date_time/completed_at, and callers must not re-notify.
 */
export async function enrichCompletedGarminActivity(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  summaryId: string,
  mappedActivity: Record<string, unknown>,
  logPrefix: string,
): Promise<GarminEnrichOutcome> {
  try {
    const { data, error } = await supabase
      .from("activities")
      .select(
        "id, duration_minutes, actual_duration_minutes, distance_meters, " +
          "distance_miles, actual_distance_miles, average_heart_rate, " +
          "max_heart_rate, calories_burned, average_pace_minutes_per_mile",
      )
      .eq("user_id", userId)
      .eq("garmin_summary_id", String(summaryId))
      .eq("status", "completed")
      .is("deleted_at", null)
      .limit(1);

    if (error) {
      console.error(`${logPrefix} Enrich lookup error:`, error);
      return { kind: "error", error };
    }
    if (!data || data.length === 0) {
      return { kind: "not_found" };
    }

    const existing = data[0] as Record<string, unknown>;
    const update: Record<string, unknown> = {};

    const num = (v: unknown): number | null =>
      typeof v === "number" && Number.isFinite(v) ? v : null;

    const durationMinutes = num(mappedActivity.duration_minutes);
    if (
      durationMinutes !== null && durationMinutes > 0 &&
      metricAbsent(existing.duration_minutes)
    ) {
      update.duration_minutes = durationMinutes;
      update.actual_duration_minutes = durationMinutes;
    }

    const distanceMeters = num(mappedActivity.distance_meters);
    if (
      distanceMeters !== null && distanceMeters > 0 &&
      metricAbsent(existing.distance_meters) &&
      metricAbsent(existing.actual_distance_miles)
    ) {
      const miles = num(mappedActivity.distance_miles) ??
        distanceMeters / 1609.34;
      update.distance_meters = distanceMeters;
      update.distance_miles = miles;
      update.actual_distance_miles = miles;
    }

    const scalarGaps: Array<[string]> = [
      ["average_heart_rate"],
      ["max_heart_rate"],
      ["calories_burned"],
      ["average_pace_minutes_per_mile"],
    ];
    for (const [field] of scalarGaps) {
      const incoming = num(mappedActivity[field]);
      if (incoming !== null && incoming > 0 && metricAbsent(existing[field])) {
        update[field] = incoming;
      }
    }

    const fields = Object.keys(update);
    if (fields.length === 0) {
      return { kind: "no_gaps" };
    }

    const syncedAt = new Date().toISOString();
    update.updated_at = syncedAt;
    update.last_synced_at = syncedAt;
    update.garmin_last_synced_at = syncedAt;

    const { error: updateError } = await supabase
      .from("activities")
      .update(update)
      .eq("id", existing.id)
      .eq("status", "completed");

    if (updateError) {
      console.error(`${logPrefix} Enrich update error:`, updateError);
      return { kind: "error", error: updateError };
    }

    const activityId = String(existing.id);
    console.log(
      `${logPrefix} Enriched completed activity ${activityId} with ${
        fields.join(", ")
      } from a concurrent Garmin payload`,
    );
    return { kind: "enriched", activityId, fields };
  } catch (err) {
    console.error(`${logPrefix} Enrich error:`, err);
    return { kind: "error", error: err };
  }
}

export type GarminInsertOutcome =
  | { kind: "inserted"; activityId: string }
  | { kind: "duplicate" } // another push already inserted this summaryId
  | { kind: "skipped_non_endurance"; sportType: string }
  | { kind: "skipped_enum_not_ready"; sportType: string }
  | { kind: "skipped_no_summary_id" }
  | { kind: "error"; error: unknown };

/**
 * Insert a new completed activity for a Garmin upload that has no matching
 * planned activity. Returns "inserted" only when WE created the row — the
 * caller should fire a OneSignal push exactly when the outcome is
 * "inserted" so concurrent webhooks don't double-notify.
 *
 * Idempotency: relies on the UNIQUE (user_id, garmin_summary_id) index
 * (migration 20260506200000). On 23505 we report "duplicate" so the caller
 * skips the notification.
 *
 * Sport gating: endurance sports (run / bike / swim / triathlon / duathlon /
 * multisport) get auto-created with full nutrition-plan context. Everything
 * else Garmin reports (strength, hiking, walking, yoga, etc.) maps to the
 * generic "other" import-only bucket via [mapGarminSportType] and is now
 * ALSO auto-created — for visibility/deletion in the activity list, never
 * with a nutrition plan. Garmin's "transition" legs (T1/T2 within a
 * multisport activity) are still skipped — they aren't a standalone
 * activity a user would want listed.
 */
export async function insertGarminActivityIfMissing(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  activity: GarminActivitySummary,
  // deno-lint-ignore no-explicit-any
  mappedActivity: Record<string, any>,
): Promise<GarminInsertOutcome> {
  const sportType = String(mappedActivity.activity_type ?? "");
  const isImportOnlyOther = sportType === "other";
  if (!isEnduranceSportType(sportType) && !isImportOnlyOther) {
    return { kind: "skipped_non_endurance", sportType };
  }

  const summaryId = activity.summaryId ??
    (activity as { activityId?: string }).activityId;
  if (!summaryId) {
    return { kind: "skipped_no_summary_id" };
  }

  const completionFields = buildGarminCompletionUpdate(activity, mappedActivity);

  // Merge: mapped row supplies user_id / activity_type / title /
  // scheduled_date_time / sport metrics; completion fields supply status,
  // completed_at, last_synced_at, etc. Completion fields win on overlap.
  const insertRow: Record<string, unknown> = {
    ...mappedActivity,
    ...completionFields,
    // activities.id has NO database default — client-created rows generate
    // their id in Dart, so server-side auto-creates must generate one too or
    // the insert fails with a 23502 not-null violation and the activity is
    // silently lost (bug: unmatched Garmin activities never imported).
    id: crypto.randomUUID(),
    garmin_summary_id: String(summaryId),
    // Server-created — no client-side upload queue entry needed.
    needs_upload: false,
  };

  const { data, error } = await supabase
    .from("activities")
    .insert(insertRow)
    .select("id")
    .single();

  if (error) {
    if ((error as { code?: string }).code === PG_UNIQUE_VIOLATION) {
      return { kind: "duplicate" };
    }
    // The 'other' activity_type_enum value may not have been migrated onto
    // this database yet (rollout ordering: this code can deploy before the
    // `ALTER TYPE activity_type_enum ADD VALUE 'other'` migration runs).
    // Degrade to a skip instead of surfacing a 500 to Garmin's webhook.
    if (
      isImportOnlyOther &&
      (error as { code?: string }).code === PG_INVALID_ENUM_VALUE
    ) {
      console.warn(
        `[garmin] 'other' activity_type not yet supported by this database's activity_type_enum — skipping import until the enum migration lands.`,
        error,
      );
      return { kind: "skipped_enum_not_ready", sportType };
    }
    // Log loudly here (in addition to the caller): garmin-push intentionally
    // returns 200 to Garmin even on per-activity failures (their webhook
    // retry semantics), so this log line is the only durable evidence that
    // an activity import was dropped.
    console.error(
      `[garmin] Auto-create insert FAILED for summaryId=${summaryId} ` +
        `sport=${sportType} user=${mappedActivity.user_id} — activity NOT imported:`,
      error,
    );
    return { kind: "error", error };
  }

  const id = (data as { id?: string } | null)?.id;
  if (!id) {
    return { kind: "error", error: new Error("Insert returned no id") };
  }
  return { kind: "inserted", activityId: id };
}
