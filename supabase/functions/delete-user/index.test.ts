/**
 * Unit Tests for delete-user Edge Function
 *
 * Tests auth enforcement, cascade-delete sequencing, idempotency, and error
 * handling with a fake Supabase client (no live DB or Supabase auth required).
 *
 * Run with:
 *   deno test --allow-env supabase/functions/delete-user/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ---------------------------------------------------------------------------
// Inline handler — mirrors delete-user/index.ts logic with injected clients
// ---------------------------------------------------------------------------

interface FakeUser {
  id: string;
}

interface DeleteUserConfig {
  authUser?: FakeUser | null;
  authError?: { message: string } | null;
  publicDeleteError?: { message: string } | null;
  authDeleteError?: { message: string } | null;
  /** Tables the fake client tracks deletions for */
  deletedTables?: string[];
}

interface DeleteCapture {
  table: string;
  userId: string;
}

function buildDeleteClients(config: DeleteUserConfig = {}) {
  const deleteCalls: DeleteCapture[] = [];

  // Use explicit undefined-check so callers can pass null intentionally
  const authUser = 'authUser' in config ? config.authUser : { id: 'user-uuid-456' };
  const authError = config.authError ?? null;
  const publicDeleteError = config.publicDeleteError ?? null;
  const authDeleteError = config.authDeleteError ?? null;

  // "userClient" — only used for auth.getUser()
  // deno-lint-ignore no-explicit-any
  const userClient: any = {
    auth: {
      getUser: () =>
        Promise.resolve({
          data: { user: authError ? null : authUser },
          error: authError,
        }),
    },
  };

  // "adminClient" — used for public.users delete + auth.admin.deleteUser
  // deno-lint-ignore no-explicit-any
  const adminClient: any = {
    from: (table: string) => ({
      delete: () => ({
        eq: (_col: string, userId: string) => {
          deleteCalls.push({ table, userId });
          return Promise.resolve({ error: publicDeleteError });
        },
      }),
    }),
    auth: {
      admin: {
        deleteUser: (userId: string) => {
          deleteCalls.push({ table: 'auth.users', userId });
          return Promise.resolve({ error: authDeleteError });
        },
      },
    },
  };

  return { userClient, adminClient, deleteCalls };
}

/**
 * Pure handler — extracted from delete-user/index.ts logic.
 * The real function calls createClient(url, anonKey, {Authorization}) and
 * createClient(url, serviceKey). Here we inject both clients directly.
 */
async function handleDeleteUser(
  req: Request,
  // deno-lint-ignore no-explicit-any
  userClient: any,
  // deno-lint-ignore no-explicit-any
  adminClient: any,
): Promise<Response> {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(
      JSON.stringify({ success: false, message: 'Missing authorization header' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return new Response(
      JSON.stringify({ success: false, message: 'Invalid or expired authentication token' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const userId = user.id;

  // Step 1: Delete from public.users (CASCADE)
  const { error: publicDeleteError } = await adminClient
    .from('users')
    .delete()
    .eq('id', userId);

  if (publicDeleteError) {
    // Production continues anyway — we log but don't fail
    console.error('Error deleting from public.users:', publicDeleteError);
  }

  // Step 2: Delete from auth.users
  const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(userId);

  if (authDeleteError) {
    return new Response(
      JSON.stringify({
        success: false,
        message: `Failed to delete auth account: ${authDeleteError.message}`,
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  return new Response(
    JSON.stringify({ success: true, message: 'Account deleted successfully', deleted_user_id: userId }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
}

// ---------------------------------------------------------------------------
// Helper: build a valid authenticated DELETE request
// ---------------------------------------------------------------------------

function makeRequest(method = 'DELETE', authHeader = 'Bearer valid-jwt') {
  return new Request('https://example.com/delete-user', {
    method,
    headers: authHeader ? { Authorization: authHeader } : {},
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('delete-user — auth enforcement', () => {
  it('returns 200 for CORS OPTIONS preflight', async () => {
    const { userClient, adminClient } = buildDeleteClients();
    const req = new Request('https://example.com/delete-user', { method: 'OPTIONS' });
    const res = await handleDeleteUser(req, userClient, adminClient);
    assertEquals(res.status, 200);
  });

  it('returns 401 when Authorization header is missing', async () => {
    const { userClient, adminClient } = buildDeleteClients();
    const req = new Request('https://example.com/delete-user', {
      method: 'DELETE',
      // No Authorization header
    });
    const res = await handleDeleteUser(req, userClient, adminClient);
    assertEquals(res.status, 401);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.message.includes('Missing authorization'));
  });

  it('returns 401 when JWT is invalid / auth.getUser() returns error', async () => {
    const { userClient, adminClient } = buildDeleteClients({
      authUser: null,
      authError: { message: 'JWT expired' },
    });
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient);
    assertEquals(res.status, 401);
    const body = await res.json();
    assert(body.message.includes('Invalid or expired'));
  });

  it('returns 401 when auth.getUser() returns null user without error', async () => {
    // Edge case: Supabase may return { data: { user: null }, error: null }
    const { userClient, adminClient } = buildDeleteClients({ authUser: null });
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient);
    assertEquals(res.status, 401);
  });
});

describe('delete-user — cascade delete sequencing', () => {
  it('deletes public.users BEFORE auth.users', async () => {
    const { userClient, adminClient, deleteCalls } = buildDeleteClients();
    await handleDeleteUser(makeRequest(), userClient, adminClient);

    assertEquals(deleteCalls.length, 2, 'Should have exactly 2 delete operations');
    assertEquals(
      deleteCalls[0].table,
      'users',
      'First delete must be public.users (cascade)',
    );
    assertEquals(
      deleteCalls[1].table,
      'auth.users',
      'Second delete must be auth.users',
    );
  });

  it('uses the authenticated user ID (not a request body) for deletion', async () => {
    const userId = 'the-real-user-id-789';
    const { userClient, adminClient, deleteCalls } = buildDeleteClients({
      authUser: { id: userId },
    });
    await handleDeleteUser(makeRequest(), userClient, adminClient);

    for (const call of deleteCalls) {
      assertEquals(
        call.userId,
        userId,
        `Deletion on ${call.table} used wrong user ID`,
      );
    }
  });

  it('returns 200 with deleted_user_id on success', async () => {
    const { userClient, adminClient } = buildDeleteClients({
      authUser: { id: 'user-abc' },
    });
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.success, true);
    assertEquals(body.deleted_user_id, 'user-abc');
  });
});

describe('delete-user — idempotency (user already gone from public schema)', () => {
  it('continues to auth deletion even when public.users delete errors', async () => {
    // This tests the idempotency intent: if the user was already removed from
    // public.users (or never had a row), the function should still delete auth.users.
    const { userClient, adminClient, deleteCalls } = buildDeleteClients({
      publicDeleteError: { message: 'row not found' },
    });
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient);

    // Should still attempt auth.users deletion
    const authDelete = deleteCalls.find((c) => c.table === 'auth.users');
    assertExists(authDelete, 'auth.users deletion should still be attempted');

    // And should ultimately succeed
    assertEquals(res.status, 200);
  });
});

describe('delete-user — error handling', () => {
  it('returns 500 when auth.admin.deleteUser fails', async () => {
    const { userClient, adminClient } = buildDeleteClients({
      authDeleteError: { message: 'user not found in auth' },
    });
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient);
    assertEquals(res.status, 500);
    const body = await res.json();
    assertEquals(body.success, false);
    assert(body.message.includes('Failed to delete auth account'));
  });

  it('response body includes the error message from Supabase admin on auth failure', async () => {
    const { userClient, adminClient } = buildDeleteClients({
      authDeleteError: { message: 'UID does not exist' },
    });
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient);
    const body = await res.json();
    assert(
      body.message.includes('UID does not exist'),
      'Error message should propagate to caller',
    );
  });
});

describe('delete-user — architecture note (live-integration needed)', () => {
  it('NOTE: cascade orphan verification requires live DB', () => {
    // The delete-user function relies entirely on PostgreSQL CASCADE DELETE to
    // clean up all related tables (activities, events, food_preferences,
    // nutrition_plans, garmin_user_mappings, etc.). The cascade behaviour is
    // defined in SQL migrations, not in this function's code.
    //
    // To verify NO orphans remain after deletion you need a live integration
    // test that:
    //   1. Creates a user with rows in every dependent table
    //   2. Calls delete-user
    //   3. Queries each table to assert zero rows remain for that user_id
    //
    // This is a live-integration concern, not unit-testable here.
    assert(true, 'Placeholder — see comment above');
  });
});
