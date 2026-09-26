/**
 * Seam tests for discard-signup (testing-wave 121-003): the real handler over
 * a fake service-role client, fed users shaped as GoTrue's admin
 * `getUserById` returns them.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/discard-signup/handler.test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { type AdminUser, isDiscardable, makeDiscardSignupHandler, MAX_AGE_MS } from './handler.ts';

const NOW = Date.parse('2026-09-26T16:39:00Z');
const FRESH_ID = 'a1a1a1a1-0000-4000-8000-000000000001';
const EMAIL = 'lee+e2e-121@rightpathprogramming.com';

/** GoTrue's user right after a confirmation-on signup: no confirmation, no sign-in. */
function freshSignup(over: Partial<AdminUser> = {}): AdminUser {
  return {
    id: FRESH_ID,
    email: EMAIL,
    email_confirmed_at: null,
    last_sign_in_at: null,
    created_at: new Date(NOW - 3 * 60_000).toISOString(),
    is_anonymous: false,
    ...over,
  };
}

function fakeAdmin(users: AdminUser[], opts: { getError?: boolean; deleteError?: boolean } = {}) {
  const deleted: string[] = [];
  const looked: string[] = [];
  const admin = {
    auth: {
      admin: {
        // deno-lint-ignore require-await
        async getUserById(id: string) {
          looked.push(id);
          if (opts.getError) return { data: { user: null }, error: { message: 'boom' } };
          const user = users.find((u) => u.id === id) ?? null;
          return user ? { data: { user }, error: null } : { data: { user: null }, error: { message: 'User not found', status: 404 } };
        },
        // deno-lint-ignore require-await
        async deleteUser(id: string) {
          deleted.push(id);
          return { error: opts.deleteError ? { message: 'boom' } : null };
        },
      },
    },
  };
  return { admin, deleted, looked };
}

function post(body: unknown, method = 'POST'): Request {
  return new Request('https://stub.supabase.test/functions/v1/discard-signup', {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: method === 'POST' ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
  });
}

async function run(users: AdminUser[], body: unknown, opts: Parameters<typeof fakeAdmin>[1] = {}) {
  const f = fakeAdmin(users, opts);
  const res = await makeDiscardSignupHandler({ admin: () => f.admin, now: () => NOW })(post(body));
  return { status: res.status, body: await res.json(), deleted: f.deleted, looked: f.looked };
}

Deno.test('a matching fresh, unconfirmed, never-signed-in user is deleted; the answer is 200 ok', async () => {
  const r = await run([freshSignup()], { user_id: FRESH_ID, email: EMAIL });
  assertEquals(r.status, 200);
  assertEquals(r.body, { ok: true });
  assertEquals(r.deleted, [FRESH_ID]);
});

Deno.test('the email match ignores case and surrounding space', async () => {
  const r = await run([freshSignup()], { user_id: FRESH_ID, email: `  ${EMAIL.toUpperCase()} ` });
  assertEquals(r.deleted, [FRESH_ID]);
});

Deno.test('the same 200 and nothing deleted when the email does not match', async () => {
  const r = await run([freshSignup()], { user_id: FRESH_ID, email: 'someone.else@example.com' });
  assertEquals(r.body, { ok: true });
  assertEquals(r.deleted, []);
});

Deno.test('a confirmed account is never deleted, even with its id and email', async () => {
  const r = await run([freshSignup({ email_confirmed_at: '2026-09-26T02:30:41Z' })], { user_id: FRESH_ID, email: EMAIL });
  assertEquals(r.body, { ok: true });
  assertEquals(r.deleted, []);
});

Deno.test('a user that ever signed in is never deleted', async () => {
  const r = await run([freshSignup({ last_sign_in_at: '2026-09-26T16:00:00Z' })], { user_id: FRESH_ID, email: EMAIL });
  assertEquals(r.deleted, []);
});

Deno.test('an anonymous user (the upgrade path keeps its uid) is never deleted', async () => {
  const r = await run([freshSignup({ is_anonymous: true })], { user_id: FRESH_ID, email: EMAIL });
  assertEquals(r.deleted, []);
});

Deno.test('a signup older than an hour is left for the cleanup, not deleted here', async () => {
  const old = freshSignup({ created_at: new Date(NOW - MAX_AGE_MS - 1).toISOString() });
  const r = await run([old], { user_id: FRESH_ID, email: EMAIL });
  assertEquals(r.deleted, []);
  const edge = freshSignup({ created_at: new Date(NOW - MAX_AGE_MS).toISOString() });
  assertEquals(isDiscardable(edge, EMAIL, NOW), true, 'exactly an hour old still counts');
});

Deno.test("GoTrue's decoy id for an existing address (124-002) matches no user: nothing happens, same 200", async () => {
  const r = await run([freshSignup()], { user_id: '350cd5c1-0000-4000-8000-0000000000de', email: EMAIL });
  assertEquals(r.body, { ok: true });
  assertEquals(r.deleted, []);
});

Deno.test('a malformed body never reaches the admin API and still answers 200 ok', async () => {
  for (const body of [
    { user_id: 'not-a-uuid', email: EMAIL },
    { user_id: FRESH_ID, email: 'no-at-sign' },
    { user_id: FRESH_ID },
    { email: EMAIL },
    {},
    'not json',
    { user_id: FRESH_ID, email: 'a@' + 'b'.repeat(330) },
  ]) {
    const r = await run([freshSignup()], body);
    assertEquals(r.status, 200, JSON.stringify(body));
    assertEquals(r.body, { ok: true });
    assertEquals(r.looked, [], `looked up for ${JSON.stringify(body)}`);
    assertEquals(r.deleted, []);
  }
});

Deno.test('a lookup error or a delete error still answers 200 ok', async () => {
  const a = await run([freshSignup()], { user_id: FRESH_ID, email: EMAIL }, { getError: true });
  assertEquals(a.body, { ok: true });
  assertEquals(a.deleted, []);
  const b = await run([freshSignup()], { user_id: FRESH_ID, email: EMAIL }, { deleteError: true });
  assertEquals(b.status, 200);
  assertEquals(b.body, { ok: true });
});

Deno.test('running twice: the second call finds no user and deletes nothing', async () => {
  const f = fakeAdmin([freshSignup()]);
  const handler = makeDiscardSignupHandler({ admin: () => f.admin, now: () => NOW });
  await handler(post({ user_id: FRESH_ID, email: EMAIL }));
  // The first delete took effect on the server: no such user any more.
  const again = makeDiscardSignupHandler({ admin: () => fakeAdmin([]).admin, now: () => NOW });
  const res = await again(post({ user_id: FRESH_ID, email: EMAIL }));
  assertEquals(await res.json(), { ok: true });
  assertEquals(f.deleted, [FRESH_ID]);
});

Deno.test('OPTIONS is the CORS preflight; anything but POST is 405', async () => {
  const handler = makeDiscardSignupHandler({ admin: () => fakeAdmin([]).admin, now: () => NOW });
  assertEquals((await handler(post(null, 'OPTIONS'))).status, 200);
  assertEquals((await handler(post(null, 'GET'))).status, 405);
});
