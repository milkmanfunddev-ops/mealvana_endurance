#!/usr/bin/env node
// Testing-wave cost caps: at most three new Vana plans, five AI logging calls and five Vana chat
// calls (an opener or a turn that is not a plan) per wave, across all agents (spec, "Cost caps per wave"). An agent spends BEFORE the step; a refusal
// means it does not run the step and writes a followup-test Finding instead.
//
// CLI (state in $TESTING_WAVE_STATE, default <tmpdir>/mealvana-testing-wave):
//   node cost.mjs spend <wave> plan|logging|chat <ticket> -> exit 0 spent, exit 3 refused (cap reached)
//   node cost.mjs status <wave>

import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { stateDir, withJson } from './state.mjs';

export const CAPS = { plan: 3, logging: 5, chat: 5 };
const FILE = 'costs.json';

/** Record one spend, or refuse it if the wave already used its cap for that kind. */
export function spend(wave, kind, ticket, { dir = stateDir(), now = Date.now } = {}) {
  if (!(kind in CAPS)) throw new Error(`kind "${kind}" is not one of ${Object.keys(CAPS).join(', ')}`);
  if (!wave || !ticket) throw new Error('a spend needs the wave and the ticket');
  return withJson(dir, FILE, all => {
    const w = (all[wave] ??= {});
    const list = (w[kind] ??= []);
    if (list.length >= CAPS[kind]) return { ok: false, wave, kind, used: list.length, cap: CAPS[kind], by: list.map(s => s.ticket) };
    list.push({ ticket: String(ticket), at: new Date(now()).toISOString() });
    return { ok: true, wave, kind, used: list.length, cap: CAPS[kind] };
  });
}

/** What the wave has spent so far, per kind. */
export function spent(wave, { dir = stateDir() } = {}) {
  return withJson(dir, FILE, all => Object.fromEntries(Object.keys(CAPS).map(k => [k, all[wave]?.[k] ?? []])));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [cmd, wave, kind, ticket] = process.argv.slice(2);
  if (cmd === 'spend' && wave && kind in CAPS && ticket) {
    const r = spend(wave, kind, ticket);
    process.stdout.write(r.ok
      ? `spent: wave ${wave} ${kind} ${r.used}/${r.cap} (ticket ${ticket})\n`
      : `refused: wave ${wave} has used ${r.used}/${r.cap} ${kind} (tickets ${r.by.join(', ')}). Do not run the step; write a followup-test Finding.\n`);
    process.exit(r.ok ? 0 : 3);
  } else if (cmd === 'status' && wave) {
    const s = spent(wave);
    for (const k of Object.keys(CAPS)) process.stdout.write(`${k}: ${s[k].length}/${CAPS[k]}${s[k].length ? ` (${s[k].map(x => x.ticket).join(', ')})` : ''}\n`);
  } else {
    process.stderr.write('usage: cost.mjs spend <wave> plan|logging|chat <ticket> | status <wave>\n');
    process.exit(64);
  }
}
