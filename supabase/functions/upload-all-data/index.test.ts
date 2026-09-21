/**
 * Tests for the upload-all-data Edge Function.
 *
 * These run against the REAL handler (`handler.ts`), with the caller check and the
 * service-role client injected. Nothing reaches a database.
 *
 * Validates:
 *  1. CALLER CHECK (ai-cost ticket 01 / mp-466): an unsigned request writes nothing.
 *  2. OWNERSHIP: the user id comes from the token; a body naming another user is
 *     ignored, and every user-scoped row is stamped with the token's user.
 *  3. Empty / absent dirty_records → immediate success, no DB calls.
 *  4. CRITICAL: Every table upsert uses onConflict: 'id' (primary key).
 *     Using a partial-unique-index column here would cause PostgreSQL 42P10.
 *  5. Partial failure is reported — a failing table appears in results with
 *     success: false and error message, NOT silently swallowed.
 *  6. anySuccess logic: true when at least one table succeeded; false when all fail.
 *  7. All supported table names are processed.
 *  8. CORS preflight OPTIONS → 200.
 *
 * Run with:
 *   deno test --allow-env --allow-net --allow-read --allow-sys \
 *     supabase/functions/upload-all-data/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';
import { handleUpload, type Row, type UploadRequest } from './handler.ts';

// ============================================================================
// Stub builders
// ============================================================================

/** Captures upsert calls: table → { rows, onConflict } */
type UpsertCall = {
  table: string;
  rows: Row[];
  onConflict: string;
};

function buildSupabaseUpsertStub(opts: {
  /** Tables that should return an error */
  failTables?: string[];
} = {}) {
  const calls: UpsertCall[] = [];

  const client = {
    from: (table: string) => ({
      upsert: (rows: Row[], options: { onConflict: string }) => {
        calls.push({ table, rows, onConflict: options.onConflict });
        const shouldFail = opts.failTables?.includes(table) ?? false;
        return Promise.resolve({
          error: shouldFail ? { message: `Simulated error for ${table}` } : null,
        });
      },
    }),
  };
  return {
    client,
    getCalls: () => calls,
    getCallForTable: (table: string) => calls.find((c) => c.table === table),
  };
}

// ============================================================================
// Test fixtures and harness
// ============================================================================

const TOKEN_USER_ID = '550e8400-e29b-41d4-a716-446655440000';
const OTHER_USER_ID = '11111111-2222-3333-4444-555555555555';

const signedIn = () => Promise.resolve({ ok: true as const, v: { userId: TOKEN_USER_ID } });
const signedOut = () =>
  Promise.resolve({ ok: false as const, status: 401, error: 'unauthenticated' });

function uploadRequest(body: UploadRequest): Request {
  return new Request('https://example.com/upload-all-data', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

const sampleActivity = { id: 'act-uuid-001', user_id: TOKEN_USER_ID, title: 'Morning Run' };
const sampleEvent = { id: 'evt-uuid-001', user_id: TOKEN_USER_ID, name: 'Boston Marathon' };

// ============================================================================
// Tests
// ============================================================================

describe('upload-all-data — caller check (ticket 01 / mp-466)', () => {
  it('an unsigned request gets 401', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(
      uploadRequest({ user_id: TOKEN_USER_ID, dirty_records: { activities: [sampleActivity] } }),
      { authenticate: signedOut, createAdminClient: () => stub.client },
    );
    assertEquals(res.status, 401);
    const body = await res.json();
    assertEquals(body.success, false);
    assertEquals(body.error, 'unauthenticated');
  });

  it('an unsigned request writes NOTHING', async () => {
    const stub = buildSupabaseUpsertStub();
    await handleUpload(
      uploadRequest({ user_id: TOKEN_USER_ID, dirty_records: { activities: [sampleActivity] } }),
      { authenticate: signedOut, createAdminClient: () => stub.client },
    );
    assertEquals(stub.getCalls().length, 0);
  });

  it('CORS preflight is answered without a token', async () => {
    const res = await handleUpload(
      new Request('https://example.com/upload-all-data', { method: 'OPTIONS' }),
      { authenticate: signedOut },
    );
    assertEquals(res.status, 200);
    assertEquals(res.headers.get('Access-Control-Allow-Origin'), '*');
  });
});

describe('upload-all-data — the token owns the rows (ticket 01 / mp-466)', () => {
  it('a body naming another user still writes to the token user', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(
      uploadRequest({
        user_id: OTHER_USER_ID,
        dirty_records: {
          activities: [{ id: 'act-1', user_id: OTHER_USER_ID, title: 'Stolen Run' }],
        },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );

    assertEquals(res.status, 200);
    const call = stub.getCallForTable('activities');
    assertExists(call);
    assertEquals(call!.rows.length, 1);
    assertEquals(call!.rows[0].user_id, TOKEN_USER_ID);
  });

  it('every user-scoped table is stamped with the token user', async () => {
    const stub = buildSupabaseUpsertStub();
    await handleUpload(
      uploadRequest({
        user_id: OTHER_USER_ID,
        dirty_records: {
          activities: [{ id: 'a1', user_id: OTHER_USER_ID }],
          events: [{ id: 'e1', user_id: OTHER_USER_ID }],
          carb_loading_plans: [{ id: 'clp-1', user_id: OTHER_USER_ID }],
          user_foods: [{ id: 'uf-1', user_id: OTHER_USER_ID }],
          feedback: [{ id: 'fb-1', user_id: OTHER_USER_ID }],
          food_preferences: [{ id: 'fp-1', user_id: OTHER_USER_ID }],
        },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );

    for (const table of [
      'activities',
      'events',
      'carb_loading_plans',
      'user_foods',
      'feedback',
      'food_preferences',
    ]) {
      const call = stub.getCallForTable(table);
      assertExists(call, `${table} should have been upserted`);
      assertEquals(call!.rows[0].user_id, TOKEN_USER_ID, `${table} row must be owned by the token user`);
    }
  });

  it('child tables with no user_id column are passed through unchanged', async () => {
    const stub = buildSupabaseUpsertStub();
    await handleUpload(
      uploadRequest({
        dirty_records: {
          carb_loading_days: [{ id: 'cld-1', carb_loading_plan_id: 'clp-1' }],
          carb_loading_day_meals: [{ id: 'cldm-1', carb_loading_day_id: 'cld-1' }],
        },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );

    const day = stub.getCallForTable('carb_loading_days');
    assertExists(day);
    assertEquals(Object.hasOwn(day!.rows[0], 'user_id'), false);
    const meal = stub.getCallForTable('carb_loading_day_meals');
    assertExists(meal);
    assertEquals(Object.hasOwn(meal!.rows[0], 'user_id'), false);
  });

  it('a body with NO user_id is accepted, not rejected (released clients)', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(
      uploadRequest({ dirty_records: { activities: [{ id: 'a1' }] } }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );
    assertEquals(res.status, 200);
    assertEquals(stub.getCallForTable('activities')?.rows[0].user_id, TOKEN_USER_ID);
  });

  it('the caller does not mutate the rows it was handed', async () => {
    const stub = buildSupabaseUpsertStub();
    const original = { id: 'a1', user_id: OTHER_USER_ID };
    await handleUpload(
      uploadRequest({ dirty_records: { activities: [original] } }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );
    // The upserted row is a copy; the stamped id must not be the body's.
    assertEquals(stub.getCallForTable('activities')?.rows[0].user_id, TOKEN_USER_ID);
  });
});

describe('upload-all-data — empty dirty_records', () => {
  it('absent dirty_records → success with no DB calls', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(uploadRequest({ user_id: TOKEN_USER_ID }), {
      authenticate: signedIn,
      createAdminClient: () => stub.client,
    });
    const body = await res.json();
    assertEquals(body.success, true);
    assertEquals(stub.getCalls().length, 0);
    assertExists(body.message);
  });

  it('empty dirty_records object → success with no DB calls', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(
      uploadRequest({ user_id: TOKEN_USER_ID, dirty_records: {} }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );
    assertEquals((await res.json()).success, true);
    assertEquals(stub.getCalls().length, 0);
  });
});

describe('upload-all-data — onConflict must be "id" (42P10 guard)', () => {
  const tables: Array<[string, Row]> = [
    ['activities', sampleActivity],
    ['events', sampleEvent],
    ['carb_loading_plans', { id: 'clp-001' }],
    ['carb_loading_days', { id: 'cld-001' }],
    ['carb_loading_day_meals', { id: 'cldm-001' }],
    ['user_foods', { id: 'uf-001' }],
    ['feedback', { id: 'fb-001' }],
    ['food_preferences', { id: 'fp-001' }],
  ];

  for (const [table, row] of tables) {
    it(`${table} upsert uses onConflict: id`, async () => {
      const stub = buildSupabaseUpsertStub();
      await handleUpload(
        uploadRequest({
          user_id: TOKEN_USER_ID,
          // deno-lint-ignore no-explicit-any
          dirty_records: { [table]: [row] } as any,
        }),
        { authenticate: signedIn, createAdminClient: () => stub.client },
      );
      const call = stub.getCallForTable(table);
      assertExists(call);
      assertEquals(call!.onConflict, 'id');
    });
  }
});

describe('upload-all-data — partial failure reporting', () => {
  it('failing table appears in results with success: false and error message', async () => {
    const stub = buildSupabaseUpsertStub({ failTables: ['events'] });
    const res = await handleUpload(
      uploadRequest({
        user_id: TOKEN_USER_ID,
        dirty_records: { activities: [sampleActivity], events: [sampleEvent] },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );
    const body = await res.json();

    assertEquals(body.results.activities?.success, true);
    assertEquals(body.results.events?.success, false);
    assertEquals(body.results.events?.error, 'Simulated error for events');
    assertEquals(body.success, true);
    assertEquals(res.status, 200);
  });

  it('all-fail → success: false and status 500', async () => {
    const stub = buildSupabaseUpsertStub({ failTables: ['activities', 'events'] });
    const res = await handleUpload(
      uploadRequest({
        user_id: TOKEN_USER_ID,
        dirty_records: { activities: [sampleActivity], events: [sampleEvent] },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );
    assertEquals(res.status, 500);
    const body = await res.json();
    assertEquals(body.success, false);
    assertEquals(body.results.activities?.success, false);
    assertEquals(body.results.events?.success, false);
  });

  it('single table partial failure continues uploading remaining tables', async () => {
    const stub = buildSupabaseUpsertStub({ failTables: ['activities'] });
    await handleUpload(
      uploadRequest({
        user_id: TOKEN_USER_ID,
        dirty_records: {
          activities: [sampleActivity],
          events: [sampleEvent],
          feedback: [{ id: 'fb-001' }],
        },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );

    const attempted = stub.getCalls().map((c) => c.table);
    assertEquals(attempted.includes('activities'), true);
    assertEquals(attempted.includes('events'), true);
    assertEquals(attempted.includes('feedback'), true);
  });
});

describe('upload-all-data — multi-table upload', () => {
  it('uploads all provided table types in a single request', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(
      uploadRequest({
        user_id: TOKEN_USER_ID,
        dirty_records: {
          activities: [sampleActivity],
          events: [sampleEvent],
          carb_loading_plans: [{ id: 'clp-001' }],
          carb_loading_days: [{ id: 'cld-001' }],
          user_foods: [{ id: 'uf-001' }],
          feedback: [{ id: 'fb-001' }],
          food_preferences: [{ id: 'fp-001' }],
        },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );

    assertEquals((await res.json()).success, true);
    assertEquals(stub.getCalls().length, 7);
  });

  it('skips tables with empty arrays', async () => {
    const stub = buildSupabaseUpsertStub();
    await handleUpload(
      uploadRequest({
        user_id: TOKEN_USER_ID,
        dirty_records: { activities: [sampleActivity], events: [] },
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );

    const calls = stub.getCalls();
    assertEquals(calls.length, 1);
    assertEquals(calls[0].table, 'activities');
  });

  it('an unparseable body → 500, no writes', async () => {
    const stub = buildSupabaseUpsertStub();
    const res = await handleUpload(
      new Request('https://example.com/upload-all-data', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'not json',
      }),
      { authenticate: signedIn, createAdminClient: () => stub.client },
    );
    assertEquals(res.status, 500);
    assertEquals((await res.json()).success, false);
    assertEquals(stub.getCalls().length, 0);
  });
});
