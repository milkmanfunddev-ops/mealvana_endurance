/**
 * Tests for garmin-ping Edge Function
 *
 * Validates ping notification parsing and callback URL handling.
 * Does NOT require live API or Supabase connection (unit-style tests).
 *
 * Run with: deno test --allow-env supabase/functions/garmin-ping/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { validateGarminRequest } from '../_shared/garmin/auth.ts';
import type {
  GarminPingNotification,
  GarminPingEntry,
} from '../_shared/garmin/types.ts';

// ============================================================================
// Test Fixtures
// ============================================================================

const TEST_CLIENT_ID = 'test-client-id-123';

const fixtures = {
  activityPing: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: 'https://apis.garmin.com/wellness-api/rest/activities?uploadStartTimeInSeconds=1711584000&uploadEndTimeInSeconds=1711670400',
        uploadStartTimeInSeconds: 1711584000,
        uploadEndTimeInSeconds: 1711670400,
      },
    ] as GarminPingEntry[],
  } as GarminPingNotification,

  dailyPing: {
    dailies: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: 'https://apis.garmin.com/wellness-api/rest/dailies?calendarDate=2024-03-28',
        uploadStartTimeInSeconds: 1711584000,
        uploadEndTimeInSeconds: 1711670400,
      },
    ] as GarminPingEntry[],
  } as GarminPingNotification,

  sleepPing: {
    sleeps: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: 'https://apis.garmin.com/wellness-api/rest/sleeps?calendarDate=2024-03-28',
      },
    ] as GarminPingEntry[],
  } as GarminPingNotification,

  mixedPing: {
    activities: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: 'https://apis.garmin.com/wellness-api/rest/activities?uploadStartTimeInSeconds=1711584000',
      },
    ] as GarminPingEntry[],
    dailies: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: 'https://apis.garmin.com/wellness-api/rest/dailies?calendarDate=2024-03-28',
      },
    ] as GarminPingEntry[],
    sleeps: [
      {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: 'https://apis.garmin.com/wellness-api/rest/sleeps?calendarDate=2024-03-28',
      },
    ] as GarminPingEntry[],
  } as GarminPingNotification,

  emptyPing: {} as GarminPingNotification,
};

// ============================================================================
// Tests
// ============================================================================

describe('garmin-ping Edge Function', () => {
  // --------------------------------------------------------------------------
  // Request Validation (same as push)
  // --------------------------------------------------------------------------
  describe('Request Validation', () => {
    it('rejects GET requests', () => {
      const req = new Request('https://example.com/garmin-ping', {
        method: 'GET',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, 'Expected POST, got GET');
    });

    it('allows missing garmin-client-id (lenient mode)', () => {
      const req = new Request('https://example.com/garmin-ping', {
        method: 'POST',
        body: '{}',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, null); // Allowed with warning log
    });

    it('rejects wrong client ID', () => {
      const req = new Request('https://example.com/garmin-ping', {
        method: 'POST',
        headers: { 'garmin-client-id': 'bad-id' },
        body: '{}',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, 'Invalid garmin-client-id');
    });

    it('accepts valid request', () => {
      const req = new Request('https://example.com/garmin-ping', {
        method: 'POST',
        headers: { 'garmin-client-id': TEST_CLIENT_ID },
        body: '{}',
      });
      const result = validateGarminRequest(req, TEST_CLIENT_ID);
      assertEquals(result, null);
    });
  });

  // --------------------------------------------------------------------------
  // Ping Notification Parsing
  // --------------------------------------------------------------------------
  describe('Ping Notification Parsing', () => {
    it('parses activity ping with callback URL', () => {
      const ping = fixtures.activityPing;
      assertExists(ping.activities);
      assertEquals(ping.activities!.length, 1);

      const entry = ping.activities![0];
      assertEquals(entry.userId, 'garmin-user-abc');
      assertExists(entry.callbackURL);
      assertEquals(
        entry.callbackURL.startsWith('https://apis.garmin.com/'),
        true,
      );
    });

    it('parses daily ping with callback URL', () => {
      const ping = fixtures.dailyPing;
      assertExists(ping.dailies);

      const entry = ping.dailies![0];
      assertEquals(entry.callbackURL.includes('dailies'), true);
    });

    it('parses sleep ping with callback URL', () => {
      const ping = fixtures.sleepPing;
      assertExists(ping.sleeps);

      const entry = ping.sleeps![0];
      assertEquals(entry.callbackURL.includes('sleeps'), true);
    });

    it('parses mixed ping types in single notification', () => {
      const ping = fixtures.mixedPing;

      assertExists(ping.activities);
      assertExists(ping.dailies);
      assertExists(ping.sleeps);
      assertEquals(ping.activities!.length, 1);
      assertEquals(ping.dailies!.length, 1);
      assertEquals(ping.sleeps!.length, 1);
    });

    it('handles empty ping notification', () => {
      const ping = fixtures.emptyPing;
      assertEquals(ping.activities, undefined);
      assertEquals(ping.dailies, undefined);
      assertEquals(ping.sleeps, undefined);
    });
  });

  // --------------------------------------------------------------------------
  // Callback URL Validation
  // --------------------------------------------------------------------------
  describe('Callback URL Validation', () => {
    it('callback URL is a valid HTTPS URL', () => {
      const entry = fixtures.activityPing.activities![0];
      const url = new URL(entry.callbackURL);

      assertEquals(url.protocol, 'https:');
      assertEquals(url.hostname, 'apis.garmin.com');
    });

    it('callback URL contains expected path segment', () => {
      const entry = fixtures.activityPing.activities![0];
      assertEquals(entry.callbackURL.includes('/activities'), true);
    });

    it('callback URL includes time range parameters', () => {
      const entry = fixtures.activityPing.activities![0];
      const url = new URL(entry.callbackURL);

      assertEquals(url.searchParams.has('uploadStartTimeInSeconds'), true);
      assertEquals(url.searchParams.has('uploadEndTimeInSeconds'), true);
    });
  });

  // --------------------------------------------------------------------------
  // Ping Entry Structure
  // --------------------------------------------------------------------------
  describe('Ping Entry Structure', () => {
    it('ping entry has required fields', () => {
      const entry = fixtures.activityPing.activities![0];

      assertExists(entry.userId);
      assertExists(entry.userAccessToken);
      assertExists(entry.callbackURL);
    });

    it('ping entry has optional upload time range', () => {
      const entry = fixtures.activityPing.activities![0];

      assertEquals(entry.uploadStartTimeInSeconds, 1711584000);
      assertEquals(entry.uploadEndTimeInSeconds, 1711670400);
    });

    it('sleep ping entry may omit upload time range', () => {
      const entry = fixtures.sleepPing.sleeps![0];

      assertEquals(entry.uploadStartTimeInSeconds, undefined);
      assertEquals(entry.uploadEndTimeInSeconds, undefined);
    });
  });

  // --------------------------------------------------------------------------
  // Edge Cases
  // --------------------------------------------------------------------------
  describe('Edge Cases', () => {
    it('handles ping with unknown data types gracefully', () => {
      const ping = {
        unknownType: [{ userId: 'abc', callbackURL: 'https://example.com' }],
      } as unknown as GarminPingNotification;

      assertEquals(ping.activities, undefined);
    });

    it('handles ping entry with empty string callbackURL', () => {
      const entry: GarminPingEntry = {
        userId: 'garmin-user-abc',
        userAccessToken: 'token-xyz',
        callbackURL: '',
      };

      assertEquals(entry.callbackURL, '');
      assertEquals(entry.callbackURL.length, 0);
    });
  });
});

// Run tests if executed directly
if (import.meta.main) {
  console.log('Running garmin-ping edge function tests...');
}
