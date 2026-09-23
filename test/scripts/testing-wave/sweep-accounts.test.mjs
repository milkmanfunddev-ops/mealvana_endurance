// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// The account sweep: which dev accounts it may select, that it only ever runs against dev, and
// that it deletes nothing unless told to.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  DEV_REF,
  PROD_REF,
  isSweepable,
  selectSweepable,
  assertDev,
  sweep,
  footprintSql,
} from '../../../scripts/testing-wave/sweep-accounts.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/sweep-accounts.mjs');

const user = (email, id = crypto.randomUUID()) => ({ id, email, created_at: '2026-09-23T12:00:00Z' });

test('plus addresses made by the testing wave are sweepable', () => {
  for (const email of [
    'lee+e2e-02-20260923T1200Z@rightpathprogramming.com',
    'lee+e2e-1758628800000@rightpathprogramming.com',
    'LEE+E2E-14-x@RightPathProgramming.com',
  ]) assert.equal(isSweepable(email), true, email);
});

test('nothing else is sweepable: the plain address, other plus tags, other domains, look-alikes', () => {
  for (const email of [
    'lee@rightpathprogramming.com', // the plain work address (the Gmail fallback) is never swept
    'lee+kroger@rightpathprogramming.com',
    'lee+e2e@rightpathprogramming.com', // no run tag after the dash
    'lee+e2e-02@rightpathprogramming.com.evil.com',
    'lee+e2e-02@gmail.com',
    'xlee+e2e-02@rightpathprogramming.com',
    'test@test.com',
    'lee+e2e-0%@rightpathprogramming.com', // a LIKE wildcard that slipped through the SQL
    'lee+e2e-02 @rightpathprogramming.com',
    '',
    null,
    undefined,
  ]) assert.equal(isSweepable(email), false, String(email));
});

test('selection keeps only sweepable accounts, whatever the listing returned', () => {
  const keep = user('lee+e2e-02-20260923T1200Z@rightpathprogramming.com');
  const listed = [keep, user('test@test.com'), user('lee@rightpathprogramming.com'), user(null)];
  assert.deepEqual(selectSweepable(listed), [keep]);
});

test('selection drops a row whose id is not a uuid, so nothing odd reaches a delete', () => {
  assert.deepEqual(selectSweepable([user('lee+e2e-02-a@rightpathprogramming.com', "1'; drop table users;--")]), []);
});

test('only the dev project is allowed; prod and anything else refuse', () => {
  assert.doesNotThrow(() => assertDev(DEV_REF));
  assert.throws(() => assertDev(PROD_REF), /prod/i);
  assert.throws(() => assertDev('abcdefghijklmnopqrst'), /dev/);
  assert.throws(() => assertDev(undefined), /dev/);
});

const fakeApi = accounts => {
  const deleted = [];
  return {
    deleted,
    listCandidates: async () => accounts,
    deleteAccount: async id => { deleted.push(id); },
  };
};

test('a sweep is a dry run unless apply is set: it lists and deletes nothing', async () => {
  const a = user('lee+e2e-02-a@rightpathprogramming.com');
  const api = fakeApi([a, user('test@test.com')]);
  const r = await sweep({ ref: DEV_REF, api });
  assert.equal(r.mode, 'dry-run');
  assert.deepEqual(r.targets.map(t => t.id), [a.id]);
  assert.deepEqual(api.deleted, []);
});

test('an applied sweep deletes exactly the selected accounts', async () => {
  const a = user('lee+e2e-02-a@rightpathprogramming.com');
  const b = user('lee+e2e-1758628800000@rightpathprogramming.com');
  const api = fakeApi([a, user('lee@rightpathprogramming.com'), b, user('test@test.com')]);
  const r = await sweep({ ref: DEV_REF, api, apply: true });
  assert.equal(r.mode, 'delete');
  assert.deepEqual(api.deleted, [a.id, b.id]);
  assert.deepEqual(r.deleted, [a.id, b.id]);
  assert.deepEqual(r.failed, []);
});

test('one failed delete is reported and the rest still run', async () => {
  const a = user('lee+e2e-02-a@rightpathprogramming.com');
  const b = user('lee+e2e-02-b@rightpathprogramming.com');
  const api = fakeApi([a, b]);
  api.deleteAccount = async id => { if (id === a.id) throw new Error('boom'); api.deleted.push(id); };
  const r = await sweep({ ref: DEV_REF, api, apply: true });
  assert.deepEqual(r.deleted, [b.id]);
  assert.deepEqual(r.failed, [{ id: a.id, email: a.email, error: 'boom' }]);
});

test('a sweep pointed at prod refuses before it lists anything', async () => {
  let listed = false;
  const api = { listCandidates: async () => { listed = true; return []; }, deleteAccount: async () => {} };
  await assert.rejects(sweep({ ref: PROD_REF, api, apply: true }), /prod/i);
  assert.equal(listed, false);
});

test('the footprint query counts every user-keyed column for one uuid, and refuses a non-uuid', () => {
  const id = '8f14e45f-ceea-467a-9575-6f2b1e0b2f11';
  const sql = footprintSql(id, [
    { table_name: 'users', column_name: 'id' },
    { table_name: 'meal_logs', column_name: 'user_id' },
  ]);
  assert.match(sql, /from auth\.users where id = '8f14e45f-ceea-467a-9575-6f2b1e0b2f11'/);
  assert.match(sql, /from public\."users" where "id" = '8f14e45f/);
  assert.match(sql, /from public\."meal_logs" where "user_id" = '8f14e45f/);
  assert.throws(() => footprintSql("x' or 1=1 --", []), /uuid/);
});

test('the CLI refuses a --ref that is not dev, without a token', () => {
  const r = spawnSync(process.execPath, [cli, 'list', '--ref', PROD_REF], { encoding: 'utf8', env: { ...process.env, SUPABASE_ACCESS_TOKEN: '' } });
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /prod/i);
});

test('the CLI prints usage and exits 64 on an unknown command', () => {
  const r = spawnSync(process.execPath, [cli, 'nuke'], { encoding: 'utf8' });
  assert.equal(r.status, 64);
  assert.match(r.stderr, /usage/);
});
