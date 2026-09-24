// Captured pictures for decisions that name a screen: the booted simulator is
// driven to the screen and photographed while the record is written.
//
// A card's `screen:` line is matched against `screens.json` beside this file.
// A screen with a `reuse` path (an existing golden or design frame that shows
// exactly that screen) is reused; the rest carry a `drive`, a list of steps
// that take the app from a fresh launch to the screen:
//   { "tap": "<label>" }                 the element whose accessibility label
//                                        is that (first line, case-insensitive);
//                                        a substring match is the fallback
//   { "tapAfter": "<label>", "type": "GenericElement" }
//                                        the first element of that type listed
//                                        after the labelled one (a card in a
//                                        row whose contents change)
//   { "wait": 1500 }                     milliseconds
// Every capture starts from terminate + launch, so a frozen app (the 09-14
// blocker: a stale debugger session left the app painted but deaf) never
// survives into a picture. The image is saved as <images dir>/<key>.png with a
// sidecar <key>.json that records the commit and app version it was taken at.
//
// The simulator is reached through `idb` (taps and the accessibility tree) and
// `xcrun simctl` (launch, screenshot). `doctor()` says what is missing.
//
// Which simulator: `bootedUdid(udid)` takes the one named (or `SSOT_SIMULATOR`
// in the environment), booting it if it is shut down, else the first booted
// one. A wave gives every ticket its own: `createSimulator` makes a device of
// the dev simulator's type and runtime, boots it, installs the dev app from
// the dev simulator's bundle container and copies its data container over, so
// the copy opens signed in with the same data, plus the mobile MCP's helper app
// when the dev simulator has it. `deleteSimulator` removes it.
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const BUNDLE = 'com.milkman.mealvanaendurance.dev';
// The mobile MCP drives an iOS simulator through this helper app. It installs it on the dev
// simulator on first use but not on a device made here, where it answers "Agent is not installed".
export const MCP_HELPER = 'com.mobilenext.devicekit-iosUITests.xctrunner';
const IDB_PATHS = [process.env.HOME + '/.local/bin', '/opt/homebrew/bin', '/usr/local/bin'];

export function loadScreens(path = join(here, 'screens.json')) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

const norm = s => String(s || '').toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();

/** The registry entry for a card's `screen:` line, or null. Each comma-separated
 * part is tried in order: an exact phrase first, then the longest phrase the part contains or sits inside. */
export function matchScreen(screenLine, screens) {
  if (!screenLine || /^none\b/i.test(screenLine)) return null;
  const parts = String(screenLine).split(/,|;| and /).map(norm).filter(Boolean);
  const entries = Object.entries(screens).map(([key, s]) => ({ key, ...s, phrases: (s.match || []).map(norm) }));
  for (const part of parts) {
    const exact = entries.find(e => e.phrases.includes(part));
    if (exact) return exact;
  }
  // Fallback: the longest phrase that contains the part or sits inside it, so registry order never decides.
  for (const part of parts) {
    let best = null, len = 0;
    for (const e of entries) for (const p of e.phrases) if ((part.includes(p) || p.includes(part)) && p.length > len) { best = e; len = p.length; }
    if (best) return best;
  }
  return null;
}

// Element lookup over the accessibility tree idb prints: [{type, AXLabel, frame:{x,y,width,height}}].
// Apostrophes compare equal whichever way iOS curls them ("Don’t Allow" matches "Don't Allow").
const label = e => String(e.AXLabel || '').replace(/[\u2018\u2019]/g, "'");
const centre = e => [Math.round(e.frame.x + e.frame.width / 2), Math.round(e.frame.y + e.frame.height / 2)];
const onScreen = e => e.frame && (e.frame.width > 0 || e.frame.height > 0);
export function findElement(tree, step) {
  const els = tree.filter(e => e.type !== 'Application' && onScreen(e));
  if (step.tap !== undefined) {
    const want = step.tap.replace(/[\u2018\u2019]/g, "'").toLowerCase();
    const typed = e => !step.type || e.type === step.type;
    return els.find(e => typed(e) && label(e).toLowerCase().split('\n')[0] === want)
      || els.find(e => typed(e) && label(e).toLowerCase().includes(want)) || null;
  }
  if (step.tapAfter !== undefined) {
    const want = step.tapAfter.toLowerCase();
    const at = els.findIndex(e => label(e).toLowerCase().split('\n')[0] === want || label(e).toLowerCase().startsWith(want));
    if (at < 0) return null;
    return els.slice(at + 1).find(e => (!step.type || e.type === step.type) && label(e).trim()) || null;
  }
  return null;
}

/** The system prompts a fresh simulator shows on first launch (notifications), dismissed before the drive starts. */
export const FIRST_LAUNCH_PROMPTS = [{ tap: "Don't Allow", type: 'Button' }];
/** Run a drive against an io: {launch(), tree(), tap(x, y), wait(ms)}. Throws naming the step that found nothing. */
export async function runDrive(steps, io, { settle = 1800 } = {}) {
  await io.launch();
  for (const prompt of FIRST_LAUNCH_PROMPTS) {
    const el = findElement(await io.tree(), prompt);
    if (el) { const [x, y] = centre(el); await io.tap(x, y); await io.wait(settle); }
  }
  for (const step of steps) {
    if (step.wait !== undefined) { await io.wait(step.wait); continue; }
    const el = findElement(await io.tree(), step);
    if (!el) throw new Error(`nothing on screen matches ${JSON.stringify(step)}`);
    const [x, y] = centre(el);
    await io.tap(x, y);
    await io.wait(step.settle ?? settle);
  }
}

/** What is written beside the image. */
export function sidecar({ screen, key, commit, version, device, runtime, at = new Date().toISOString() }) {
  return { screen, key, capturedAt: at, commit, appVersion: version, device, runtime };
}

// The real simulator io. `udid` defaults to the booted simulator.
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
 * A simulator of its own for one agent: same device type and runtime as `from`
 * (the dev simulator, default the booted one), booted, with the dev app
 * installed from `from`'s bundle container and `from`'s data container copied
 * in (login, local database, preferences). Returns {udid, name, from, runtime}.
 */
/**
 * Copies one app data container over another. SplashBoard snapshots are skipped: the dev
 * simulator rewrites them while it runs, and a file vanishing mid-copy failed a claim (rsync 23,
 * IMPROVEMENTS #42); the app redraws them on launch.
 */
export function copyAppData(src, dst) {
  execFileSync('rsync', ['-a', '--delete', '--exclude', 'Library/SplashBoard', src + '/', dst + '/']);
}
export function createSimulator(name, { from, bundle = BUNDLE, run = simctl, copy = copyAppData } = {}) {
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
  const idb = idbPath();
  if (idb) spawnSync(idb, ['connect', udid], { stdio: 'ignore' });
  return { udid, name, from: source.udid, runtime: source.runtime };
}
/**
 * The simulator pool. A Mac runs at most SIMULATOR_CAP wave simulators at once (Lee, 2026-09-15),
 * so an agent claims one when it needs a device and releases it right after. `claimSimulator`
 * hands back a free pool device (its dev data re-copied so it opens as the dev account, whatever
 * the last ticket did on it), creates one only when none is free and fewer than the cap exist,
 * and otherwise answers `{waiting: true}` so the caller waits. Claims live in one JSON file in the
 * machine's temp dir, keyed by udid, since the simulators are machine-global too; a claim on a
 * device that no longer exists is dropped on the next call.
 */
export const SIMULATOR_CAP = 3;
export const POOL_PREFIX = 'wave-';
export const CLAIMS_PATH = join(tmpdir(), 'mealvana-ssot-simulators.json');
function readClaims(path) { try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return {}; } }
/** A mkdir lock around the claims file: two agents claiming at once take turns. */
function withClaims(path, fn) {
  const lock = path + '.lock';
  for (let i = 0; ; i++) {
    try { mkdirSync(lock); break; } catch (e) {
      if (e.code !== 'EEXIST' || i > 100) throw new Error(`could not lock ${lock}: ${e.message}`);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
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
export function claimSimulator(owner, { from, cap = SIMULATOR_CAP, prefix = POOL_PREFIX, path = CLAIMS_PATH, run = simctl, bundle = BUNDLE, copy, now = () => new Date().toISOString() } = {}) {
  if (!owner) throw new Error('a claim needs an owner (the ticket, e.g. mealplanning-13)');
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
    const made = createSimulator(`${prefix}pool-${n}`, { from, run, bundle, ...(copy ? { copy } : {}) });
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
/** The simulators whose names start with a prefix (`wave-`), with their state. */
export function listSimulators(prefix, { run = simctl, path = CLAIMS_PATH } = {}) {
  const claims = readClaims(path);
  return devices(run).filter(d => d.name.startsWith(prefix)).map(d => ({ udid: d.udid, name: d.name, state: d.state, runtime: d.runtime, owner: claims[d.udid]?.owner ?? null, since: claims[d.udid]?.since ?? null }));
}
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

/** Drive the simulator to a screen and save <dir>/<key>.png + <key>.json. Returns the sidecar. */
export async function capture(entry, { dir, commit, version, device, runtime, io }) {
  if (!entry.drive) throw new Error(`${entry.key} has no drive`);
  const screen = entry.match?.[0] || entry.key; // the registry's name for the screen, not a card's wording
  mkdirSync(dir, { recursive: true });
  await runDrive(entry.drive, io);
  const png = join(dir, `${entry.key}.png`);
  io.screenshot(png);
  const side = sidecar({ screen, key: entry.key, commit, version, device, runtime });
  writeFileSync(png.replace(/\.png$/, '.json'), JSON.stringify(side, null, 2) + '\n');
  return { ...side, path: png };
}

/** The commit and app version a capture is stamped with. */
export function stamp(root = process.cwd()) {
  const commit = spawnSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: root, encoding: 'utf8' }).stdout.trim();
  const pubspec = existsSync(join(root, 'pubspec.yaml')) ? readFileSync(join(root, 'pubspec.yaml'), 'utf8') : '';
  const version = (pubspec.match(/^version:\s*(\S+)/m) || [])[1] || '';
  return { commit, version };
}

/** What stands between this machine and a capture. Empty means ready. */
export async function doctor({ bundle = BUNDLE, udid } = {}) {
  const problems = [];
  const idb = idbPath();
  if (!idb) problems.push('idb is not installed: run scripts/ssot-capture-setup.sh');
  const companion = IDB_PATHS.some(d => existsSync(join(d, 'idb_companion'))) || spawnSync('which', ['idb_companion']).status === 0;
  if (!companion) problems.push('idb_companion is not installed: run scripts/ssot-capture-setup.sh');
  let booted = null;
  try { booted = bootedUdid(udid); } catch (e) { problems.push(/no simulator is called/.test(e.message) ? e.message : 'xcrun simctl is not available (install Xcode)'); }
  if (booted === null && !problems.some(p => p.startsWith('xcrun'))) problems.push('no booted simulator: open Simulator.app and boot one');
  if (booted) {
    const apps = spawnSync('xcrun', ['simctl', 'listapps', booted.udid], { encoding: 'utf8' }).stdout || '';
    if (!apps.includes(bundle)) problems.push(`${bundle} is not installed on ${booted.name}: run the dev app on it once`);
    else if (idb && companion) {
      const io = simulatorIo(booted.udid, { bundle, idb });
      await io.launch();
      const tree = await io.tree();
      if (tree.filter(e => e.type !== 'Application').length === 0) problems.push('the app answers with an empty accessibility tree after a fresh launch: check it is signed in and not paused in a debugger');
    }
  }
  return { ready: problems.length === 0, problems, booted };
}
