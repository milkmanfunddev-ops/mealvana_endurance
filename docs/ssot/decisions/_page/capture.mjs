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
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const BUNDLE = 'com.milkman.mealvanaendurance.dev';
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
const label = e => String(e.AXLabel || '');
const centre = e => [Math.round(e.frame.x + e.frame.width / 2), Math.round(e.frame.y + e.frame.height / 2)];
const onScreen = e => e.frame && (e.frame.width > 0 || e.frame.height > 0);
export function findElement(tree, step) {
  const els = tree.filter(e => e.type !== 'Application' && onScreen(e));
  if (step.tap !== undefined) {
    const want = step.tap.toLowerCase();
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

/** Run a drive against an io: {launch(), tree(), tap(x, y), wait(ms)}. Throws naming the step that found nothing. */
export async function runDrive(steps, io, { settle = 1800 } = {}) {
  await io.launch();
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
export function bootedUdid() {
  const out = execFileSync('xcrun', ['simctl', 'list', 'devices', 'booted', '-j'], { encoding: 'utf8' });
  const j = JSON.parse(out);
  for (const [runtime, devs] of Object.entries(j.devices)) for (const d of devs) if (d.state === 'Booted') return { udid: d.udid, name: d.name, runtime: runtimeName(runtime) };
  return null;
}
export function simulatorIo(udid, { bundle = BUNDLE, idb = idbPath() } = {}) {
  const run = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
  return {
    async launch() {
      spawnSync('xcrun', ['simctl', 'terminate', udid, bundle]);
      run('xcrun', ['simctl', 'launch', udid, bundle]);
      await sleep(5000);
    },
    async tree() { try { return JSON.parse(run(idb, ['ui', 'describe-all', '--udid', udid, '--json'])); } catch { return []; } },
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
export async function doctor({ bundle = BUNDLE } = {}) {
  const problems = [];
  const idb = idbPath();
  if (!idb) problems.push('idb is not installed: run scripts/ssot-capture-setup.sh');
  const companion = IDB_PATHS.some(d => existsSync(join(d, 'idb_companion'))) || spawnSync('which', ['idb_companion']).status === 0;
  if (!companion) problems.push('idb_companion is not installed: run scripts/ssot-capture-setup.sh');
  let booted = null;
  try { booted = bootedUdid(); } catch { problems.push('xcrun simctl is not available (install Xcode)'); }
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
