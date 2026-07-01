/**
 * Garmin data mappers
 *
 * Transform Garmin API data structures into our internal formats.
 */

import {
  GARMIN_ACTIVITY_TYPE_MAP,
  type GarminActivitySummary,
  type GarminDailySummary,
  type GarminSleepSummary,
  type OurSportType,
} from './types.ts';

/**
 * Normalize Garmin's deviceName field. Garmin uses the literal string
 * "unknown" when the device model isn't identified — persisting that
 * would violate the brand guidelines and produce "Garmin unknown"
 * attribution strings. Drop it so the client falls back to
 * "Garmin Connect".
 */
export function normalizeGarminDeviceName(
  deviceName?: string | null,
): string | null {
  const trimmed = deviceName?.trim();
  if (!trimmed) return null;
  if (trimmed.toLowerCase() === 'unknown') return null;
  return trimmed;
}

/**
 * Map a Garmin activity type string to our sport type.
 * Falls back to 'other' for unknown types.
 */
export function mapGarminSportType(garminType: string): OurSportType {
  const normalized = garminType.toLowerCase().replace(/\s+/g, '_');
  return (GARMIN_ACTIVITY_TYPE_MAP[normalized] as OurSportType) ?? 'other';
}

/**
 * Convert Garmin epoch seconds + offset to ISO 8601 date string.
 * Garmin provides startTimeInSeconds as UTC epoch and an offset for the local timezone.
 */
export function garminTimestampToISO(
  startTimeInSeconds: number,
  _startTimeOffsetInSeconds?: number,
): string {
  return new Date(startTimeInSeconds * 1000).toISOString();
}

/**
 * Convert Garmin epoch seconds to a date-only string (YYYY-MM-DD) in the user's local timezone.
 */
export function garminTimestampToDateString(
  startTimeInSeconds: number,
  startTimeOffsetInSeconds: number,
): string {
  // Apply timezone offset to get local date
  const localEpochMs = (startTimeInSeconds + startTimeOffsetInSeconds) * 1000;
  const localDate = new Date(localEpochMs);
  const year = localDate.getUTCFullYear();
  const month = String(localDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(localDate.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Map a Garmin activity summary to our activities table format.
 * Returns a partial row suitable for upsert.
 */
export function mapGarminActivityToActivity(
  garminActivity: GarminActivitySummary,
  userId: string,
): Record<string, unknown> {
  const sportType = mapGarminSportType(garminActivity.activityType);
  const durationMinutes = Math.round(garminActivity.durationInSeconds / 60);
  const scheduledDate = garminTimestampToDateString(
    garminActivity.startTimeInSeconds,
    garminActivity.startTimeOffsetInSeconds,
  );
  const scheduledDateTime = garminTimestampToISO(
    garminActivity.startTimeInSeconds,
  );

  // Column names must match the actual activities table schema
  const activity: Record<string, unknown> = {
    user_id: userId,
    activity_type: sportType,
    title: garminActivity.activityName || `Garmin ${sportType}`,
    scheduled_date_time: scheduledDateTime,
    duration_minutes: durationMinutes > 0 ? durationMinutes : null,
    distance_meters: garminActivity.distanceInMeters ?? null,
    synced_from_provider: 'garmin',
    provider_workout_id: garminActivity.summaryId,
    status: 'completed',
    average_heart_rate: garminActivity.averageHeartRateInBeatsPerMinute ?? null,
    max_heart_rate: garminActivity.maxHeartRateInBeatsPerMinute ?? null,
    calories_burned: garminActivity.activeKilocalories ?? null,
    // Persist the Garmin device model so the app can render the
    // "Garmin [device model]" attribution required by Garmin's
    // Developer API Brand Guidelines. Garmin sends "unknown" when
    // the device model isn't identified — drop it so the client
    // falls back to "Garmin Connect" cleanly.
    garmin_device_name: normalizeGarminDeviceName(garminActivity.deviceName),
  };

  // Add sport-specific fields (using actual column names)
  if (sportType === 'running') {
    if (garminActivity.averagePaceInMinutesPerKilometer) {
      // Convert min/km to min/mile
      activity.average_pace_minutes_per_mile =
        garminActivity.averagePaceInMinutesPerKilometer * 1.60934;
    }
    // Include an explicit 0 (started-and-stopped run) so it overwrites a stale
    // planned distance; only skip when Garmin omitted distance entirely.
    if (typeof garminActivity.distanceInMeters === 'number') {
      activity.distance_miles = garminActivity.distanceInMeters / 1609.34;
    }
  }

  if (sportType === 'cycling') {
    if (garminActivity.averagePowerInWatts) {
      activity.cycling_power_watts = garminActivity.averagePowerInWatts;
    }
    if (garminActivity.averageSpeedInMetersPerSecond) {
      activity.cycling_speed_mph =
        garminActivity.averageSpeedInMetersPerSecond * 2.23694;
    }
    if (garminActivity.elevationGainInMeters) {
      activity.cycling_elevation_gain_ft =
        garminActivity.elevationGainInMeters * 3.28084;
    }
  }

  if (sportType === 'swimming') {
    if (
      garminActivity.averageSwimCadenceInStrokesPerMinute &&
      garminActivity.averageSpeedInMetersPerSecond
    ) {
      activity.swimming_pace_per_100m_seconds =
        100 / garminActivity.averageSpeedInMetersPerSecond;
    }
  }

  return activity;
}

/**
 * Map a Garmin daily summary to a health data record.
 */
export function mapGarminDailySummary(
  summary: GarminDailySummary,
): Record<string, unknown> {
  return {
    garmin_user_id: summary.userId,
    summary_id: summary.summaryId,
    data_type: 'daily',
    calendar_date: summary.calendarDate,
    data: {
      steps: summary.steps,
      distance_meters: summary.distanceInMeters,
      active_time_seconds: summary.activeTimeInSeconds,
      active_kilocalories: summary.activeKilocalories,
      bmr_kilocalories: summary.bmrKilocalories,
      avg_heart_rate: summary.averageHeartRateInBeatsPerMinute,
      max_heart_rate: summary.maxHeartRateInBeatsPerMinute,
      min_heart_rate: summary.minHeartRateInBeatsPerMinute,
      resting_heart_rate: summary.restingHeartRateInBeatsPerMinute,
      avg_stress_level: summary.averageStressLevel,
      max_stress_level: summary.maxStressLevel,
      body_battery_highest: summary.bodyBatteryHighestValue,
      body_battery_lowest: summary.bodyBatteryLowestValue,
      floors_climbed: summary.floorsClimbed,
    },
  };
}

/**
 * Map a Garmin sleep summary to a health data record.
 */
export function mapGarminSleepSummary(
  summary: GarminSleepSummary,
): Record<string, unknown> {
  return {
    garmin_user_id: summary.userId,
    summary_id: summary.summaryId,
    data_type: 'sleep',
    calendar_date: summary.calendarDate,
    data: {
      duration_seconds: summary.durationInSeconds,
      deep_sleep_seconds: summary.deepSleepDurationInSeconds,
      light_sleep_seconds: summary.lightSleepDurationInSeconds,
      rem_sleep_seconds: summary.remSleepInSeconds,
      awake_seconds: summary.awakeDurationInSeconds,
      sleep_score_quality: summary.sleepScoreQuality,
      overall_sleep_score: summary.overallSleepScore,
      sleep_quality_score: summary.sleepQualityScore,
      sleep_duration_score: summary.sleepDurationScore,
      restless_moments_count: summary.restlessMomentsCount,
    },
  };
}
