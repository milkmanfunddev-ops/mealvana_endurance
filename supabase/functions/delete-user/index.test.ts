/**
 * Unit Tests for delete-user Edge Function
 *
 * Tests auth enforcement, cascade-delete sequencing, idempotency, error
 * handling and the RevenueCat customer delete (02-005, ticket 95), driving the
 * real handler (handler.ts) with a fake Supabase client and a fake RevenueCat
 * client (no live DB, Supabase auth or RevenueCat required).
 *
 * Run with:
 *   deno test --allow-env --allow-sys supabase/functions/delete-user/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';
import { makeDeleteUserHandler } from './handler.ts';
import { RevenueCatError, type RevenueCatClient } from '../_shared/revenuecat/client.ts';

// ---------------------------------------------------------------------------
// Fakes: the user's JWT client, the service-role client, RevenueCat
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

/** A RevenueCat client that records customer deletes; every other call is refused. */
function fakeRevenueCat(fail?: Error) {
  const deleted: string[] = [];
  const never = () => Promise.reject(new Error('delete-user only deletes customers'));
  const rc: RevenueCatClient = {
    currentProExpiry: never,
    grantPro: never,
    setAttributes: never,
    getAttributes: never,
    promotionalProEnd: never,
    createCustomer: never,
    deleteCustomer: (id: string) => {
      if (fail) return Promise.reject(fail);
      deleted.push(id);
      return Promise.resolve();
    },
  };
  return { rc, deleted };
}

/** Run the real handler (handler.ts) with the fakes injected. */
function handleDeleteUser(
  req: Request,
  // deno-lint-ignore no-explicit-any
  userClient: any,
  // deno-lint-ignore no-explicit-any
  adminClient: any,
  revenueCat: () => RevenueCatClient = () => fakeRevenueCat().rc,
): Promise<Response> {
  return makeDeleteUserHandler({
    userClient: () => userClient,
    admin: () => adminClient,
    revenueCat,
  })(req);
}

/** Capture console.error while [fn] runs. */
async function capturingErrors<T>(fn: () => Promise<T>): Promise<{ result: T; logged: string[] }> {
  const logged: string[] = [];
  const original = console.error;
  console.error = (...args: unknown[]) => logged.push(args.map(String).join(' '));
  try {
    return { result: await fn(), logged };
  } finally {
    console.error = original;
  }
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

describe('delete-user — the RevenueCat customer goes too (02-005, ticket 95)', () => {
  it("deletes the account's RevenueCat customer by the Supabase user id", async () => {
    const { userClient, adminClient } = buildDeleteClients({ authUser: { id: 'user-rc-1' } });
    const { rc, deleted } = fakeRevenueCat();
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient, () => rc);
    assertEquals(res.status, 200);
    assertEquals(deleted, ['user-rc-1']);
  });

  it('deletes the customer only after the auth account is gone', async () => {
    const { userClient, adminClient } = buildDeleteClients({
      authDeleteError: { message: 'UID does not exist' },
    });
    const { rc, deleted } = fakeRevenueCat();
    const res = await handleDeleteUser(makeRequest(), userClient, adminClient, () => rc);
    assertEquals(res.status, 500);
    assertEquals(deleted, [], 'a failed delete keeps the RevenueCat customer');
  });

  it('a RevenueCat error still deletes the account, and is logged with the user id', async () => {
    const { userClient, adminClient, deleteCalls } = buildDeleteClients({ authUser: { id: 'user-rc-2' } });
    const { rc } = fakeRevenueCat(new RevenueCatError('RevenueCat DELETE → 503: down', 503));
    const { result: res, logged } = await capturingErrors(() =>
      handleDeleteUser(makeRequest(), userClient, adminClient, () => rc)
    );
    assertEquals(res.status, 200);
    assertEquals((await res.json()).success, true);
    assertEquals(deleteCalls.map((c) => c.table), ['users', 'auth.users']);
    assert(
      logged.some((l) => l.includes('user-rc-2') && l.includes('RevenueCat')),
      `logged: ${logged.join(' | ')}`,
    );
  });

  it('a RevenueCat key that is not set still deletes the account, and is logged with the user id', async () => {
    const { userClient, adminClient } = buildDeleteClients({ authUser: { id: 'user-rc-3' } });
    const { result: res, logged } = await capturingErrors(() =>
      handleDeleteUser(makeRequest(), userClient, adminClient, () => {
        throw new RevenueCatError('RevenueCat secret key not set');
      })
    );
    assertEquals(res.status, 200);
    assert(logged.some((l) => l.includes('user-rc-3')), `logged: ${logged.join(' | ')}`);
  });

  it('no Authorization header never reaches RevenueCat', async () => {
    const { userClient, adminClient } = buildDeleteClients();
    const { rc, deleted } = fakeRevenueCat();
    const req = new Request('https://example.com/delete-user', { method: 'DELETE' });
    await handleDeleteUser(req, userClient, adminClient, () => rc);
    assertEquals(deleted, []);
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
