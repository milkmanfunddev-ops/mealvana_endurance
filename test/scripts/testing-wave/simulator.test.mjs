// The simulator pool against a fake `simctl`: an in-memory device list that answers the simctl
// calls the pool makes (list, create, boot, install, get_app_container, shutdown, delete) and
// records them. Claims go to a temp file; nothing here touches a real simulator.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  claimSimulator, releaseSimulator, createSimulator, deleteSimulator, listSimulators, bootedUdid,
  simulatorClaims, runtimeName, SIMULATOR_CAP, BUNDLE, MCP_HELPER,
} from '../../../scripts/testing-wave/simulator.mjs';

const cli = join(dirname(fileURLToPath(import.meta.url)), '../../../scripts/testing-wave/simulator.mjs');
const RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-26-2';
const TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-17';

function fakeSimctl({ helper = true } = {}) {
  const devs = [{ udid: 'DEV-0', name: 'iPhone 17 Dev', state: 'Booted', deviceTypeIdentifier: TYPE }];
  const calls = [];
  let next = 1;
  const find = id => devs.find(d => d.udid === id);
  const run = args => {
    calls.push(args.join(' '));
    const [cmd, a, b, c] = args;
    switch (cmd) {
      case 'list': return JSON.stringify({ devices: { [RUNTIME]: devs.map(d => ({ ...d })) } });
      case 'create': { const udid = `NEW-${next++}`; devs.push({ udid, name: a, state: 'Shutdown', deviceTypeIdentifier: b }); return `${udid}\n`; }
      case 'boot': find(a).state = 'Booted'; return '';
      case 'shutdown': find(a).state = 'Shutdown'; return '';
      case 'delete': devs.splice(devs.indexOf(find(a)), 1); return '';
      case 'install': return '';
      case 'get_app_container':
        if (b === MCP_HELPER && !helper) throw new Error('not installed');
        return `/containers/${a}/${b}/${c ?? 'app'}\n`;
      default: throw new Error(`fake simctl: ${args.join(' ')}`);
    }
  };
  return { run, calls, devs };
}

function pool(opts) {
  const sim = fakeSimctl(opts);
  const copies = [];
  const path = join(mkdtempSync(join(tmpdir(), 'sim-claims-')), 'claims.json');
  const o = { run: sim.run, copy: (src, dst) => copies.push([src, dst]), idb: '', path, now: () => '2026-10-06T12:00:00.000Z' };
  return { sim, copies, path, o };
}

test('runtimeName reads a runtime id as a name', () => {
  assert.equal(runtimeName(RUNTIME), 'iOS 26.2');
});

test('createSimulator copies the dev simulator: app, MCP helper and data', () => {
  const { sim, copies, o } = pool();
  const made = createSimulator('wave-a', { run: o.run, copy: o.copy, idb: '' });
  assert.deepEqual(made, { udid: 'NEW-1', name: 'wave-a', from: 'DEV-0', runtime: 'iOS 26.2' });
  assert.ok(sim.calls.includes(`create wave-a ${TYPE} ${RUNTIME}`));
  assert.ok(sim.calls.includes(`install NEW-1 /containers/DEV-0/${BUNDLE}/app`));
  assert.ok(sim.calls.includes(`install NEW-1 /containers/DEV-0/${MCP_HELPER}/app`));
  assert.deepEqual(copies, [[`/containers/DEV-0/${BUNDLE}/data`, `/containers/NEW-1/${BUNDLE}/data`]]);
});

test('createSimulator works when the dev simulator never ran the mobile MCP', () => {
  const { sim, o } = pool({ helper: false });
  createSimulator('wave-a', { run: o.run, copy: o.copy, idb: '' });
  assert.ok(!sim.calls.some(c => c.includes(`install NEW-1 /containers/DEV-0/${MCP_HELPER}`)));
});

test('createSimulator refuses a name that is taken', () => {
  const { o } = pool();
  createSimulator('wave-a', { run: o.run, copy: o.copy, idb: '' });
  assert.throws(() => createSimulator('wave-a', { run: o.run, copy: o.copy, idb: '' }), /already exists/);
});

test('claims fill the pool up to the cap, then the next owner waits', () => {
  const { o } = pool();
  const got = [];
  for (let i = 1; i <= SIMULATOR_CAP; i++) got.push(claimSimulator(`testing-wave-${i}`, o));
  assert.deepEqual(got.map(g => g.name), ['wave-pool-1', 'wave-pool-2', 'wave-pool-3']);
  assert.ok(got.every(g => g.reused === false));
  const wait = claimSimulator('testing-wave-9', o);
  assert.equal(wait.waiting, true);
  assert.equal(wait.cap, 3);
  assert.deepEqual(wait.held.map(h => h.owner), ['testing-wave-1', 'testing-wave-2', 'testing-wave-3']);
});

test('an owner that claims again gets the device it already holds', () => {
  const { o } = pool();
  const first = claimSimulator('testing-wave-1', o);
  const again = claimSimulator('testing-wave-1', o);
  assert.equal(again.udid, first.udid);
  assert.equal(again.reused, true);
  assert.equal(listSimulators('wave-', o).length, 1);
});

test('a released device goes to the next owner with the dev data copied in again', () => {
  const { copies, o } = pool();
  const first = claimSimulator('testing-wave-1', o);
  const r = releaseSimulator(first.name, o);
  assert.deepEqual(r, { released: true, udid: first.udid, name: 'wave-pool-1', owner: 'testing-wave-1' });
  copies.length = 0;
  const second = claimSimulator('testing-wave-2', o);
  assert.equal(second.udid, first.udid);
  assert.equal(second.reused, true);
  assert.deepEqual(copies, [[`/containers/DEV-0/${BUNDLE}/data`, `/containers/${first.udid}/${BUNDLE}/data`]]);
  assert.equal(simulatorClaims(o)[first.udid].owner, 'testing-wave-2');
});

test('a free pool device that was shut down is booted before it is handed out', () => {
  const { sim, o } = pool();
  const first = claimSimulator('testing-wave-1', o);
  releaseSimulator(first.udid, o);
  sim.devs.find(d => d.udid === first.udid).state = 'Shutdown';
  sim.calls.length = 0;
  claimSimulator('testing-wave-2', o);
  assert.ok(sim.calls.includes(`boot ${first.udid}`));
});

test('a claim on a device that was deleted outside the pool is dropped', () => {
  const { sim, o } = pool();
  const first = claimSimulator('testing-wave-1', o);
  sim.devs.splice(sim.devs.findIndex(d => d.udid === first.udid), 1);
  claimSimulator('testing-wave-2', o);
  assert.equal(simulatorClaims(o)[first.udid], undefined);
});

test('drop deletes the device and its claim; an unknown one is a no-op', () => {
  const { sim, o } = pool();
  const first = claimSimulator('testing-wave-1', o);
  const r = deleteSimulator('wave-pool-1', o);
  assert.deepEqual(r, { deleted: true, udid: first.udid, name: 'wave-pool-1' });
  assert.ok(sim.calls.includes(`shutdown ${first.udid}`) && sim.calls.includes(`delete ${first.udid}`));
  assert.deepEqual(simulatorClaims(o), {});
  assert.deepEqual(deleteSimulator('wave-nope', o), { deleted: false });
});

test('list shows the pool with owners and leaves the dev simulator out', () => {
  const { o } = pool();
  claimSimulator('testing-wave-1', o);
  const list = listSimulators('wave-', o);
  assert.equal(list.length, 1);
  assert.equal(list[0].owner, 'testing-wave-1');
  assert.equal(list[0].since, '2026-10-06T12:00:00.000Z');
  assert.equal(list[0].runtime, 'iOS 26.2');
  assert.equal(JSON.parse(readFileSync(o.path, 'utf8'))[list[0].udid].owner, 'testing-wave-1');
});

test('bootedUdid finds the named simulator, boots it, or answers the booted one', () => {
  const { sim, o } = pool();
  assert.deepEqual(bootedUdid(undefined, { run: o.run }), { udid: 'DEV-0', name: 'iPhone 17 Dev', runtime: 'iOS 26.2' });
  createSimulator('wave-a', { run: o.run, copy: o.copy, idb: '' });
  sim.devs.find(d => d.name === 'wave-a').state = 'Shutdown';
  assert.equal(bootedUdid('wave-a', { run: o.run }).udid, 'NEW-1');
  assert.equal(sim.devs.find(d => d.name === 'wave-a').state, 'Booted');
  assert.throws(() => bootedUdid('nope', { run: o.run }), /no simulator is called nope/);
});

test('a claim needs an owner', () => {
  const { o } = pool();
  assert.throws(() => claimSimulator('', o), /owner/);
});

test('the CLI prints its usage for an unknown command', () => {
  const r = spawnSync(process.execPath, [cli, 'fly'], { encoding: 'utf8' });
  assert.equal(r.status, 2);
  assert.match(r.stderr, /usage: simulator\.mjs claim <owner>/);
});
