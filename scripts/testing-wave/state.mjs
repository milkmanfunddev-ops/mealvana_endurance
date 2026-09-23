// Shared state for the testing-wave harness: one folder per machine, one JSON file per
// counter, each read-modify-write under a mkdir mutex so agents in different worktrees
// take turns. The folder is machine-global like the simulator claims (capture.mjs):
// every worktree's agent must see the same slots, build lock and cost counts.
// TESTING_WAVE_STATE overrides it (the tests use a temp folder).

import { readFileSync, writeFileSync, mkdirSync, rmSync, statSync, renameSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export const stateDir = () => process.env.TESTING_WAVE_STATE ?? join(tmpdir(), 'mealvana-testing-wave');

/** Block the thread for `ms` (the CLI waits synchronously, like `simulator claim --wait`). */
export const sleepSync = ms => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

/** Read `<dir>/<file>`, let `fn` change it, write it back; the mutex is a directory beside it. */
export function withJson(dir, file, fn) {
  mkdirSync(dir, { recursive: true });
  const path = join(dir, file);
  const mutex = path + '.lock';
  const token = randomUUID();
  for (let i = 0; ; i++) {
    try { mkdirSync(mutex); writeFileSync(join(mutex, 'owner'), token); break; } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      // A mutex older than ten seconds belongs to a process that died inside the critical section.
      // Rename it aside first: only one waiter's rename succeeds, so two never both take it.
      try {
        if (Date.now() - statSync(mutex).mtimeMs > 10_000) {
          const aside = `${mutex}.stale-${token}`;
          renameSync(mutex, aside);
          rmSync(aside, { recursive: true, force: true });
          continue;
        }
      } catch {}
      if (i > 200) throw new Error(`could not lock ${mutex}`);
      sleepSync(50);
    }
  }
  try {
    let data;
    try { data = JSON.parse(readFileSync(path, 'utf8')); } catch (e) {
      // Only a missing file means empty. A torn or unreadable one must stop the caller rather
      // than silently free every lock and zero every cost counter.
      if (e.code !== 'ENOENT') throw new Error(`${path} is unreadable (${e.message}); inspect or delete it by hand`);
      data = {};
    }
    const out = fn(data);
    const tmp = `${path}.${token}.tmp`;
    writeFileSync(tmp, JSON.stringify(data, null, 2));
    renameSync(tmp, path);
    return out;
  } finally {
    // A holder slower than the stale limit may have lost the mutex to a waiter; leave theirs alone.
    try { if (readFileSync(join(mutex, 'owner'), 'utf8') === token) rmSync(mutex, { recursive: true, force: true }); } catch {}
  }
}

/** Take `--name <value>` out of `args` and return the value (undefined when absent). */
export function flag(args, name) {
  const i = args.indexOf(name);
  if (i < 0) return undefined;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
}

/** A `--name <minutes>` value in milliseconds; anything but a non-negative finite number is refused. */
export function minutesFlag(value, name) {
  if (value === undefined) return undefined;
  const n = Number(value);
  if (value === '' || !Number.isFinite(n) || n < 0) throw new Error(`${name} takes a number of minutes, got "${value}"`);
  return n * 60_000;
}
