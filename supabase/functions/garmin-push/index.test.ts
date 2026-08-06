/**
 * Tests for garmin-push Edge Function
 *
 * Validates push notification parsing, activity mapping, and health data processing.
 * Does NOT require live API or Supabase connection (unit-style tests).
 *
 * Run with: deno test --allow-env supabase/functions/garmin-push/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { validateGarminRequest } from '../_shared/garmin/auth.ts';
import {
  mapGarminActivityToActivity,
  mapGarminSportType,
  mapGarminDailySummary,
  mapGarminSleepSummary,
} from '../_shared/garmin/mappers.ts';
import {
  insertGarminActivityIfMissing,
} from '../_shared/garmin/activity_completion.ts';
import {
  isEnduranceSportType,
} from '../_shared/garmin/types.ts';
import type {
  GarminPushNotification,
  GarminActivitySummary,
  GarminDailySummary,
  GarminSleepSummary,
  GarminBodyComposition,
  GarminStressDetail,
  GarminEpochSummary,
} from '../_shared/garmin/types.ts';

// ============================================================================
// Test Fixtures - Realistic Garmin push payloads
// ============================================================================

const TEST_CLIENT_ID = 'test-client-id-123';
const TEST_USER_ID = '550e8400-e29b-41d4-a716-446655440000';

const fixtures = {
  // Realistic running activity push from Garmin
  runningActivityPush: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-run-001',
        activityType: 'running',
        activityName: 'Easy Morning Run',
        durationInSeconds: 2700,
        startTimeInSeconds: 1711612800, // 2024-03-28 08:00:00 UTC
        startTimeOffsetInSeconds: -18000,
        distanceInMeters: 5200,
        activeKilocalories: 380,
        averageHeartRateInBeatsPerMinute: 142,
        maxHeartRateInBeatsPerMinute: 168,
        averageRunCadenceInStepsPerMinute: 172,
        averageSpeedInMetersPerSecond: 1.93,
        averagePaceInMinutesPerKilometer: 8.65,
        elevationGainInMeters: 35,
        elevationLossInMeters: 40,
        deviceName: 'Garmin Forerunner 965',
      },
    ] as GarminActivitySummary[],
  } as GarminPushNotification,

  cyclingActivityPush: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-cycle-001',
        activityType: 'road_biking',
        activityName: 'Saturday Group Ride',
        durationInSeconds: 10800,
        startTimeInSeconds: 1711627200,
        startTimeOffsetInSeconds: -18000,
        distanceInMeters: 80000,
        activeKilocalories: 1200,
        averageHeartRateInBeatsPerMinute: 138,
        averageSpeedInMetersPerSecond: 7.41,
        averagePowerInWatts: 215,
        normalizedPowerInWatts: 230,
        elevationGainInMeters: 450,
        deviceName: 'Garmin Edge 1040',
      },
    ] as GarminActivitySummary[],
  } as GarminPushNotification,

  swimmingActivityPush: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-swim-001',
        activityType: 'lap_swimming',
        activityName: 'Lunch Swim',
        durationInSeconds: 3000,
        startTimeInSeconds: 1711641600,
        startTimeOffsetInSeconds: -18000,
        distanceInMeters: 2500,
        activeKilocalories: 350,
        averageHeartRateInBeatsPerMinute: 130,
        averageSwimCadenceInStrokesPerMinute: 28,
        averageSpeedInMetersPerSecond: 0.83,
      },
    ] as GarminActivitySummary[],
  } as GarminPushNotification,

  multiSportPush: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-multi-parent',
        activityType: 'multi_sport',
        activityName: 'Sprint Triathlon',
        durationInSeconds: 5400,
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: 0,
        distanceInMeters: 27000,
        isParent: true,
      },
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-multi-swim',
        activityType: 'open_water_swimming',
        activityName: 'Swim Leg',
        durationInSeconds: 900,
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: 0,
        distanceInMeters: 750,
        parentSummaryId: 'act-multi-parent',
      },
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-multi-bike',
        activityType: 'cycling',
        activityName: 'Bike Leg',
        durationInSeconds: 2400,
        startTimeInSeconds: 1711585200,
        startTimeOffsetInSeconds: 0,
        distanceInMeters: 20000,
        parentSummaryId: 'act-multi-parent',
      },
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-multi-run',
        activityType: 'running',
        activityName: 'Run Leg',
        durationInSeconds: 1500,
        startTimeInSeconds: 1711588200,
        startTimeOffsetInSeconds: 0,
        distanceInMeters: 5000,
        parentSummaryId: 'act-multi-parent',
      },
    ] as GarminActivitySummary[],
  } as GarminPushNotification,

  manualActivity: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-manual-001',
        activityType: 'running',
        activityName: 'Manually Added Run',
        durationInSeconds: 1800,
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: 0,
        distanceInMeters: 3000,
        manual: true,
      },
    ] as GarminActivitySummary[],
  } as GarminPushNotification,

  dailySummaryPush: {
    dailies: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'daily-20240328',
        calendarDate: '2024-03-28',
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 86400,
        steps: 15200,
        distanceInMeters: 11500,
        activeTimeInSeconds: 4200,
        activeKilocalories: 520,
        bmrKilocalories: 1850,
        averageHeartRateInBeatsPerMinute: 65,
        maxHeartRateInBeatsPerMinute: 168,
        minHeartRateInBeatsPerMinute: 48,
        restingHeartRateInBeatsPerMinute: 52,
        averageStressLevel: 32,
        maxStressLevel: 78,
        bodyBatteryHighestValue: 98,
        bodyBatteryLowestValue: 20,
        floorsClimbed: 22,
      },
    ] as GarminDailySummary[],
  } as GarminPushNotification,

  sleepSummaryPush: {
    sleeps: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'sleep-20240328',
        calendarDate: '2024-03-28',
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 27000,
        deepSleepDurationInSeconds: 6300,
        lightSleepDurationInSeconds: 12600,
        remSleepInSeconds: 5400,
        awakeDurationInSeconds: 2700,
        sleepScoreQuality: 'EXCELLENT',
        overallSleepScore: 88,
        sleepQualityScore: 90,
        sleepDurationScore: 82,
        restlessMomentsCount: 5,
      },
    ] as GarminSleepSummary[],
  } as GarminPushNotification,

  bodyCompPush: {
    bodyComps: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'body-20240328',
        measurementTimeInSeconds: 1711612800,
        measurementTimeOffsetInSeconds: -18000,
        weightInGrams: 72000,
        percentFat: 15.2,
        percentHydration: 58.5,
        boneMassInGrams: 3200,
        muscleMassInGrams: 34000,
        bmi: 23.1,
      },
    ] as GarminBodyComposition[],
  } as GarminPushNotification,

  stressDetailPush: {
    stressDetails: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'stress-20240328',
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 86400,
        calendarDate: '2024-03-28',
        timeOffsetStressLevelValues: [[0, 25], [900, 30], [1800, 45], [2700, 35]],
        timeOffsetBodyBatteryValues: [[0, 95], [900, 92], [1800, 88], [2700, 90]],
      },
    ] as GarminStressDetail[],
  } as GarminPushNotification,

  epochPush: {
    epochs: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'epoch-20240328-0800',
        startTimeInSeconds: 1711612800,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 900,
        activityType: 'running',
        activeKilocalories: 120,
        steps: 2200,
        distanceInMeters: 1800,
        averageHeartRateInBeatsPerMinute: 145,
        maxHeartRateInBeatsPerMinute: 160,
        intensity: 'HIGHLY_ACTIVE',
      },
    ] as GarminEpochSummary[],
  } as GarminPushNotification,

  multipleDailies: {
    dailies: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'daily-20240326',
        calendarDate: '2024-03-26',
        startTimeInSeconds: 1711411200,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 86400,
        steps: 8500,
      },
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'daily-20240327',
        calendarDate: '2024-03-27',
        startTimeInSeconds: 1711497600,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 86400,
        steps: 11200,
      },
    ] as GarminDailySummary[],
  } as GarminPushNotification,

  emptyPush: {} as GarminPushNotification,
};

// ============================================================================
// Tests
// ============================================================================

describe('garmin-push Edge Function', () => {
  // --------------------------------------------------------------------------
  // Request Validation
  // --------------------------------------------------------------------------
  describe('Request Validation', () => {
    it('rejects non-POST requests', () => {
      const req = new Request('https://example.com/garmin-push', {
        method: 'GET',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, 'Expected POST, got GET');
    });

    it('allows requests without garmin-client-id header (lenient mode)', () => {
      const req = new Request('https://example.com/garmin-push', {
        method: 'POST',
        body: '{}',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, null); // Allowed with warning log
    });

    it('rejects requests with wrong client ID', () => {
      const req = new Request('https://example.com/garmin-push', {
        method: 'POST',
        headers: { 'garmin-client-id': 'wrong-id' },
        body: '{}',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, 'Invalid garmin-client-id');
    });

    it('accepts valid requests', () => {
      const req = new Request('https://example.com/garmin-push', {
        method: 'POST',
        headers: { 'garmin-client-id': TEST_CLIENT_ID },
        body: '{}',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, null);
    });
  });

  // --------------------------------------------------------------------------
  // Activity Push Parsing
  // --------------------------------------------------------------------------
  describe('Activity Push Parsing', () => {
    it('parses running activity push', () => {
      const push = fixtures.runningActivityPush;
      assertExists(push.activities);
      assertEquals(push.activities!.length, 1);

      const activity = push.activities![0];
      assertEquals(activity.activityType, 'running');
      assertEquals(activity.activityName, 'Easy Morning Run');
      assertEquals(activity.durationInSeconds, 2700);
      assertEquals(activity.distanceInMeters, 5200);
    });

    it('parses cycling activity push', () => {
      const push = fixtures.cyclingActivityPush;
      const activity = push.activities![0];

      assertEquals(activity.activityType, 'road_biking');
      assertEquals(activity.averagePowerInWatts, 215);
      assertEquals(activity.normalizedPowerInWatts, 230);
    });

    it('parses swimming activity push', () => {
      const push = fixtures.swimmingActivityPush;
      const activity = push.activities![0];

      assertEquals(activity.activityType, 'lap_swimming');
      assertEquals(activity.averageSwimCadenceInStrokesPerMinute, 28);
    });

    it('parses multi-sport push with parent and child activities', () => {
      const push = fixtures.multiSportPush;
      assertExists(push.activities);
      assertEquals(push.activities!.length, 4);

      const parent = push.activities![0];
      assertEquals(parent.isParent, true);
      assertEquals(parent.activityType, 'multi_sport');

      const children = push.activities!.slice(1);
      for (const child of children) {
        assertEquals(child.parentSummaryId, 'act-multi-parent');
      }
    });

    it('parses manually updated activity', () => {
      const push = fixtures.manualActivity;
      const activity = push.activities![0];

      assertEquals(activity.manual, true);
      assertEquals(activity.activityName, 'Manually Added Run');
    });

    it('handles empty push notification', () => {
      const push = fixtures.emptyPush;
      assertEquals(push.activities, undefined);
      assertEquals(push.dailies, undefined);
      assertEquals(push.sleeps, undefined);
    });
  });

  // --------------------------------------------------------------------------
  // Activity Mapping (push → our format)
  // --------------------------------------------------------------------------
  describe('Activity Mapping', () => {
    it('maps running activity with key fields', () => {
      const activity = fixtures.runningActivityPush.activities![0];
      const result = mapGarminActivityToActivity(activity, TEST_USER_ID);

      assertEquals(result.activity_type, 'running');
      assertEquals(result.title, 'Easy Morning Run');
      assertEquals(result.duration_minutes, 45); // 2700 / 60
      assertEquals(result.distance_meters, 5200);
      assertEquals(result.synced_from_provider, 'garmin');
      assertEquals(result.provider_workout_id, 'act-run-001');
      assertEquals(result.status, 'completed');
    });

    it('maps road_biking to cycling sport type', () => {
      const activity = fixtures.cyclingActivityPush.activities![0];
      const result = mapGarminActivityToActivity(activity, TEST_USER_ID);

      assertEquals(result.activity_type, 'cycling');
      assertEquals(result.cycling_power_watts, 215);
    });

    it('maps lap_swimming to swimming sport type', () => {
      const activity = fixtures.swimmingActivityPush.activities![0];
      const result = mapGarminActivityToActivity(activity, TEST_USER_ID);

      assertEquals(result.activity_type, 'swimming');
    });

    it('extracts heart rate data', () => {
      const activity = fixtures.runningActivityPush.activities![0];
      assertEquals(activity.averageHeartRateInBeatsPerMinute, 142);
      assertEquals(activity.maxHeartRateInBeatsPerMinute, 168);
    });

    it('handles activity with no HR data', () => {
      const activity: GarminActivitySummary = {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-no-hr',
        activityType: 'running',
        durationInSeconds: 1800,
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: 0,
      };
      const result = mapGarminActivityToActivity(activity, TEST_USER_ID);

      assertExists(result);
      assertEquals(result.activity_type, 'running');
    });

    it('handles missing optional fields gracefully', () => {
      const activity: GarminActivitySummary = {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        summaryId: 'act-minimal',
        activityType: 'running',
        durationInSeconds: 600,
        startTimeInSeconds: 1711584000,
        startTimeOffsetInSeconds: 0,
      };
      const result = mapGarminActivityToActivity(activity, TEST_USER_ID);

      assertEquals(result.distance_meters, null);
      assertEquals(result.title, 'Garmin running');
    });
  });

  // --------------------------------------------------------------------------
  // Sport Type Mapping
  // --------------------------------------------------------------------------
  describe('Sport Type Mapping', () => {
    it('maps RUNNING variants', () => {
      assertEquals(mapGarminSportType('running'), 'running');
      assertEquals(mapGarminSportType('trail_running'), 'running');
      assertEquals(mapGarminSportType('treadmill_running'), 'running');
    });

    it('maps CYCLING variants', () => {
      assertEquals(mapGarminSportType('cycling'), 'cycling');
      assertEquals(mapGarminSportType('road_biking'), 'cycling');
      assertEquals(mapGarminSportType('mountain_biking'), 'cycling');
      assertEquals(mapGarminSportType('indoor_cycling'), 'cycling');
    });

    it('maps SWIMMING variants', () => {
      assertEquals(mapGarminSportType('lap_swimming'), 'swimming');
      assertEquals(mapGarminSportType('open_water_swimming'), 'swimming');
    });

    it('maps multi-sport types', () => {
      assertEquals(mapGarminSportType('multi_sport'), 'multisport');
      assertEquals(mapGarminSportType('triathlon'), 'triathlon');
    });

    it('returns "other" for unsupported types', () => {
      assertEquals(mapGarminSportType('yoga'), 'other');
      assertEquals(mapGarminSportType('strength_training'), 'other');
      assertEquals(mapGarminSportType('hiking'), 'other');
      assertEquals(mapGarminSportType(''), 'other');
    });
  });

  // --------------------------------------------------------------------------
  // Health Push Parsing
  // --------------------------------------------------------------------------
  describe('Health Push - Daily Summaries', () => {
    it('parses daily summary with all wellness fields', () => {
      const push = fixtures.dailySummaryPush;
      assertExists(push.dailies);
      assertEquals(push.dailies!.length, 1);

      const daily = push.dailies![0];
      assertEquals(daily.steps, 15200);
      assertEquals(daily.restingHeartRateInBeatsPerMinute, 52);
      assertEquals(daily.averageStressLevel, 32);
      assertEquals(daily.bodyBatteryHighestValue, 98);
    });

    it('maps daily summary to our format', () => {
      const daily = fixtures.dailySummaryPush.dailies![0];
      const result = mapGarminDailySummary(daily);

      assertEquals(result.data_type, 'daily');
      assertEquals(result.calendar_date, '2024-03-28');
      const data = result.data as Record<string, unknown>;
      assertEquals(data.steps, 15200);
      assertEquals(data.resting_heart_rate, 52);
      assertEquals(data.body_battery_highest, 98);
    });

    it('handles multiple dailies in single push', () => {
      const push = fixtures.multipleDailies;
      assertEquals(push.dailies!.length, 2);
      assertEquals(push.dailies![0].calendarDate, '2024-03-26');
      assertEquals(push.dailies![1].calendarDate, '2024-03-27');
    });
  });

  describe('Health Push - Sleep Summaries', () => {
    it('parses sleep summary with stages', () => {
      const push = fixtures.sleepSummaryPush;
      const sleep = push.sleeps![0];

      assertEquals(sleep.durationInSeconds, 27000);
      assertEquals(sleep.deepSleepDurationInSeconds, 6300);
      assertEquals(sleep.lightSleepDurationInSeconds, 12600);
      assertEquals(sleep.remSleepInSeconds, 5400);
      assertEquals(sleep.awakeDurationInSeconds, 2700);
    });

    it('parses sleep score fields', () => {
      const sleep = fixtures.sleepSummaryPush.sleeps![0];

      assertEquals(sleep.sleepScoreQuality, 'EXCELLENT');
      assertEquals(sleep.overallSleepScore, 88);
    });

    it('maps sleep summary to our format', () => {
      const sleep = fixtures.sleepSummaryPush.sleeps![0];
      const result = mapGarminSleepSummary(sleep);

      assertEquals(result.data_type, 'sleep');
      const data = result.data as Record<string, unknown>;
      assertEquals(data.deep_sleep_seconds, 6300);
      assertEquals(data.sleep_score_quality, 'EXCELLENT');
      assertEquals(data.overall_sleep_score, 88);
    });
  });

  describe('Health Push - Body Composition', () => {
    it('parses body composition push', () => {
      const bodyComp = fixtures.bodyCompPush.bodyComps![0];

      assertEquals(bodyComp.weightInGrams, 72000);
      assertEquals(bodyComp.percentFat, 15.2);
      assertEquals(bodyComp.bmi, 23.1);
      assertEquals(bodyComp.muscleMassInGrams, 34000);
    });
  });

  describe('Health Push - Stress Details', () => {
    it('parses stress detail with timeline data', () => {
      const stress = fixtures.stressDetailPush.stressDetails![0];

      assertEquals(stress.calendarDate, '2024-03-28');
      assertExists(stress.timeOffsetStressLevelValues);
      assertEquals(stress.timeOffsetStressLevelValues!.length, 4);
      assertExists(stress.timeOffsetBodyBatteryValues);
      assertEquals(stress.timeOffsetBodyBatteryValues!.length, 4);
    });
  });

  describe('Health Push - Epoch Summaries', () => {
    it('parses epoch summary (15-min granularity)', () => {
      const epoch = fixtures.epochPush.epochs![0];

      assertEquals(epoch.durationInSeconds, 900);
      assertEquals(epoch.activityType, 'running');
      assertEquals(epoch.steps, 2200);
      assertEquals(epoch.intensity, 'HIGHLY_ACTIVE');
    });
  });

  // --------------------------------------------------------------------------
  // Edge Cases
  // --------------------------------------------------------------------------
  describe('Edge Cases', () => {
    it('handles push with unknown summary types gracefully', () => {
      // Unknown keys should just be ignored
      const push = {
        unknownType: [{ userId: 'abc', summaryId: 'unknown' }],
      } as unknown as GarminPushNotification;

      // None of our known fields are present
      assertEquals(push.activities, undefined);
      assertEquals(push.dailies, undefined);
    });

    it('handles mixed push with activities and health data', () => {
      const push: GarminPushNotification = {
        activities: fixtures.runningActivityPush.activities,
        dailies: fixtures.dailySummaryPush.dailies,
        sleeps: fixtures.sleepSummaryPush.sleeps,
      };

      assertExists(push.activities);
      assertExists(push.dailies);
      assertExists(push.sleeps);
      assertEquals(push.activities!.length, 1);
      assertEquals(push.dailies!.length, 1);
      assertEquals(push.sleeps!.length, 1);
    });
  });
});

// ============================================================================
// Endurance Sport Allowlist
// ============================================================================

describe('Endurance Sport Allowlist', () => {
  it('accepts core endurance sport types', () => {
    assertEquals(isEnduranceSportType('running'), true);
    assertEquals(isEnduranceSportType('cycling'), true);
    assertEquals(isEnduranceSportType('swimming'), true);
    assertEquals(isEnduranceSportType('triathlon'), true);
    assertEquals(isEnduranceSportType('duathlon'), true);
    assertEquals(isEnduranceSportType('multisport'), true);
  });

  it('rejects non-endurance and unmapped types', () => {
    assertEquals(isEnduranceSportType('other'), false);
    assertEquals(isEnduranceSportType('transition'), false);
    assertEquals(isEnduranceSportType('hiking'), false);
    assertEquals(isEnduranceSportType('strength_training'), false);
    assertEquals(isEnduranceSportType(''), false);
    assertEquals(isEnduranceSportType(undefined), false);
    assertEquals(isEnduranceSportType(null), false);
  });
});

// ============================================================================
// Auto-create on no-match (insertGarminActivityIfMissing)
// ============================================================================

/**
 * Minimal supabase-shaped stub that records the insert payload and returns
 * a canned response. Mirrors the chain shape used by insertGarminActivityIfMissing:
 *   client.from(table).insert(row).select(cols).single()
 */
function buildSupabaseInsertStub(
  // deno-lint-ignore no-explicit-any
  response: { data: any; error: any },
): {
  // deno-lint-ignore no-explicit-any
  client: any;
  // deno-lint-ignore no-explicit-any
  capturedRow: () => Record<string, any> | null;
  insertCallCount: () => number;
} {
  // deno-lint-ignore no-explicit-any
  let captured: Record<string, any> | null = null;
  let calls = 0;
  const client = {
    from: (_table: string) => ({
      // deno-lint-ignore no-explicit-any
      insert: (row: Record<string, any>) => {
        calls++;
        captured = row;
        return {
          select: (_cols: string) => ({
            single: () => Promise.resolve(response),
          }),
        };
      },
    }),
  };
  return {
    client,
    capturedRow: () => captured,
    insertCallCount: () => calls,
  };
}

describe('insertGarminActivityIfMissing', () => {
  const TEST_USER = '550e8400-e29b-41d4-a716-446655440000';

  // activities.id has NO database default — the server must generate it or
  // the insert 23502s and the activity is silently dropped.
  const UUID_RE =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  it('inserts a completed activity for a no-match endurance push', async () => {
    const activity = fixtures.swimmingActivityPush.activities![0];
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    const stub = buildSupabaseInsertStub({
      data: { id: 'new-activity-uuid' },
      error: null,
    });

    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    assertEquals(outcome.kind, 'inserted');
    if (outcome.kind === 'inserted') {
      assertEquals(outcome.activityId, 'new-activity-uuid');
    }

    const row = stub.capturedRow();
    assertExists(row);
    // The insert payload MUST carry a server-generated uuid id — activities.id
    // has no DB default, so omitting it fails with a 23502 not-null violation.
    assertExists(row!.id);
    assertEquals(typeof row!.id, 'string');
    assertEquals(UUID_RE.test(row!.id as string), true);
    assertEquals(row!.user_id, TEST_USER);
    assertEquals(row!.activity_type, 'swimming');
    assertEquals(row!.status, 'completed');
    assertEquals(row!.synced_from_provider, 'garmin');
    assertEquals(row!.garmin_summary_id, 'act-swim-001');
    assertEquals(row!.needs_upload, false);
    // Completion fields from buildGarminCompletionUpdate must be applied.
    assertExists(row!.completed_at);
    assertExists(row!.last_synced_at);
    assertExists(row!.garmin_last_synced_at);
  });

  it('reports duplicate when the unique constraint is violated', async () => {
    const activity = fixtures.runningActivityPush.activities![0];
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    const stub = buildSupabaseInsertStub({
      data: null,
      error: { code: '23505', message: 'duplicate key value' },
    });

    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    assertEquals(outcome.kind, 'duplicate');
    assertEquals(stub.insertCallCount(), 1);
  });

  it('imports unsupported (non-endurance) sports as ActivityType.other', async () => {
    const activity: GarminActivitySummary = {
      userId: 'garmin-user-abc',
      userAccessToken: 'token-xyz',
      summaryId: 'act-strength-001',
      activityType: 'strength_training', // maps to "other"
      activityName: 'Leg Day',
      durationInSeconds: 1800,
      startTimeInSeconds: 1711584000,
      startTimeOffsetInSeconds: 0,
    };
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    assertEquals(mapped.activity_type, 'other');

    const stub = buildSupabaseInsertStub({
      data: { id: 'new-other-activity-uuid' },
      error: null,
    });
    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    // Import-only bucket: still auto-created, just never matched to a
    // planned activity (findMatchingPlannedActivity refuses 'other').
    assertEquals(outcome.kind, 'inserted');
    if (outcome.kind === 'inserted') {
      assertEquals(outcome.activityId, 'new-other-activity-uuid');
    }
    const row = stub.capturedRow();
    assertExists(row);
    assertEquals(UUID_RE.test(String(row!.id)), true);
    assertEquals(row!.activity_type, 'other');
    assertEquals(row!.title, 'Leg Day');
    assertEquals(stub.insertCallCount(), 1);
  });

  it('generates a unique uuid id per auto-created activity', async () => {
    const activity = fixtures.runningActivityPush.activities![0];
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);

    const first = buildSupabaseInsertStub({ data: { id: 'a' }, error: null });
    await insertGarminActivityIfMissing(first.client, activity, mapped);
    const second = buildSupabaseInsertStub({ data: { id: 'b' }, error: null });
    await insertGarminActivityIfMissing(second.client, activity, mapped);

    const firstId = String(first.capturedRow()!.id);
    const secondId = String(second.capturedRow()!.id);
    assertEquals(UUID_RE.test(firstId), true);
    assertEquals(UUID_RE.test(secondId), true);
    // Fresh uuid per insert — not a constant, not copied from the payload.
    assertEquals(firstId === secondId, false);
  });

  it('skips Garmin "transition" legs without inserting', async () => {
    const activity: GarminActivitySummary = {
      userId: 'garmin-user-abc',
      userAccessToken: 'token-xyz',
      summaryId: 'act-transition-001',
      activityType: 'transition',
      durationInSeconds: 120,
      startTimeInSeconds: 1711584000,
      startTimeOffsetInSeconds: 0,
    };
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    assertEquals(mapped.activity_type, 'transition');

    const stub = buildSupabaseInsertStub({
      data: { id: 'should-not-be-used' },
      error: null,
    });
    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    assertEquals(outcome.kind, 'skipped_non_endurance');
    if (outcome.kind === 'skipped_non_endurance') {
      assertEquals(outcome.sportType, 'transition');
    }
    assertEquals(stub.insertCallCount(), 0);
  });

  it('degrades to skipped_enum_not_ready when the DB enum lacks "other"', async () => {
    const activity: GarminActivitySummary = {
      userId: 'garmin-user-abc',
      userAccessToken: 'token-xyz',
      summaryId: 'act-hiking-001',
      activityType: 'hiking', // maps to "other"
      durationInSeconds: 3600,
      startTimeInSeconds: 1711584000,
      startTimeOffsetInSeconds: 0,
    };
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    assertEquals(mapped.activity_type, 'other');

    const stub = buildSupabaseInsertStub({
      data: null,
      error: {
        code: '22P02',
        message: 'invalid input value for enum activity_type_enum: "other"',
      },
    });
    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    assertEquals(outcome.kind, 'skipped_enum_not_ready');
    if (outcome.kind === 'skipped_enum_not_ready') {
      assertEquals(outcome.sportType, 'other');
    }
    assertEquals(stub.insertCallCount(), 1);
  });

  it('skips when summaryId is missing', async () => {
    const activity = {
      ...fixtures.runningActivityPush.activities![0],
      summaryId: '',
    } as GarminActivitySummary;
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    const stub = buildSupabaseInsertStub({
      data: { id: 'unused' },
      error: null,
    });

    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    assertEquals(outcome.kind, 'skipped_no_summary_id');
    assertEquals(stub.insertCallCount(), 0);
  });

  it('reports error on non-23505 db failure', async () => {
    const activity = fixtures.cyclingActivityPush.activities![0];
    const mapped = mapGarminActivityToActivity(activity, TEST_USER);
    const stub = buildSupabaseInsertStub({
      data: null,
      error: { code: '23502', message: 'null violates not-null constraint' },
    });

    const outcome = await insertGarminActivityIfMissing(
      stub.client,
      activity,
      mapped,
    );

    assertEquals(outcome.kind, 'error');
  });
});

// Run tests if executed directly
if (import.meta.main) {
  console.log('Running garmin-push edge function tests...');
}
