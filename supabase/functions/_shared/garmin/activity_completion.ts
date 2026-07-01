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
} from "./mappers.ts";
import { isEnduranceSportType } from "./types.ts";
import type { GarminActivitySummary } from "./types.ts";

/** Postgres unique-violation error code surfaced by PostgREST. */
const PG_UNIQUE_VIOLATION = "23505";

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
 * Find an existing planned/draft activity that matches the Garmin upload.
 *
 * Matching is based on:
 * - same user
 * - same sport type
 * - same local Garmin calendar date
 * - activity not deleted
 * - activity not already completed
 */
export async function findMatchingPlannedActivity(
  supabase: any,
  userId: string,
  sportType: string,
  activity: GarminActivityTiming,
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

export type GarminInsertOutcome =
  | { kind: "inserted"; activityId: string }
  | { kind: "duplicate" } // another push already inserted this summaryId
  | { kind: "skipped_non_endurance"; sportType: string }
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
 * Sport gating: only endurance sports (run / bike / swim / triathlon /
 * duathlon / multisport) get auto-created. Walks, strength sessions, and
 * Garmin's "other" bucket have no nutrition context to attach to.
 */
export async function insertGarminActivityIfMissing(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  activity: GarminActivitySummary,
  // deno-lint-ignore no-explicit-any
  mappedActivity: Record<string, any>,
): Promise<GarminInsertOutcome> {
  const sportType = String(mappedActivity.activity_type ?? "");
  if (!isEnduranceSportType(sportType)) {
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
    return { kind: "error", error };
  }

  const id = (data as { id?: string } | null)?.id;
  if (!id) {
    return { kind: "error", error: new Error("Insert returned no id") };
  }
  return { kind: "inserted", activityId: id };
}
