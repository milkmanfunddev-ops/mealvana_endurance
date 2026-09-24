#!/usr/bin/env node
// What the self-hosted runner's Patrol job runs (.github/workflows/tests-selfhosted.yml).
//
// Targets: every *_test.dart directly in integration_test/ and in integration_test/flows/,
// minus the flows named in integration_test/runner_exclusions.json. A new flow joins the run
// by existing; nobody edits the workflow. A flow that spends on AI (or needs a clean install,
// or interactive OAuth) goes on the exclusion list with a reason and a why.
//
// Expected count: the patrolTest calls across the targets, so the workflow can tell "every
// case ran" from "a target was dropped". A file that registers its cases in a loop says how
// many with a `// runner-cases: N` line.
//
// CLI:
//   node scripts/patrol-targets.mjs targets [--root <repo>]   one target per line
//   node scripts/patrol-targets.mjs count   [--root <repo>]   the expected patrolTest cases
//   node scripts/patrol-targets.mjs excluded [--root <repo>]  target<TAB>reason<TAB>why
// Exit 1 with the reason on stderr when the exclusion list is broken.

import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const DIR = 'integration_test';
const FOLDERS = ['', 'flows'];
const EXCLUSIONS = 'runner_exclusions.json';

/** The patrolTest cases one test file registers. */
export function cases(source) {
  const declared = source.match(/^\s*\/\/+\s*runner-cases:\s*(\d+)\s*$/m);
  if (declared) return Number(declared[1]);
  return source.split('\n').filter(l => !/^\s*\/\//.test(l) && /(^|[^\w.])patrolTest\(/.test(l)).length;
}

/** { targets, excluded, expected } for the repo at `root`. Throws when the exclusion list is broken. */
export function plan(root) {
  const base = join(root, DIR);
  const exclusionsPath = join(base, EXCLUSIONS);
  const exclusions = existsSync(exclusionsPath) ? JSON.parse(readFileSync(exclusionsPath, 'utf8')) : {};
  for (const [rel, entry] of Object.entries(exclusions)) {
    if (!existsSync(join(base, rel))) throw new Error(`${EXCLUSIONS}: ${rel} does not exist; drop it from the list`);
    if (!entry?.reason || !entry?.why) throw new Error(`${EXCLUSIONS}: ${rel} needs a reason and a why`);
  }
  const all = FOLDERS.flatMap(folder => {
    const dir = join(base, folder);
    if (!existsSync(dir)) return [];
    return readdirSync(dir, { withFileTypes: true })
      .filter(e => e.isFile() && e.name.endsWith('_test.dart'))
      .map(e => (folder ? `${folder}/${e.name}` : e.name));
  });
  const targets = all.filter(rel => !(rel in exclusions)).sort().map(rel => `${DIR}/${rel}`);
  const excluded = Object.keys(exclusions).sort().map(rel => ({ target: `${DIR}/${rel}`, reason: exclusions[rel].reason, why: exclusions[rel].why }));
  const expected = targets.reduce((n, t) => n + cases(readFileSync(join(root, t), 'utf8')), 0);
  return { targets, excluded, expected };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const cmd = args[0];
  const at = args.indexOf('--root');
  const root = at >= 0 ? args[at + 1] : join(dirname(fileURLToPath(import.meta.url)), '..');
  let p;
  try { p = plan(root); } catch (e) { process.stderr.write(`${e.message}\n`); process.exit(1); }
  if (cmd === 'targets') process.stdout.write(p.targets.map(t => `${t}\n`).join(''));
  else if (cmd === 'count') process.stdout.write(`${p.expected}\n`);
  else if (cmd === 'excluded') process.stdout.write(p.excluded.map(e => `${e.target}\t${e.reason}\t${e.why}\n`).join(''));
  else { process.stderr.write('usage: patrol-targets.mjs targets|count|excluded [--root <repo>]\n'); process.exit(64); }
}
