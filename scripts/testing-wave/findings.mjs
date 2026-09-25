#!/usr/bin/env node
// Testing-wave Findings: the index, and whether the loop is finished.
//
// A Finding is one markdown file in .scratch/testing-wave/findings/, named
// <ticket>-<number>-<slug>.md (TEMPLATE.md shows the shape). The loop is finished when
// every Finding is closed or wontfix: nothing open, no follow-up test waiting, no fix
// waiting for its retest (spec, "Findings, not fixes" and "Triage").
//
// An ssot-conflict names what it clashes with on its `decision:` line: a decision id (mp-457),
// or a spec reference, docs/ssot/spec/<path>.md#<heading text>. A spec reference must point at
// a file that exists, a heading in it with that text, and text that holds the Decision quote.
//
// CLI:
//   node findings.mjs index [<dir>] [--out <file>] [--root <repo>]
//                                                    -> prints the index and writes it (default <dir>/INDEX.md);
//                                                       exit 0 finished, 1 not finished, 2 a Finding is malformed.
//                                                       --root: where spec references resolve (default this repo)
//   node findings.mjs new <ticket> <title> --kind <kind> --run <run> [--dir <dir>]
//                                                    -> copies the template to the next free <ticket>-NNN-<slug>.md, prints its path

import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname, basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { flag } from './state.mjs';

export const KINDS = ['bug', 'ssot-conflict', 'followup-test', 'idea'];
export const STATUSES = ['open', 'triaged', 'fixing', 'closed', 'wontfix'];
const DONE = new Set(['closed', 'wontfix']);
const NAME = /^(\d{2,3})-(\d{3})-[a-z0-9-]+\.md$/;
const DECISION_ID = /^[a-z]+-\d+$/;
const SPEC_REF = /^(docs\/ssot\/spec\/[^#]+\.md)#(.+)$/;

const repo = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
export const FINDINGS_DIR = join(repo, '.scratch/testing-wave/findings');

/** Text under each `**Name.**` heading, with placeholder-only lines (`1.`, `-`, `>`) dropped. */
function sections(body) {
  const out = {};
  let key = null;
  for (const line of body.split('\n')) {
    const h = line.match(/^\*\*(.+?)\.\*\*\s*$/);
    if (h) { key = h[1].toLowerCase(); out[key] = []; continue; }
    if (key && !/^\s*(\d+\.|-|>)?\s*$/.test(line)) out[key].push(line);
  }
  return Object.fromEntries(Object.entries(out).map(([k, v]) => [k, v.join('\n').trim()]));
}

export function parseFinding(text, file) {
  const body = text.replace(/<!--[\s\S]*?-->/g, '');
  const fields = {};
  for (const m of body.matchAll(/^- (kind|status|ticket|run|screen|decision):[ \t]*(.*)$/gm)) fields[m[1]] = m[2].trim();
  const title = (body.match(/^# \S+ · (.+)$/m) ?? [])[1]?.trim() ?? '';
  const parts = sections(body);
  const name = basename(file);
  const m = name.match(NAME);
  const f = { file: name, id: m ? `${m[1]}-${m[2]}` : name.replace(/\.md$/, ''), title, ...fields, sections: parts, errors: [] };
  const err = s => f.errors.push(s);
  if (!m) err('file name must be <ticket>-<number>-<slug>.md');
  if (!KINDS.includes(f.kind)) err(`kind "${f.kind ?? ''}" is not one of ${KINDS.join(', ')}`);
  if (!STATUSES.includes(f.status)) err(`status "${f.status ?? ''}" is not one of ${STATUSES.join(', ')}`);
  if (m && f.ticket !== m[1]) err(`ticket "${f.ticket ?? ''}" does not match the file name's ${m[1]}`);
  if (!title) err('no title line (# NN-SSS · title)');
  if (!f.run) err('no run');
  if (!f.screen) err('no screen (write `none` if there is none)');
  if (f.kind === 'bug' || f.kind === 'ssot-conflict') {
    if (!parts.actual) err('no Actual');
    if (!parts.evidence) err('no Evidence');
  }
  if (f.kind === 'ssot-conflict') {
    if (!DECISION_ID.test(f.decision ?? '') && !SPEC_REF.test(f.decision ?? '')) err('an ssot-conflict needs the decision id it clashes with (mp-457) or a spec reference (docs/ssot/spec/<path>.md#<heading text>)');
    if (!parts['decision quote']) err('an ssot-conflict needs the decision quote');
  }
  return f;
}

/**
 * The paths a Finding's Evidence cites: the first word of each bullet when it looks like a
 * relative path (`runs/08/console.log`, `scripts/edge_logs.sh`), backticks allowed. Prose bullets
 * cite nothing.
 */
export function evidencePaths(evidence = '') {
  const paths = [];
  for (const line of evidence.split('\n')) {
    const m = line.match(/^\s*-\s+`?([A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.*-]+)+\/?)`?(?=[\s,;:)]|$)/);
    if (m) paths.push(m[1]);
  }
  return paths;
}

const squash = s => s.split('\n').map(l => l.replace(/^\s*>\s?/, '')).join(' ').replace(/\s+/g, ' ').trim();

/**
 * The errors of an ssot-conflict that cites a spec (`docs/ssot/spec/<path>.md#<heading text>`)
 * rather than a decision id: the file must exist under `root`, carry a markdown heading with
 * that text (whitespace and case aside), and hold the Decision quote (blockquote marks and
 * whitespace aside). A decision id, or any other kind, has none.
 */
export function specRefErrors(f, root = repo) {
  const m = f.kind === 'ssot-conflict' ? (f.decision ?? '').match(SPEC_REF) : null;
  if (!m) return [];
  const [, path, heading] = m;
  const full = join(root, path);
  if (!existsSync(full)) return [`decision ${path} does not exist`];
  const text = readFileSync(full, 'utf8');
  const norm = s => s.replace(/\s+/g, ' ').trim().toLowerCase();
  const headings = [...text.matchAll(/^#{1,6}\s+(.*?)\s*#*\s*$/gm)].map(h => norm(h[1]));
  const errors = [];
  if (!headings.includes(norm(heading))) errors.push(`decision ${path} has no heading "${heading.trim()}"`);
  const quote = squash(f.sections['decision quote'] ?? '');
  if (quote && !squash(text).includes(quote)) errors.push(`the decision quote is not in ${path}`);
  return errors;
}

/**
 * Every Finding in the folder, file-name order. TEMPLATE.md, INDEX.md and anything not named
 * NN-... are skipped. An Evidence path that exists neither beside the findings folder (`runs/...`)
 * nor in the repo is an error, so a Finding never points at a file that was not saved. A spec
 * reference in `decision:` is checked against `root` (the repo) by `specRefErrors`.
 */
export function readFindings(dir = FINDINGS_DIR, { root = repo } = {}) {
  if (!existsSync(dir)) return [];
  const wave = dirname(resolve(dir));
  const exists = p => {
    const at = base => {
      const full = join(base, p);
      return p.includes('*') ? existsSync(dirname(full)) : existsSync(full);
    };
    return at(wave) || at(repo);
  };
  return readdirSync(dir).filter(n => /^\d{2,3}-\d{3}-.*\.md$/.test(n)).sort().map(n => {
    const f = parseFinding(readFileSync(join(dir, n), 'utf8'), n);
    for (const p of evidencePaths(f.sections.evidence)) if (!exists(p)) f.errors.push(`evidence ${p} does not exist`);
    f.errors.push(...specRefErrors(f, root));
    return f;
  });
}

/** Finished when every Finding is closed or wontfix; `blocking` lists the rest. */
export function loopState(findings) {
  const blocking = findings.filter(f => !DONE.has(f.status));
  return { finished: blocking.length === 0, blocking, invalid: findings.filter(f => f.errors.length) };
}

export function renderIndex(findings) {
  const state = loopState(findings);
  const lines = ['# Testing-wave Findings', '', 'Generated by `node scripts/testing-wave/findings.mjs index`. Do not edit by hand.', ''];
  lines.push(`${findings.length} Finding${findings.length === 1 ? '' : 's'}. Loop ${state.finished ? 'finished: every Finding is closed or wontfix.' : `not finished: ${state.blocking.length} still open, waiting or fixing.`}`);
  if (state.invalid.length) lines.push('', `${state.invalid.length} malformed: ${state.invalid.map(f => f.file).join(', ')}.`);
  const kinds = [...KINDS, ...new Set(findings.map(f => f.kind).filter(k => !KINDS.includes(k)))];
  for (const kind of kinds) {
    const ofKind = findings.filter(f => f.kind === kind);
    if (!ofKind.length) continue;
    lines.push('', `## ${kind} (${ofKind.length})`);
    const statuses = [...STATUSES, ...new Set(ofKind.map(f => f.status).filter(s => !STATUSES.includes(s)))];
    for (const status of statuses) {
      const rows = ofKind.filter(f => f.status === status);
      if (!rows.length) continue;
      lines.push('', `### ${status} (${rows.length})`, '');
      for (const f of rows) {
        const extra = [f.screen && `screen: ${f.screen}`, f.decision && `decision: ${f.decision}`, f.run && `run: ${f.run}`].filter(Boolean).join('; ');
        lines.push(`- [${f.id}](${f.file}) ${f.title}${extra ? ` (${extra})` : ''}`);
      }
    }
  }
  return lines.join('\n') + '\n';
}

const slugify = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'finding';

/** Copy the template to the ticket's next free number and fill in the list lines. Returns the path. */
export function newFinding(dir, ticket, title, { kind, run, template = join(dir, 'TEMPLATE.md') } = {}) {
  if (!KINDS.includes(kind)) throw new Error(`kind "${kind}" is not one of ${KINDS.join(', ')}`);
  if (!run) throw new Error('a Finding needs its run id (--run w<wave>-<UTC time>)');
  const t = String(ticket).padStart(2, '0');
  if (!/^\d{2,3}$/.test(t)) throw new Error(`ticket "${ticket}" is not a ticket number`);
  const used = readdirSync(dir).map(n => n.match(NAME)).filter(m => m && m[1] === t).map(m => Number(m[2]));
  const seq = String((used.length ? Math.max(...used) : 0) + 1).padStart(3, '0');
  const path = join(dir, `${t}-${seq}-${slugify(title)}.md`);
  const text = readFileSync(template, 'utf8')
    .replace(/<!--[\s\S]*?-->\n*/, '')
    .replace(/^# .*$/m, `# ${t}-${seq} · ${title}`)
    .replace(/^- kind:.*$/m, `- kind: ${kind}`)
    .replace(/^- status:.*$/m, '- status: open')
    .replace(/^- ticket:.*$/m, `- ticket: ${t}`)
    .replace(/^- run:.*$/m, `- run: ${run}`);
  writeFileSync(path, text, { flag: 'wx' });
  return path;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const cmd = args.shift();
  if (cmd === 'index') {
    const out = flag(args, '--out');
    const root = flag(args, '--root');
    const dir = resolve(args[0] ?? FINDINGS_DIR);
    const findings = readFindings(dir, root ? { root: resolve(root) } : {});
    const text = renderIndex(findings);
    writeFileSync(out ? resolve(out) : join(dir, 'INDEX.md'), text);
    process.stdout.write(text);
    const state = loopState(findings);
    for (const f of state.invalid) for (const e of f.errors) process.stderr.write(`${f.file}: ${e}\n`);
    process.exit(state.invalid.length ? 2 : state.finished ? 0 : 1);
  } else if (cmd === 'new') {
    const kind = flag(args, '--kind');
    const run = flag(args, '--run');
    const dir = resolve(flag(args, '--dir') ?? FINDINGS_DIR);
    const [ticket, title] = args;
    if (!ticket || !title) { process.stderr.write('usage: findings.mjs new <ticket> <title> --kind <kind> --run <run> [--dir <dir>]\n'); process.exit(64); }
    process.stdout.write(newFinding(dir, ticket, title, { kind, run }) + '\n');
  } else {
    process.stderr.write('usage: findings.mjs index [<dir>] [--out <file>] [--root <repo>] | new <ticket> <title> --kind <kind> --run <run> [--dir <dir>]\n');
    process.exit(64);
  }
}
