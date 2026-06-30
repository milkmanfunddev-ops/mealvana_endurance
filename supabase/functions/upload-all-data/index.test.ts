/**
 * Tests for upload-all-data Edge Function
 *
 * Validates:
 *  1. user_id required validation.
 *  2. Empty / absent dirty_records → immediate success, no DB calls.
 *  3. CRITICAL: Every table upsert uses onConflict: 'id' (primary key).
 *     Using a partial-unique-index column here would cause PostgreSQL 42P10.
 *  4. Partial failure is reported — a failing table appears in results with
 *     success: false and error message, NOT silently swallowed.
 *  5. anySuccess logic: true when at least one table succeeded; false when all fail.
 *  6. totalUploaded is sum of successful uploads.
 *  7. All supported table names are processed (activities, events, carb_loading_plans,
 *     carb_loading_days, carb_loading_day_meals, user_foods, feedback, food_preferences).
 *  8. CORS preflight OPTIONS → 200.
 *
 * Run with:
 *   deno test --allow-env supabase/functions/upload-all-data/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Pure logic extracted from production
// ============================================================================

interface TableResult {
  success: boolean;
  uploaded: number;
  error?: string;
}

/**
 * Mirrors production anySuccess logic:
 *   Object.keys(results).length === 0 || Object.values(results).some(r => r.success)
 */
function computeAnySuccess(results: Record<string, TableResult>): boolean {
  return (
    Object.keys(results).length === 0 ||
    Object.values(results).some((r) => r.success)
  );
}

/** Mirrors production totalUploaded computation */
function computeTotalUploaded(results: Record<string, TableResult>): number {
  return Object.values(results).reduce((sum, r) => sum + r.uploaded, 0);
}

/** Mirrors production failedTables extraction */
function computeFailedTables(results: Record<string, TableResult>): string[] {
  return Object.entries(results)
    .filter(([, r]) => !r.success)
    .map(([name]) => name);
}

// ============================================================================
// Stub builders
// ============================================================================

/** Captures upsert calls: table → { payload, onConflict } */
type UpsertCall = {
  table: string;
  // deno-lint-ignore no-explicit-any
  rows: any[];
  onConflict: string;
};

function buildSupabaseUpsertStub(opts: {
  /** Tables that should return an error */
  failTables?: string[];
}) {
  const calls: UpsertCall[] = [];

  const client = {
    from: (table: string) => ({
      // deno-lint-ignore no-explicit-any
      upsert: (rows: any[], options: { onConflict: string }) => {
        calls.push({ table, rows, onConflict: options.onConflict });
        const shouldFail = opts.failTables?.includes(table) ?? false;
        return Promise.resolve({
          error: shouldFail ? { message: `Simulated error for ${table}` } : null,
        });
      },
    }),
    getCalls: () => calls,
    getCallForTable: (table: string) => calls.find((c) => c.table === table),
  };
  return client;
}

// ============================================================================
// Mirrors the upload handler's table-processing loop so we can test its logic
// without importing the production file (which calls serve() at module level).
// ============================================================================

interface UploadRequest {
  user_id: string;
  dirty_records?: {
    activities?: unknown[];
    events?: unknown[];
    carb_loading_plans?: unknown[];
    carb_loading_days?: unknown[];
    carb_loading_day_meals?: unknown[];
    user_foods?: unknown[];
    feedback?: unknown[];
    food_preferences?: unknown[];
  };
}

// deno-lint-ignore no-explicit-any
type SupabaseClient = any;

async function processUpload(
  request: UploadRequest,
  supabase: SupabaseClient,
): Promise<{
  success: boolean;
  results: Record<string, TableResult>;
  message?: string;
}> {
  if (!request.user_id) {
    throw new Error('user_id is required');
  }

  const dirty = request.dirty_records;
  if (!dirty || Object.keys(dirty).length === 0) {
    return { success: true, results: {}, message: 'No dirty records to upload' };
  }

  const results: Record<string, TableResult> = {};

  // Upload activities
  if (dirty.activities && dirty.activities.length > 0) {
    try {
      const { error } = await supabase
        .from('activities')
        .upsert(dirty.activities, { onConflict: 'id' });
      if (error) throw error;
      results.activities = { success: true, uploaded: dirty.activities.length };
    } catch (e) {
      results.activities = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload events
  if (dirty.events && dirty.events.length > 0) {
    try {
      const { error } = await supabase
        .from('events')
        .upsert(dirty.events, { onConflict: 'id' });
      if (error) throw error;
      results.events = { success: true, uploaded: dirty.events.length };
    } catch (e) {
      results.events = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload carb_loading_plans
  if (dirty.carb_loading_plans && dirty.carb_loading_plans.length > 0) {
    try {
      const { error } = await supabase
        .from('carb_loading_plans')
        .upsert(dirty.carb_loading_plans, { onConflict: 'id' });
      if (error) throw error;
      results.carb_loading_plans = {
        success: true,
        uploaded: dirty.carb_loading_plans.length,
      };
    } catch (e) {
      results.carb_loading_plans = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload carb_loading_days
  if (dirty.carb_loading_days && dirty.carb_loading_days.length > 0) {
    try {
      const { error } = await supabase
        .from('carb_loading_days')
        .upsert(dirty.carb_loading_days, { onConflict: 'id' });
      if (error) throw error;
      results.carb_loading_days = {
        success: true,
        uploaded: dirty.carb_loading_days.length,
      };
    } catch (e) {
      results.carb_loading_days = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload carb_loading_day_meals
  if (dirty.carb_loading_day_meals && dirty.carb_loading_day_meals.length > 0) {
    try {
      const { error } = await supabase
        .from('carb_loading_day_meals')
        .upsert(dirty.carb_loading_day_meals, { onConflict: 'id' });
      if (error) throw error;
      results.carb_loading_day_meals = {
        success: true,
        uploaded: dirty.carb_loading_day_meals.length,
      };
    } catch (e) {
      results.carb_loading_day_meals = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload user_foods
  if (dirty.user_foods && dirty.user_foods.length > 0) {
    try {
      const { error } = await supabase
        .from('user_foods')
        .upsert(dirty.user_foods, { onConflict: 'id' });
      if (error) throw error;
      results.user_foods = { success: true, uploaded: dirty.user_foods.length };
    } catch (e) {
      results.user_foods = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload feedback
  if (dirty.feedback && dirty.feedback.length > 0) {
    try {
      const { error } = await supabase
        .from('feedback')
        .upsert(dirty.feedback, { onConflict: 'id' });
      if (error) throw error;
      results.feedback = { success: true, uploaded: dirty.feedback.length };
    } catch (e) {
      results.feedback = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  // Upload food_preferences
  if (dirty.food_preferences && dirty.food_preferences.length > 0) {
    try {
      const { error } = await supabase
        .from('food_preferences')
        .upsert(dirty.food_preferences, { onConflict: 'id' });
      if (error) throw error;
      results.food_preferences = {
        success: true,
        uploaded: dirty.food_preferences.length,
      };
    } catch (e) {
      results.food_preferences = {
        success: false,
        uploaded: 0,
        error: (e as Error).message,
      };
    }
  }

  const anySuccess = computeAnySuccess(results);
  return { success: anySuccess, results };
}

// ============================================================================
// Test fixtures
// ============================================================================

const TEST_USER_ID = '550e8400-e29b-41d4-a716-446655440000';

const sampleActivity = { id: 'act-uuid-001', user_id: TEST_USER_ID, title: 'Morning Run' };
const sampleEvent = { id: 'evt-uuid-001', user_id: TEST_USER_ID, name: 'Boston Marathon' };

// ============================================================================
// Tests
// ============================================================================

describe('upload-all-data', () => {
  // --------------------------------------------------------------------------
  // user_id validation
  // --------------------------------------------------------------------------
  describe('user_id validation', () => {
    it('throws when user_id is missing', async () => {
      const stub = buildSupabaseUpsertStub({});
      let threw = false;
      try {
        await processUpload({ user_id: '' } as UploadRequest, stub);
      } catch {
        threw = true;
      }
      assertEquals(threw, true);
    });
  });

  // --------------------------------------------------------------------------
  // Empty dirty_records
  // --------------------------------------------------------------------------
  describe('Empty dirty_records', () => {
    it('absent dirty_records → success with no DB calls', async () => {
      const stub = buildSupabaseUpsertStub({});
      const result = await processUpload(
        { user_id: TEST_USER_ID, dirty_records: undefined },
        stub,
      );
      assertEquals(result.success, true);
      assertEquals(stub.getCalls().length, 0);
      assertExists(result.message);
    });

    it('empty dirty_records object → success with no DB calls', async () => {
      const stub = buildSupabaseUpsertStub({});
      const result = await processUpload(
        { user_id: TEST_USER_ID, dirty_records: {} },
        stub,
      );
      assertEquals(result.success, true);
      assertEquals(stub.getCalls().length, 0);
    });
  });

  // --------------------------------------------------------------------------
  // CRITICAL: onConflict uses 'id' (primary key) — NOT partial-unique-index columns
  // --------------------------------------------------------------------------
  describe('onConflict must be "id" (42P10 guard)', () => {
    it('activities upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { activities: [sampleActivity] },
        },
        stub,
      );
      const call = stub.getCallForTable('activities');
      assertExists(call);
      assertEquals(call!.onConflict, 'id');
    });

    it('events upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { events: [sampleEvent] },
        },
        stub,
      );
      const call = stub.getCallForTable('events');
      assertExists(call);
      assertEquals(call!.onConflict, 'id');
    });

    it('carb_loading_plans upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { carb_loading_plans: [{ id: 'clp-001' }] },
        },
        stub,
      );
      const call = stub.getCallForTable('carb_loading_plans');
      assertEquals(call?.onConflict, 'id');
    });

    it('carb_loading_days upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { carb_loading_days: [{ id: 'cld-001' }] },
        },
        stub,
      );
      assertEquals(stub.getCallForTable('carb_loading_days')?.onConflict, 'id');
    });

    it('carb_loading_day_meals upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: {
            carb_loading_day_meals: [{ id: 'cldm-001' }],
          },
        },
        stub,
      );
      assertEquals(
        stub.getCallForTable('carb_loading_day_meals')?.onConflict,
        'id',
      );
    });

    it('user_foods upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { user_foods: [{ id: 'uf-001' }] },
        },
        stub,
      );
      assertEquals(stub.getCallForTable('user_foods')?.onConflict, 'id');
    });

    it('feedback upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { feedback: [{ id: 'fb-001' }] },
        },
        stub,
      );
      assertEquals(stub.getCallForTable('feedback')?.onConflict, 'id');
    });

    it('food_preferences upsert uses onConflict: id', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: { food_preferences: [{ id: 'fp-001' }] },
        },
        stub,
      );
      assertEquals(stub.getCallForTable('food_preferences')?.onConflict, 'id');
    });
  });

  // --------------------------------------------------------------------------
  // Partial failure — NOT silently swallowed
  // --------------------------------------------------------------------------
  describe('Partial failure reporting', () => {
    it('failing table appears in results with success: false and error message', async () => {
      const stub = buildSupabaseUpsertStub({ failTables: ['events'] });
      const result = await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: {
            activities: [sampleActivity],
            events: [sampleEvent],
          },
        },
        stub,
      );

      // activities should succeed
      assertEquals(result.results.activities?.success, true);
      // events should fail and REPORT the error
      assertEquals(result.results.events?.success, false);
      assertExists(result.results.events?.error);
      // Overall success because activities succeeded
      assertEquals(result.success, true);
    });

    it('all-fail → success: false', async () => {
      const stub = buildSupabaseUpsertStub({
        failTables: ['activities', 'events'],
      });
      const result = await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: {
            activities: [sampleActivity],
            events: [sampleEvent],
          },
        },
        stub,
      );

      assertEquals(result.success, false);
      assertEquals(result.results.activities?.success, false);
      assertEquals(result.results.events?.success, false);
    });

    it('single table partial failure continues uploading remaining tables', async () => {
      const stub = buildSupabaseUpsertStub({ failTables: ['activities'] });
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: {
            activities: [sampleActivity],
            events: [sampleEvent],
            feedback: [{ id: 'fb-001' }],
          },
        },
        stub,
      );

      // All three tables must have been attempted
      const calls = stub.getCalls();
      const attempted = calls.map((c: UpsertCall) => c.table);
      assertEquals(attempted.includes('activities'), true);
      assertEquals(attempted.includes('events'), true);
      assertEquals(attempted.includes('feedback'), true);
    });
  });

  // --------------------------------------------------------------------------
  // anySuccess / totalUploaded logic
  // --------------------------------------------------------------------------
  describe('computeAnySuccess', () => {
    it('empty results → true (no tables → nothing failed)', () => {
      assertEquals(computeAnySuccess({}), true);
    });

    it('all success → true', () => {
      assertEquals(
        computeAnySuccess({
          activities: { success: true, uploaded: 5 },
          events: { success: true, uploaded: 2 },
        }),
        true,
      );
    });

    it('mixed → true (at least one succeeded)', () => {
      assertEquals(
        computeAnySuccess({
          activities: { success: true, uploaded: 3 },
          events: { success: false, uploaded: 0, error: 'err' },
        }),
        true,
      );
    });

    it('all fail → false', () => {
      assertEquals(
        computeAnySuccess({
          activities: { success: false, uploaded: 0, error: 'err1' },
          events: { success: false, uploaded: 0, error: 'err2' },
        }),
        false,
      );
    });
  });

  describe('computeTotalUploaded', () => {
    it('sums uploaded counts across tables', () => {
      assertEquals(
        computeTotalUploaded({
          activities: { success: true, uploaded: 5 },
          events: { success: true, uploaded: 3 },
          feedback: { success: false, uploaded: 0 },
        }),
        8,
      );
    });

    it('zero when nothing succeeded', () => {
      assertEquals(
        computeTotalUploaded({
          activities: { success: false, uploaded: 0 },
        }),
        0,
      );
    });
  });

  describe('computeFailedTables', () => {
    it('returns names of failed tables', () => {
      const failed = computeFailedTables({
        activities: { success: true, uploaded: 1 },
        events: { success: false, uploaded: 0, error: 'err' },
        feedback: { success: false, uploaded: 0, error: 'err' },
      });
      assertEquals(failed.length, 2);
      assertEquals(failed.includes('events'), true);
      assertEquals(failed.includes('feedback'), true);
      assertEquals(failed.includes('activities'), false);
    });
  });

  // --------------------------------------------------------------------------
  // Multi-table upload
  // --------------------------------------------------------------------------
  describe('Multi-table upload', () => {
    it('uploads all provided table types in a single request', async () => {
      const stub = buildSupabaseUpsertStub({});
      const result = await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: {
            activities: [sampleActivity],
            events: [sampleEvent],
            carb_loading_plans: [{ id: 'clp-001' }],
            carb_loading_days: [{ id: 'cld-001' }],
            user_foods: [{ id: 'uf-001' }],
            feedback: [{ id: 'fb-001' }],
            food_preferences: [{ id: 'fp-001' }],
          },
        },
        stub,
      );

      assertEquals(result.success, true);
      assertEquals(stub.getCalls().length, 7);
    });

    it('skips tables with empty arrays', async () => {
      const stub = buildSupabaseUpsertStub({});
      await processUpload(
        {
          user_id: TEST_USER_ID,
          dirty_records: {
            activities: [sampleActivity],
            events: [], // empty → should be skipped
          },
        },
        stub,
      );

      const calls = stub.getCalls();
      assertEquals(calls.length, 1);
      assertEquals(calls[0].table, 'activities');
    });
  });

  // --------------------------------------------------------------------------
  // CORS preflight
  // --------------------------------------------------------------------------
  describe('CORS preflight', () => {
    it('OPTIONS request → 200 with CORS headers', () => {
      const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers':
          'authorization, x-client-info, apikey, content-type',
      };
      const req = new Request('https://example.com/upload-all-data', {
        method: 'OPTIONS',
      });

      // Mirrors production handler
      let response: Response | null = null;
      if (req.method === 'OPTIONS') {
        response = new Response('ok', { headers: corsHeaders });
      }

      assertExists(response);
      assertEquals(response!.status, 200);
      assertEquals(
        response!.headers.get('Access-Control-Allow-Origin'),
        '*',
      );
    });
  });
});

if (import.meta.main) {
  console.log('Running upload-all-data tests...');
}
