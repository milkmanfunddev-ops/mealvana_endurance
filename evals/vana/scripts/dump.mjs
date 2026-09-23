#!/usr/bin/env node
/** Dump `eval_traces` back out as JSONL — what the review app and any eval script consume. The table is the
 *  durable home; this is the bridge to the local-file world of the evals skills (evals/vana/README.md).
 *
 *  Usage:  node evals/vana/scripts/dump.mjs [--run <run_id>] [--source synthetic|real] [--scenario S03] [--limit 200] [--out <file>]
 *  Env:    SUPABASE_URL (defaults to dev) and SUPABASE_SERVICE_ROLE_KEY. */
const SUPABASE_URL = process.env.SUPABASE_URL ?? 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!KEY) { console.error('export SUPABASE_SERVICE_ROLE_KEY first (secrets/supabase_service_role_keys.md)'); process.exit(1); }

const arg = (k) => { const i = process.argv.indexOf(`--${k}`); return i >= 0 ? process.argv[i + 1] : undefined; };
const q = new URLSearchParams({ select: '*', order: 'created_at.asc', limit: arg('limit') ?? '200' });
if (arg('run')) q.set('run_id', `eq.${arg('run')}`);
if (arg('source')) q.set('source', `eq.${arg('source')}`);
if (arg('scenario')) q.set('scenario_id', `eq.${arg('scenario')}`);

const res = await fetch(`${SUPABASE_URL}/rest/v1/eval_traces?${q}`, { headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } });
if (!res.ok) { console.error(`dump failed ${res.status}: ${(await res.text()).slice(0, 500)}`); process.exit(1); }
const rows = await res.json();
const jsonl = rows.map((r) => JSON.stringify(r)).join('\n') + (rows.length ? '\n' : '');
const out = arg('out');
if (out) { const { writeFileSync } = await import('node:fs'); writeFileSync(out, jsonl); console.log(`${rows.length} trace(s) -> ${out}`); }
else { process.stdout.write(jsonl); }
