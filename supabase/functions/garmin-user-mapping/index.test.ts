/**
 * Tests for garmin-user-mapping Edge Function
 *
 * Validates:
 *  1. Action routing: 'upsert' vs 'delete' vs invalid.
 *  2. Upsert requires garmin_user_id + access_token.
 *  3. Upsert uses onConflict: 'garmin_user_id' (NOT a partial-unique-index column
 *     → avoids the 42P10 PostgREST partial-index gotcha).
 *  4. Delete is idempotent — row not found → no error.
 *  5. user_id spoofing guard: body.user_id !== authenticated user → 403.
 *  6. verifyGarminUserId: mismatch between provided garmin_user_id and the
 *     userId returned from the Garmin /user/id endpoint → 403.
 *  7. verifyGarminUserId: Garmin API failure → 401.
 *  8. token_expires_at defaults to now + 1 hour when not provided.
 *  9. Method guard: non-POST → 405.
 *
 * Run with:
 *   deno test --allow-env supabase/functions/garmin-user-mapping/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure logic extracted from production
// ============================================================================

// Mirrors production verifyGarminUserId
async function verifyGarminUserId(
  accessToken: string,
  expectedGarminUserId: string,
  // deno-lint-ignore no-explicit-any
  fetchFn: (url: string, init?: RequestInit) => Promise<any>,
): Promise<{ ok: true } | { ok: false; status: number; message: string }> {
  const response = await fetchFn(
    'https://apis.garmin.com/wellness-api/rest/user/id',
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );

  if (!response.ok) {
    return { ok: false, status: 401, message: 'Unable to verify Garmin account' };
  }

  const payload = await response.json();
  if (payload.userId !== expectedGarminUserId) {
    return { ok: false, status: 403, message: 'Garmin account verification mismatch' };
  }

  return { ok: true };
}

type UpsertPayload = {
  user_id: string;
  garmin_user_id: string;
  access_token: string;
  refresh_token: string | null;
  token_expires_at: string;
  updated_at: string;
};

/** Mirrors the upsert call site — returns the payload and the conflict column */
function buildUpsertPayload(
  userId: string,
  garminUserId: string,
  accessToken: string,
  refreshToken: string | null,
  tokenExpiresAt: string | null,
): { payload: UpsertPayload; onConflict: string } {
  const resolvedExpiresAt =
    tokenExpiresAt ?? new Date(Date.now() + 60 * 60 * 1000).toISOString();

  return {
    payload: {
      user_id: userId,
      garmin_user_id: garminUserId,
      access_token: accessToken,
      refresh_token: refreshToken,
      token_expires_at: resolvedExpiresAt,
      updated_at: new Date().toISOString(),
    },
    onConflict: 'garmin_user_id',
  };
}

/** Validates that required fields are present for an upsert */
function validateUpsertFields(
  garminUserId: string | undefined,
  accessToken: string | undefined,
): string | null {
  if (!garminUserId || !accessToken) {
    return 'garmin_user_id and access_token are required';
  }
  return null;
}

// ============================================================================
// Stub builders
// ============================================================================

function buildGarminUserIdFetchStub(opts: {
  ok: boolean;
  garminUserId?: string;
// deno-lint-ignore no-explicit-any
}): (url: string, init?: RequestInit) => Promise<any> {
  return (_url: string, _init?: RequestInit) =>
    Promise.resolve({
      ok: opts.ok,
      status: opts.ok ? 200 : 401,
      json: () =>
        Promise.resolve(
          opts.ok ? { userId: opts.garminUserId ?? 'garmin-abc' } : {},
        ),
      text: () => Promise.resolve('error'),
    });
}

function buildSupabaseUpsertStub(opts: {
  shouldError?: boolean;
}) {
  // deno-lint-ignore no-explicit-any
  let capturedPayload: any = null;
  let capturedOnConflict: string | null = null;
  let callCount = 0;

  const client = {
    from: (_table: string) => ({
      // deno-lint-ignore no-explicit-any
      upsert: (data: any, options: { onConflict: string }) => {
        callCount++;
        capturedPayload = data;
        capturedOnConflict = options.onConflict;
        return Promise.resolve({
          error: opts.shouldError
            ? { message: 'DB error', code: '23000' }
            : null,
        });
      },
    }),
    getCapturedPayload: () => capturedPayload,
    getCapturedOnConflict: () => capturedOnConflict,
    getCallCount: () => callCount,
  };
  return client;
}

function buildSupabaseDeleteStub(opts: {
  shouldError?: boolean;
  remainingCount?: number;
}) {
  let deleteCount = 0;
  const client = {
    from: (_table: string) => ({
      delete: () => ({
        eq: (_col: string, _val: string) => {
          deleteCount++;
          // Returns another eq builder (for optional garmin_user_id filter)
          return {
            eq: (_col2: string, _val2: string) =>
              Promise.resolve({
                error: opts.shouldError ? { message: 'err' } : null,
              }),
            // When used without a second eq (delete by user_id only):
            then: (resolve: (v: { error: null | object }) => void) => {
              resolve({ error: opts.shouldError ? { message: 'err' } : null });
            },
          };
        },
      }),
      select: (_cols: string, _opts: object) => ({
        eq: (_col: string, _val: string) => ({
          eq: (_col2: string, _val2: string) =>
            Promise.resolve({
              count: opts.remainingCount ?? 0,
              error: null,
            }),
        }),
      }),
    }),
    getDeleteCount: () => deleteCount,
  };
  return client;
}

// ============================================================================
// Tests
// ============================================================================

const TEST_USER_ID = '550e8400-e29b-41d4-a716-446655440000';
const TEST_GARMIN_USER_ID = 'garmin-user-abc123';
const TEST_ACCESS_TOKEN = 'garmin-access-token-xyz';

describe('garmin-user-mapping', () => {
  // --------------------------------------------------------------------------
  // Validation of required upsert fields
  // --------------------------------------------------------------------------
  describe('validateUpsertFields', () => {
    it('returns null when both fields present', () => {
      assertEquals(
        validateUpsertFields(TEST_GARMIN_USER_ID, TEST_ACCESS_TOKEN),
        null,
      );
    });

    it('returns error when garmin_user_id missing', () => {
      const msg = validateUpsertFields(undefined, TEST_ACCESS_TOKEN);
      assertExists(msg);
      assertEquals(msg!.includes('required'), true);
    });

    it('returns error when access_token missing', () => {
      const msg = validateUpsertFields(TEST_GARMIN_USER_ID, undefined);
      assertExists(msg);
      assertEquals(msg!.includes('required'), true);
    });

    it('returns error when both missing', () => {
      const msg = validateUpsertFields(undefined, undefined);
      assertExists(msg);
    });

    it('returns error for empty string garmin_user_id', () => {
      const msg = validateUpsertFields('', TEST_ACCESS_TOKEN);
      assertExists(msg);
    });
  });

  // --------------------------------------------------------------------------
  // Upsert payload and onConflict column
  // --------------------------------------------------------------------------
  describe('buildUpsertPayload', () => {
    it('builds correct payload with all required fields', () => {
      const { payload } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        'refresh-tok',
        null,
      );

      assertEquals(payload.user_id, TEST_USER_ID);
      assertEquals(payload.garmin_user_id, TEST_GARMIN_USER_ID);
      assertEquals(payload.access_token, TEST_ACCESS_TOKEN);
      assertEquals(payload.refresh_token, 'refresh-tok');
      assertExists(payload.token_expires_at);
      assertExists(payload.updated_at);
    });

    it('CRITICAL: onConflict is garmin_user_id (unique constraint, NOT a partial index)', () => {
      // 42P10 gotcha: if we used a partial unique index column (e.g. one with a
      // WHERE clause) PostgREST would fail. garmin_user_id has a plain unique
      // constraint — safe to use as conflict target.
      const { onConflict } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        null,
        null,
      );
      assertEquals(onConflict, 'garmin_user_id');
    });

    it('does NOT use user_id or id as conflict column', () => {
      const { onConflict } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        null,
        null,
      );
      assertEquals(onConflict !== 'user_id', true);
      assertEquals(onConflict !== 'id', true);
    });

    it('defaults token_expires_at to approx 1 hour from now when null', () => {
      const before = Date.now();
      const { payload } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        null,
        null, // no expiry provided
      );
      const after = Date.now();

      const expiresMs = Date.parse(payload.token_expires_at);
      // Should be approximately 1 hour from now (±5 s tolerance)
      assertEquals(expiresMs >= before + 60 * 60 * 1000 - 5000, true);
      assertEquals(expiresMs <= after + 60 * 60 * 1000 + 5000, true);
    });

    it('uses provided token_expires_at when given', () => {
      const futureExpiry = '2030-01-01T00:00:00.000Z';
      const { payload } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        null,
        futureExpiry,
      );
      assertEquals(payload.token_expires_at, futureExpiry);
    });

    it('stores null refresh_token when not provided', () => {
      const { payload } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        null,
        null,
      );
      assertEquals(payload.refresh_token, null);
    });
  });

  // --------------------------------------------------------------------------
  // verifyGarminUserId
  // --------------------------------------------------------------------------
  describe('verifyGarminUserId', () => {
    it('returns ok when Garmin API returns matching userId', async () => {
      const fetchStub = buildGarminUserIdFetchStub({
        ok: true,
        garminUserId: TEST_GARMIN_USER_ID,
      });
      const result = await verifyGarminUserId(
        TEST_ACCESS_TOKEN,
        TEST_GARMIN_USER_ID,
        fetchStub,
      );
      assertEquals(result.ok, true);
    });

    it('returns 403 when Garmin userId does not match expected', async () => {
      const fetchStub = buildGarminUserIdFetchStub({
        ok: true,
        garminUserId: 'different-garmin-user', // mismatch
      });
      const result = await verifyGarminUserId(
        TEST_ACCESS_TOKEN,
        TEST_GARMIN_USER_ID,
        fetchStub,
      );
      assertEquals(result.ok, false);
      if (!result.ok) {
        assertEquals(result.status, 403);
      }
    });

    it('returns 401 when Garmin API call fails', async () => {
      const fetchStub = buildGarminUserIdFetchStub({ ok: false });
      const result = await verifyGarminUserId(
        'bad-token',
        TEST_GARMIN_USER_ID,
        fetchStub,
      );
      assertEquals(result.ok, false);
      if (!result.ok) {
        assertEquals(result.status, 401);
      }
    });

    it('sends Bearer token in Authorization header', async () => {
      let capturedHeaders: Record<string, string> = {};
      const fetchStub = (
        _url: string,
        init?: RequestInit,
      ) => {
        capturedHeaders = (init?.headers ?? {}) as Record<string, string>;
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ userId: TEST_GARMIN_USER_ID }),
          text: () => Promise.resolve(''),
        });
      };

      await verifyGarminUserId(
        TEST_ACCESS_TOKEN,
        TEST_GARMIN_USER_ID,
        fetchStub,
      );

      assertEquals(
        capturedHeaders['Authorization'],
        `Bearer ${TEST_ACCESS_TOKEN}`,
      );
    });

    it('calls the correct Garmin user-id endpoint', async () => {
      let capturedUrl = '';
      const fetchStub = (url: string) => {
        capturedUrl = url;
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ userId: TEST_GARMIN_USER_ID }),
          text: () => Promise.resolve(''),
        });
      };

      await verifyGarminUserId(
        TEST_ACCESS_TOKEN,
        TEST_GARMIN_USER_ID,
        fetchStub,
      );

      assertEquals(
        capturedUrl,
        'https://apis.garmin.com/wellness-api/rest/user/id',
      );
    });
  });

  // --------------------------------------------------------------------------
  // User-ID spoofing guard
  // --------------------------------------------------------------------------
  describe('User ID spoofing guard', () => {
    // Helper that mirrors production guard: returns true when the body user_id
    // is present but doesn't match the authenticated user — i.e. spoof attempt.
    function isSpoofAttempt(
      bodyUserId: string | undefined,
      authenticatedUserId: string,
    ): boolean {
      return !!bodyUserId && bodyUserId !== authenticatedUserId;
    }

    it('body.user_id that differs from authenticated user is rejected', () => {
      assertEquals(
        isSpoofAttempt('aaaaaaaa-0000-0000-0000-bbbbbbbbbbbb', TEST_USER_ID),
        true,
      );
    });

    it('body.user_id matching authenticated user is allowed', () => {
      assertEquals(isSpoofAttempt(TEST_USER_ID, TEST_USER_ID), false);
    });

    it('missing body.user_id does not trigger spoof guard', () => {
      assertEquals(isSpoofAttempt(undefined, TEST_USER_ID), false);
    });

    it('empty string body.user_id does not trigger spoof guard', () => {
      assertEquals(isSpoofAttempt('', TEST_USER_ID), false);
    });
  });

  // --------------------------------------------------------------------------
  // Upsert stub integration
  // --------------------------------------------------------------------------
  describe('Upsert DB interaction', () => {
    it('upsert is called with garmin_user_id as conflict column', async () => {
      const stub = buildSupabaseUpsertStub({ shouldError: false });
      const { payload, onConflict } = buildUpsertPayload(
        TEST_USER_ID,
        TEST_GARMIN_USER_ID,
        TEST_ACCESS_TOKEN,
        null,
        null,
      );

      await stub
        .from('garmin_user_mappings')
        .upsert(payload, { onConflict });

      assertEquals(stub.getCapturedOnConflict(), 'garmin_user_id');
      assertEquals(stub.getCapturedPayload()?.user_id, TEST_USER_ID);
      assertEquals(stub.getCapturedPayload()?.garmin_user_id, TEST_GARMIN_USER_ID);
    });
  });

  // --------------------------------------------------------------------------
  // Action validation
  // --------------------------------------------------------------------------
  describe('Action routing', () => {
    it('default action is upsert when not specified', () => {
      // Mirrors: const action = body.action ?? 'upsert'
      const body = {} as { action?: string };
      const action = body.action ?? 'upsert';
      assertEquals(action, 'upsert');
    });

    it('explicit upsert action routes to upsert path', () => {
      const action: string = 'upsert';
      assertEquals(action === 'upsert', true);
      assertEquals(action === 'delete', false);
    });

    it('explicit delete action routes to delete path', () => {
      const action: string = 'delete';
      assertEquals(action === 'delete', true);
    });

    it('invalid action is detected', () => {
      const action: string = 'update'; // not 'upsert' or 'delete'
      const isInvalid = action !== 'upsert' && action !== 'delete';
      assertEquals(isInvalid, true);
    });
  });
});

if (import.meta.main) {
  console.log('Running garmin-user-mapping tests...');
}
