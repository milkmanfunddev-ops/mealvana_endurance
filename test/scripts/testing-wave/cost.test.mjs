// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// The per-wave cost caps: three new Vana plans, five AI logging calls, five Vana chat calls.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spend, spent, CAPS } from '../../../scripts/testing-wave/cost.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/cost.mjs');
const state = () => mkdtempSync(join(tmpdir(), 'tw-cost-'));

test('the caps are three plans, five logging calls and five chat calls', () => {
  assert.deepEqual(CAPS, { plan: 3, logging: 5, chat: 5 });
});

test('the fourth new plan in a wave is refused, across tickets', () => {
  const dir = state();
  for (const t of ['14', '15', '16']) assert.equal(spend('1', 'plan', t, { dir }).ok, true);
  const fourth = spend('1', 'plan', '17', { dir });
  assert.equal(fourth.ok, false);
  assert.equal(fourth.used, 3);
  assert.equal(fourth.cap, 3);
  assert.deepEqual(spent('1', { dir }).plan.map(s => s.ticket), ['14', '15', '16']);
});

test('the sixth AI logging call in a wave is refused', () => {
  const dir = state();
  for (let i = 0; i < 5; i++) assert.equal(spend('1', 'logging', '23', { dir }).ok, true);
  assert.equal(spend('1', 'logging', '24', { dir }).ok, false);
  assert.equal(spent('1', { dir }).logging.length, 5);
});

test('plans and logging calls are counted apart', () => {
  const dir = state();
  for (let i = 0; i < 3; i++) spend('1', 'plan', '14', { dir });
  assert.equal(spend('1', 'logging', '23', { dir }).ok, true);
});

test('each wave starts from nothing', () => {
  const dir = state();
  for (let i = 0; i < 3; i++) spend('1', 'plan', '14', { dir });
  assert.equal(spend('2', 'plan', '14', { dir }).ok, true);
  assert.equal(spend('2', 'plan', '14', { dir }).used, 2);
});

test('an unknown kind is an error, not a spend', () => {
  assert.throws(() => spend('1', 'image', '14', { dir: state() }), /kind/);
});

test('the CLI spends, refuses with exit 3 and reports', () => {
  const env = { ...process.env, TESTING_WAVE_STATE: state() };
  const run = (...a) => spawnSync(process.execPath, [cli, ...a], { encoding: 'utf8', env });
  for (let i = 0; i < 3; i++) assert.equal(run('spend', '1', 'plan', '14').status, 0);
  const refused = run('spend', '1', 'plan', '15');
  assert.equal(refused.status, 3);
  assert.match(refused.stdout, /refused/i);
  const status = run('status', '1');
  assert.equal(status.status, 0);
  assert.match(status.stdout, /plan.*3\/3/);
  assert.match(status.stdout, /logging.*0\/5/);
});
