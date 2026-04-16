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
import type { GarminActivitySummary } from "./types.ts";

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
  startOfDayIso: string;
  endOfDayIso: string;
} {
  const localEpochMs =
    (activity.startTimeInSeconds + activity.startTimeOffsetInSeconds) * 1000;
  const localDate = new Date(localEpochMs);

  const year = localDate.getUTCFullYear();
  const month = localDate.getUTCMonth();
  const day = localDate.getUTCDate();

  const startOfDayUtcMs = Date.UTC(year, month, day, 0, 0, 0, 0) -
    activity.startTimeOffsetInSeconds * 1000;
  const endOfDayUtcMs = startOfDayUtcMs + 24 * 60 * 60 * 1000 - 1;

  return {
    scheduledDate: getGarminScheduledDate(activity),
    startOfDayIso: new Date(startOfDayUtcMs).toISOString(),
    endOfDayIso: new Date(endOfDayUtcMs).toISOString(),
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
  try {
    const { startOfDayIso, endOfDayIso } = getGarminLocalDayBounds(activity);

    const { data, error } = await supabase
      .from("activities")
      .select("id, title, scheduled_date_time")
      .eq("user_id", userId)
      .eq("activity_type", sportType)
      .in("status", ["planned", "draft"])
      .gte("scheduled_date_time", startOfDayIso)
      .lte("scheduled_date_time", endOfDayIso)
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

  if (derivedDistanceMiles !== null) {
    updateFields.actual_distance_miles = derivedDistanceMiles;
  }

  if (typeof mappedActivity.distance_miles === "number") {
    updateFields.distance_miles = mappedActivity.distance_miles;
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

  return updateFields;
}
