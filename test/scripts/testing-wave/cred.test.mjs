// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// Credentials without reading the file: no command ever prints a password.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse, find, addAccount, updateAccount, makePassword } from '../../../scripts/testing-wave/cred.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/cred.mjs');

const FIXTURE = `# Test accounts (testing-wave)

## Dev admin

| Field | Value |
|---|---|
| Address | test@test.com |
| Password | adminSecret99 |
| Notes | Admin. |

## Apple sandbox testers

| Address | Password | Region | Notes |
|---|---|---|---|

## Created accounts

| Address | Password | Bought | When | State | Ticket / run |
|---|---|---|---|---|---|
| lee+e2e-02-a@rightpathprogramming.com | oldRowSecret1 | nothing | | deleted | 02 / w2 |
`;

const tmpFile = () => {
  const f = join(mkdtempSync(join(tmpdir(), 'tw-cred-')), 'test_accounts.md');
  writeFileSync(f, FIXTURE);
  return f;
};
const run = (file, ...args) => spawnSync('node', [cli, ...args], { encoding: 'utf8', env: { ...process.env, TESTING_WAVE_CREDENTIALS: file } });

test('parse finds the fixed admin and each created row', () => {
  const all = parse(FIXTURE);
  assert.deepEqual(all.map(a => [a.address, a.kind]), [
    ['test@test.com', 'kv'],
    ['lee+e2e-02-a@rightpathprogramming.com', 'row'],
  ]);
  assert.equal(find(FIXTURE, 'TEST@test.com').password, 'adminSecret99');
  assert.equal(find(FIXTURE, 'nobody@x.com'), null);
});

test('--section picks one of two sections that share an address', () => {
  const shared = FIXTURE.replace('## Apple sandbox testers', `## Patrol account

| Field | Value |
|---|---|
| Address | lee@x.com |
| Password | patrolSecret1 |

## Kroger shopper login

| Field | Value |
|---|---|
| Address | lee@x.com |
| Password | krogerSecret1 |

## Apple sandbox testers`);
  assert.equal(find(shared, 'lee@x.com').password, 'krogerSecret1');
  assert.equal(find(shared, 'lee@x.com', 'patrol').password, 'patrolSecret1');
  assert.equal(find(shared, 'lee@x.com', 'nothing like it'), null);
});

test('new appends a row in Created accounts with a generated password', () => {
  const next = addAccount(FIXTURE, 'lee+e2e-32-b@rightpathprogramming.com', { ticket: '32', run: 'w9', password: 'Gen1' });
  const acct = find(next, 'lee+e2e-32-b@rightpathprogramming.com');
  assert.equal(acct.password, 'Gen1');
  assert.equal(acct.state, 'new');
  assert.throws(() => addAccount(next, 'lee+e2e-32-b@rightpathprogramming.com', { ticket: '32', run: 'w9' }));
});

test('update changes state, bought, password and appends a note', () => {
  const email = 'lee+e2e-02-a@rightpathprogramming.com';
  const next = updateAccount(FIXTURE, email, { state: 'paid', bought: 'monthly', when: '2026-09-24T15:00Z', note: 'kept', newPassword: 'New2' });
  const line = next.split('\n').find(l => l.includes(email));
  assert.equal(line, `| ${email} | New2 | monthly | 2026-09-24T15:00Z | paid | 02 / w2 kept |`);
  assert.equal(updateAccount(FIXTURE, 'nobody@x.com', { state: 'deleted' }), null);
  assert.throws(() => updateAccount(FIXTURE, 'test@test.com', { state: 'deleted' }));
});

test('generated passwords meet the app rules and differ', () => {
  const a = makePassword();
  assert.match(a, /^[A-Za-z0-9]{16}A1!$/);
  assert.notEqual(a, makePassword());
});

test('no CLI command prints a password', () => {
  const file = tmpFile();
  const outDir = mkdtempSync(join(tmpdir(), 'tw-cred-out-'));
  const email = 'lee+e2e-32-c@rightpathprogramming.com';
  const outputs = [
    run(file, 'list'),
    run(file, 'new', email, '--ticket', '32', '--run', 'w9'),
    run(file, 'file', 'test@test.com', join(outDir, 'pw')),
    run(file, 'update', email, '--state', 'deleted', '--new-password'),
  ];
  const secrets = parse(readFileSync(file, 'utf8')).map(a => a.password).filter(Boolean);
  assert.equal(secrets.length, 3);
  for (const r of outputs) {
    assert.equal(r.status, 0, r.stderr);
    for (const s of secrets.concat('adminSecret99', 'oldRowSecret1')) {
      assert.ok(!r.stdout.includes(s) && !r.stderr.includes(s), 'a password reached the output');
    }
  }
  assert.equal(readFileSync(join(outDir, 'pw'), 'utf8'), 'adminSecret99');
  assert.equal(statSync(join(outDir, 'pw')).mode & 0o777, 0o600);
});

test('an unknown account exits 2 and bad usage exits 64', () => {
  const file = tmpFile();
  assert.equal(run(file, 'file', 'nobody@x.com', '/tmp/x').status, 2);
  assert.equal(run(file, 'bogus').status, 64);
});

test('type waits before typing and 2 s after it, so no screenshot right after shows the last character', () => {
  // A fake idb on PATH records when it ran; the password goes to it and nowhere else.
  const dir = mkdtempSync(join(tmpdir(), 'tw-cred-idb-'));
  const stamp = join(dir, 'typed-at');
  writeFileSync(join(dir, 'idb'), `#!/bin/sh\nnode -e 'process.stdout.write(String(Date.now()))' > "${stamp}"\n`, { mode: 0o755 });
  const started = Date.now();
  const r = spawnSync('node', [cli, 'type', 'test@test.com', '--udid', 'FAKE'], {
    encoding: 'utf8',
    env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, TESTING_WAVE_CREDENTIALS: tmpFile(), CRED_TYPE_DELAY_MS: '300' },
  });
  const returned = Date.now();
  assert.equal(r.status, 0, r.stderr);
  const typedAt = Number(readFileSync(stamp, 'utf8'));
  assert.ok(typedAt - started >= 300, `waited ${typedAt - started} ms before typing (the #93 wait)`);
  assert.ok(returned - typedAt >= 2000, `returned ${returned - typedAt} ms after typing, not 2 s (120-010)`);
  assert.ok(!r.stdout.includes('adminSecret99') && !r.stderr.includes('adminSecret99'), 'the password is never printed');
});
