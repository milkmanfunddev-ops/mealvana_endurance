/**
 * requirePro reads the two-field RevenueCat cache and nothing else (mp-285, ticket 18).
 *
 * The rows fed in are shaped as the webhook writes them (active_until ISO, period_type string);
 * there is no flag, no RPC and no tester bypass on this path any more.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { isEntitled, RENEWAL_GRACE_MS, requirePro } from '../../_shared/vana/entitlement.ts';
import type { Db } from '../../_shared/vana/env.ts';

const USER = 'c18d3737-0000-4000-8000-000000000001';
const NOW = Date.parse('2026-09-15T12:00:00Z');
const HOUR = 3600_000;

type Row = { user_id: string; active_until: string | null; period_type: string | null; will_renew?: boolean };
const MINUTE = 60_000;

/** The only query requirePro may make: select the two fields for one user. */
function fakeAdmin(rows: Row[], opts: { error?: { message: string }; throws?: boolean } = {}) {
  const log: { table: string; cols: string; user: string }[] = [];
  const admin = {
    from(table: string) {
      let cols = '';
      let user = '';
      const q = {
        select(c: string) { cols = c; return q; },
        eq(_col: string, v: string) { user = v; return q; },
        // deno-lint-ignore require-await
        async maybeSingle() {
          log.push({ table, cols, user });
          if (opts.throws) throw new Error('network');
          if (opts.error) return { data: null, error: opts.error };
          return { data: rows.find((r) => r.user_id === user) ?? null, error: null };
        },
      };
      return q;
    },
    rpc() { throw new Error('requirePro must not call an RPC'); },
  };
  return { admin: admin as unknown as Db, log };
}

Deno.test('isEntitled: active_until in the future → true; past, null, garbage → false', () => {
  assertEquals(isEntitled({ active_until: new Date(NOW + HOUR).toISOString() }, NOW), true);
  assertEquals(isEntitled({ active_until: new Date(NOW - 1).toISOString() }, NOW), false);
  assertEquals(isEntitled({ active_until: new Date(NOW).toISOString() }, NOW), false);
  assertEquals(isEntitled({ active_until: null }, NOW), false);
  assertEquals(isEntitled({ active_until: 'not a date' }, NOW), false);
  assertEquals(isEntitled(null, NOW), false);
});

Deno.test('a renewing row a minute past active_until is entitled; a non-renewing one is not (06-002)', () => {
  const lapsed = new Date(NOW - MINUTE).toISOString();
  assertEquals(isEntitled({ active_until: lapsed, will_renew: true }, NOW), true);
  assertEquals(isEntitled({ active_until: lapsed, will_renew: false }, NOW), false);
  assertEquals(isEntitled({ active_until: lapsed }, NOW), false, 'a row without the flag gets no grace');
});

Deno.test('past the grace neither a renewing nor a non-renewing row is entitled', () => {
  const beyond = new Date(NOW - RENEWAL_GRACE_MS - 1).toISOString();
  assertEquals(isEntitled({ active_until: beyond, will_renew: true }, NOW), false);
  assertEquals(isEntitled({ active_until: beyond, will_renew: false }, NOW), false);
  const edge = new Date(NOW - RENEWAL_GRACE_MS).toISOString();
  assertEquals(isEntitled({ active_until: edge, will_renew: true }, NOW), false, 'the grace end is exclusive, like active_until');
});

Deno.test('requirePro lets a renewing row through while its RENEWAL webhook is late', async () => {
  const lapsed = new Date(NOW - 3 * MINUTE).toISOString();
  const renewing = fakeAdmin([{ user_id: USER, active_until: lapsed, period_type: 'NORMAL', will_renew: true }]);
  assertEquals(await requirePro(renewing.admin, USER, NOW), { ok: true });
  const cancelled = fakeAdmin([{ user_id: USER, active_until: lapsed, period_type: 'NORMAL', will_renew: false }]);
  assertEquals(await requirePro(cancelled.admin, USER, NOW), { ok: false, reason: 'pro_required' });
});

Deno.test('a trial row (period_type TRIAL, active_until in seven days) passes', async () => {
  const { admin, log } = fakeAdmin([{ user_id: USER, active_until: new Date(NOW + 7 * 24 * HOUR).toISOString(), period_type: 'TRIAL' }]);
  assertEquals(await requirePro(admin, USER, NOW), { ok: true });
  assertEquals(log, [{ table: 'user_entitlements', cols: 'active_until, period_type, will_renew', user: USER }]);
});

Deno.test('no row → pro_required', async () => {
  const { admin } = fakeAdmin([]);
  assertEquals(await requirePro(admin, USER, NOW), { ok: false, reason: 'pro_required' });
});

Deno.test('an expired row → pro_required, whatever the period type', async () => {
  const { admin } = fakeAdmin([{ user_id: USER, active_until: new Date(NOW - HOUR).toISOString(), period_type: 'NORMAL' }]);
  assertEquals(await requirePro(admin, USER, NOW), { ok: false, reason: 'pro_required' });
});

Deno.test('a read error or a thrown client fails closed', async () => {
  assertEquals(await requirePro(fakeAdmin([], { error: { message: 'boom' } }).admin, USER, NOW), { ok: false, reason: 'pro_required' });
  assertEquals(await requirePro(fakeAdmin([], { throws: true }).admin, USER, NOW), { ok: false, reason: 'pro_required' });
});

Deno.test('the PRO_GATE_ENABLED secret no longer opens the gate', async () => {
  Deno.env.set('PRO_GATE_ENABLED', 'false');
  try {
    const { admin } = fakeAdmin([]);
    assertEquals(await requirePro(admin, USER, NOW), { ok: false, reason: 'pro_required' });
  } finally {
    Deno.env.delete('PRO_GATE_ENABLED');
  }
});
