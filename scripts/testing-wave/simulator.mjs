#!/usr/bin/env node
// Testing-wave simulator pool: at most SIMULATOR_CAP wave simulators on this Mac at once
// (Lee, 2026-09-15), each a copy of the dev simulator (same device type and runtime, the dev app
// and the mobile MCP helper installed, the dev app's data container copied in: login, Drift
// database, preferences). An agent claims one when it needs a device and releases it right after.
//
// Moved here from the mealplanning branch's docs/ssot/decisions/_page/capture.mjs (the functions)
// and sync.mjs (the `simulator` subcommand). sync.mjs does not exist on this branch, so there is
// no shim: this file is the only entry point. On a branch that has both, the two share one pool,
// because they use the same claims file.
//
// Claims: one JSON file, CLAIMS_PATH = <os tmpdir>/mealvana-ssot-simulators.json (on macOS
// $TMPDIR, e.g. /var/folders/.../T/), keyed by udid, guarded by a mkdir lock beside it
// (`<file>.lock`). Simulators are machine-global, so the claims are too: every worktree sees the
// same pool. A claim on a device that no longer exists is dropped on the next call.
//
// CLI (prints JSON):
//   node simulator.mjs claim <owner> [--wait <minutes>]   a free pool device (its dev data re-copied),
//                                                         or a new one while fewer than the cap exist;
//                                                         exit 3 when all are held and --wait ran out
//   node simulator.mjs release <name|udid>                hand a device back to the pool
//   node simulator.mjs add <name> [--from <udid|name>]    make one outside claim (refused at the cap)
//   node simulator.mjs drop <name|udid>                   shut down and delete one
//   node simulator.mjs list [<prefix>]                    the pool (default prefix `wave-`) with owners
// --from names the simulator to copy (default: the booted one that is not a pool device).
//
// Every function takes its side effects as options, so the tests drive a fake `simctl`:
// `run` (simctl argv -> stdout), `copy` (data container -> data container), `path` (claims file),
// `idb` (the idb binary, '' for none), `now`.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { flag, minutesFlag, sleepSync } from './state.mjs';

export const BUNDLE = 'com.milkman.mealvanaendurance.dev';
// The mobile MCP's on-device helper. Installed on each copy so mobile-mcp can drive it at once.
export const MCP_HELPER = 'com.mobilenext.devicekit-iosUITests.xctrunner';
export const SIMULATOR_CAP = 3;
export const POOL_PREFIX = 'wave-';
export const CLAIMS_PATH = join(tmpdir(), 'mealvana-ssot-simulators.json');
const IDB_PATHS = [process.env.HOME + '/.local/bin', '/opt/homebrew/bin', '/usr/local/bin'];

const sleep = ms => new Promise(r => setTimeout(r, ms));
export function idbPath() {
  for (const dir of IDB_PATHS) if (existsSync(join(dir, 'idb'))) return join(dir, 'idb');
  const w = spawnSync('which', ['idb'], { encoding: 'utf8' });
  return w.status === 0 ? w.stdout.trim() : '';
}
/** "com.apple.CoreSimulator.SimRuntime.iOS-26-2" reads as "iOS 26.2". */
export function runtimeName(id) {
  const m = String(id).split('.').pop().match(/^([A-Za-z]+)-(\d+)-(\d+)$/);
  return m ? `${m[1]} ${m[2]}.${m[3]}` : String(id).split('.').pop();
}
export const simctl = (args, opts = {}) => execFileSync('xcrun', ['simctl', ...args], { encoding: 'utf8', ...opts });
const devices = run => { const j = JSON.parse(run(['list', 'devices', '-j'])); return Object.entries(j.devices).flatMap(([runtime, devs]) => devs.map(d => ({ ...d, runtimeId: runtime, runtime: runtimeName(runtime) }))); };

/** The simulator to drive: the one named (a udid or a device name; `SSOT_SIMULATOR` when none is given), booted if need be, else the first booted one. */
export function bootedUdid(udid = process.env.SSOT_SIMULATOR, { run = simctl } = {}) {
  const all = devices(run);
  if (udid) {
    const d = all.find(x => x.udid === udid || x.name === udid);
    if (!d) throw new Error(`no simulator is called ${udid}`);
    if (d.state !== 'Booted') run(['boot', d.udid]);
    return { udid: d.udid, name: d.name, runtime: d.runtime };
  }
  const d = all.find(x => x.state === 'Booted');
  return d ? { udid: d.udid, name: d.name, runtime: d.runtime } : null;
}

/**
 * Copies one app data container over another. SplashBoard snapshots are skipped: the dev
 * simulator rewrites them while it runs, and a file vanishing mid-copy failed a claim (rsync 23,
 * IMPROVEMENTS #42); the app redraws them on launch.
 */
export function copyAppData(src, dst) {
  execFileSync('rsync', ['-a', '--delete', '--exclude', 'Library/SplashBoard', src + '/', dst + '/']);
}

/**
 * A simulator of its own for one agent: same device type and runtime as `from`
 * (the dev simulator, default the booted one), booted, with the dev app
 * installed from `from`'s bundle container and `from`'s data container copied
 * in (login, local database, preferences). Returns {udid, name, from, runtime}.
 */
export function createSimulator(name, { from, bundle = BUNDLE, run = simctl, copy = copyAppData, idb = idbPath() } = {}) {
  const all = devices(run);
  const source = from ? all.find(x => x.udid === from || x.name === from) : all.find(x => x.state === 'Booted');
  if (!source) throw new Error(from ? `no simulator is called ${from}` : 'no booted simulator to copy from');
  if (all.some(x => x.name === name)) throw new Error(`a simulator called ${name} already exists; drop it first`);
  const udid = run(['create', name, source.deviceTypeIdentifier, source.runtimeId]).trim();
  run(['boot', udid]);
  const app = run(['get_app_container', source.udid, bundle]).trim();
  run(['install', udid, app]);
  // The mobile MCP helper goes on before the data copy, so a failed copy never leaves a device without it.
  let helper = '';
  try { helper = run(['get_app_container', source.udid, MCP_HELPER]).trim(); } catch { /* the dev simulator has never run the mobile MCP */ }
  if (helper) run(['install', udid, helper]);
  const data = run(['get_app_container', source.udid, bundle, 'data']).trim();
  const target = run(['get_app_container', udid, bundle, 'data']).trim();
  copy(data, target);
  // Start idb's companion for the new device now, so the first drive does not wait on it.
  if (idb) spawnSync(idb, ['connect', udid], { stdio: 'ignore' });
  return { udid, name, from: source.udid, runtime: source.runtime };
}

function readClaims(path) { try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return {}; } }
/** A mkdir lock around the claims file: two agents claiming at once take turns. */
function withClaims(path, fn) {
  const lock = path + '.lock';
  for (let i = 0; ; i++) {
    try { mkdirSync(lock); break; } catch (e) {
      if (e.code !== 'EEXIST' || i > 100) throw new Error(`could not lock ${lock}: ${e.message}`);
      sleepSync(100);
    }
  }
  try {
    const claims = readClaims(path);
    const out = fn(claims);
    writeFileSync(path, JSON.stringify(claims, null, 2));
    return out;
  } finally { rmSync(lock, { recursive: true, force: true }); }
}
export function simulatorClaims({ path = CLAIMS_PATH } = {}) { return readClaims(path); }

/**
 * Hand `owner` a pool device: the one it already holds, else a free one (booted, its dev data
 * re-copied so it opens as the dev account whatever the last ticket did on it), else a new one
 * while fewer than `cap` exist, else `{waiting: true, cap, held}` so the caller waits.
 */
export function claimSimulator(owner, { from, cap = SIMULATOR_CAP, prefix = POOL_PREFIX, path = CLAIMS_PATH, run = simctl, bundle = BUNDLE, copy, idb, now = () => new Date().toISOString() } = {}) {
  if (!owner) throw new Error('a claim needs an owner (the ticket, e.g. testing-wave-29)');
  return withClaims(path, claims => {
    const pool = devices(run).filter(d => d.name.startsWith(prefix));
    for (const udid of Object.keys(claims)) if (!pool.some(d => d.udid === udid)) delete claims[udid];
    const mine = pool.find(d => claims[d.udid]?.owner === owner);
    if (mine) return { udid: mine.udid, name: mine.name, reused: true, owner };
    const free = pool.find(d => !claims[d.udid]);
    if (free) {
      if (free.state !== 'Booted') run(['boot', free.udid]);
      // Same data as the dev simulator again, so the last ticket's local state does not leak into this one.
      const source = from ? devices(run).find(x => x.udid === from || x.name === from) : devices(run).find(x => x.state === 'Booted' && !x.name.startsWith(prefix));
      if (source) {
        const data = run(['get_app_container', source.udid, bundle, 'data']).trim();
        const target = run(['get_app_container', free.udid, bundle, 'data']).trim();
        (copy ?? copyAppData)(data, target);
      }
      claims[free.udid] = { owner, name: free.name, since: now() };
      return { udid: free.udid, name: free.name, reused: true, owner };
    }
    if (pool.length >= cap) return { waiting: true, cap, held: pool.map(d => ({ name: d.name, owner: claims[d.udid]?.owner ?? null })) };
    let n = 1; while (pool.some(d => d.name === `${prefix}pool-${n}`)) n++;
    const made = createSimulator(`${prefix}pool-${n}`, { from, run, bundle, ...(copy ? { copy } : {}), ...(idb !== undefined ? { idb } : {}) });
    claims[made.udid] = { owner, name: made.name, since: now() };
    return { ...made, reused: false, owner };
  });
}

export function releaseSimulator(nameOrUdid, { path = CLAIMS_PATH, run = simctl } = {}) {
  return withClaims(path, claims => {
    const d = devices(run).find(x => x.udid === nameOrUdid || x.name === nameOrUdid);
    const udid = d?.udid ?? nameOrUdid;
    const had = claims[udid];
    delete claims[udid];
    return { released: Boolean(had), udid, name: d?.name ?? had?.name ?? null, owner: had?.owner ?? null };
  });
}

/** Shut a simulator down and delete it. Takes a udid or a name; a device that does not exist is a no-op. */
export function deleteSimulator(nameOrUdid, { run = simctl, path = CLAIMS_PATH } = {}) {
  const d = devices(run).find(x => x.udid === nameOrUdid || x.name === nameOrUdid);
  if (!d) return { deleted: false };
  if (d.state !== 'Shutdown') try { run(['shutdown', d.udid]); } catch {}
  run(['delete', d.udid]);
  withClaims(path, claims => { delete claims[d.udid]; });
  return { deleted: true, udid: d.udid, name: d.name };
}

/** The simulators whose names start with a prefix (`wave-`), with their state and owner. */
export function listSimulators(prefix = POOL_PREFIX, { run = simctl, path = CLAIMS_PATH } = {}) {
  const claims = readClaims(path);
  return devices(run).filter(d => d.name.startsWith(prefix)).map(d => ({ udid: d.udid, name: d.name, state: d.state, runtime: d.runtime, owner: claims[d.udid]?.owner ?? null, since: claims[d.udid]?.since ?? null }));
}

/** Launch, read, tap and screenshot one simulator through simctl and idb (screen reads for agents). */
export function simulatorIo(udid, { bundle = BUNDLE, idb = idbPath() } = {}) {
  const run = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  return {
    async launch() {
      spawnSync('xcrun', ['simctl', 'terminate', udid, bundle]);
      run('xcrun', ['simctl', 'launch', udid, bundle]);
      await sleep(5000);
    },
    // idb starts a companion on the first call to a device and answers with nothing until it is up: one retry after a pause.
    async tree() {
      for (let attempt = 0; attempt < 2; attempt++) {
        try { return JSON.parse(run(idb, ['ui', 'describe-all', '--udid', udid, '--json'])); } catch { await sleep(3000); }
      }
      return [];
    },
    async tap(x, y) { run(idb, ['ui', 'tap', '--udid', udid, String(x), String(y)]); },
    async wait(ms) { await sleep(ms); },
    screenshot(path) { run('xcrun', ['simctl', 'io', udid, 'screenshot', path]); },
  };
}

const USAGE = 'usage: simulator.mjs claim <owner> [--wait <minutes>] | release <name|udid> | add <name> [--from <udid|name>] | drop <name|udid> | list [<prefix>]';

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const from = flag(args, '--from');
  let waitMs;
  try { waitMs = minutesFlag(flag(args, '--wait'), '--wait') ?? 0; } catch (e) { console.error(e.message); process.exit(2); }
  const [op, name] = args;
  if (op === 'claim' && name) {
    // With --wait, poll every 30 s until a device frees up or the minutes run out (exit 3), so an agent needs no loop of its own.
    const deadline = Date.now() + waitMs;
    for (;;) {
      const got = claimSimulator(name, { from });
      if (!got.waiting) { process.stdout.write(JSON.stringify(got)); break; }
      if (Date.now() >= deadline) { console.error(`simulator claim: all ${got.cap} wave simulators are held (${got.held.map(h => `${h.name}: ${h.owner ?? 'free?'}`).join(', ')}); pass --wait <minutes> or try again later`); process.stdout.write(JSON.stringify(got)); process.exit(3); }
      sleepSync(30_000);
    }
  } else if (op === 'release' && name) process.stdout.write(JSON.stringify(releaseSimulator(name)));
  else if (op === 'add' && name) {
    if (listSimulators(POOL_PREFIX).length >= SIMULATOR_CAP) { console.error(`simulator add: ${SIMULATOR_CAP} wave simulators already exist; the cap is ${SIMULATOR_CAP}. Use claim, or drop one first`); process.exit(3); }
    process.stdout.write(JSON.stringify(createSimulator(name, { from })));
  } else if (op === 'drop' && name) process.stdout.write(JSON.stringify(deleteSimulator(name)));
  else if (op === 'list') process.stdout.write(JSON.stringify(listSimulators(name || POOL_PREFIX), null, 2));
  else { console.error(USAGE); process.exit(2); }
}
