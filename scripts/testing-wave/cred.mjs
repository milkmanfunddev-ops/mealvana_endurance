#!/usr/bin/env node
// Testing-wave credentials without reading the file. Agents never open secrets/test_accounts.md
// (IMPROVEMENTS #30: a layout read printed the password column); they learn its shape from
// test_accounts.template.md and reach passwords only through this script, which never prints one.
//
// CLI (file in $TESTING_WAVE_CREDENTIALS, default the main clone's secrets/test_accounts.md):
//   node cred.mjs type <email> --udid <udid>          types the password into the focused field (idb)
//   node cred.mjs file <email> <path>                 writes the password to <path> (mode 600), for API checks
//   node cred.mjs new <email> --ticket NN --run RUN   makes a password, appends a Created accounts row (state new)
//   node cred.mjs update <email> [--state S] [--bought B] [--when W] [--note TEXT] [--new-password]
//   node cred.mjs list                                addresses and states only
// `type` and `file` take --section <words> when one address sits in two sections (the Patrol
// account and the Kroger login are both Lee's Gmail): only sections whose name contains the words.
// Exit 2: no such account. Exit 64: usage.

import { readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEFAULT_FILE = '/Users/leemartin/development/mealvana_endurance/secrets/test_accounts.md';
const credFile = () => process.env.TESTING_WAVE_CREDENTIALS || DEFAULT_FILE;

const cells = line => line.trim().replace(/^\||\|$/g, '').split('|').map(c => c.trim());
const isRow = line => /^\s*\|/.test(line) && !/^\s*\|\s*-{3}/.test(line);

/** Every account in the file: {address, password, section, line, kind: 'kv'|'row', state}. */
export function parse(text) {
  const lines = text.split('\n');
  const out = [];
  let section = '';
  let kv = null;
  let header = null;
  lines.forEach((line, i) => {
    if (/^## /.test(line)) { section = line.slice(3).trim(); kv = null; header = null; return; }
    if (!isRow(line)) return;
    const c = cells(line);
    if (!header) { header = c; if (c[0] === 'Field') kv = { section }; return; }
    if (kv) {
      if (c[0] === 'Address') kv.address = c[1];
      if (c[0] === 'Password') { kv.password = c[1]; kv.passwordLine = i; }
      if (kv.address && kv.password !== undefined && !kv.pushed) {
        kv.pushed = true;
        out.push({ address: kv.address, password: kv.password, section, line: kv.passwordLine, kind: 'kv', state: '' });
      }
      return;
    }
    const col = name => header.indexOf(name);
    out.push({ address: c[0], password: c[1], section, line: i, kind: 'row', state: col('State') >= 0 ? c[col('State')] : '' });
  });
  return out;
}

export function find(text, email, section) {
  const want = email.trim().toLowerCase();
  const inSection = a => !section || a.section.toLowerCase().includes(section.trim().toLowerCase());
  const hits = parse(text).filter(a => a.address.toLowerCase() === want && inSection(a));
  return hits[hits.length - 1] ?? null;
}

/** Letters and digits plus a fixed tail, so the app's password rules always pass. */
export function makePassword() {
  return randomBytes(24).toString('base64').replace(/[^A-Za-z0-9]/g, '').slice(0, 16) + 'A1!';
}

const setCell = (line, index, value) => {
  const c = cells(line);
  c[index] = value;
  return `| ${c.join(' | ')} |`;
};

/** Append a Created accounts row; the password is made here and never returned to the caller's output. */
export function addAccount(text, email, { ticket, run, password = makePassword() }) {
  if (find(text, email)) throw new Error(`${email} is already in the file`);
  const lines = text.split('\n');
  const start = lines.findIndex(l => /^## Created accounts/.test(l));
  if (start < 0) throw new Error('no "## Created accounts" section');
  let last = start;
  for (let i = start + 1; i < lines.length && !/^## /.test(lines[i]); i++) if (/^\s*\|/.test(lines[i])) last = i;
  lines.splice(last + 1, 0, `| ${email} | ${password} | nothing |  | new | ${ticket} / ${run} |`);
  return lines.join('\n');
}

/** Change a Created accounts row's cells (Password with newPassword, Bought, When, State, and a note on Ticket / run). */
export function updateAccount(text, email, { state, bought, when, note, newPassword } = {}) {
  const acct = find(text, email);
  if (!acct) return null;
  const lines = text.split('\n');
  if (acct.kind === 'kv') {
    if (state || bought || when || note) throw new Error(`${email} is a fixed account; only --new-password applies`);
    if (newPassword) lines[acct.line] = setCell(lines[acct.line], 1, newPassword);
    return lines.join('\n');
  }
  let line = lines[acct.line];
  if (newPassword) line = setCell(line, 1, newPassword);
  if (bought) line = setCell(line, 2, bought);
  if (when) line = setCell(line, 3, when);
  if (state) line = setCell(line, 4, state);
  if (note) line = setCell(line, 5, `${cells(line)[5]} ${note}`.trim());
  lines[acct.line] = line;
  return lines.join('\n');
}

function flags(args) {
  const f = { _: [] };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--new-password') f.newPassword = true;
    else if (args[i].startsWith('--')) f[args[i].slice(2)] = args[++i];
    else f._.push(args[i]);
  }
  return f;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [cmd, ...rest] = process.argv.slice(2);
  const f = flags(rest);
  const email = f._[0];
  const file = credFile();
  const text = () => readFileSync(file, 'utf8');
  const missing = () => { process.stderr.write(`no account ${email} in ${file}\n`); process.exit(2); };
  const usage = () => {
    process.stderr.write('usage: cred.mjs type <email> --udid <udid> [--section S] | file <email> <path> [--section S] | new <email> --ticket NN --run RUN | update <email> [--state S] [--bought B] [--when W] [--note TEXT] [--new-password] | list\n');
    process.exit(64);
  };

  if (cmd === 'type' && email && f.udid) {
    const acct = find(text(), email, f.section) ?? missing();
    // A field tapped a moment ago drops the first characters typed into it (IMPROVEMENTS #93).
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, Number(process.env.CRED_TYPE_DELAY_MS ?? 1000));
    const r = spawnSync('idb', ['ui', 'text', acct.password, '--udid', f.udid], { stdio: ['ignore', 'ignore', 'pipe'] });
    if (r.status !== 0) { process.stderr.write(`idb failed (exit ${r.status})\n`); process.exit(1); }
    process.stdout.write(`typed the password for ${acct.address} (${acct.section})\n`);
  } else if (cmd === 'file' && email && f._[1]) {
    const acct = find(text(), email, f.section) ?? missing();
    writeFileSync(f._[1], acct.password, { mode: 0o600 });
    chmodSync(f._[1], 0o600);
    process.stdout.write(`wrote the password for ${acct.address} to ${f._[1]}\n`);
  } else if (cmd === 'new' && email && f.ticket && f.run) {
    writeFileSync(file, addAccount(text(), email, { ticket: f.ticket, run: f.run }));
    process.stdout.write(`added ${email} (state new); type its password with: cred.mjs type ${email} --udid <udid>\n`);
  } else if (cmd === 'update' && email) {
    const next = updateAccount(text(), email, { ...f, newPassword: f.newPassword ? makePassword() : undefined });
    if (next === null) missing();
    writeFileSync(file, next);
    process.stdout.write(`updated ${email}${f.newPassword ? ' (new password stored; save the old one first with `file` if the run still needs it)' : ''}\n`);
  } else if (cmd === 'list') {
    for (const a of parse(text())) process.stdout.write(`${a.section} | ${a.address} | ${a.state || '-'}\n`);
  } else usage();
}
