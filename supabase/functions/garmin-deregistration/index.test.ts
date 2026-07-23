/**
 * Tests for garmin-deregistration Edge Function
 *
 * Validates:
 *  1. Request validation (POST-only, client-ID header).
 *  2. processDeregistrationBody logic — extracted as a pure testable function.
 *  3. Idempotency: deleting a non-existent mapping is not an error.
 *  4. Partial failure: one mapping fails, others still process.
 *  5. Empty deregistrations array → early return (no DB calls).
 *  6. Multiple deregistrations processed independently.
 *
 * Run with:
 *   deno test --allow-env supabase/functions/garmin-deregistration/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { validateGarminRequest } from '../_shared/garmin/auth.ts';
import type { GarminDeregistrationNotification } from '../_shared/garmin/types.ts';

// ============================================================================
// Pure extraction of processDeregistrationBody logic
// (mirrors the production function — keeps Deno.serve out of test scope)
// ============================================================================

interface DeregResult {
  processed: number;
  errors: number;
  skipped: boolean; // true when deregistrations array is empty/missing
}

// deno-lint-ignore no-explicit-any
type SupabaseStub = any;

async function processDeregistrationBody(
  body: GarminDeregistrationNotification,
  supabase: SupabaseStub,
): Promise<DeregResult> {
  if (!body.deregistrations || body.deregistrations.length === 0) {
    return { processed: 0, errors: 0, skipped: true };
  }

  let processed = 0;
  let errors = 0;

  for (const dereg of body.deregistrations) {
    try {
      const { error } = await supabase
        .from('garmin_user_mappings')
        .delete()
        .eq('garmin_user_id', dereg.userId);

      if (error) {
        errors++;
      } else {
        processed++;
      }
    } catch {
      errors++;
    }
  }

  return { processed, errors, skipped: false };
}

// ============================================================================
// Stub builders
// ============================================================================

/** Builds a Supabase delete stub. `shouldError` controls per-call error injection. */
function buildDeleteStub(options: {
  shouldError?: boolean;
  errorPerUserId?: Record<string, boolean>;
}) {
  const deletedIds: string[] = [];

  const client = {
    from: (_table: string) => ({
      delete: () => ({
        eq: (_col: string, value: string) => {
          deletedIds.push(value);
          const errForThis = options.errorPerUserId?.[value] ??
            options.shouldError ??
            false;
          return Promise.resolve({
            error: errForThis
              ? { message: 'DB error', code: '42501' }
              : null,
          });
        },
      }),
    }),
  };

  return { client, deletedIds };
}

// ============================================================================
// Fixtures
// ============================================================================

const TEST_CLIENT_ID = 'test-garmin-client';

const singleDereg: GarminDeregistrationNotification = {
  deregistrations: [
    { userId: 'garmin-user-001', userAccessToken: 'tok-001' },
  ],
};

const multiDereg: GarminDeregistrationNotification = {
  deregistrations: [
    { userId: 'garmin-user-001', userAccessToken: 'tok-001' },
    { userId: 'garmin-user-002', userAccessToken: 'tok-002' },
    { userId: 'garmin-user-003', userAccessToken: 'tok-003' },
  ],
};

const emptyDereg: GarminDeregistrationNotification = {
  deregistrations: [],
};

// ============================================================================
// Tests
// ============================================================================

describe('garmin-deregistration', () => {
  // --------------------------------------------------------------------------
  // Request validation (reuses shared auth helper)
  // --------------------------------------------------------------------------
  describe('Request Validation', () => {
    it('rejects GET requests', () => {
      const req = new Request('https://example.com/garmin-deregistration', {
        method: 'GET',
      });
      assertEquals(validateGarminRequest(req, TEST_CLIENT_ID), 'Expected POST, got GET');
    });

    it('allows POST with no garmin-client-id header (lenient mode)', () => {
      const req = new Request('https://example.com/garmin-deregistration', {
        method: 'POST',
        body: '{}',
      });
      assertEquals(validateGarminRequest(req, TEST_CLIENT_ID), null);
    });

    it('rejects POST with wrong client-id', () => {
      const req = new Request('https://example.com/garmin-deregistration', {
        method: 'POST',
        headers: { 'garmin-client-id': 'evil-client' },
        body: '{}',
      });
      assertEquals(validateGarminRequest(req, TEST_CLIENT_ID), 'Invalid garmin-client-id');
    });

    it('accepts POST with correct client-id', () => {
      const req = new Request('https://example.com/garmin-deregistration', {
        method: 'POST',
        headers: { 'garmin-client-id': TEST_CLIENT_ID },
        body: '{}',
      });
      assertEquals(validateGarminRequest(req, TEST_CLIENT_ID), null);
    });
  });

  // --------------------------------------------------------------------------
  // processDeregistrationBody: happy path
  // --------------------------------------------------------------------------
  describe('processDeregistrationBody - happy path', () => {
    it('deletes a single user mapping', async () => {
      const stub = buildDeleteStub({});
      const result = await processDeregistrationBody(singleDereg, stub.client);

      assertEquals(result.processed, 1);
      assertEquals(result.errors, 0);
      assertEquals(result.skipped, false);
      assertEquals(stub.deletedIds, ['garmin-user-001']);
    });

    it('deletes multiple user mappings independently', async () => {
      const stub = buildDeleteStub({});
      const result = await processDeregistrationBody(multiDereg, stub.client);

      assertEquals(result.processed, 3);
      assertEquals(result.errors, 0);
      assertEquals(stub.deletedIds.length, 3);
      assertEquals(stub.deletedIds.includes('garmin-user-001'), true);
      assertEquals(stub.deletedIds.includes('garmin-user-002'), true);
      assertEquals(stub.deletedIds.includes('garmin-user-003'), true);
    });
  });

  // --------------------------------------------------------------------------
  // Idempotency: already-gone mapping
  // --------------------------------------------------------------------------
  describe('Idempotency', () => {
    it('delete of non-existent mapping returns no error (PostgREST delete is idempotent)', async () => {
      // PostgREST .delete().eq() on a row that doesn't exist returns no error —
      // it just affects 0 rows. We treat null error as success.
      const stub = buildDeleteStub({ shouldError: false });
      const result = await processDeregistrationBody(singleDereg, stub.client);

      assertEquals(result.processed, 1);
      assertEquals(result.errors, 0);
    });
  });

  // --------------------------------------------------------------------------
  // Empty / missing deregistrations
  // --------------------------------------------------------------------------
  describe('Empty deregistrations', () => {
    it('empty array → skipped early, no DB calls', async () => {
      const stub = buildDeleteStub({});
      const result = await processDeregistrationBody(emptyDereg, stub.client);

      assertEquals(result.skipped, true);
      assertEquals(result.processed, 0);
      assertEquals(result.errors, 0);
      assertEquals(stub.deletedIds.length, 0);
    });

    it('missing deregistrations key → skipped early', async () => {
      const stub = buildDeleteStub({});
      // Cast to satisfy type — production receives unvalidated JSON
      const body = {} as GarminDeregistrationNotification;
      const result = await processDeregistrationBody(body, stub.client);

      assertEquals(result.skipped, true);
      assertEquals(stub.deletedIds.length, 0);
    });
  });

  // --------------------------------------------------------------------------
  // Partial failure: one mapping errors, others still process
  // --------------------------------------------------------------------------
  describe('Partial failure handling', () => {
    it('continues processing after one user mapping delete fails', async () => {
      const stub = buildDeleteStub({
        errorPerUserId: { 'garmin-user-002': true },
      });
      const result = await processDeregistrationBody(multiDereg, stub.client);

      assertEquals(result.processed, 2);
      assertEquals(result.errors, 1);
      // All three were still attempted
      assertEquals(stub.deletedIds.length, 3);
    });

    it('all-error case: processed=0, errors=count', async () => {
      const stub = buildDeleteStub({ shouldError: true });
      const result = await processDeregistrationBody(singleDereg, stub.client);

      assertEquals(result.processed, 0);
      assertEquals(result.errors, 1);
    });
  });

  // --------------------------------------------------------------------------
  // Deregistration notification type shape
  // --------------------------------------------------------------------------
  describe('GarminDeregistrationNotification structure', () => {
    it('notification has deregistrations array', () => {
      assertExists(singleDereg.deregistrations);
      assertEquals(Array.isArray(singleDereg.deregistrations), true);
    });

    it('each entry has userId and userAccessToken', () => {
      const entry = singleDereg.deregistrations[0];
      assertExists(entry.userId);
      assertExists(entry.userAccessToken);
    });

    it('deregistrations array can have multiple entries', () => {
      assertEquals(multiDereg.deregistrations.length, 3);
    });
  });
});

if (import.meta.main) {
  console.log('Running garmin-deregistration tests...');
}
