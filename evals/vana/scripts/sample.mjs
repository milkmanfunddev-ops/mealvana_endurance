#!/usr/bin/env node
/** Sample N traces from a run's JSONL into the review app's data file. Sampling stays OUTSIDE the app (the
 *  build-review-interface convention): re-run this for a fresh sample, or point --out elsewhere for a custom set.
 *
 *  Usage:  node evals/vana/scripts/sample.mjs evals/vana/traces/<run>.jsonl [10] [--seed 42]
 *          [--stratify task]   # one-per-task round-robin instead of uniform random
 *  Writes: evals/vana/review/traces.json (and prints the scenario ids chosen). */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const argv = process.argv.slice(2);
const file = argv[0];
const n = Number(argv.find((a) => /^\d+$/.test(a)) ?? 10);
const seed = Number(argv.find((a) => /^--seed=/.test(a))?.split('=')[1] ?? 42);
const stratify = argv.find((a) => /^--stratify=/.test(a))?.split('=')[1];
if (!file) { console.error('usage: sample.mjs <traces.jsonl> [n] [--seed=42] [--stratify=task]'); process.exit(1); }

const rows = readFileSync(file, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
const rng = (s) => () => (s = (s * 1664525 + 1013904223) >>> 0, s / 2 ** 32);
const rand = rng(seed);
let picked;
if (stratify) {
  // Round-robin over the dimension's values (shuffled within each), so every task/athlete gets represented.
  const byVal = new Map();
  for (const r of rows) { const k = r[stratify] ?? r.payload?.[stratify] ?? '?'; byVal.set(k, [...(byVal.get(k) ?? []), r]); }
  for (const v of byVal.values()) v.sort(() => rand() - 0.5);
  picked = [];
  outer: for (let i = 0; picked.length < Math.min(n, rows.length); i++) {
    let advanced = false;
    for (const v of byVal.values()) if (v[i]) { picked.push(v[i]); advanced = true; if (picked.length >= n) break outer; }
    if (!advanced) break;
  }
} else {
  const pool = [...rows];
  picked = [];
  for (let i = 0; i < Math.min(n, pool.length); i++) picked.push(...pool.splice(Math.floor(rand() * pool.length), 1));
}
mkdirSync(new URL('.', import.meta.url).pathname + '/../review', { recursive: true });
writeFileSync(new URL('.', import.meta.url).pathname + '/../review/traces.json', JSON.stringify(picked, null, 1));
console.log(`sampled ${picked.length}/${rows.length} -> evals/vana/review/traces.json`);
console.log(picked.map((r) => `${r.scenario_id}.${r.turn} (${r.task}/${r.athlete}/${r.character})`).join('\n'));
