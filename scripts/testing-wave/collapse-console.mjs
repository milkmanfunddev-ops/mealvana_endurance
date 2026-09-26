#!/usr/bin/env node
// Collapses repeated logger boxes in a redacted run console (IMPROVEMENTS #94).
//
//   node scripts/testing-wave/collapse-console.mjs RUNS/console-redacted.log [--keep 3] [--min 20]
//
// A box is the run of `(Flutter)` lines from one `┌` to its `└`. Two boxes are the same when
// their lines match once the syslog prefix and the logger's own time line are dropped. A box
// seen at least --min times keeps its first --keep copies and its last one; one count line
// stands where the cut ones were. The file is rewritten in place; the summary goes to stdout.
import { readFileSync, writeFileSync } from 'node:fs';

const args = process.argv.slice(2);
const file = args.find((a) => !a.startsWith('--'));
const opt = (name, dflt) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? Number(args[i + 1]) : dflt;
};
const keep = opt('keep', 3);
const min = opt('min', 20);
if (!file) {
  console.error('usage: collapse-console.mjs <console-redacted.log> [--keep 3] [--min 20]');
  process.exit(2);
}

const lines = readFileSync(file, 'utf8').split('\n');
const body = (l) => l.replace(/^.*?\(Flutter\) flutter: /, '');
const isTime = (b) => /│ \d\d:\d\d:\d\d\.\d+ \(\+/.test(b);
const stamp = (l) => l.slice(0, 26);

// Items: a single line, or a box [start, end].
const items = [];
for (let i = 0; i < lines.length; i++) {
  if (body(lines[i]).includes('┌')) {
    let j = i + 1;
    while (j < lines.length && j - i < 200 && !body(lines[j]).includes('└')) j++;
    if (j < lines.length && body(lines[j]).includes('└')) {
      const key = lines.slice(i, j + 1).map(body).filter((b) => !isTime(b)).join('\n');
      items.push({ start: i, end: j, key });
      i = j;
      continue;
    }
  }
  items.push({ start: i, end: i, key: null });
}

const byKey = new Map();
items.forEach((it, n) => {
  if (!it.key) return;
  if (!byKey.has(it.key)) byKey.set(it.key, []);
  byKey.get(it.key).push(n);
});

const drop = new Set();
const note = new Map(); // item index -> count line inserted before it
let cutBoxes = 0;
for (const [key, ns] of byKey) {
  if (ns.length < min) continue;
  const cut = ns.slice(keep, -1);
  if (!cut.length) continue;
  cut.forEach((n) => drop.add(n));
  cutBoxes += cut.length;
  const label = (key.split('\n').find((b) => /[A-Za-z]\S*\]|⚠|⛔|ERROR|WARN/.test(b)) ?? key.split('\n')[1] ?? '')
    .replace(/\x1b\[[0-9;]*m|\^\[\[[0-9;]*m/g, '').replace(/\\/g, '').replace(/^[│\s]+/, '').trim().slice(0, 120);
  const first = items[cut[0]], last = items[cut[cut.length - 1]];
  note.set(cut[0], `[collapse-console] ${cut.length} more identical boxes '${label}' cut here, from ${stamp(lines[first.start])} to ${stamp(lines[last.start])}; ${ns.length} in total (IMPROVEMENTS #94).`);
}

const out = [];
items.forEach((it, n) => {
  if (note.has(n)) out.push(note.get(n));
  if (!drop.has(n)) out.push(...lines.slice(it.start, it.end + 1));
});
writeFileSync(file, out.join('\n'));
console.log(JSON.stringify({ file, linesBefore: lines.length, linesAfter: out.length, boxesCut: cutBoxes, groups: note.size }));
