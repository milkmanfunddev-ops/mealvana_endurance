#!/usr/bin/env node
// The round-file writer (vana-judging ticket 05). One input in, the pair every round produces
// out (eval/README.md, "Where a round gets written"):
//
//   eval/runs/<round>/round.md    prose: the table of Runs and Marks, each Run's verdict
//   eval/runs/<round>/round.json  the JSON sidecar the board renders from
//
// The Examiner supplies the Marks, verdicts, and Improvement ids; this tool computes where they
// land — the weighted Mark from the rubric.md weights, the robotic cap override, the round
// average (a Scenario's rerun Mark when one exists), and the pass bar (average >= 90, no
// effective Mark below 80). Field names match eval/board/README.md exactly.
//
//   node eval/tools/write-round.mjs <input.json> [--runs-dir <dir>]
//
// input.json:
//   { "round": "001", "date": "2026-09-26",
//     "runs": [ { "scenario": "<slug>", "account": "<accounts.md slug>", "rerun": false,
//                 "dimensions": { "<ten slugs>": 0|25|50|75|100, … },
//                 "robotic_cap_applied": false, "verdict": "…", "improvements": ["IMP-001"] } ] }
//
// Exit 2: usage / invalid input (every problem named). Writes nothing unless the input is valid.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildSidecar, renderProse } from './lib/round.mjs';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');

function usage(message) {
  if (message) console.error(`write-round: ${message}`);
  console.error('usage: write-round.mjs <input.json> [--runs-dir <dir>]   (default runs dir: eval/runs)');
  process.exit(message ? 2 : 0);
}

let inputFile;
const args = { runsDir: resolve(REPO_ROOT, 'eval', 'runs') };
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  const value = () => {
    const v = process.argv[++i];
    if (v === undefined || v.startsWith('--')) usage(`${a} needs a value`);
    return v;
  };
  if (a === '--runs-dir') args.runsDir = resolve(value());
  else if (a === '--help' || a === '-h') usage();
  else if (a.startsWith('--')) usage(`unknown flag ${a}`);
  else if (inputFile) usage(`two input files ("${inputFile}" and "${a}")`);
  else inputFile = a;
}
if (!inputFile) usage('an input json file is required');

let input;
try {
  input = JSON.parse(readFileSync(resolve(inputFile), 'utf8'));
} catch (e) {
  usage(`cannot read input as json: ${e.message}`);
}

let sidecar;
try {
  sidecar = buildSidecar(input);
} catch (e) {
  usage(e.message);
}

const roundDir = resolve(args.runsDir, sidecar.round);
mkdirSync(roundDir, { recursive: true });
writeFileSync(resolve(roundDir, 'round.json'), `${JSON.stringify(sidecar, null, 2)}\n`);
writeFileSync(resolve(roundDir, 'round.md'), renderProse(sidecar));
console.log(`round ${sidecar.round}: ${sidecar.runs.length} run(s), average ${sidecar.average_mark}, ${sidecar.passed ? 'PASS' : 'FAIL'}`);
console.log(`wrote ${resolve(roundDir, 'round.md')} and ${resolve(roundDir, 'round.json')}`);
