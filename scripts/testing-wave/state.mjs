// Shared state for the testing-wave harness: one folder per machine, one JSON file per
// counter, each read-modify-write under a mkdir mutex so agents in different worktrees
// take turns. The folder is machine-global like the simulator claims (capture.mjs):
// every worktree's agent must see the same slots, build lock and cost counts.
// TESTING_WAVE_STATE overrides it (the tests use a temp folder).

import { readFileSync, writeFileSync, mkdirSync, rmSync, statSync } from 'node:fs';
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
  for (let i = 0; ; i++) {
    try { mkdirSync(mutex); break; } catch (e) {
      if (e.code !== 'EEXIST') throw e;
      // A mutex older than ten seconds belongs to a process that died inside the critical section.
      try { if (Date.now() - statSync(mutex).mtimeMs > 10_000) { rmSync(mutex, { recursive: true, force: true }); continue; } } catch {}
      if (i > 200) throw new Error(`could not lock ${mutex}`);
      sleepSync(50);
    }
  }
  try {
    let data;
    try { data = JSON.parse(readFileSync(path, 'utf8')); } catch { data = {}; }
    const out = fn(data);
    writeFileSync(path, JSON.stringify(data, null, 2));
    return out;
  } finally { rmSync(mutex, { recursive: true, force: true }); }
}
