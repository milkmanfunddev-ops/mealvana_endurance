// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// The slot semaphore and the build lock, driven with a fake clock in a temp state folder.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { acquire, release, holders, LOCKS } from '../../../scripts/testing-wave/lock.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/lock.mjs');
const MIN = 60_000;

function clock(start = Date.parse('2026-09-23T14:00:00Z')) {
  let t = start;
  return { now: () => t, sleep: ms => { t += ms; }, advance: ms => { t += ms; } };
}
const state = () => mkdtempSync(join(tmpdir(), 'tw-lock-'));

test('the slot lets two runs in and makes the third wait', () => {
  const dir = state();
  const c = clock();
  assert.equal(LOCKS.slot.cap, 2);
  assert.equal(acquire('slot', 'testing-wave-02', { dir, now: c.now }).acquired, true);
  assert.equal(acquire('slot', 'testing-wave-03', { dir, now: c.now }).acquired, true);
  const third = acquire('slot', 'testing-wave-04', { dir, now: c.now, sleep: c.sleep, waitMs: 10 * MIN });
  assert.equal(third.acquired, false);
  assert.deepEqual(third.held.map(h => h.owner).sort(), ['testing-wave-02', 'testing-wave-03']);
  assert.ok(c.now() >= Date.parse('2026-09-23T14:10:00Z'), 'it waited the whole wait before giving up');
});

test('the build lock lets one build at a time', () => {
  const dir = state();
  const c = clock();
  assert.equal(LOCKS.build.cap, 1);
  assert.equal(acquire('build', 'testing-wave-02', { dir, now: c.now }).acquired, true);
  assert.equal(acquire('build', 'testing-wave-03', { dir, now: c.now }).acquired, false);
  release('build', 'testing-wave-02', { dir });
  assert.equal(acquire('build', 'testing-wave-03', { dir, now: c.now }).acquired, true);
});

test('the slot and the build lock are counted apart', () => {
  const dir = state();
  const c = clock();
  acquire('slot', 'a', { dir, now: c.now });
  acquire('slot', 'b', { dir, now: c.now });
  assert.equal(acquire('build', 'a', { dir, now: c.now }).acquired, true);
});

test('a waiter gets in as soon as a holder releases', () => {
  const dir = state();
  const c = clock();
  acquire('build', 'testing-wave-02', { dir, now: c.now });
  let polls = 0;
  const sleep = ms => { c.sleep(ms); if (++polls === 3) release('build', 'testing-wave-02', { dir }); };
  const r = acquire('build', 'testing-wave-03', { dir, now: c.now, sleep, waitMs: 30 * MIN, pollMs: MIN });
  assert.equal(r.acquired, true);
  assert.equal(polls, 3);
  assert.deepEqual(holders('build', { dir, now: c.now }).map(h => h.owner), ['testing-wave-03']);
});

test('claiming again as the same owner keeps the one claim', () => {
  const dir = state();
  const c = clock();
  acquire('slot', 'testing-wave-02', { dir, now: c.now });
  const again = acquire('slot', 'testing-wave-02', { dir, now: c.now });
  assert.equal(again.acquired, true);
  assert.equal(again.reused, true);
  assert.equal(holders('slot', { dir, now: c.now }).length, 1);
});

test('a stale claim is dropped and its place given to the next run', () => {
  const dir = state();
  const c = clock();
  acquire('build', 'crashed-agent', { dir, now: c.now });
  c.advance(LOCKS.build.staleMs + 1);
  const r = acquire('build', 'testing-wave-03', { dir, now: c.now });
  assert.equal(r.acquired, true);
  assert.deepEqual(r.dropped.map(h => h.owner), ['crashed-agent']);
});

test('a claim younger than the stale timeout is kept', () => {
  const dir = state();
  const c = clock();
  acquire('build', 'slow-build', { dir, now: c.now });
  c.advance(LOCKS.build.staleMs - MIN);
  assert.equal(acquire('build', 'testing-wave-03', { dir, now: c.now }).acquired, false);
});

test('a stale claim is dropped while a waiter waits', () => {
  const dir = state();
  const c = clock();
  acquire('slot', 'a', { dir, now: c.now });
  c.advance(LOCKS.slot.staleMs - 5 * MIN);
  acquire('slot', 'b', { dir, now: c.now });
  const r = acquire('slot', 'c', { dir, now: c.now, sleep: c.sleep, waitMs: 10 * MIN, pollMs: MIN });
  assert.equal(r.acquired, true);
  assert.deepEqual(r.dropped.map(h => h.owner), ['a']);
});

test('releasing a claim you do not hold says so', () => {
  assert.equal(release('slot', 'nobody', { dir: state() }).released, false);
});

test('the CLI claims, refuses with exit 3, lists and releases', () => {
  const env = { ...process.env, TESTING_WAVE_STATE: state() };
  const run = (...a) => spawnSync(process.execPath, [cli, ...a], { encoding: 'utf8', env });
  assert.equal(run('claim', 'build', 'testing-wave-02').status, 0);
  const refused = run('claim', 'build', 'testing-wave-03', '--wait', '0');
  assert.equal(refused.status, 3);
  assert.match(refused.stdout, /testing-wave-02/);
  assert.match(run('list').stdout, /build.*testing-wave-02/s);
  assert.equal(run('release', 'build', 'testing-wave-02').status, 0);
  assert.equal(run('claim', 'build', 'testing-wave-03', '--wait', '0').status, 0);
  assert.equal(run('claim', 'nonsense', 'x').status, 64);
});
