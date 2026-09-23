#!/usr/bin/env node
// Testing-wave code probe: a loopback HTTP endpoint on the Mac that a Patrol flow on the simulator
// calls for the email code of a lee+e2e-* account on DEV. It asks the Auth admin API to generate
// the code (generate_link returns it and sends no email), so the service-role key stays on the Mac
// and never goes into the app under test. Agents driving by hand read codes with the Gmail tool.
//
// CLI:
//   node code-probe.mjs serve [--port 8787]
//     POST /code {"email": "lee+e2e-…", "type": "signup"|"magiclink"|"recovery", "password"?}
//       -> 200 {"code": "123456"} | 400 {"error": "..."}
//   node code-probe.mjs code <email> <type> [password]   -> prints the code once
//
// A signup code needs the account's password (GoTrue's generate_link signup contract).
// Calling it replaces any code already emailed for that account.

import { createServer } from 'node:http';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { devAdmin, isSweepable } from './sweep-accounts.mjs';

const TYPES = ['signup', 'magiclink', 'recovery'];

/** Generate a code for a lee+e2e-* account through `admin.authAdmin` (see devAdmin). */
export async function readCode(admin, { email, type, password } = {}) {
  if (!isSweepable(email)) throw new Error('the probe only serves lee+e2e-*@rightpathprogramming.com accounts');
  if (!TYPES.includes(type)) throw new Error(`type must be one of ${TYPES.join(', ')}`);
  if (type === 'signup' && !password) throw new Error('a signup code needs the account password');
  const body = type === 'signup' ? { type, email, password } : { type, email };
  const reply = await admin.authAdmin('/generate_link', { method: 'POST', body: JSON.stringify(body) });
  const code = reply?.email_otp ?? reply?.properties?.email_otp;
  if (!code) throw new Error('generate_link returned no code');
  return { code: String(code) };
}

/** Start the probe on 127.0.0.1. Resolves with the listening server. */
export function startProbe({ admin = devAdmin(), port = 8787 } = {}) {
  const server = createServer(async (req, res) => {
    const send = (status, obj) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(obj));
    };
    if (req.method !== 'POST' || req.url !== '/code') return send(404, { error: 'POST /code only' });
    let raw = '';
    for await (const chunk of req) raw += chunk;
    try {
      send(200, await readCode(admin, JSON.parse(raw || '{}')));
    } catch (e) {
      send(400, { error: e.message });
    }
  });
  return new Promise(ok => server.listen(port, '127.0.0.1', () => ok(server)));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [cmd, ...rest] = process.argv.slice(2);
  try {
    if (cmd === 'serve') {
      const i = rest.indexOf('--port');
      const server = await startProbe({ port: i === -1 ? 8787 : Number(rest[i + 1]) });
      process.stdout.write(`code probe on http://127.0.0.1:${server.address().port}/code (dev, lee+e2e-* only)\n`);
    } else if (cmd === 'code' && rest.length >= 2) {
      const [email, type, password] = rest;
      process.stdout.write(`${(await readCode(devAdmin(), { email, type, password })).code}\n`);
    } else {
      process.stderr.write('usage: code-probe.mjs serve [--port 8787] | code <email> <type> [password]\n');
      process.exit(64);
    }
  } catch (e) {
    process.stderr.write(`${e.message}\n`);
    process.exit(2);
  }
}
