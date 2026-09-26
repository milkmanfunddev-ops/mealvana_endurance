// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// Start states: only throwaway accounts, only dev, and the rows each state writes.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROD_REF } from '../../../scripts/testing-wave/sweep-accounts.mjs';
import { throwaway, pairingSql, grantBody, revenueCat } from '../../../scripts/testing-wave/seed-states.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/seed-states.mjs');
const ID = '9a986318-7cbf-4489-8115-b60850a2bac7';
const fakeDb = users => ({ query: async sql => users.filter(u => sql.includes(u.id) || sql.toLowerCase().includes(u.email.toLowerCase())) });

test('a start state goes only on a lee+e2e-* account', async () => {
  const mine = { id: ID, email: 'lee+e2e-142-20260926T1300Z@rightpathprogramming.com' };
  assert.deepEqual(await throwaway(fakeDb([mine]), ID), mine);
  assert.deepEqual(await throwaway(fakeDb([mine]), mine.email), mine);
  await assert.rejects(throwaway(fakeDb([{ id: ID, email: 'test@test.com' }]), ID), /not a lee\+e2e-\* account/);
  await assert.rejects(throwaway(fakeDb([]), ID), /no account/);
});

test('the pairing upserts one row per coach and athlete, with the timestamp its status implies', () => {
  const active = pairingSql(ID, 'test@test.com');
  assert.match(active, /'active', 'athlete', now\(\), now\(\), null, null/);
  assert.match(active, /on conflict \(coach_user_id, athlete_user_id\) do update/);
  assert.match(pairingSql(ID, 'test@test.com', { status: 'pending', requestedBy: 'coach' }), /'pending', 'coach', now\(\), null, null, null/);
  assert.match(pairingSql(ID, 'test@test.com', { status: 'declined' }), /'declined', 'athlete', now\(\), null, now\(\), null/);
  assert.throws(() => pairingSql(ID, 'x', { status: 'accepted' }), /--status/);
  assert.throws(() => pairingSql(ID, 'x', { requestedBy: 'admin' }), /--requested-by/);
  assert.throws(() => pairingSql("x'; drop table users; --", 'x'), /not a uuid/);
  assert.ok(pairingSql(ID, "o'brien@x.com").includes("'o''brien@x.com'"), 'the coach address is quoted');
});

test('the grant ends the given minutes from now, and refuses nonsense', () => {
  assert.deepEqual(grantBody('entl1', 1_000_000, 2), { entitlement_id: 'entl1', expires_at: 1_120_000 });
  assert.throws(() => grantBody('e', 0, 0), /--minutes/);
  assert.throws(() => grantBody('e', 0, 'soon'), /--minutes/);
  assert.throws(() => grantBody('e', 0, 60 * 24 + 1), /--minutes/);
});

test('a grant to a customer RevenueCat has not met creates it, then grants', async () => {
  const calls = [];
  let created = false;
  const fetch = async (url, init) => {
    const path = new URL(url).pathname.replace(/^\/v2\/projects\/p1/, '');
    calls.push(`${init.method} ${path}`);
    const reply = (status, body) => ({ status, ok: status < 300, text: async () => JSON.stringify(body) });
    if (path === '/customers') { created = true; return reply(201, {}); }
    if (path.endsWith('/grant_entitlement')) return created ? reply(201, {}) : reply(404, {});
    if (path.endsWith('/active_entitlements')) return reply(200, { items: [{ entitlement_id: 'e', expires_at: 120_000 }] });
    return reply(500, {});
  };
  await revenueCat({ key: 'k', project: 'p1', fetch }).grant(ID, { entitlement_id: 'e', expires_at: 120_000 });
  assert.deepEqual(calls, [`POST /customers/${ID}/actions/grant_entitlement`, 'POST /customers', `POST /customers/${ID}/actions/grant_entitlement`, `GET /customers/${ID}/active_entitlements`]);
});

test('a grant RevenueCat answers but does not hold (a second grant on one account) fails loudly', async () => {
  const fetch = async url => {
    const reply = (status, body) => ({ status, ok: status < 300, text: async () => JSON.stringify(body) });
    if (url.includes('/grant_entitlement')) return reply(201, {});
    if (url.includes('/active_entitlements')) return reply(200, { items: [] });
    return reply(500, {});
  };
  await assert.rejects(
    revenueCat({ key: 'k', project: 'p1', fetch }).grant(ID, { entitlement_id: 'e', expires_at: 120_000 }, { sleep: async () => {} }),
    /drops a second grant/);
});

test('the CLI refuses prod before it reads a token or touches the network', () => {
  for (const cmd of ['pairing', 'grant', 'show']) {
    const r = spawnSync('node', [cli, cmd, ID, '--ref', PROD_REF], { encoding: 'utf8', env: { ...process.env, SUPABASE_ACCESS_TOKEN: 'unused' } });
    assert.equal(r.status, 2, cmd);
    assert.match(r.stderr, /PROD/);
  }
});

test('the CLI checks its flags before any call', () => {
  const r = spawnSync('node', [cli, 'grant', ID, '--minutes', '0'], { encoding: 'utf8', env: { ...process.env, SUPABASE_ACCESS_TOKEN: 'unused' } });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /--minutes/);
});
