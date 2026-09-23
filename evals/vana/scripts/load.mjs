#!/usr/bin/env node
/** Load harness JSONL traces into the dev `eval_traces` table. The table is the durable home (repo JSONL is the
 *  interchange format); see evals/vana/README.md.
 *
 *  Usage:  node evals/vana/scripts/load.mjs <traces.jsonl> [--replace-run]
 *  Env:    SUPABASE_URL (defaults to dev) and SUPABASE_SERVICE_ROLE_KEY
 *          (secrets/supabase_service_role_keys.md has the dev key).
 *  --replace-run deletes rows already in the table for each loaded run_id first, so re-running a run is clean. */
import { readFileSync } from 'node:fs';

const SUPABASE_URL = process.env.SUPABASE_URL ?? 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!KEY) { console.error('export SUPABASE_SERVICE_ROLE_KEY first (secrets/supabase_service_role_keys.md)'); process.exit(1); }

const files = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const replaceRun = process.argv.includes('--replace-run');
if (!files.length) { console.error('usage: load.mjs <traces.jsonl>... [--replace-run]'); process.exit(1); }

const rows = files.flatMap((f) => readFileSync(f, 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l)));
const runs = [...new Set(rows.map((r) => r.run_id))];
if (replaceRun && runs.length) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/eval_traces?run_id=in.(${runs.map((r) => `"${r}"`).join(',')})`, { method: 'DELETE', headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } });
  if (!res.ok) { console.error(`delete failed ${res.status}: ${await res.text()}`); process.exit(1); }
  console.log(`replaced ${runs.join(', ')}`);
}
for (let i = 0; i < rows.length; i += 50) {
  const chunk = rows.slice(i, i + 50);
  const res = await fetch(`${SUPABASE_URL}/rest/v1/eval_traces`, {
    method: 'POST', headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify(chunk),
  });
  if (!res.ok) { console.error(`insert failed ${res.status}: ${(await res.text()).slice(0, 500)}`); process.exit(1); }
}
console.log(`loaded ${rows.length} trace(s) from ${files.length} file(s) -> ${SUPABASE_URL}`);
