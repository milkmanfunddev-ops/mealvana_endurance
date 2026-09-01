/**
 * Tests for Garmin data mappers
 *
 * Run with: deno test --allow-env supabase/functions/_shared/garmin/mappers.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Import production code directly (types + mappers)
// ============================================================================

import {
  GARMIN_ACTIVITY_TYPE_MAP,
  type GarminActivitySummary,
  type GarminDailySummary,
  type GarminSleepSummary,
} from './types.ts';

import {
  mapGarminSportType,
  garminTimestampToISO,
  garminTimestampToLocalNaiveISO,
  garminTimestampToDateString,
  mapGarminActivityToActivity,
  mapGarminDailySummary,
  mapGarminSleepSummary,
} from './mappers.ts';

// ============================================================================
// Test Fixtures
// ============================================================================

const USER_ID = '550e8400-e29b-41d4-a716-446655440000';

const fixtures = {
  runningActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-001',
    activityType: 'running',
    activityName: 'Morning Run',
    durationInSeconds: 3600,
    startTimeInSeconds: 1711584000, // 2024-03-28 00:00:00 UTC
    startTimeOffsetInSeconds: -18000, // EST (UTC-5)
    distanceInMeters: 10000,
    activeKilocalories: 650,
    averageHeartRateInBeatsPerMinute: 145,
    maxHeartRateInBeatsPerMinute: 175,
    averageRunCadenceInStepsPerMinute: 170,
    averageSpeedInMetersPerSecond: 2.78,
    averagePaceInMinutesPerKilometer: 6.0,
    elevationGainInMeters: 50,
  } as GarminActivitySummary,

  cyclingActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-002',
    activityType: 'cycling',
    activityName: 'Afternoon Ride',
    durationInSeconds: 5400,
    startTimeInSeconds: 1711627200, // 2024-03-28 12:00:00 UTC
    startTimeOffsetInSeconds: -18000,
    distanceInMeters: 40000,
    activeKilocalories: 800,
    averageHeartRateInBeatsPerMinute: 135,
    averageSpeedInMetersPerSecond: 7.41,
    averagePowerInWatts: 220,
    normalizedPowerInWatts: 235,
    elevationGainInMeters: 300,
  } as GarminActivitySummary,

  swimmingActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-003',
    activityType: 'lap_swimming',
    activityName: 'Pool Session',
    durationInSeconds: 2700,
    startTimeInSeconds: 1711670400, // 2024-03-28 24:00:00 UTC
    startTimeOffsetInSeconds: -18000,
    distanceInMeters: 2000,
    activeKilocalories: 400,
    averageSwimCadenceInStrokesPerMinute: 30,
    averageSpeedInMetersPerSecond: 0.74,
  } as GarminActivitySummary,

  trailRunningActivity: {
    userId: 'garmin-user-456',
    userAccessToken: 'token-def',
    summaryId: 'activity-004',
    activityType: 'trail_running',
    activityName: 'Trail Run',
    durationInSeconds: 7200,
    startTimeInSeconds: 1711584000,
    startTimeOffsetInSeconds: -18000,
    distanceInMeters: 15000,
    activeKilocalories: 900,
    elevationGainInMeters: 500,
  } as GarminActivitySummary,

  multiSportActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-005',
    activityType: 'multi_sport',
    activityName: 'Sprint Triathlon',
    durationInSeconds: 7200,
    startTimeInSeconds: 1711584000,
    startTimeOffsetInSeconds: -18000,
    distanceInMeters: 25000,
    isParent: true,
  } as GarminActivitySummary,

  childActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-006',
    activityType: 'running',
    activityName: 'Triathlon Run Leg',
    durationInSeconds: 1800,
    startTimeInSeconds: 1711591200,
    startTimeOffsetInSeconds: -18000,
    distanceInMeters: 5000,
    parentSummaryId: 'activity-005',
  } as GarminActivitySummary,

  // Reporter scenario (bug 38ee3fdb): a planned run completed as a 0.0-mi /
  // 0-min run. Garmin sends explicit zeros that must overwrite the plan.
  zeroActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-007',
    activityType: 'running',
    durationInSeconds: 0,
    distanceInMeters: 0,
    averagePaceInMinutesPerKilometer: 0,
    startTimeInSeconds: 1711584000,
    startTimeOffsetInSeconds: 0,
  } as GarminActivitySummary,

  minimalActivity: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'activity-008',
    activityType: 'yoga',
    durationInSeconds: 1800,
    startTimeInSeconds: 1711584000,
    startTimeOffsetInSeconds: 0,
  } as GarminActivitySummary,

  dailySummary: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'daily-001',
    calendarDate: '2024-03-28',
    startTimeInSeconds: 1711584000,
    startTimeOffsetInSeconds: -18000,
    durationInSeconds: 86400,
    steps: 12500,
    distanceInMeters: 9500,
    activeTimeInSeconds: 3600,
    activeKilocalories: 450,
    bmrKilocalories: 1800,
    averageHeartRateInBeatsPerMinute: 68,
    maxHeartRateInBeatsPerMinute: 175,
    minHeartRateInBeatsPerMinute: 52,
    restingHeartRateInBeatsPerMinute: 55,
    averageStressLevel: 35,
    maxStressLevel: 85,
    bodyBatteryHighestValue: 95,
    bodyBatteryLowestValue: 25,
    floorsClimbed: 15,
  } as GarminDailySummary,

  sleepSummary: {
    userId: 'garmin-user-123',
    userAccessToken: 'token-abc',
    summaryId: 'sleep-001',
    calendarDate: '2024-03-28',
    startTimeInSeconds: 1711584000,
    startTimeOffsetInSeconds: -18000,
    durationInSeconds: 28800, // 8 hours
    deepSleepDurationInSeconds: 7200,
    lightSleepDurationInSeconds: 14400,
    remSleepInSeconds: 5400,
    awakeDurationInSeconds: 1800,
    sleepScoreQuality: 'GOOD',
    overallSleepScore: 78,
    sleepQualityScore: 80,
    sleepDurationScore: 85,
    restlessMomentsCount: 12,
  } as GarminSleepSummary,
};

// ============================================================================
// Tests
// ============================================================================

describe('Garmin Mappers', () => {
  // --------------------------------------------------------------------------
  // Sport type mapping
  // --------------------------------------------------------------------------
  describe('mapGarminSportType', () => {
    it('maps running types correctly', () => {
      assertEquals(mapGarminSportType('running'), 'running');
      assertEquals(mapGarminSportType('trail_running'), 'running');
      assertEquals(mapGarminSportType('treadmill_running'), 'running');
      assertEquals(mapGarminSportType('track_running'), 'running');
      assertEquals(mapGarminSportType('ultra_run'), 'running');
      assertEquals(mapGarminSportType('virtual_run'), 'running');
      assertEquals(mapGarminSportType('indoor_running'), 'running');
    });

    it('maps cycling types correctly', () => {
      assertEquals(mapGarminSportType('cycling'), 'cycling');
      assertEquals(mapGarminSportType('mountain_biking'), 'cycling');
      assertEquals(mapGarminSportType('road_biking'), 'cycling');
      assertEquals(mapGarminSportType('indoor_cycling'), 'cycling');
      assertEquals(mapGarminSportType('virtual_ride'), 'cycling');
      assertEquals(mapGarminSportType('gravel_cycling'), 'cycling');
    });

    it('maps swimming types correctly', () => {
      assertEquals(mapGarminSportType('lap_swimming'), 'swimming');
      assertEquals(mapGarminSportType('open_water_swimming'), 'swimming');
      assertEquals(mapGarminSportType('swimming'), 'swimming');
    });

    it('maps multi-sport types correctly', () => {
      assertEquals(mapGarminSportType('multi_sport'), 'multisport');
      assertEquals(mapGarminSportType('triathlon'), 'triathlon');
      assertEquals(mapGarminSportType('duathlon'), 'duathlon');
    });

    it('returns "other" for unknown activity types', () => {
      assertEquals(mapGarminSportType('yoga'), 'other');
      assertEquals(mapGarminSportType('strength_training'), 'other');
      assertEquals(mapGarminSportType('pilates'), 'other');
      assertEquals(mapGarminSportType('unknown_type'), 'other');
      assertEquals(mapGarminSportType(''), 'other');
    });

    it('handles case-insensitive matching', () => {
      assertEquals(mapGarminSportType('Running'), 'running');
      assertEquals(mapGarminSportType('CYCLING'), 'cycling');
      assertEquals(mapGarminSportType('Lap_Swimming'), 'swimming');
    });

    it('handles spaces in type names (normalizes to underscores)', () => {
      assertEquals(mapGarminSportType('trail running'), 'running');
      assertEquals(mapGarminSportType('mountain biking'), 'cycling');
      assertEquals(mapGarminSportType('open water swimming'), 'swimming');
    });
  });

  // --------------------------------------------------------------------------
  // Timestamp conversion
  // --------------------------------------------------------------------------
  describe('garminTimestampToISO', () => {
    it('converts epoch seconds to ISO string', () => {
      const result = garminTimestampToISO(1711584000);
      assertEquals(result, '2024-03-28T00:00:00.000Z');
    });

    it('handles zero epoch', () => {
      const result = garminTimestampToISO(0);
      assertEquals(result, '1970-01-01T00:00:00.000Z');
    });
  });

  describe('garminTimestampToLocalNaiveISO', () => {
    it('renders local wall-clock time with negative offset (EST)', () => {
      // 2024-03-28 00:00:00 UTC at -5h = 2024-03-27 19:00:00 local
      const result = garminTimestampToLocalNaiveISO(1711584000, -18000);
      assertEquals(result, '2024-03-27T19:00:00');
    });

    it('renders local wall-clock time with positive offset (JST)', () => {
      const result = garminTimestampToLocalNaiveISO(1711584000, 32400);
      assertEquals(result, '2024-03-28T09:00:00');
    });

    it('emits no zone suffix (tz-naive column contract)', () => {
      const result = garminTimestampToLocalNaiveISO(1711584000, 0);
      assertEquals(result, '2024-03-28T00:00:00');
      assertEquals(result.includes('Z'), false);
    });
  });

  describe('garminTimestampToDateString', () => {
    it('returns correct local date with negative offset (EST)', () => {
      // 2024-03-28 00:00:00 UTC with EST offset (-5 hours)
      // Local time: 2024-03-27 19:00:00
      const result = garminTimestampToDateString(1711584000, -18000);
      assertEquals(result, '2024-03-27');
    });

    it('returns correct local date with positive offset (JST)', () => {
      // 2024-03-28 00:00:00 UTC with JST offset (+9 hours)
      // Local time: 2024-03-28 09:00:00
      const result = garminTimestampToDateString(1711584000, 32400);
      assertEquals(result, '2024-03-28');
    });

    it('returns correct local date with zero offset (UTC)', () => {
      const result = garminTimestampToDateString(1711584000, 0);
      assertEquals(result, '2024-03-28');
    });

    it('handles date crossing midnight with positive offset', () => {
      // 2024-03-28 20:00:00 UTC with +5 hours offset
      // Local time: 2024-03-29 01:00:00
      const result = garminTimestampToDateString(1711656000, 18000);
      assertEquals(result, '2024-03-29');
    });
  });

  // --------------------------------------------------------------------------
  // Activity mapping
  // --------------------------------------------------------------------------
  describe('mapGarminActivityToActivity', () => {
    it('maps running activity with all fields', () => {
      const result = mapGarminActivityToActivity(fixtures.runningActivity, USER_ID);

      assertEquals(result.user_id, USER_ID);
      assertEquals(result.activity_type, 'running');
      assertEquals(result.title, 'Morning Run');
      assertEquals(result.duration_minutes, 60);
      assertEquals(result.distance_meters, 10000);
      assertEquals(result.synced_from_provider, 'garmin');
      assertEquals(result.provider_workout_id, 'activity-001');
      assertEquals(result.status, 'completed');
      assertEquals(result.average_heart_rate, 145);
      assertEquals(result.max_heart_rate, 175);
      assertEquals(result.calories_burned, 650);
    });

    it('maps cycling activity with power and speed', () => {
      const result = mapGarminActivityToActivity(fixtures.cyclingActivity, USER_ID);

      assertEquals(result.activity_type, 'cycling');
      assertEquals(result.cycling_power_watts, 220);
      assertExists(result.cycling_speed_mph);
      // 7.41 m/s * 2.23694 ≈ 16.58 mph
      assertEquals(Math.round(result.cycling_speed_mph as number), 17);
      assertExists(result.cycling_elevation_gain_ft);
      // 300 meters * 3.28084 ≈ 984 feet
      assertEquals(Math.round(result.cycling_elevation_gain_ft as number), 984);
    });

    it('maps swimming activity with pace', () => {
      const result = mapGarminActivityToActivity(fixtures.swimmingActivity, USER_ID);

      assertEquals(result.activity_type, 'swimming');
      assertExists(result.swimming_pace_per_100m_seconds);
      // 100 / 0.74 ≈ 135.1 seconds per 100m
      assertEquals(Math.round(result.swimming_pace_per_100m_seconds as number), 135);
    });

    it('maps trail running as running sport type', () => {
      const result = mapGarminActivityToActivity(fixtures.trailRunningActivity, USER_ID);
      assertEquals(result.activity_type, 'running');
    });

    it('maps multi-sport parent activity', () => {
      const result = mapGarminActivityToActivity(fixtures.multiSportActivity, USER_ID);

      assertEquals(result.activity_type, 'multisport');
    });

    it('maps child activity sport type', () => {
      const result = mapGarminActivityToActivity(fixtures.childActivity, USER_ID);

      assertEquals(result.activity_type, 'running');
    });

    it('keeps zero duration/distance/pace so an abandoned run overwrites the plan', () => {
      // Regression for bug 38ee3fdb: zero values were coerced to null/undefined
      // by truthiness guards, so a 0.0-mi completed run never overwrote the
      // planned 14-mi distance. They must now survive as real zeros.
      const result = mapGarminActivityToActivity(fixtures.zeroActivity, USER_ID);

      assertEquals(result.duration_minutes, 0);
      assertEquals(result.distance_meters, 0);
      assertEquals(result.distance_miles, 0);
      assertEquals(result.average_pace_minutes_per_mile, 0);
    });

    it('coerces missing (undefined) duration to null', () => {
      const activity = {
        ...fixtures.minimalActivity,
        durationInSeconds: undefined as unknown as number,
      };
      const result = mapGarminActivityToActivity(activity, USER_ID);

      assertEquals(result.duration_minutes, null);
    });

    it('handles unknown activity type as "other"', () => {
      const result = mapGarminActivityToActivity(fixtures.minimalActivity, USER_ID);

      assertEquals(result.activity_type, 'other');
      assertEquals(result.title, 'Garmin other');
    });

    it('handles activity with no optional fields', () => {
      const result = mapGarminActivityToActivity(fixtures.minimalActivity, USER_ID);

      assertEquals(result.distance_meters, null);
      assertEquals(result.synced_from_provider, 'garmin');
    });

    it('generates local-naive scheduled_date_time from actual start + offset', () => {
      // Regression for bug 3a6e3fdb: scheduled_date_time is a tz-naive column
      // holding local wall-clock time everywhere else in the system. Writing
      // the UTC instant ('2024-03-28T00:00:00.000Z') rendered the wrong hour
      // in the app; the mapper must emit the Garmin local time instead.
      const result = mapGarminActivityToActivity(fixtures.runningActivity, USER_ID);

      // 2024-03-28 00:00:00 UTC at offset -18000 (EST) = 2024-03-27 19:00 local
      assertEquals(result.scheduled_date_time, '2024-03-27T19:00:00');
    });

    it('uses activityName when provided', () => {
      const result = mapGarminActivityToActivity(fixtures.runningActivity, USER_ID);
      assertEquals(result.title, 'Morning Run');
    });

    it('generates fallback title when activityName is missing', () => {
      const activity = { ...fixtures.runningActivity, activityName: undefined };
      const result = mapGarminActivityToActivity(activity, USER_ID);
      assertEquals(result.title, 'Garmin running');
    });

    it('maps running pace correctly', () => {
      const result = mapGarminActivityToActivity(fixtures.runningActivity, USER_ID);

      // 6.0 min/km * 1.60934 ≈ 9.66 min/mile
      assertExists(result.average_pace_minutes_per_mile);
      assertEquals(
        Math.round((result.average_pace_minutes_per_mile as number) * 100) / 100,
        9.66,
      );
    });
  });

  // --------------------------------------------------------------------------
  // Daily summary mapping
  // --------------------------------------------------------------------------
  describe('mapGarminDailySummary', () => {
    it('maps daily summary with all health fields', () => {
      const result = mapGarminDailySummary(fixtures.dailySummary);

      assertEquals(result.garmin_user_id, 'garmin-user-123');
      assertEquals(result.summary_id, 'daily-001');
      assertEquals(result.data_type, 'daily');
      assertEquals(result.calendar_date, '2024-03-28');

      const data = result.data as Record<string, unknown>;
      assertEquals(data.steps, 12500);
      assertEquals(data.distance_meters, 9500);
      assertEquals(data.active_time_seconds, 3600);
      assertEquals(data.active_kilocalories, 450);
      assertEquals(data.bmr_kilocalories, 1800);
      assertEquals(data.avg_heart_rate, 68);
      assertEquals(data.max_heart_rate, 175);
      assertEquals(data.min_heart_rate, 52);
      assertEquals(data.resting_heart_rate, 55);
      assertEquals(data.avg_stress_level, 35);
      assertEquals(data.max_stress_level, 85);
      assertEquals(data.body_battery_highest, 95);
      assertEquals(data.body_battery_lowest, 25);
      assertEquals(data.floors_climbed, 15);
    });

    it('handles daily summary with minimal data', () => {
      const minimal: GarminDailySummary = {
        userId: 'garmin-user-789',
        userAccessToken: 'token-xyz',
        summaryId: 'daily-002',
        calendarDate: '2024-03-29',
        startTimeInSeconds: 1711670400,
        startTimeOffsetInSeconds: 0,
        durationInSeconds: 86400,
      };

      const result = mapGarminDailySummary(minimal);

      assertEquals(result.data_type, 'daily');
      const data = result.data as Record<string, unknown>;
      assertEquals(data.steps, undefined);
      assertEquals(data.avg_heart_rate, undefined);
    });
  });

  // --------------------------------------------------------------------------
  // Sleep summary mapping
  // --------------------------------------------------------------------------
  describe('mapGarminSleepSummary', () => {
    it('maps sleep summary with all fields', () => {
      const result = mapGarminSleepSummary(fixtures.sleepSummary);

      assertEquals(result.garmin_user_id, 'garmin-user-123');
      assertEquals(result.summary_id, 'sleep-001');
      assertEquals(result.data_type, 'sleep');
      assertEquals(result.calendar_date, '2024-03-28');

      const data = result.data as Record<string, unknown>;
      assertEquals(data.duration_seconds, 28800);
      assertEquals(data.deep_sleep_seconds, 7200);
      assertEquals(data.light_sleep_seconds, 14400);
      assertEquals(data.rem_sleep_seconds, 5400);
      assertEquals(data.awake_seconds, 1800);
      assertEquals(data.sleep_score_quality, 'GOOD');
      assertEquals(data.overall_sleep_score, 78);
      assertEquals(data.sleep_quality_score, 80);
      assertEquals(data.sleep_duration_score, 85);
      assertEquals(data.restless_moments_count, 12);
    });

    it('handles sleep summary with minimal data', () => {
      const minimal: GarminSleepSummary = {
        userId: 'garmin-user-789',
        userAccessToken: 'token-xyz',
        summaryId: 'sleep-002',
        calendarDate: '2024-03-29',
        startTimeInSeconds: 1711670400,
        startTimeOffsetInSeconds: 0,
        durationInSeconds: 21600,
      };

      const result = mapGarminSleepSummary(minimal);

      assertEquals(result.data_type, 'sleep');
      const data = result.data as Record<string, unknown>;
      assertEquals(data.duration_seconds, 21600);
      assertEquals(data.deep_sleep_seconds, undefined);
      assertEquals(data.overall_sleep_score, undefined);
    });
  });

  // --------------------------------------------------------------------------
  // Activity type mapping completeness
  // --------------------------------------------------------------------------
  describe('GARMIN_ACTIVITY_TYPE_MAP', () => {
    it('has entries for all major running types', () => {
      const runningTypes = Object.entries(GARMIN_ACTIVITY_TYPE_MAP)
        .filter(([, v]) => v === 'running')
        .map(([k]) => k);

      assertEquals(runningTypes.length >= 5, true);
    });

    it('has entries for all major cycling types', () => {
      const cyclingTypes = Object.entries(GARMIN_ACTIVITY_TYPE_MAP)
        .filter(([, v]) => v === 'cycling')
        .map(([k]) => k);

      assertEquals(cyclingTypes.length >= 5, true);
    });

    it('has entries for swimming types', () => {
      const swimmingTypes = Object.entries(GARMIN_ACTIVITY_TYPE_MAP)
        .filter(([, v]) => v === 'swimming')
        .map(([k]) => k);

      assertEquals(swimmingTypes.length >= 2, true);
    });

    it('all mapped values are valid sport types', () => {
      const validTypes = new Set([
        'running', 'cycling', 'swimming', 'triathlon',
        'duathlon', 'multisport', 'transition',
      ]);

      for (const [key, value] of Object.entries(GARMIN_ACTIVITY_TYPE_MAP)) {
        assertEquals(
          validTypes.has(value),
          true,
          `Invalid sport type "${value}" for Garmin type "${key}"`,
        );
      }
    });
  });
});

// Run tests if executed directly
if (import.meta.main) {
  console.log('Running Garmin mapper tests...');
}
