#!/usr/bin/env node
// count-vectors.mjs — derive vector counts from the files, never by hand.
// The "168 vectors" figure in the v1/v2 manifests was stale twice (real: 170,
// then 172). Manifests and handoffs must quote THIS script's output.
//   node scripts/count-vectors.mjs [family]     (default: all under vectors/)
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..', 'vectors');
const fam = process.argv[2];
let total = 0;
for (const family of readdirSync(root)) {
  if (fam && family !== fam) continue;
  let famTotal = 0;
  const rows = [];
  for (const f of readdirSync(join(root, family)).filter((f) => f.endsWith('.json'))) {
    const n = (JSON.parse(readFileSync(join(root, family, f))).vectors ?? []).length;
    rows.push(`  ${f.padEnd(32)} ${n}`);
    famTotal += n;
  }
  console.log(`${family}: ${famTotal}`);
  rows.forEach((r) => console.log(r));
  total += famTotal;
}
console.log(`TOTAL: ${total}`);
