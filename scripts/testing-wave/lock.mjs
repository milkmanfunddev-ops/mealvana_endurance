#!/usr/bin/env node
// Testing-wave locks: a slot semaphore (two runs at once) and a build lock (one build at once).
//
// A claim is {owner, since}. A claim older than its lock's stale timeout belongs to an agent
// that died without releasing and is dropped on the next claim. Claiming again as the same
// owner keeps the one claim. The numbers come from the spec ("Parallelism for this feature").
//
// CLI (state in $TESTING_WAVE_STATE, default <tmpdir>/mealvana-testing-wave):
//   node lock.mjs claim slot|build <owner> [--wait <minutes>] [--stale <minutes>]
//        -> exit 0 held, exit 3 still full after the wait (prints who holds it)
//   node lock.mjs release slot|build <owner>
//   node lock.mjs list

import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { stateDir, sleepSync, withJson } from './state.mjs';

const MIN = 60_000;
export const LOCKS = {
  // A run holds its slot for the whole scenario; four hours without a release means it died.
  slot: { cap: 2, staleMs: 240 * MIN, waitMs: 90 * MIN },
  // A dev debug build and first launch take minutes; half an hour without a release means it died.
  build: { cap: 1, staleMs: 30 * MIN, waitMs: 45 * MIN },
};
const FILE = 'locks.json';

function spec(name) {
  const s = LOCKS[name];
  if (!s) throw new Error(`no lock "${name}": use ${Object.keys(LOCKS).join(' or ')}`);
  return s;
}

function tryOnce(name, owner, { dir, now, staleMs, cap }) {
  return withJson(dir, FILE, all => {
    const t = now();
    const list = all[name] ?? [];
    const dropped = list.filter(h => t - Date.parse(h.since) > staleMs);
    const live = list.filter(h => !dropped.includes(h));
    all[name] = live;
    if (live.some(h => h.owner === owner)) return { acquired: true, reused: true, owner, dropped, held: live };
    if (live.length >= cap) return { acquired: false, owner, dropped, held: live };
    live.push({ owner, since: new Date(t).toISOString() });
    return { acquired: true, reused: false, owner, dropped, held: live };
  });
}

/** Claim a place in the lock, waiting up to `waitMs` (polling every `pollMs`). */
export function acquire(name, owner, { dir = stateDir(), now = Date.now, sleep = sleepSync, waitMs = 0, pollMs = 30_000, staleMs, cap } = {}) {
  if (!owner) throw new Error('a claim needs an owner (the ticket, e.g. testing-wave-02)');
  const s = spec(name);
  const opts = { dir, now, staleMs: staleMs ?? s.staleMs, cap: cap ?? s.cap };
  const start = now();
  const dropped = [];
  for (;;) {
    const r = tryOnce(name, owner, opts);
    dropped.push(...r.dropped);
    if (r.acquired) return { ...r, dropped };
    const left = start + waitMs - now();
    if (left <= 0) return { ...r, dropped, waitedMs: now() - start };
    sleep(Math.min(pollMs, left));
  }
}

export function release(name, owner, { dir = stateDir() } = {}) {
  spec(name);
  return withJson(dir, FILE, all => {
    const list = all[name] ?? [];
    all[name] = list.filter(h => h.owner !== owner);
    return { released: all[name].length < list.length, owner };
  });
}

/** Who holds the lock now, stale claims included (they go on the next claim). */
export function holders(name, { dir = stateDir(), now = Date.now } = {}) {
  const s = spec(name);
  return withJson(dir, FILE, all => (all[name] ?? []).map(h => ({ ...h, stale: now() - Date.parse(h.since) > s.staleMs })));
}

function flag(args, name) {
  const i = args.indexOf(name);
  if (i < 0) return undefined;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const cmd = args.shift();
  const usage = () => { process.stderr.write('usage: lock.mjs claim slot|build <owner> [--wait <minutes>] [--stale <minutes>] | release slot|build <owner> | list\n'); process.exit(64); };
  const print = o => process.stdout.write(JSON.stringify(o, null, 2) + '\n');
  if (cmd === 'claim') {
    const wait = flag(args, '--wait');
    const stale = flag(args, '--stale');
    const [name, owner] = args;
    if (!LOCKS[name] || !owner) usage();
    const r = acquire(name, owner, {
      waitMs: wait === undefined ? LOCKS[name].waitMs : Number(wait) * MIN,
      ...(stale !== undefined ? { staleMs: Number(stale) * MIN } : {}),
    });
    print(r);
    process.exit(r.acquired ? 0 : 3);
  } else if (cmd === 'release') {
    const [name, owner] = args;
    if (!LOCKS[name] || !owner) usage();
    print(release(name, owner));
  } else if (cmd === 'list') {
    print(Object.fromEntries(Object.keys(LOCKS).map(n => [n, { cap: LOCKS[n].cap, held: holders(n) }])));
  } else usage();
}
