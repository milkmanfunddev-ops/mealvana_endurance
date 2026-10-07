#!/usr/bin/env node
// Testing-wave Findings: the index, whether the loop is finished, the round folders, and the
// ledgers that outlive a round.
//
// A round is one folder, .scratch/testing-wave/rounds/<name>/ (issues/, findings/, runs/,
// app-build.json, TRIAGE.md). The commands that read or write one round's Findings take the round
// from --round <name>, else $TESTING_WAVE_ROUND, else the newest folder under rounds/ (newest by
// the date its name ends in, `develop-2026-10`, then by folder creation time).
// $TESTING_WAVE_ROUNDS moves the rounds folder itself (the tests use a temp one).
//
// A Finding is one markdown file in <round>/findings/, named <ticket>-<number>-<slug>.md
// (finding.template.md beside this script shows the shape). The loop is finished when every
// Finding is closed or wontfix: nothing open, no follow-up test waiting, no fix waiting for its
// retest (docs/testing-wave/SPEC.md, "Findings, not fixes" and "Triage").
//
// An ssot-conflict names what it clashes with on its `decision:` line: a decision id (mp-457),
// or a spec reference, docs/ssot/spec/<path>.md#<heading text>. A spec reference must point at
// a file that exists, a heading in it with that text, and text that holds the Decision quote.
//
// The ledgers, docs/testing-wave/BUGS.md and COVERAGE.md, hold every round's Findings: bug and
// ssot-conflict in BUGS.md, followup-test, idea and the round's retest drafts in COVERAGE.md.
// Rows live between two marker lines and are keyed by round + Finding id: re-running `ledger`
// never adds a row twice, a changed status rewrites its row where it stands, a new Finding is
// appended. Text outside the markers is never touched.
//
// CLI:
//   node findings.mjs index [<dir>] [--round <name>] [--out <file>] [--root <repo>]
//                                                    -> prints the index and writes it (default <dir>/INDEX.md;
//                                                       <dir> defaults to the round's findings/);
//                                                       exit 0 finished, 1 not finished, 2 a Finding is malformed.
//                                                       --root: where spec references resolve (default this repo)
//   node findings.mjs new <ticket> <title> --kind <kind> --run <run> [--round <name>] [--dir <dir>]
//                                                    -> copies the template to the next free <ticket>-NNN-<slug>.md, prints its path
//   node findings.mjs round new <name>              -> lays out rounds/<name>/; safe to re-run (never overwrites)
//   node findings.mjs ledger <name> [--from <dir>] [--docs <dir>]
//                                                    -> adds the round's Findings to BUGS.md and COVERAGE.md.
//                                                       --from: a folder holding findings/ (and retest-drafts/)
//                                                       instead of rounds/<name>/; the name may then come from --round.
//                                                       --docs: where the ledgers live (default docs/testing-wave)

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join, dirname, basename, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { flag } from './state.mjs';

export const KINDS = ['bug', 'ssot-conflict', 'followup-test', 'idea'];
export const STATUSES = ['open', 'triaged', 'fixing', 'closed', 'wontfix'];
const DONE = new Set(['closed', 'wontfix']);
const NAME = /^(\d{2,3})-(\d{3})-[a-z0-9-]+\.md$/;
const DECISION_ID = /^[a-z]+-\d+$/;
const SPEC_REF = /^(docs\/ssot\/spec\/[^#]+\.md)#(.+)$/;

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
export const roundsDir = () => process.env.TESTING_WAVE_ROUNDS || join(repo, '.scratch/testing-wave/rounds');
export const DOCS_DIR = join(repo, 'docs/testing-wave');
export const TEMPLATE = join(here, 'finding.template.md');

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
export function readFindings(dir = findingsDir(), { root = repo } = {}) {
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
export function newFinding(dir, ticket, title, { kind, run, template = existsSync(join(dir, 'TEMPLATE.md')) ? join(dir, 'TEMPLATE.md') : TEMPLATE } = {}) {
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

// ---------------------------------------------------------------------------------------------
// Rounds

const ROUND_NAME = /^[a-z0-9][a-z0-9._-]*$/;
const DATED = /(\d{4}-\d{2}(?:-\d{2})?)$/;

/** Every round folder under the rounds folder, oldest first (name date, then creation time). */
export function listRounds(dir = roundsDir()) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).filter(d => d.isDirectory()).map(d => {
    const full = join(dir, d.name);
    const st = statSync(full);
    return { name: d.name, dir: full, date: (d.name.match(DATED) ?? [])[1] ?? '', born: st.birthtimeMs || st.mtimeMs };
  }).sort((a, b) => a.date.localeCompare(b.date) || a.born - b.born || a.name.localeCompare(b.name));
}

/**
 * The round a command works on: the one named (flag, then $TESTING_WAVE_ROUND), else the newest.
 * A named round that does not exist, or no round at all, is an error.
 */
export function resolveRound(name = process.env.TESTING_WAVE_ROUND, { dir = roundsDir() } = {}) {
  if (name) {
    const full = join(dir, name);
    if (!ROUND_NAME.test(name) || !existsSync(full)) throw new Error(`no round "${name}" under ${dir} (make it with: findings.mjs round new ${name})`);
    return { name, dir: full };
  }
  const newest = listRounds(dir).at(-1);
  if (!newest) throw new Error(`no round under ${dir} (make one with: findings.mjs round new <name>)`);
  return { name: newest.name, dir: newest.dir };
}

/** The findings folder of a round (see resolveRound). */
export const findingsDir = (name, opts) => join(resolveRound(name, opts).dir, 'findings');

const INDEX_PLACEHOLDER = '# Testing-wave Findings\n\nGenerated by `node scripts/testing-wave/findings.mjs index`. Do not edit by hand.\n\n0 Findings. Loop finished: every Finding is closed or wontfix.\n';

/**
 * Lay out rounds/<name>/: issues/, findings/ (with the Finding template and an empty index),
 * runs/, app-build.json and TRIAGE.md. A file that is already there is left as it is, so a
 * second run on a live round changes nothing. Returns the round folder.
 */
export function newRound(name, { dir = roundsDir(), template = TEMPLATE } = {}) {
  if (!ROUND_NAME.test(name ?? '')) throw new Error(`round name "${name ?? ''}" must be lower-case letters, digits, '.', '_' or '-' (e.g. develop-2026-10)`);
  const round = join(dir, name);
  for (const sub of ['issues', 'findings', 'runs']) mkdirSync(join(round, sub), { recursive: true });
  const seed = (path, text) => { if (!existsSync(path)) writeFileSync(path, text); };
  seed(join(round, 'app-build.json'), JSON.stringify({ sha: null, built_at: null, simulator: null }, null, 2) + '\n');
  seed(join(round, 'TRIAGE.md'), `# Triage: ${name}\n\n## Wave log\n\nOne line per wave: number, base sha, tickets, start time, who led it.\n\n## Rulings\n\nOne line per Finding decision, made with Lee in the terminal: id, decision, who and when.\n`);
  seed(join(round, 'findings/INDEX.md'), INDEX_PLACEHOLDER);
  seed(join(round, 'findings/TEMPLATE.md'), readFileSync(template, 'utf8'));
  return round;
}

// ---------------------------------------------------------------------------------------------
// Ledgers

export const BUG_KINDS = ['bug', 'ssot-conflict'];
export const COVERAGE_KINDS = ['followup-test', 'idea'];
const START = '<!-- ledger:rows:start (generated by `node scripts/testing-wave/findings.mjs ledger`; rows keyed by round + id, edit above this line) -->';
const END = '<!-- ledger:rows:end -->';

const LEDGERS = {
  bugs: {
    file: 'BUGS.md',
    columns: ['id', 'round', 'ticket', 'title', 'kind', 'status', 'fix ticket'],
    preamble: `# Testing-wave bugs

Every bug and SSOT conflict the testing-wave has found, across rounds. One row per Finding; the
round column names the round folder (\`.scratch/testing-wave/rounds/<round>/findings/\`) that holds
the full Finding with its steps and evidence.

Append-only: rows are never deleted. The rows between the markers below are generated by
\`node scripts/testing-wave/findings.mjs ledger <round>\` at the end of each round's triage; a
re-run updates a row's status in place and adds new Findings at the end. Write notes above the
start marker; anything between the markers is rewritten.

Status: \`open\` (not triaged yet), \`triaged\` (a fix ticket or a decision is waiting),
\`fixed @<sha>\` (closed by a passing retest on that build, or by that commit), \`wontfix: <ruling>\`,
\`closed\` (closed without a fix, e.g. a retest that moved the problem to a new Finding).
`,
  },
  coverage: {
    file: 'COVERAGE.md',
    columns: ['id', 'round', 'ticket', 'title', 'kind', 'status'],
    preamble: `# Testing-wave coverage

Additional tests to consider, across rounds: every \`followup-test\` and \`idea\` Finding, and every
retest draft a round left behind (kind \`retest-draft\`, id \`retest-<number>\`). A round's cold-start
ticket lists the screens no ticket has covered yet; add those here by hand, above the markers.

Append-only: rows are never deleted. The rows between the markers below are generated by
\`node scripts/testing-wave/findings.mjs ledger <round>\`; a re-run updates a row's status in place
and adds new rows at the end. Write notes above the start marker; anything between the markers is
rewritten.

Status uses BUGS.md's words; on a follow-up test, \`fixed @<sha>\` means its retest passed on that
build. A retest draft's status is its ticket's \`**Status:**\` line.
`,
  },
};

const HEX_SHA = '([0-9a-f]{7,40})';

/** The first sentence of the first line that matches, without its trailing whitespace. */
const firstSentence = s => (s.match(/^.*?\.(?=\s|$)/) ?? [s])[0].trim();

/**
 * A Finding's ledger status, from its `status:` line and its Triage text:
 * closed + "fixed by <sha>", a retest "build <sha>): pass" or a "Closed by" line citing a `<sha>`
 *   -> `fixed @<sha>` (the last one named);
 * wontfix + "Won't fix (<who, date>): <why>" -> `wontfix: <who, date>: <why>`;
 * fixing -> `triaged` (a fix is waiting either way); anything else as written.
 */
export function ledgerStatus(f) {
  const triage = f.sections?.triage ?? '';
  if (f.status === 'closed') {
    // "fixed by `sha`", a retest's "build <sha>): pass", or a "Closed by ..." line citing a `sha`.
    const shas = [...triage.matchAll(new RegExp(`fixed by \`?${HEX_SHA}\\b|build ${HEX_SHA}\\):\\s*pass|^Closed\\b[^\\n]*?\`${HEX_SHA}\``, 'gim'))].map(m => m[1] ?? m[2] ?? m[3]);
    return shas.length ? `fixed @${shas.at(-1)}` : 'closed';
  }
  if (f.status === 'wontfix') {
    const line = triage.split('\n').find(l => /won.t fix/i.test(l));
    const m = line?.match(/won.t fix\s*\(([^)]*)\)\s*:?\s*(.*)$/i);
    if (m) return `wontfix: ${m[1].trim()}: ${firstSentence(m[2])}`.replace(/:\s*$/, '');
    const any = triage.split('\n').map(l => l.trim()).find(Boolean);
    return any ? `wontfix: ${firstSentence(any)}` : 'wontfix';
  }
  if (f.status === 'fixing') return 'triaged';
  return f.status ?? 'open';
}

/** The fix tickets a Finding's Triage names ("Fix ticket 33"), in order, once each. */
export const fixTickets = f => [...new Set([...(f.sections?.triage ?? '').matchAll(/\bfix ticket (\d+)/gi)].map(m => m[1]))].join(', ');

const cell = v => String(v ?? '').replace(/\s+/g, ' ').trim().replace(/\|/g, '\\|');
const rowLine = cells => `| ${cells.map(cell).join(' | ')} |`;
// The key of a generated row: its id and round cells (the first two), pipes inside them escaped.
const rowKey = line => { const c = line.split(/(?<!\\)\|/).map(x => x.trim()); return `${c[2]}\u0000${c[1]}`; };

/** A round's retest drafts: `<number>-<slug>.md` with a `# <number>: <title>` line and a `**Status:**` line. */
export function readRetestDrafts(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(n => /^\d+-.*\.md$/.test(n)).sort().map(n => {
    const text = readFileSync(join(dir, n), 'utf8');
    const number = n.match(/^(\d+)/)[1];
    const title = (text.match(/^# \d+:\s*(.+)$/m) ?? [])[1] ?? n.replace(/^\d+-|\.md$/g, '');
    const status = (text.match(/^\*\*Status:\*\*\s*(.+)$/m) ?? [])[1] ?? '';
    return { id: `retest-${number}`, ticket: number, title, kind: 'retest-draft', status: status.trim() };
  });
}

/**
 * Merge rows into one ledger file: rows whose (round, id) is already there are rewritten where
 * they stand, new ones go at the end. Text outside the markers is kept; a missing file starts
 * from the preamble. Returns the counts.
 */
export function mergeLedger(path, { columns, preamble }, rows) {
  const header = [rowLine(columns), `|${columns.map(() => '---').join('|')}|`];
  const text = existsSync(path) ? readFileSync(path, 'utf8') : `${preamble}\n${START}\n${END}\n`;
  const s = text.indexOf(START);
  const e = text.indexOf(END);
  if (s < 0 || e < s) throw new Error(`${path} has no ledger markers; add ${START} and ${END} around the rows`);
  const existing = text.slice(s + START.length, e).split('\n').filter(l => l.startsWith('| ') && !header.includes(l));
  const at = new Map(existing.map((l, i) => [rowKey(l), i]));
  const counts = { added: 0, updated: 0, unchanged: 0 };
  for (const cells of rows) {
    const line = rowLine(cells);
    const key = rowKey(line);
    if (!at.has(key)) { at.set(key, existing.length); existing.push(line); counts.added++; }
    else if (existing[at.get(key)] !== line) { existing[at.get(key)] = line; counts.updated++; }
    else counts.unchanged++;
  }
  const body = [START, ...header, ...existing, END].join('\n');
  writeFileSync(path, text.slice(0, s) + body + text.slice(e + END.length));
  return { ...counts, rows: existing.length };
}

/**
 * Add one round's Findings to the ledgers. `from` is a folder holding findings/ and, if the round
 * left any, retest-drafts/. Malformed Findings still get a row (their fields as written); a kind
 * outside both ledgers is skipped and reported.
 */
export function writeLedgers(round, from, { docs = DOCS_DIR } = {}) {
  const dir = join(from, 'findings');
  if (!existsSync(dir)) throw new Error(`${from} has no findings/ folder`);
  const findings = readdirSync(dir).filter(n => /^\d{2,3}-\d{3}-.*\.md$/.test(n)).sort()
    .map(n => parseFinding(readFileSync(join(dir, n), 'utf8'), n));
  const skipped = findings.filter(f => !BUG_KINDS.includes(f.kind) && !COVERAGE_KINDS.includes(f.kind));
  const bugRows = findings.filter(f => BUG_KINDS.includes(f.kind))
    .map(f => [f.id, round, f.ticket, f.title, f.kind, ledgerStatus(f), fixTickets(f)]);
  const coverageRows = [
    ...findings.filter(f => COVERAGE_KINDS.includes(f.kind)).map(f => [f.id, round, f.ticket, f.title, f.kind, ledgerStatus(f)]),
    ...readRetestDrafts(join(from, 'retest-drafts')).map(d => [d.id, round, d.ticket, d.title, d.kind, d.status]),
  ];
  mkdirSync(docs, { recursive: true });
  const kinds = {};
  for (const row of [...bugRows, ...coverageRows]) kinds[row[4]] = (kinds[row[4]] ?? 0) + 1;
  return {
    bugs: mergeLedger(join(docs, LEDGERS.bugs.file), LEDGERS.bugs, bugRows),
    coverage: mergeLedger(join(docs, LEDGERS.coverage.file), LEDGERS.coverage, coverageRows),
    kinds,
    skipped: skipped.map(f => f.file),
  };
}

const USAGE = 'usage: findings.mjs index [<dir>] [--round <name>] [--out <file>] [--root <repo>]\n' +
  '     | new <ticket> <title> --kind <kind> --run <run> [--round <name>] [--dir <dir>]\n' +
  '     | round new <name>\n' +
  '     | ledger <name> [--from <dir>] [--docs <dir>]   (or ledger --from <dir> --round <name>)\n';

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const cmd = args.shift();
  const fail = (msg, code = 2) => { process.stderr.write(`${msg}\n`); process.exit(code); };
  // The round folder a command reads, or exit 2 naming the round that is missing.
  const roundFindings = name => { try { return findingsDir(name); } catch (e) { return fail(e.message); } };
  if (cmd === 'index') {
    const out = flag(args, '--out');
    const root = flag(args, '--root');
    const round = flag(args, '--round');
    const dir = resolve(args[0] ?? roundFindings(round));
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
    const round = flag(args, '--round');
    const dirFlag = flag(args, '--dir');
    const [ticket, title] = args;
    if (!ticket || !title) fail(USAGE, 64);
    const dir = resolve(dirFlag ?? roundFindings(round));
    process.stdout.write(newFinding(dir, ticket, title, { kind, run }) + '\n');
  } else if (cmd === 'round' && args[0] === 'new') {
    try { process.stdout.write(newRound(args[1]) + '\n'); } catch (e) { fail(e.message, 64); }
  } else if (cmd === 'ledger') {
    const from = flag(args, '--from');
    const docs = flag(args, '--docs');
    const round = flag(args, '--round') ?? args[0];
    if (!round) fail(USAGE, 64);
    let source = from && resolve(from);
    if (!source) { try { source = resolveRound(round).dir; } catch (e) { fail(e.message); } }
    let r;
    try { r = writeLedgers(round, source, docs ? { docs: resolve(docs) } : {}); } catch (e) { fail(e.message); }
    const line = (file, c) => `${file}: ${c.added} added, ${c.updated} updated, ${c.unchanged} unchanged, ${c.rows} rows in all\n`;
    process.stdout.write(line('BUGS.md', r.bugs) + line('COVERAGE.md', r.coverage));
    process.stdout.write(`round ${round}: ${Object.entries(r.kinds).map(([k, n]) => `${k} ${n}`).join(', ') || 'nothing'}\n`);
    for (const f of r.skipped) process.stderr.write(`${f}: kind is in neither ledger; skipped\n`);
  } else {
    fail(USAGE, 64);
  }
}
