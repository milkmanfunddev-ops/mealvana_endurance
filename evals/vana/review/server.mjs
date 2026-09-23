#!/usr/bin/env node
/** Serves the review app and persists labels. Run from anywhere:  node evals/vana/review/server.mjs [port]
 *  - GET  /            the app · GET /app.js · GET /traces.json (the sampled set)
 *  - GET  /labels      { "<scenario_id.turn>": { "label": "pass|fail|defer", "note": "..." } }
 *  - POST /labels      merge-save one label (autosave); stored in labels/ next to this file, one file per run. */
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const port = Number(process.argv[2] ?? 4173);
const traces = JSON.parse(readFileSync(join(here, 'traces.json'), 'utf8'));
const runId = traces[0]?.run_id ?? 'unknown-run';
const labelsFile = join(here, 'labels', `${runId}.json`);
mkdirSync(join(here, 'labels'), { recursive: true });
const readLabels = () => (existsSync(labelsFile) ? JSON.parse(readFileSync(labelsFile, 'utf8')) : {});
if (!existsSync(labelsFile)) writeFileSync(labelsFile, '{}');

const send = (res, code, body, type = 'application/json') => { res.writeHead(code, { 'content-type': type }); res.end(body); };

createServer((req, res) => {
  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) return send(res, 200, readFileSync(join(here, 'index.html')), 'text/html; charset=utf-8');
  if (req.method === 'GET' && req.url === '/app.js') return send(res, 200, readFileSync(join(here, 'app.js')), 'text/javascript; charset=utf-8');
  if (req.method === 'GET' && req.url === '/traces.json') return send(res, 200, JSON.stringify(traces));
  if (req.method === 'GET' && req.url === '/labels') return send(res, 200, JSON.stringify(readLabels()));
  if (req.method === 'POST' && req.url === '/labels') {
    let body = '';
    req.on('data', (c) => body += c);
    req.on('end', () => {
      try {
        const { key, label, note } = JSON.parse(body);
        const all = readLabels();
        all[key] = { ...(all[key] ?? {}), ...(label !== undefined ? { label } : {}), ...(note !== undefined ? { note } : {}), at: new Date().toISOString() };
        writeFileSync(labelsFile, JSON.stringify(all, null, 1));
        send(res, 200, '{"ok":true}');
      } catch (e) { send(res, 400, JSON.stringify({ error: String(e) })); }
    });
    return;
  }
  send(res, 404, '{"error":"not found"}');
}).listen(port, () => console.log(`[review] ${traces.length} trace(s) from ${runId} -> http://localhost:${port} (labels: ${labelsFile})`));
