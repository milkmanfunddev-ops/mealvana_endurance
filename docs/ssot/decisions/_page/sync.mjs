#!/usr/bin/env node
// Decision record sync: markdown <-> page documents, and verdicts -> markdown.
//
// A decisions file (proposals in .scratch/<feature>/decisions.md, truth in
// docs/ssot/decisions/<feature>.md) is a header block followed by one `##`
// section per decision. This module parses it, serialises it back
// byte-identically, and applies verdicts from the page.
//
// CLI:
//   node sync.mjs export <decisions.md> [more.md...]   -> JSON docs on stdout
//   node sync.mjs apply <verdicts.json> <proposals.md> <ssot.md>
//   node sync.mjs pending <decisions.md> [<category>]   -> count of proposed/amended; with a category, {category, count, ids}
//   node sync.mjs ticket-plan <feature> <proposals.md> [<ssot.md>]   -> the ticket cards with their blocking edges (declared + touches overlap)
//   node sync.mjs publish-tickets <feature> <proposals.md> <ssot.md> <issues dir> --next <cmd>   -> writes one file per approved ticket card; refuses while one is pending, blocked by a later ticket, or built on a rejected id
//   node sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>
//   node sync.mjs questions <proposals.md> [<ssot.md>]      -> the open questions as JSON, file order
//   node sync.mjs linked <proposals.md> [<ssot.md>]         -> decisions that answered a question, as JSON
//   node sync.mjs cite <spec.md> <proposals.md> [<ssot.md>]  -> what the spec's decision sections cite, as JSON
//   node sync.mjs triage <verdicts.json> --out <dir>   -> clear.json (apply now), words.json (synthesise first), rewrites.json (apply after yes)
//   node sync.mjs next-id <proposals.md> <ssot.md>     -> the next free id
//   node sync.mjs images <assets.json> <_images.json>  -> images to upload (new, changed, missing), plus unreferenced assets with the id to delete
//   node sync.mjs asset <assets.json> <path> <asset id> -> record one upload with the file's hash; prints the id it replaced
//   node sync.mjs asset <assets.json> <path> --drop     -> forget a path; prints the id to delete
//   node sync.mjs undrawn <proposals.md> [<ssot.md>]   -> screenless cards with no drawn picture yet
//   node sync.mjs draw <spec.json> [<out.svg>]         -> draw a diagram from a spec (diagram.mjs), checked
//   node sync.mjs attach-svg <decisions.md> <id> <svg path>  -> check the file and set the card's `svg:` line
//   node sync.mjs uncaptured <proposals.md> [<ssot.md>]  -> cards that name a screen and have no picture, with what would picture them
//   node sync.mjs capture --check                      -> what stands between this machine and a capture
//   node sync.mjs capture <feature> <screen>           -> drive the booted simulator to the screen, save the png and its sidecar
//   node sync.mjs attach-image <decisions.md> <id> <png path> [--caption <text>]  -> set the card's image line, record where it came from
//   node sync.mjs pictures <feature> <proposals.md> <ssot.md>  -> uncaptured -> reuse or capture -> attach, for every card at once
//   node sync.mjs stale <proposals.md> [<ssot.md>] [--screens <screens.json>]  -> every picture in use with its age and whether its screen's code moved on
//   node sync.mjs refresh <feature> <proposals.md> <ssot.md> [--screens <screens.json>] [--only <key,key>]  -> retake every stale picture once, in place; cards on a golden move to the capture; --only retakes those screens whether stale or not
//   node sync.mjs wave <feature> <issues dir> [--branch <b>]  -> the frontier: done, building, blocked, uncommitted ticket files, and branch + worktree + renderings per wave ticket
//   node sync.mjs wave <feature> <issues dir> --open           -> the same, then commits the ticket files with their in-progress marks and logs the wave (base = that commit)
//   node sync.mjs wave <feature> <issues dir> --close <n> [--merged NN,NN] [--failed NN,NN] [--suite green|red]  -> close the wave with elapsed time; merged tickets become done, every other wave ticket ready-for-agent again
//   node sync.mjs touched-screens --since <commit> [<file>...]  -> registry screens drawn from the files changed since the commit (committed, uncommitted, untracked)
//   node sync.mjs simulator add <name> [--from <udid|name>] | drop <name|udid> | list [<prefix>]  -> a simulator per agent, copied from the dev one (app + data); every capture command takes --udid or SSOT_SIMULATOR

import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { join, isAbsolute, basename, dirname, resolve } from 'node:path';
import { draw, TOKENS } from './diagram.mjs';
import { loadScreens, matchScreen, capture, simulatorIo, bootedUdid, stamp, doctor, createSimulator, deleteSimulator, listSimulators } from './capture.mjs';

const HEAD_KEYS = ['feature', 'feature name', 'last extracted', 'artifact'];
const PARTS = [
  ['context', 'Context'],
  ['question', 'Question'],
  ['decision', 'Decision'],
  ['why', 'Why'],
  ['alternatives', 'What else was considered'],
  ['touches', 'What it touches'],
  ['details', 'Details'],
];
const AMEND_PARTS = [
  ['original', 'Original'],
  ['leeSaid', 'Lee said'],
];

export function parse(text) {
  const lines = text.split('\n');
  const doc = { title: '', head: {}, decisions: [], preamble: [] };
  let i = 0;
  // title
  while (i < lines.length && !lines[i].startsWith('# ')) i++;
  if (i < lines.length) { doc.title = lines[i].slice(2).trim(); i++; }
  // head block: `Key: value` lines until first `## `
  while (i < lines.length && !lines[i].startsWith('## ')) {
    const m = lines[i].match(/^([A-Za-z ]+):\s*(.*)$/);
    if (m && HEAD_KEYS.includes(m[1].toLowerCase())) doc.head[m[1].toLowerCase()] = m[2].trim();
    else doc.preamble.push(lines[i]);
    i++;
  }
  // sections
  while (i < lines.length) {
    if (!lines[i].startsWith('## ')) { i++; continue; }
    const hm = lines[i].match(/^## ([a-z0-9]+-\d{3})\s+·\s+(.*)$/);
    if (!hm) throw new Error(`Bad decision heading at line ${i + 1}: ${lines[i]}`);
    const d = { id: hm[1], title: hm[2].trim(), meta: {}, parts: {}, history: [] };
    i++;
    // meta bullets
    while (i < lines.length && lines[i].startsWith('- ')) {
      const m = lines[i].match(/^- ([a-z]+):\s*(.*)$/);
      if (m) d.meta[m[1]] = m[2].trim();
      i++;
    }
    // body until next `## `
    const body = [];
    while (i < lines.length && !lines[i].startsWith('## ')) { body.push(lines[i]); i++; }
    let current = null;
    for (const raw of body) {
      const pm = raw.match(/^\*\*([^*]+)\.\*\*\s?(.*)$/);
      if (pm) {
        const key = [...PARTS, ...AMEND_PARTS].find(([, label]) => label === pm[1])?.[0] || pm[1].toLowerCase();
        current = key; d.parts[key] = pm[2];
        continue;
      }
      const hist = raw.match(/^> (\d{4}-\d{2}-\d{2}) (.*)$/);
      if (hist) { d.history.push({ date: hist[1], note: hist[2] }); current = null; continue; }
      if (current && raw.trim() !== '') d.parts[current] += '\n' + raw;
      else if (current && raw.trim() === '' && d.parts[current] && !d.parts[current].endsWith('\n')) d.parts[current] += '\n';
    }
    for (const k of Object.keys(d.parts)) d.parts[k] = d.parts[k].replace(/\n+$/, '');
    doc.decisions.push(d);
  }
  return doc;
}

export function serialize(doc) {
  const out = [`# ${doc.title}`, ''];
  for (const k of HEAD_KEYS) if (doc.head[k] !== undefined) out.push(`${cap(k)}: ${doc.head[k]}`);
  if (Object.keys(doc.head).length) out.push('');
  for (const d of doc.decisions) {
    out.push(`## ${d.id} · ${d.title}`);
    for (const [k, v] of Object.entries(d.meta)) out.push(v === '' ? `- ${k}:` : `- ${k}: ${v}`);
    out.push('');
    for (const [key, label] of [...AMEND_PARTS, ...PARTS]) {
      if (d.parts[key] === undefined) continue;
      out.push(`**${label}.** ${d.parts[key]}`);
      out.push('');
    }
    for (const h of d.history) out.push(`> ${h.date} ${h.note}`);
    if (d.history.length) out.push('');
  }
  return out.join('\n').replace(/\n+$/, '') + '\n';
}
const cap = s => s.charAt(0).toUpperCase() + s.slice(1);

/** Page documents for the `decisions` collection, keyed by id. */
export function toDocuments(doc, { order = 0, readSvg = () => '', readCaptured = () => null } = {}) {
  // readSvg(path) returns the drawn picture's markup for the page, or '' to leave the box empty.
  // readCaptured(image path) returns the capture's sidecar ({commit, appVersion, capturedAt, ...}) or null.
  const feature = doc.head.feature;
  return doc.decisions.map((d, n) => ({
    id: d.id,
    feature,
    category: d.meta.category || 'Other',
    title: d.title,
    kind: kindOf(d),
    status: d.meta.status || 'proposed',
    linked: d.meta.linked || '',
    source: d.meta.source || '',
    screen: d.meta.screen || '',
    detail: d.meta.detail === 'yes',
    work: d.meta.work || '',
    ticket: d.meta.ticket || '',
    blocked: d.meta.blocked || '',
    depends: d.meta.depends || '',
    image: d.meta.image && d.meta.image !== 'none' ? d.meta.image : '',
    imageCaption: d.meta.caption || '',
    captured: d.meta.image && d.meta.image !== 'none' ? readCaptured(d.meta.image) : null,
    svgPath: d.meta.svg || '',
    svg: d.meta.svg ? readSvg(d.meta.svg) : '',
    context: d.parts.context || '',
    question: d.parts.question || '',
    decision: ticketDecision(d),
    clauses: clauses(d.parts.decision || ''),
    why: d.parts.why || '',
    alternatives: d.parts.alternatives || '',
    touches: d.parts.touches || '',
    details: d.parts.details || '',
    original: d.parts.original || '',
    leeSaid: d.parts.leeSaid || '',
    ruled: ruling(d.history),
    order: order + n,
  }));
}

/** A ticket card's Decision on the page ends with its blockers, so the ratifier approves the edges, not only the prose. */
const ticketDecision = d => {
  const decision = d.parts.decision || '';
  if (d.meta.ticket === undefined || d.meta.ticket === '') return decision;
  const blocked = splitList(d.meta.blocked).map(num2);
  return `${decision}\n\nBlocked by: ${blocked.length ? blocked.join(', ') : 'nothing, it can start at once'}.`;
};

/**
 * Who ruled last, and when. Reads the newest history line that is a verdict
 * (`approved`, `rejected`, `withdrawn`, `amended`, `approved again`, and the
 * `added`/`edited`/`removed` lines a change card writes) and returns
 * `{status, by, date}`; `by` is the name after the last " by " ahead of any
 * reason (`: …`), or '' when the line names nobody. Fold and answered lines are
 * history, not rulings, so a card with only those has none.
 */
export function ruling(history) {
  for (let i = history.length - 1; i >= 0; i--) {
    const m = /^(approved again|approved|rejected|withdrawn|amended|added|edited|removed)\b([^:]*)(?::.*)?$/.exec(history[i].note);
    if (!m) continue;
    const by = /(?:^| )by (.+)$/.exec(m[2].trim());
    return { status: m[1] === 'approved again' ? 'approved' : m[1], by: by ? by[1].trim() : '', date: history[i].date };
  }
  return null;
}

/** A Decision written as numbered lines is a list of clauses Lee can keep or drop one by one. */
export function clauses(decision) {
  const lines = decision.split('\n').map(s => s.trim()).filter(Boolean);
  if (lines.length < 2 || !lines.every(l => /^\d+\.\s/.test(l))) return [];
  return lines.map(l => l.replace(/^\d+\.\s+/, ''));
}

/**
 * Move the closing "The question was X." sentence of every Context into its
 * own Question part, as a question. Idempotent: a section that already has a
 * Question part, or whose Context does not end that way, is left alone.
 */
export function questionFirst(doc) {
  let moved = 0;
  for (const d of doc.decisions) {
    if (d.parts.question || !d.parts.context) continue;
    const m = d.parts.context.match(/^([\s\S]*?)\s*The question (?:was|is) ([^.]+)\.\s*$/);
    if (!m) continue;
    const q = m[2].trim();
    d.parts.question = q.charAt(0).toUpperCase() + q.slice(1) + '.';
    d.parts.context = m[1].trim();
    moved++;
  }
  return moved;
}

/**
 * Fold several proposals into one. `plan` is a list of
 * {from: [ids], into: {id?, title, category, screen?, source?, detail?, work?, question, context, decision, why, alternatives, touches, details?}}.
 * The folded sections leave the proposals file; the new section carries a history line naming them.
 * A `from` id that is not a proposal (already ruled on) is refused and the fold is skipped.
 */
export function fold(plan, proposals, ssot, today = new Date().toISOString().slice(0, 10)) {
  const folded = [], refused = [];
  for (const step of plan) {
    const missing = step.from.filter(id => !proposals.decisions.some(d => d.id === id));
    if (missing.length) { refused.push({ into: step.into.title, why: `not a proposal: ${missing.join(', ')}` }); continue; }
    const members = step.from.map(id => proposals.decisions.find(d => d.id === id));
    const held = members.filter(d => !['proposed', 'amended'].includes(d.meta.status));
    if (held.length) { refused.push({ into: step.into.title, why: `not foldable: ${held.map(d => d.id + ' is ' + d.meta.status).join(', ')}` }); continue; }
    const into = step.into;
    const id = into.id || nextId(proposals, ssot); // before the splice, so a folded number is never reused
    for (const m of step.from) proposals.decisions.splice(proposals.decisions.findIndex(d => d.id === m), 1);
    const sources = [...new Set(members.flatMap(d => (d.meta.source || '').split(';').map(s => s.trim()).filter(Boolean)))];
    const meta = {
      category: into.category || members[0].meta.category,
      status: 'proposed',
      image: into.image || members.find(d => d.meta.image && d.meta.image !== 'none')?.meta.image || 'none',
      caption: into.caption || members.find(d => d.meta.image && d.meta.image !== 'none')?.meta.caption || '',
      screen: into.screen || members[0].meta.screen || '',
      source: into.source || sources.join('; '),
    };
    if (into.detail) meta.detail = 'yes';
    if (into.work) meta.work = into.work;
    const parts = { question: into.question || '', context: into.context || '', decision: into.decision || '', why: into.why || '', alternatives: into.alternatives || 'none recorded', touches: into.touches || '' };
    if (into.details) parts.details = into.details;
    for (const k of Object.keys(parts)) if (parts[k] === '' && k !== 'context') delete parts[k];
    proposals.decisions.push({ id, title: into.title, meta, parts, history: [{ date: today, note: `folded from ${step.from.join(', ')}` }] });
    folded.push({ id, from: step.from });
  }
  return { folded, refused };
}

/**
 * Tickets for the `tickets` collection: one document per `.scratch/<feature>/issues/NN-*.md`.
 * Status, blockers and next come from the three header lines every ticket carries.
 * `cites` is every decision id mentioned anywhere in the ticket.
 */
export function ticketDocument(feature, file, text, idPrefix = '') {
  const name = file.split('/').pop().replace(/\.md$/, '');
  const num = (name.match(/^(\d+)/) || [])[1] || '';
  const title = (text.match(/^# (.+)$/m) || [, name])[1].replace(/^\d+:\s*/, '').trim();
  const line = k => { const m = text.match(new RegExp(`^\\*\\*${k}:\\*\\*\\s*(.*)$`, 'mi')); return m ? m[1].trim() : ''; };
  const [statusLine, blockedLine, nextLine] = TICKET_HEADERS.map(line);
  const s = statusLine.toLowerCase();
  const state = /wontfix/.test(s) ? 'dropped' : /^(done|built|verified|typed-postcode|send,|partly verified)/.test(s) ? 'done' : /needs-grilling|needs grilling/.test(s) ? 'needs grilling' : /^(in-progress|building)/.test(s) ? 'building' : /ready/.test(s) ? 'ready' : /after|blocked/.test(s) ? 'waiting' : s ? 'other' : 'proposed';
  const owed = /owed|not yet (seen|looked)|awaiting a look|untested|unverified|not exercised|fails/.test(s);
  const cites = [...new Set((text.match(new RegExp(`\\b${idPrefix || '[a-z]+'}-\\d{3}\\b`, 'g')) || []))].sort();
  return { id: `${feature}-${num}`, feature, number: num, title, status: statusLine, state, owed, blockedBy: blockedLine, next: nextLine, cites, file, order: parseInt(num, 10) || 0 };
}

/** The ticket files of a feature (`NN-<slug>.md`), sorted, as `<dir>/<file>` paths; an absent dir is empty. */
export const ticketFiles = (root, dir) => existsSync(under(root, dir)) ? readdirSync(under(root, dir)).filter(x => /^\d+-.*\.md$/.test(x)).sort().map(f => `${dir}/${f}`) : [];

export function nextId(proposals, ssot) {
  const ids = [...proposals.decisions, ...ssot.decisions].map(d => d.id);
  const prefix = (ids[0] || 'x-000').split('-')[0];
  const max = ids.reduce((m, id) => Math.max(m, parseInt(id.split('-')[1], 10) || 0), 0);
  return `${prefix}-${String(max + 1).padStart(3, '0')}`;
}

/**
 * Apply verdicts. `verdicts` is {id: {verdict, text, at, by?}}. Returns
 * {proposals, ssot, applied: [...], refused: [...]} with the two docs mutated.
 * approve: proposals -> ssot (status approved) ; on an approved id -> withdrawn
 *          (pressing Approve again takes the approval back) ; on a withdrawn id -> approved again
 * withdraw: approved -> withdrawn (in ssot)
 * reject: proposals -> ssot as rejected with reason
 * amend: stays in proposals as amended, carrying original + Lee's words; the
 *        rewrite is the skill's job (it replaces `decision` and sets proposed).
 * `by` names who gave the verdict; the history line ends "by <name>" so the
 * record can tell Lee's ruling from Xuan's. A verdict without `by` still applies.
 */
export function apply(verdicts, proposals, ssot, today = new Date().toISOString().slice(0, 10)) {
  const applied = [], refused = [];
  const take = (id) => {
    const i = proposals.decisions.findIndex(d => d.id === id);
    return i < 0 ? null : proposals.decisions.splice(i, 1)[0];
  };
  const inSsot = (id) => ssot.decisions.find(d => d.id === id);
  const withdraw = (d, date, by) => { d.meta.status = 'withdrawn'; d.history.push({ date, note: 'withdrawn' + by }); applied.push({ id: d.id, to: 'withdrawn' }); };
  for (const [id, v] of Object.entries(verdicts)) {
    const date = (v.at || '').slice(0, 10) || today;
    const who = String(v.by ?? '').replace(/\s+/g, ' ').trim();
    const by = who ? ` by ${who}` : '';
    const existing = inSsot(id);
    if (v.verdict === 'approve') {
      if (existing && existing.meta.status === 'approved') { withdraw(existing, date, by); continue; }
      if (existing) { existing.meta.status = 'approved'; existing.history.push({ date, note: 'approved again' + by }); applied.push({ id, to: 'approved' }); continue; }
      const d = take(id); if (!d) { refused.push({ id, why: 'unknown id' }); continue; }
      d.meta.status = 'approved';
      delete d.parts.original; delete d.parts.leeSaid;
      d.history.push({ date, note: 'approved' + by });
      ssot.decisions.push(d); applied.push({ id, to: 'approved' });
    } else if (v.verdict === 'withdraw') {
      if (!existing || existing.meta.status !== 'approved') { refused.push({ id, why: 'not approved' }); continue; }
      withdraw(existing, date, by);
    } else if (v.verdict === 'reject') {
      const d = take(id) || (existing && existing.meta.status !== 'rejected' ? existing : null);
      if (!d) { refused.push({ id, why: 'unknown id' }); continue; }
      d.meta.status = 'rejected';
      d.history.push({ date, note: 'rejected' + by + (v.text ? `: ${v.text}` : '') });
      if (!existing) ssot.decisions.push(d);
      applied.push({ id, to: 'rejected' });
    } else if (v.verdict === 'change') {
      // A change drafted from a category discussion and accepted by Lee on the page.
      if (!v.accepted) { refused.push({ id, why: 'change not accepted' }); continue; }
      const c = v.change || {};
      const note = 'from the category discussion on ' + date;
      if (c.op === 'add') {
        const nid = nextId(proposals, ssot);
        proposals.decisions.push({ id: nid, title: c.title || 'Untitled', meta: { category: v.category || 'Other', status: 'proposed', image: 'none', caption: '', screen: c.screen || '', source: `${v.by ? v.by + ', ' : ''}${note}` }, parts: { context: c.context || '', decision: c.decision || '', why: c.why || '', alternatives: c.alternatives || 'none recorded', touches: c.touches || '' }, history: [{ date, note: 'added ' + note + by }] });
        applied.push({ id, to: 'added as ' + nid });
      } else if (c.op === 'edit') {
        const d = proposals.decisions.find(x => x.id === c.id) || inSsot(c.id);
        if (!d) { refused.push({ id, why: `unknown id ${c.id}` }); continue; }
        d.meta.status = 'amended';
        if (!d.parts.original) d.parts.original = d.parts.decision;
        d.parts.leeSaid = `Edit accepted ${note}: ${c.title || ''}`;
        if (c.title) d.title = c.title;
        if (c.context) d.parts.context = c.context;
        if (c.decision) d.parts.decision = c.decision;
        if (c.why) d.parts.why = c.why;
        d.history.push({ date, note: 'edited ' + note + by });
        applied.push({ id, to: 'amended ' + c.id });
      } else if (c.op === 'delete') {
        const d = take(c.id) || (inSsot(c.id) && inSsot(c.id).meta.status !== 'rejected' ? inSsot(c.id) : null);
        if (!d) { refused.push({ id, why: `unknown id ${c.id}` }); continue; }
        d.meta.status = 'rejected';
        d.history.push({ date, note: 'removed ' + note + by + (c.reason ? `: ${c.reason}` : '') });
        if (!inSsot(c.id)) ssot.decisions.push(d);
        applied.push({ id, to: 'rejected ' + c.id });
      } else refused.push({ id, why: `unknown change op ${c.op}` });
    } else if (v.verdict === 'amend') {
      const d = proposals.decisions.find(x => x.id === id) || existing;
      if (!d) { refused.push({ id, why: 'unknown id' }); continue; }
      d.meta.status = 'amended';
      if (!d.parts.original) d.parts.original = d.parts.decision;
      // A rewrite from a clause list says which clauses Lee dropped, then his words.
      const dropped = Array.isArray(v.dropped) && v.dropped.length ? `Dropped clause${v.dropped.length > 1 ? 's' : ''} ${v.dropped.join(', ')}. ` : '';
      d.parts.leeSaid = (dropped + (v.text || '')).trim();
      d.history.push({ date, note: 'amended' + by });
      applied.push({ id, to: 'amended' });
    } else refused.push({ id, why: `unknown verdict ${v.verdict}` });
  }
  ssot.decisions.sort((a, b) => a.id.localeCompare(b.id));
  return { proposals, ssot, applied, refused };
}

/**
 * Close an open question with the decision that answers it. The question
 * (`kind: question`, `status: open`, in either file) gets `status: answered`
 * and a history line naming the decision; the decision (in either file) gets
 * `linked:` pointing back, appended after any link it already carries.
 * A question that is not open, or an id that is not found, is refused and nothing changes.
 */
export function answers(questionId, decisionId, proposals, ssot, today = new Date().toISOString().slice(0, 10)) {
  const find = id => proposals.decisions.find(d => d.id === id) || ssot.decisions.find(d => d.id === id);
  const q = find(questionId), d = find(decisionId);
  if (!q) return { applied: [], refused: [{ id: questionId, why: `unknown question ${questionId}` }] };
  if (!d) return { applied: [], refused: [{ id: questionId, why: `unknown decision ${decisionId}` }] };
  if (q.meta.kind !== 'question' || q.meta.status !== 'open') return { applied: [], refused: [{ id: questionId, why: 'not an open question' }] };
  q.meta.status = 'answered';
  q.history.push({ date: today, note: `answered by ${decisionId}` });
  const links = splitLinks(d.meta.linked);
  if (!links.includes(questionId)) links.push(questionId);
  d.meta.linked = links.join('; ');
  return { applied: [{ question: questionId, decision: decisionId }], refused: [] };
}

/**
 * The open questions, proposals first then the record, each in file order.
 * A grill walks these one at a time; everything the question carries is here
 * so the skill never re-reads the files to ask it.
 */
export function openQuestions(proposals, ssot = { decisions: [] }) {
  const keep = ['id', 'title', 'category', 'linked', 'screen', 'source', 'context', 'question', 'why', 'touches'];
  return [...toDocuments({ head: {}, decisions: proposals.decisions }), ...toDocuments({ head: {}, decisions: ssot.decisions })]
    .filter(d => d.kind === 'question' && d.status === 'open')
    .map(d => Object.fromEntries(keep.map(k => [k, d[k]])));
}

const GONE = ['rejected', 'withdrawn'];
const PENDING = ['proposed', 'amended'];
const splitLinks = linked => String(linked || '').split(';').map(s => s.trim()).filter(Boolean);

/**
 * Decisions that answered a question (`linked:` names a question whose status is
 * `answered`), proposals first then the record, each in file order. `/to-spec-lee`
 * states these in the spec before anything else. `stale` marks a decision that was
 * rejected or withdrawn after it answered: the question then points at a ruling that
 * no longer stands, and the ratifier decides whether to reopen it.
 */
export function answeredLinks(proposals, ssot = { decisions: [] }) {
  const all = [...toDocuments({ head: {}, decisions: proposals.decisions }), ...toDocuments({ head: {}, decisions: ssot.decisions })];
  const byId = new Map(all.map(d => [d.id, d]));
  const out = [];
  for (const d of all) {
    if (d.kind === 'question') continue;
    for (const qid of splitLinks(d.linked)) {
      const q = byId.get(qid);
      if (!q || q.kind !== 'question' || q.status !== 'answered') continue;
      out.push({ id: d.id, title: d.title, category: d.category, status: d.status, stale: GONE.includes(d.status), question: q.id, questionTitle: q.title });
    }
  }
  return out;
}

/**
 * What the spec's Implementation Decisions and Testing Decisions sections cite.
 * Each paragraph (blank-line separated; a list item is its own paragraph) carries the
 * ids it names, matched on the id prefix the two files use (`mp` in `mp-042`). `rejected` are
 * paragraphs naming any id that was rejected or withdrawn (`gone` says which ids; the
 * paragraph or the clause goes), `uncited` name no id (backfill candidates), `unknown`
 * are ids in neither file, `pending` are cited ids still proposed or amended, and
 * `pendingSpec` the subset in the Spec category (the `/to-tickets-lee` gate).
 * `unstated` are decisions that answered a question but appear nowhere in the spec.
 * Nothing is written.
 */
export function specCitations(spec, proposals, ssot = { decisions: [] }) {
  const all = [...proposals.decisions, ...ssot.decisions];
  const known = new Map(all.map(d => [d.id, d.meta.status || 'proposed']));
  const category = new Map(all.map(d => [d.id, d.meta.category || 'Other']));
  const first = all.find(d => d.id);
  const prefix = first ? first.id.slice(0, first.id.lastIndexOf('-')) : '[a-z][a-z0-9]*';
  const idRe = new RegExp(`\\b(${prefix}-\\d{3})\\b`, 'g');
  const sections = ['Implementation Decisions', 'Testing Decisions'];
  const paragraphs = [];
  let section = '', buf = [];
  const flush = () => {
    const text = buf.join('\n').trim();
    buf = [];
    if (!section || !text) return;
    paragraphs.push({ section, text, ids: [...new Set([...text.matchAll(idRe)].map(m => m[1]))] });
  };
  for (const line of spec.split('\n')) {
    const h = line.match(/^## (.*)$/);
    if (h) { flush(); section = sections.includes(h[1].trim()) ? h[1].trim() : ''; continue; }
    if (!section) continue;
    const startsParagraph = line.trim() === '' || /^\s*([-*]|\d+\.)\s/.test(line);
    if (startsParagraph) flush();
    if (line.trim() !== '') buf.push(line);
  }
  flush();
  const statuses = {};
  for (const p of paragraphs) for (const id of p.ids) statuses[id] = known.get(id) || 'unknown';
  const gone = id => GONE.includes(statuses[id]);
  const cited = new Set(Object.keys(statuses));
  const pending = Object.keys(statuses).filter(id => PENDING.includes(statuses[id]));
  return {
    paragraphs,
    statuses,
    rejected: paragraphs.filter(p => p.ids.some(gone)).map(p => ({ ...p, gone: p.ids.filter(gone) })),
    uncited: paragraphs.filter(p => !p.ids.length),
    unknown: Object.keys(statuses).filter(id => statuses[id] === 'unknown'),
    pending,
    pendingSpec: pending.filter(id => category.get(id) === 'Spec'),
    unstated: answeredLinks(proposals, ssot).filter(l => !l.stale && !cited.has(l.id)).map(l => l.id),
  };
}


/** The proposed and amended cards of one category: `{category, count, ids}`. The `/to-tickets-lee` gate reads `Spec`. */
export function pendingIn(doc, category) {
  const ids = doc.decisions.filter(d => (d.meta.category || 'Other') === category && PENDING.includes(d.meta.status)).map(d => d.id);
  return { category, count: ids.length, ids };
}

const splitList = s => String(s || '').split(/[,\n]/).map(x => x.trim().replace(/\.$/, '')).filter(Boolean);
const num2 = n => String(n).padStart(2, '0');
/** The header lines a ticket file carries and the Work page reads (`ticketDocument`). */
export const TICKET_HEADERS = ['Status', 'Blocked by', 'Next'];
const touchKey = t => t.replace(/\/+$/, '').toLowerCase();
/** Two touches overlap when they name the same thing or one is a directory the other sits in. */
const overlap = (a, b) => { const x = touchKey(a), y = touchKey(b); return x === y || x.startsWith(y + '/') || y.startsWith(x + '/'); };

/**
 * The ticket breakdown a `/to-tickets-lee` run put on the page: every card in
 * either file with a `ticket:` meta line, in ticket-number order. Each comes
 * back with `declared` (its `blocked:` line), `overlaps` (the earlier tickets
 * whose touches it shares, and on what), and `blockedBy`, the union of the two,
 * lower numbers blocking higher ones. A declared blocker that is not a lower
 * number is listed in `forward` (a later or same-numbered ticket cannot block an
 * earlier one). `pending` and `approved` name the cards by status; a rejected
 * or withdrawn card is listed but never published.
 */
export function ticketPlan(feature, proposals, ssot = { decisions: [] }) {
  const cards = [...proposals.decisions, ...ssot.decisions].filter(d => d.meta.ticket !== undefined && d.meta.ticket !== '');
  const tickets = cards.map(d => ({
    id: d.id,
    number: num2(d.meta.ticket),
    title: d.title.replace(/^Ticket \d+:\s*/i, '').trim(),
    status: d.meta.status || 'proposed',
    declared: splitList(d.meta.blocked).map(num2),
    touches: splitList(d.parts.touches),
    depends: splitList(d.meta.depends),
    decision: d.parts.decision || '',
    details: d.parts.details || '',
    overlaps: [],
    blockedBy: [],
  })).sort((a, b) => a.number.localeCompare(b.number));
  const live = tickets.filter(t => !GONE.includes(t.status));
  for (let j = 0; j < live.length; j++) {
    for (let i = 0; i < j; i++) {
      const on = live[j].touches.find(t => live[i].touches.some(u => overlap(t, u)));
      if (on !== undefined) live[j].overlaps.push({ with: live[i].number, on });
    }
    live[j].blockedBy = [...new Set([...live[j].declared, ...live[j].overlaps.map(o => o.with)])].sort();
  }
  return {
    feature,
    tickets,
    forward: live.flatMap(t => t.declared.filter(n => n >= t.number).map(n => ({ ticket: t.number, blockedBy: n }))),
    pending: tickets.filter(t => PENDING.includes(t.status)).map(t => t.id),
    approved: tickets.filter(t => t.status === 'approved').map(t => t.id),
  };
}

const slug = s => s.toLowerCase().replace(/`/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60).replace(/-$/, '');

/**
 * Write the approved ticket cards of a feature as one file each under `dir`,
 * in the local ticket template with the three header lines the Work page reads
 * (Status, Blocked by, Next), a Decisions line citing the ids the card depends
 * on and the card's own id, the touches, the Details as acceptance criteria,
 * and a closing `Next:` line. Refuses (writes nothing) while any ticket card
 * is still proposed or amended, a declared blocker is not a lower number, or
 * a card depends on a rejected or withdrawn id; `why` says which. A number that
 * already has a file is skipped.
 */
export function publishTickets(feature, proposals, ssot, dir, { next }) {
  if (!next) throw new Error('publishTickets needs the Next: command the files will carry');
  const plan = ticketPlan(feature, proposals, ssot);
  const status = new Map([...proposals.decisions, ...ssot.decisions].map(d => [d.id, d.meta.status || 'proposed']));
  const why = {};
  for (const id of plan.pending) why[id] = 'still pending on the page';
  for (const f of plan.forward) { const t = plan.tickets.find(x => x.number === f.ticket); why[t.id] = `blocked by ${f.blockedBy}, which is not a lower number`; }
  for (const t of plan.tickets) { const gone = t.depends.filter(id => GONE.includes(status.get(id))); if (gone.length) why[t.id] = `depends on ${gone.join(', ')}, which no longer stands`; }
  const refused = Object.keys(why);
  if (refused.length) return { written: [], skipped: [], refused, why };
  const written = [], skipped = [];
  const present = existsSync(dir) ? readdirSync(dir) : [];
  for (const t of plan.tickets) {
    if (t.status !== 'approved') continue;
    const clash = present.find(f => f.startsWith(t.number + '-'));
    if (clash) { skipped.push({ id: t.id, file: `${dir}/${clash}` }); continue; }
    const file = `${dir}/${t.number}-${slug(t.title)}.md`;
    const blockedBy = t.blockedBy.length
      ? t.blockedBy.map(n => { const o = t.overlaps.find(x => x.with === n); return o ? `${n} (touches ${o.on})` : n; }).join(', ') + '.'
      : 'None (can start immediately).';
    const ids = t.depends.length ? `${t.depends.join(', ')}; approved as ${t.id}.` : `approved as ${t.id}.`;
    const criteria = t.details.split('\n').map(l => l.trim()).filter(Boolean).map(l => /^- \[[ x]\]/.test(l) ? l : `- [ ] ${l.replace(/^[-*]\s+|^\d+\.\s+/, '')}`);
    const out = [
      `# ${t.number}: ${t.title}`, '',
      `**${TICKET_HEADERS[0]}:** ready-for-agent`,
      `**${TICKET_HEADERS[1]}:** ${blockedBy}`,
      `**${TICKET_HEADERS[2]}:** \`${next}\``, '',
      `**What to build:** ${t.decision}`, '',
      `**Decisions:** ${ids}`, '',
      `**Touches:** ${t.touches.join(', ')}`, '',
      ...criteria, '',
      `Next: ${next}`, '',
    ];
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
    writeFileSync(file, out.join('\n'));
    written.push({ id: t.id, file, blockedBy: t.blockedBy });
  }
  return { written, skipped, refused: [], why };
}

// ---- CLI ----

/**
 * Split the page's verdicts into what a skill applies at once and what it must
 * first say back in the terminal. Clear-cut: approve, withdraw, reject with a
 * plain reason. With words: amend, an accepted change card, a new term, and a
 * rejection whose reason is really a question. Anything else (a change card
 * that was dismissed, an unknown verdict) is `other` and is only reported.
 */
export function triage(verdicts) {
  const clear = {}, words = {}, other = {};
  const withWords = (id, v, pile) => { words[id] = { ...v, pile }; };
  for (const [id, v] of Object.entries(verdicts)) {
    const asksQuestion = String(v.text || '').includes('?');
    if (v.verdict === 'approve' || v.verdict === 'withdraw') clear[id] = v;
    else if (v.verdict === 'reject' && !asksQuestion) clear[id] = v;
    else if (v.verdict === 'reject') withWords(id, v, 'a rejection that asks a question');
    else if (v.verdict === 'amend') withWords(id, v, 'a rewrite in the ratifier\'s words');
    else if (v.verdict === 'change' && v.accepted) withWords(id, v, 'an accepted change card');
    else if (v.verdict === 'term') withWords(id, v, 'a new glossary term');
    else other[id] = v;
  }
  return { clear, words, other };
}

// Drawn pictures. A screenless card (`screen:` starts with "none") carries
// `- svg: <repo path>` to a file diagram.mjs drew; `prepare` inlines it. The
// check keeps them plain: an svg root, no raster or stock link, and no colour
// that is not a page token (`var(--token, fallback)`; the fallback is free).
const isScreenless = d => /^none\b/i.test(d.meta.screen || '');
const kindOf = d => d.meta.kind || 'decision';
const isQuestion = d => kindOf(d) === 'question';
export function svgCheck(text) {
  const problems = [];
  const t = String(text || '');
  if (!/^\s*(<\?xml[^>]*>\s*)?(<!--[\s\S]*?-->\s*)*<svg[\s>]/i.test(t)) problems.push('does not start with <svg');
  if (/<image\b/i.test(t)) problems.push('<image> element (raster)');
  if (/<foreignObject\b/i.test(t)) problems.push('<foreignObject> element');
  if (/url\(\s*["']?data:/i.test(t)) problems.push('data: url');
  if (/(?:xlink:)?href\s*=\s*["'](?!#)/i.test(t)) problems.push('href to something outside the file');
  for (const m of t.matchAll(/var\(\s*--([a-z0-9-]+)/gi)) if (!TOKENS.includes(m[1])) problems.push(`--${m[1]} is not a page token`);
  // Strip the token references (with their fallbacks) and look for what is left.
  const rest = t.replace(/var\(\s*--[a-z0-9-]+\s*(?:,[^)]*)?\)/gi, 'var()');
  for (const m of rest.matchAll(/#[0-9a-f]{3,8}\b|rgba?\(|hsla?\(/gi)) problems.push(`colour ${m[0]} outside the page tokens`);
  for (const m of rest.matchAll(/(?:fill|stroke|stop-color|color|flood-color|lighting-color)\s*[:=]\s*["']?\s*([a-z]+)/gi)) {
    if (!['none', 'currentcolor', 'inherit', 'transparent', 'var', 'url'].includes(m[1].toLowerCase())) problems.push(`colour ${m[1]} outside the page tokens`);
  }
  return { ok: problems.length === 0, problems: [...new Set(problems)] };
}

/** Read a drawn picture and check it: {svg, problems}. A missing file is a problem, not a throw. */
export function checkedSvg(path) {
  if (!existsSync(path)) return { svg: '', problems: ['file missing'] };
  const svg = readFileSync(path, 'utf8');
  return { svg, problems: svgCheck(svg).problems };
}

/** Screenless decisions with no drawn picture, proposals then record, file order. Questions and ruled-out cards are not drawn. */
export function undrawn(proposals, ssot = { decisions: [] }) {
  const out = [];
  for (const [file, doc] of [['proposals', proposals], ['record', ssot]]) {
    for (const d of doc.decisions) {
      if (isQuestion(d) || GONE.includes(d.meta.status)) continue;
      if (isScreenless(d) && !d.meta.svg) out.push({ id: d.id, title: d.title, file });
    }
  }
  return out;
}

/** Set a card's `svg:` line (after `caption:`, else after `image:`, else last); false when the id is not in the doc. */
export function attachSvg(doc, id, path) {
  const d = doc.decisions.find(x => x.id === id);
  if (!d) return false;
  d.meta = setMeta(d.meta, 'svg', path, ['caption', 'image']);
  return true;
}
/** Set one meta line: in place when the card has it, else inserted after the first key of `after` the card has (or last). */
function setMeta(meta, key, value, after = []) {
  if (meta[key] !== undefined) return { ...meta, [key]: value };
  const keys = Object.keys(meta);
  const at = after.find(k => keys.includes(k)) || keys[keys.length - 1];
  const out = {};
  for (const k of keys) { out[k] = meta[k]; if (k === at) out[key] = value; }
  return out;
}

// Captured pictures. A card that names a screen (`screen:` not "none") and has
// `image: none` is pictured from the simulator (capture.mjs) or from an existing
// golden or design frame the screen registry names for that screen. Either
// way `attachImage` sets the card's `image:` line and writes one dated history
// line saying where the picture came from; the sidecar beside a capture
// (`<png>.json` with the png's extension swapped) carries the commit and app
// version it was taken at.
const sidecarPath = png => png.replace(/\.png$/i, '.json');
const imageDir = feature => `docs/ssot/decisions/images/${feature}`;
// "at 1.26.0+1, 43496fed": how a history line names the build a picture was taken at.
const pictureStamp = c => `at ${c?.appVersion || '?'}, ${c?.commit || '?'}`;
export function readSidecar(png) {
  const p = sidecarPath(png);
  if (!existsSync(p)) return null;
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return null; }
}
/**
 * Cards with a screen and no picture, and what would picture each: reuse (a path),
 * capture (a drive), or none. A registry `reuse` comes first only while it is not
 * stale (`captureStatus`); a stale golden with a drive is captured instead, so a
 * picture a refresh already replaced is never attached again.
 */
export function uncaptured(proposals, ssot = { decisions: [] }, screens = {}, { root = process.cwd() } = {}) {
  const out = [], cache = new Map();
  const freshReuse = m => m.reuse && !(m.drive && captureStatus(m.reuse, screens, { root, cache })?.stale);
  for (const [file, doc] of [['proposals', proposals], ['record', ssot]]) {
    for (const d of doc.decisions) {
      if (isQuestion(d) || GONE.includes(d.meta.status)) continue;
      if (!d.meta.screen || isScreenless(d) || (d.meta.image && d.meta.image !== 'none')) continue;
      const m = matchScreen(d.meta.screen, screens);
      const how = !m ? 'none' : freshReuse(m) ? 'reuse' : m.drive ? 'capture' : 'none';
      out.push({ id: d.id, title: d.title, file, screen: d.meta.screen, key: m?.key || '', how, path: how === 'reuse' ? m.reuse : '', note: m?.note || (m ? '' : 'no screen in screens.json matches') });
    }
  }
  return out;
}
/** Set a card's image (and caption when given) and record the picture's origin as a history line; false when the id is not in the doc. */
export function attachImage(doc, id, path, { caption, captured = readSidecar(path), today = new Date().toISOString().slice(0, 10) } = {}) {
  const d = doc.decisions.find(x => x.id === id);
  if (!d) return false;
  d.meta = setMeta(d.meta, 'image', path, ['status']);
  if (caption !== undefined) d.meta = setMeta(d.meta, 'caption', caption, ['image']);
  const note = captured ? `picture captured ${pictureStamp(captured)}` : `picture reused from ${path}`;
  d.history.push({ date: today, note });
  return true;
}

// Picture age. A capture's sidecar says when it was taken; a reused golden has
// none, so git says: the commit that last touched the file, its date, and the
// version pubspec.yaml held at that commit. Either way the screen's `code`
// list in screens.json is what may have moved on since: `changedSince` asks
// git which files under those paths differ between that commit and the working
// tree, plus untracked files under them (uncommitted edits and new files count,
// since that is what the simulator shows). A
// screen with no code list, or a commit this clone never had, says nothing
// about staleness (`stale: null`) rather than guessing.
const git = (root, ...a) => { const r = spawnSync('git', a, { cwd: root, encoding: 'utf8' }); return r.status === 0 ? r.stdout : null; };
const under = (root, p) => isAbsolute(p) ? p : join(root, p);
export function changedSince(commit, paths, { root = process.cwd() } = {}) {
  if (!commit || !paths?.length || git(root, 'cat-file', '-e', `${commit}^{commit}`) === null) return null;
  const out = git(root, 'diff', '--name-only', commit, '--', ...paths);
  if (out === null) return null;
  const untracked = git(root, 'ls-files', '--others', '--exclude-standard', '--', ...paths) || '';
  return [...new Set([...out.split('\n'), ...untracked.split('\n')].filter(Boolean))].sort();
}
/** The age of a file with no sidecar, from the commit that last touched it; null when git does not track it. */
export function imageOrigin(path, { root = process.cwd() } = {}) {
  const line = (git(root, 'log', '-1', '--format=%h %cI', '--', path) || '').trim();
  if (!line) return null;
  const [commit, at] = line.split(' ');
  const pubspec = git(root, 'show', `${commit}:pubspec.yaml`) || '';
  return { commit, appVersion: (pubspec.match(/^version:\s*(\S+)/m) || [])[1] || '', capturedAt: new Date(at).toISOString(), how: 'reused' };
}
/** What the page shows under a picture: its sidecar or git origin, the screen key, and whether the screen's code changed since. */
export function captureStatus(path, screens = {}, { root = process.cwd(), cache } = {}) {
  if (cache?.has(path)) return cache.get(path);
  const side = readSidecar(under(root, path));
  const base = side ? { ...side, how: 'captured' } : imageOrigin(path, { root });
  let status = null;
  if (base) {
    const key = side?.key || Object.keys(screens).find(k => screens[k].reuse === path) || basename(path, '.png');
    const code = screens[key]?.code;
    const changed = code ? changedSince(base.commit, code, { root }) : null;
    status = { ...base, key, changed: changed || [], stale: changed === null ? null : changed.length > 0 };
  }
  cache?.set(path, status);
  return status;
}
/** Every picture the live cards use, once each, with its age, the cards on it, and whether a refresh could retake it. */
export function stalePictures(proposals, ssot = { decisions: [] }, screens = {}, { root = process.cwd() } = {}) {
  const cache = new Map(), byPath = new Map();
  for (const doc of [proposals, ssot]) {
    for (const d of doc.decisions) {
      if (isQuestion(d) || GONE.includes(d.meta.status)) continue;
      const path = d.meta.image;
      if (!path || path === 'none') continue;
      if (!byPath.has(path)) {
        const s = captureStatus(path, screens, { root, cache });
        if (!s) continue;
        byPath.set(path, { path, ...s, cards: [], refresh: screens[s.key]?.drive ? 'capture' : 'none' });
      }
      byPath.get(path).cards.push(d.id);
    }
  }
  return [...byPath.values()];
}
/**
 * Retake every stale picture in one pass, one capture per screen. `takePicture(entry)`
 * drives the simulator and returns `{path}`; a capture lands on `<dir>/<key>.png`,
 * so a stale capture is rewritten in place and its cards need nothing. A stale
 * golden cannot be rewritten, so its cards move to the capture with one dated
 * history line naming what it replaced. A screen with no drive, or a drive that
 * fails, is skipped and its file left alone.
 */
export async function refreshPictures(proposals, ssot, screens, { root = process.cwd(), dir, takePicture, only, today = new Date().toISOString().slice(0, 10) }) {
  const result = { refreshed: [], fresh: [], skipped: [] };
  const took = new Map(); // key -> {path} | null, so a golden and a capture of one screen share a drive
  // `only` (screen keys a wave touched) retakes those screens whether stale or not and leaves every other picture alone.
  const wanted = p => only ? only.includes(p.key) : p.stale;
  for (const p of stalePictures(proposals, ssot, screens, { root })) {
    if (!wanted(p)) { result.fresh.push(p.path); continue; }
    const entry = screens[p.key];
    if (!entry?.drive) { result.skipped.push({ path: p.path, why: `${p.key} has no drive` }); continue; }
    if (!took.has(p.key)) {
      try { took.set(p.key, await takePicture({ key: p.key, ...entry, dir })); }
      catch (e) { took.set(p.key, null); result.skipped.push({ path: p.path, why: `capture of ${p.key} failed: ${e.message}` }); continue; }
    }
    const taken = took.get(p.key);
    if (!taken) { result.skipped.push({ path: p.path, why: `capture of ${p.key} failed` }); continue; }
    if (taken.path !== p.path) {
      const side = readSidecar(under(root, taken.path));
      const note = `picture refreshed ${pictureStamp(side)}, replacing ${p.path}`;
      for (const doc of [proposals, ssot]) for (const d of doc.decisions) if (p.cards.includes(d.id)) { d.meta = setMeta(d.meta, 'image', taken.path, ['status']); d.history.push({ date: today, note }); }
    }
    result.refreshed.push({ key: p.key, from: p.path, path: taken.path, cards: p.cards });
  }
  return result;
}

// ---- /implement-lee: waves in worktrees ----

const ticketNumbers = line => [...new Set((String(line || '').match(/\b\d{2}\b/g) || []))];
/**
 * The frontier: every ticket that is ready and whose blockers are all done or
 * dropped, from the header lines `ticketDocument` read. `building` is what an
 * earlier wave holds (status in-progress), `blocked` says what each waiting
 * ticket still waits on. Numbers, in ticket order.
 */
export function ticketFrontier(tickets) {
  const sorted = [...tickets].sort((a, b) => a.order - b.order);
  const building = t => t.state === 'building';
  const done = sorted.filter(t => t.state === 'done').map(t => t.number);
  const dropped = sorted.filter(t => t.state === 'dropped').map(t => t.number);
  const settled = new Set([...done, ...dropped]);
  const out = { done, dropped, building: sorted.filter(building).map(t => t.number), frontier: [], blocked: [] };
  for (const t of sorted) {
    if (settled.has(t.number) || building(t)) continue;
    const waitingOn = ticketNumbers(t.blockedBy).filter(n => !settled.has(n));
    if (waitingOn.length) out.blocked.push({ number: t.number, waitingOn });
    else if (t.state === 'ready' || t.state === 'proposed') out.frontier.push(t.number);
    else out.blocked.push({ number: t.number, waitingOn: [], status: t.status });
  }
  return out;
}
/** The design renderings a ticket cites (`docs/ssot/spec/design/renderings/...`), once each, in order. */
export function designRenderings(text) {
  return [...new Set(String(text).match(/docs\/ssot\/spec\/design\/renderings\/[^\s`'")\]]+/g) || [])];
}
/** The registry screens whose `code` covers any of the files, in registry order. */
export function touchedScreens(files, screens) {
  const drawnFrom = (file, codePath) => { const dir = codePath.replace(/\/+$/, ''); return file === dir || file.startsWith(dir + '/'); };
  return Object.entries(screens).filter(([, entry]) => (entry.code || []).some(codePath => files.some(file => drawnFrom(file, codePath)))).map(([key]) => key);
}
/** Rewrite a ticket's `**Status:**` header line and nothing else. */
export function setTicketStatus(text, status) {
  const re = new RegExp(`^\\*\\*${TICKET_HEADERS[0]}:\\*\\*.*$`, 'm');
  if (!re.test(text)) throw new Error(`the ticket has no **${TICKET_HEADERS[0]}:** line`);
  return text.replace(re, `**${TICKET_HEADERS[0]}:** ${status}`);
}
const gitOut = (root, ...a) => (git(root, ...a) || '').trim();
/**
 * The next wave for a feature: the frontier from the ticket files, and for each
 * ticket the branch and worktree its agent builds on, the design renderings it
 * cites (visual parity), and the ids it cites. `base` is the working branch's
 * tip the worktrees start from; `uncommitted` lists ticket files a worktree
 * could not see. Worktrees sit beside the clone (`<clone>-waves/<feature>/NN`),
 * never inside it, so the app's analyzer and tests never walk another ticket's tree.
 */
export function wavePlan(feature, dir, { root = process.cwd(), branch } = {}) {
  root = resolve(root);
  const docs = ticketFiles(root, dir).map(f => ticketDocument(feature, f, readFileSync(under(root, f), 'utf8')));
  const frontier = ticketFrontier(docs);
  branch = branch || gitOut(root, 'rev-parse', '--abbrev-ref', 'HEAD');
  const base = gitOut(root, 'rev-parse', 'HEAD');
  const status = gitOut(root, 'status', '--porcelain', '--', dir);
  const uncommitted = status.split('\n').filter(Boolean).map(l => l.slice(3).trim()).filter(p => /\/\d+-.*\.md$/.test(p)).sort();
  const wavesDir = join(dirname(root), `${basename(root)}-waves`, feature);
  const wave = frontier.frontier.map(n => {
    const t = docs.find(d => d.number === n);
    const text = readFileSync(under(root, t.file), 'utf8');
    const name = `${n}-${basename(t.file).replace(/^\d+-/, '').replace(/\.md$/, '')}`;
    return { number: n, title: t.title, file: t.file, branch: `wave/${feature}/${name}`, worktree: join(wavesDir, name), simulator: `wave-${feature}-${n}`, renderings: designRenderings(text), cites: t.cites };
  });
  return { feature, branch, base, done: frontier.done, dropped: frontier.dropped, building: frontier.building, blocked: frontier.blocked, wave, uncommitted };
}
/** Minutes, or hours and minutes, between two ISO instants. */
export function elapsed(from, to) {
  const m = Math.max(0, Math.floor((new Date(to) - new Date(from)) / 60000));
  return m < 60 ? `${m}m` : `${Math.floor(m / 60)}h ${m % 60}m`;
}
/** Append a wave to the feature's log (`.scratch/<feature>/waves.json`); numbers count from 1. */
export function waveOpen(log, { tickets, base, branch, now = new Date().toISOString() }) {
  const entry = { number: log.length + 1, tickets, base, branch, startedAt: now, closedAt: null };
  log.push(entry);
  return entry;
}
/** Close a wave: what merged, what failed, how the suite ended, and the time it took. */
export function waveClose(log, number, { merged = [], failed = [], suite = '', now = new Date().toISOString() } = {}) {
  const entry = log.find(w => w.number === Number(number));
  if (!entry) throw new Error(`wave ${number} is not in the log`);
  // A wave ticket named in neither list did not merge: it fails, so the next run puts it back on the frontier.
  failed = [...new Set([...failed, ...entry.tickets.filter(t => !merged.includes(t) && !failed.includes(t))])].sort();
  Object.assign(entry, { merged, failed, suite, closedAt: now, elapsed: elapsed(entry.startedAt, now) });
  return entry;
}
// The assets map (`_page/assets.json`) keys a repo image path to the artifact
// asset it was uploaded as. New entries are {id, sha256}; the first entries
// were bare ids and still resolve. An image is uploaded again only when its
// hash no longer matches.
const sha256 = path => createHash('sha256').update(readFileSync(path)).digest('hex');
export function assetId(assets, path) { const a = assets[path]; return !a ? '' : typeof a === 'string' ? a : a.id || ''; }
export function staleImages(assets, paths) {
  const out = [];
  for (const path of paths) {
    if (!existsSync(path)) { out.push({ path, why: 'file missing' }); continue; }
    const a = assets[path];
    if (!a) out.push({ path, why: 'new' });
    else if (typeof a === 'object' && a.sha256 && a.sha256 !== sha256(path)) out.push({ path, why: 'changed' });
  }
  return out;
}
/** Record an upload; hands back the id it replaced ('' for a first upload) so the old asset can be deleted. */
export function recordAsset(assets, path, id) { const prev = assetId(assets, path); assets[path] = { id, sha256: sha256(path) }; return prev; }
/** Forget a path; hands back its asset id ('' when there was none) for the same reason. */
export function dropAsset(assets, path) { const prev = assetId(assets, path); delete assets[path]; return prev; }
/** Assets under a prepared feature's image folder that no prepared document references any more. */
export function unreferencedAssets(assets, paths, features) {
  const used = new Set(paths);
  return Object.keys(assets).filter(p => !used.has(p) && features.some(f => p.startsWith(imageDir(f) + '/'))).map(path => ({ path, why: 'unreferenced', id: assetId(assets, path) }));
}
// `--flag value` pairs pulled out of a CLI's arguments; what is left is positional.
const commaList = v => typeof v === 'string' ? v.split(',').map(x => x.trim()).filter(Boolean) : [];
const flags = args => { const pos = [], opts = {}; for (let k = 0; k < args.length; k++) { if (args[k].startsWith('--')) opts[args[k].slice(2)] = args[k + 1] === undefined || args[k + 1].startsWith('--') ? true : args[++k]; else pos.push(args[k]); } return [pos, opts]; };
const loadAssets = path => path && existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : {};
// The proposals file and the record; a record that does not exist yet reads as empty.
const readPair = (pf, sf) => [parse(readFileSync(pf, 'utf8')), sf && existsSync(sf) ? parse(readFileSync(sf, 'utf8')) : { head: {}, decisions: [] }];

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split('/').pop())) {
  const [cmd, ...args] = process.argv.slice(2);
  if (cmd === 'export') {
    let order = 0; const docs = [];
    for (const f of args) { const d = parse(readFileSync(f, 'utf8')); docs.push(...toDocuments(d, { order })); order += 1000; }
    process.stdout.write(JSON.stringify(docs, null, 2));
  } else if (cmd === 'apply') {
    const [vf, pf, sf] = args;
    const verdicts = JSON.parse(readFileSync(vf, 'utf8')).verdicts || JSON.parse(readFileSync(vf, 'utf8'));
    const proposals = parse(readFileSync(pf, 'utf8'));
    const ssot = existsSync(sf) ? parse(readFileSync(sf, 'utf8')) : { title: proposals.title.replace('Proposed decisions', 'Decisions'), head: { feature: proposals.head.feature, 'feature name': proposals.head['feature name'] }, decisions: [], preamble: [] };
    const r = apply(verdicts, proposals, ssot);
    writeFileSync(pf, serialize(proposals)); writeFileSync(sf, serialize(ssot));
    console.log(JSON.stringify({ applied: r.applied, refused: r.refused }, null, 2));
  } else if (cmd === 'prepare') {
    // prepare <decisions.md>... --assets <assets.json> --out <dir>
    // Writes one JSON file per page document (with imageAssetId resolved from
    // the assets map {repoPath: assetId}) and prints the batch entries for the
    // Artifact tool's write_db batch, 50 per batch.
    const { mkdirSync } = await import('node:fs');
    const [files, opts] = flags(args);
    const assets = loadAssets(opts.assets);
    const { resolve } = await import('node:path'); const out = resolve(opts.out || 'docs-out'); mkdirSync(out, { recursive: true });
    const screens = loadScreens(opts.screens || undefined), ageCache = new Map();
    const readCaptured = path => captureStatus(path, screens, { cache: ageCache });
    let order = 0; const entries = [], features = new Set();
    for (const f of files) {
      const d = parse(readFileSync(f, 'utf8'));
      if (d.head.feature) features.add(d.head.feature);
      // A drawn picture that fails the check is reported and left out; the page shows the empty box.
      const readSvg = path => { const c = checkedSvg(path); if (c.problems.length) { console.error(`svg ${path} left out: ${c.problems.join('; ')}`); return ''; } return c.svg; };
      for (const doc of toDocuments(d, { order, readSvg, readCaptured })) {
        const { id, ...body } = doc;
        body.imageAssetId = body.image ? assetId(assets, body.image) : '';
        writeFileSync(`${out}/${id}.json`, JSON.stringify(body, null, 2));
        entries.push({ op: 'set', collection: 'decisions', doc_id: id, file_path: `${out}/${id}.json` });
      }
      order += 1000;
    }
    // Tickets ride along: --tickets <feature>=<issues dir> (repeatable via commas).
    for (const spec of (opts.tickets || '').split(',').filter(Boolean)) {
      const [feature, dir] = spec.split('=');
      for (const f of ticketFiles(process.cwd(), dir)) {
        const t = ticketDocument(feature, f, readFileSync(f, 'utf8'));
        const { id, ...body } = t;
        writeFileSync(`${out}/ticket-${id}.json`, JSON.stringify(body, null, 2));
        entries.push({ op: 'set', collection: 'tickets', doc_id: id, file_path: `${out}/ticket-${id}.json` });
      }
    }
    const batches = []; for (let k = 0; k < entries.length; k += 50) batches.push(entries.slice(k, k + 50));
    writeFileSync(`${out}/_batches.json`, JSON.stringify(batches, null, 2));
    const images = [...new Set(entries.map(e => JSON.parse(readFileSync(e.file_path, 'utf8')).image).filter(Boolean))];
    writeFileSync(`${out}/_images.json`, JSON.stringify(images, null, 2));
    writeFileSync(`${out}/_features.json`, JSON.stringify([...features], null, 2));
    console.log(`${entries.length} documents in ${batches.length} batches; ${images.length} distinct images (${staleImages(assets, images).length} to upload)`);
  } else if (cmd === 'terms') {
    // terms <verdicts.json> <CONTEXT.md>: append accepted `term` verdicts to the glossary
    // under their area heading (created at the end of ## Language if missing).
    const [vf, cf] = args;
    const raw = JSON.parse(readFileSync(vf, 'utf8')); const verdicts = raw.verdicts || raw;
    let ctx = readFileSync(cf, 'utf8'); const added = [];
    for (const [id, v] of Object.entries(verdicts)) {
      if (v.verdict !== 'term') continue;
      const entry = `**${v.term}**:\n${v.definition.trim()}\n${v.avoid ? `_Avoid_: ${v.avoid}\n` : ''}`;
      const area = v.area && v.area.trim() ? v.area.trim() : 'General';
      const h = `### ${area}`;
      if (ctx.includes(h + '\n')) {
        const i = ctx.indexOf(h + '\n'); const rest = ctx.slice(i + h.length + 1); const next = rest.search(/\n### |\n## /);
        const end = next < 0 ? ctx.length : i + h.length + 1 + next;
        ctx = ctx.slice(0, end).replace(/\n+$/, '') + '\n\n' + entry + ctx.slice(end);
      } else ctx = ctx.replace(/\n+$/, '') + `\n\n${h}\n\n${entry}`;
      added.push(id);
    }
    writeFileSync(cf, ctx.replace(/\n+$/, '') + '\n');
    console.log(JSON.stringify({ added }));
  } else if (cmd === 'answers') {
    // answers <question id> <decision id> <proposals.md> <ssot.md>: link both ways.
    const [qid, did, pf, sf] = args;
    const proposals = parse(readFileSync(pf, 'utf8'));
    const ssot = existsSync(sf) ? parse(readFileSync(sf, 'utf8')) : { title: '', head: {}, decisions: [], preamble: [] };
    const r = answers(qid, did, proposals, ssot);
    if (r.applied.length) { writeFileSync(pf, serialize(proposals)); if (existsSync(sf)) writeFileSync(sf, serialize(ssot)); }
    console.log(JSON.stringify(r, null, 2));
    if (r.refused.length) process.exit(1);
  } else if (cmd === 'questions') {
    // questions <proposals.md> [<ssot.md>]: the open questions as JSON, nothing written.
    const [pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(openQuestions(proposals, ssot), null, 2));
  } else if (cmd === 'linked') {
    // linked <proposals.md> [<ssot.md>]: decisions that answered a question, nothing written.
    const [pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(answeredLinks(proposals, ssot), null, 2));
  } else if (cmd === 'cite') {
    // cite <spec.md> <proposals.md> [<ssot.md>]: what the spec's decision sections cite, nothing written.
    const [specf, pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(specCitations(readFileSync(specf, 'utf8'), proposals, ssot), null, 2));
  } else if (cmd === 'pending') {
    // pending <decisions.md> [<category>]: a bare count, or {category, count, ids} for one category.
    const d = parse(readFileSync(args[0], 'utf8'));
    if (args[1]) process.stdout.write(JSON.stringify(pendingIn(d, args[1]), null, 2) + '\n');
    else console.log(d.decisions.filter(x => PENDING.includes(x.meta.status)).length);
  } else if (cmd === 'ticket-plan') {
    // ticket-plan <feature> <proposals.md> [<ssot.md>]: the ticket cards with their edges, nothing written.
    const [feature, pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(ticketPlan(feature, proposals, ssot), null, 2));
  } else if (cmd === 'publish-tickets') {
    // publish-tickets <feature> <proposals.md> <ssot.md> <issues dir> --next <cmd>
    const [feature, pf, sf, dir, flag, next] = args;
    if (flag !== '--next' || !next) { console.error('usage: publish-tickets <feature> <proposals.md> <ssot.md> <issues dir> --next <command>'); process.exit(2); }
    const [proposals, ssot] = readPair(pf, sf);
    const r = publishTickets(feature, proposals, ssot, dir, { next });
    process.stdout.write(JSON.stringify(r, null, 2));
  } else if (cmd === 'question-first') {
    // question-first <decisions.md>...: lift the closing question out of every Context.
    for (const f of args) { const d = parse(readFileSync(f, 'utf8')); const n = questionFirst(d); writeFileSync(f, serialize(d)); console.log(`${f}: ${n} questions lifted`); }
  } else if (cmd === 'fold') {
    // fold <plan.json> <proposals.md> <ssot.md>: combine proposals per the plan.
    const [pf, prf, sf] = args;
    const plan = JSON.parse(readFileSync(pf, 'utf8'));
    const proposals = parse(readFileSync(prf, 'utf8'));
    const ssot = existsSync(sf) ? parse(readFileSync(sf, 'utf8')) : { decisions: [] };
    const r = fold(plan, proposals, ssot);
    writeFileSync(prf, serialize(proposals));
    console.log(JSON.stringify(r, null, 2));
  } else if (cmd === 'tickets') {
    // tickets <feature> <issues dir>: ticket documents as JSON
    const [feature, dir] = args;
    const docs = ticketFiles(process.cwd(), dir).map(f => ticketDocument(feature, f, readFileSync(f, 'utf8')));
    process.stdout.write(JSON.stringify(docs, null, 2));
  } else if (cmd === 'triage') {
    // triage <verdicts.json> --out <dir>: clear.json for apply, words.json for the terminal.
    const [vf, flag, dir] = args;
    const raw = JSON.parse(readFileSync(vf, 'utf8')); const verdicts = raw.verdicts || raw;
    const t = triage(verdicts);
    if (flag !== '--out' || !dir) { console.error('usage: sync.mjs triage <verdicts.json> --out <dir>'); process.exit(2); }
    const out = dir;
    const { mkdirSync } = await import('node:fs'); mkdirSync(out, { recursive: true });
    writeFileSync(`${out}/clear.json`, JSON.stringify({ sentAt: raw.sentAt || null, verdicts: t.clear }, null, 2));
    writeFileSync(`${out}/words.json`, JSON.stringify({ sentAt: raw.sentAt || null, verdicts: t.words }, null, 2));
    // rewrites.json is the part of words.json that `apply` may take after the ratifier's yes:
    // amend and accepted change verdicts. A question-shaped reject or a term never goes to apply.
    const rewrites = Object.fromEntries(Object.entries(t.words).filter(([, v]) => v.verdict === 'amend' || v.verdict === 'change'));
    writeFileSync(`${out}/rewrites.json`, JSON.stringify({ sentAt: raw.sentAt || null, verdicts: rewrites }, null, 2));
    const n = o => Object.keys(o).length;
    console.log(`${n(t.clear)} clear, ${n(t.words)} with words, ${n(t.other)} other` + (n(t.other) ? ` (${Object.keys(t.other).join(', ')})` : ''));
  } else if (cmd === 'next-id') {
    const [pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    console.log(nextId(proposals, ssot));
  } else if (cmd === 'images') {
    // images <assets.json> <_images.json>: which images prepare found that still need an upload.
    const [af, imf] = args;
    // Beside _images.json, prepare leaves _features.json; an asset under one of those features' image folders
    // that no document uses any more is listed as unreferenced, with the id to delete.
    const assets = loadAssets(af);
    const paths = JSON.parse(readFileSync(imf, 'utf8'));
    const ff = imf.replace(/[^/]*$/, '_features.json');
    const features = existsSync(ff) ? JSON.parse(readFileSync(ff, 'utf8')) : [];
    process.stdout.write(JSON.stringify([...staleImages(assets, paths), ...unreferencedAssets(assets, paths, features)], null, 2));
  } else if (cmd === 'asset') {
    // asset <assets.json> <path> <asset id>: record one upload, keyed by path and hash; prints the id it replaced.
    // asset <assets.json> <path> --drop: forget the path; prints the id to delete.
    const [af, path, id] = args;
    const assets = loadAssets(af);
    const printed = id === '--drop' ? { path, dropped: dropAsset(assets, path) } : { path, id, replaced: recordAsset(assets, path, id) };
    writeFileSync(af, JSON.stringify(assets, null, 2) + '\n');
    console.log(JSON.stringify(printed));
  } else if (cmd === 'undrawn') {
    // undrawn <proposals.md> [<ssot.md>]: screenless cards with no drawn picture, nothing written.
    const [pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(undrawn(proposals, ssot), null, 2));
  } else if (cmd === 'draw') {
    // draw <spec.json> [<out.svg>]: diagram.mjs draws it; the result is checked before it is written.
    const [specf, outf] = args;
    const svg = draw(JSON.parse(readFileSync(specf, 'utf8')));
    const check = svgCheck(svg);
    if (check.problems.length) { console.error(`drawn svg fails the check: ${check.problems.join('; ')}`); process.exit(1); }
    if (outf) writeFileSync(outf, svg); else process.stdout.write(svg);
  } else if (cmd === 'attach-svg') {
    // attach-svg <decisions.md> <id> <svg path>: check the file, then set the card's svg line.
    const [df, id, path] = args;
    if (!df || !id || !path) { console.error('usage: sync.mjs attach-svg <decisions.md> <id> <svg path>'); process.exit(2); }
    const check = checkedSvg(path);
    if (check.problems.length) { console.error(`${path}: ${check.problems.join('; ')}`); process.exit(1); }
    const doc = parse(readFileSync(df, 'utf8'));
    if (!attachSvg(doc, id, path)) { console.error(`${id} is not in ${df}`); process.exit(1); }
    writeFileSync(df, serialize(doc));
    console.log(`${id}: svg ${path}`);
  } else if (cmd === 'uncaptured') {
    // uncaptured <proposals.md> [<ssot.md>]: screen cards with no picture and how each would get one, nothing written.
    const [pf, sf] = args;
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(uncaptured(proposals, ssot, loadScreens()), null, 2));
  } else if (cmd === 'capture') {
    // capture --check: what is missing on this machine. capture <feature> <screen>: one picture, printed as its sidecar. --udid (or SSOT_SIMULATOR) names the simulator.
    const [pos, opts] = flags(args);
    const udid = typeof opts.udid === 'string' ? opts.udid : undefined;
    if (opts.check) {
      const r = await doctor({ udid });
      console.log(JSON.stringify(r, null, 2));
      process.exit(r.ready ? 0 : 1);
    }
    const [feature, ...rest] = pos; const screen = rest.join(' ');
    if (!feature || !screen) { console.error('usage: sync.mjs capture --check | capture <feature> <screen>  [--udid <udid|name>]'); process.exit(2); }
    const entry = matchScreen(screen, loadScreens());
    if (!entry) { console.error(`no screen in screens.json matches "${screen}"`); process.exit(1); }
    if (!entry.drive) { console.error(`${entry.key} has no drive${entry.reuse ? `; reuse ${entry.reuse}` : ''}${entry.note ? `. ${entry.note}` : ''}`); process.exit(1); }
    const booted = bootedUdid(udid);
    if (!booted) { console.error('no booted simulator'); process.exit(1); }
    const r = await capture(entry, { dir: imageDir(feature), ...stamp(), device: booted.name, runtime: booted.runtime, io: simulatorIo(booted.udid) });
    console.log(JSON.stringify(r, null, 2));
  } else if (cmd === 'attach-image') {
    // attach-image <decisions.md> <id> <png path> [--caption <text>]: set the image line and record where the picture came from.
    const [[df, id, path], opts] = flags(args); const caption = typeof opts.caption === 'string' ? opts.caption : undefined;
    if (!df || !id || !path) { console.error('usage: sync.mjs attach-image <decisions.md> <id> <png path> [--caption <text>]'); process.exit(2); }
    if (!existsSync(path)) { console.error(`${path}: file missing`); process.exit(1); }
    const doc = parse(readFileSync(df, 'utf8'));
    if (!attachImage(doc, id, path, { caption })) { console.error(`${id} is not in ${df}`); process.exit(1); }
    writeFileSync(df, serialize(doc));
    console.log(`${id}: image ${path}`);
  } else if (cmd === 'pictures') {
    // pictures <feature> <proposals.md> <ssot.md> [--udid <udid|name>]: every uncaptured card gets its picture, one capture per screen.
    const [[feature, pf, sf], opts] = flags(args);
    const udid = typeof opts.udid === 'string' ? opts.udid : undefined;
    if (!feature || !pf || !sf) { console.error('usage: sync.mjs pictures <feature> <proposals.md> <ssot.md> [--udid <udid|name>]'); process.exit(2); }
    const screens = loadScreens();
    const [proposals, ssot] = readPair(pf, sf);
    const docs = { proposals, record: ssot };
    const todo = uncaptured(proposals, ssot, screens);
    const result = { attached: [], skipped: [] };
    // One capture per screen key per run; the png path (or null after a failed drive) is remembered here.
    const captures = new Map();
    let session = null; // the booted simulator, its io and the commit/version stamp, opened on the first capture
    const dir = imageDir(feature);
    for (const c of todo) {
      const doc = docs[c.file];
      const skip = why => result.skipped.push({ id: c.id, screen: c.screen, why });
      if (c.how === 'reuse') {
        if (!existsSync(c.path)) { skip(`${c.path} is missing`); continue; }
        attachImage(doc, c.id, c.path, { captured: null });
        result.attached.push({ id: c.id, screen: c.screen, path: c.path, how: 'reused' });
      } else if (c.how === 'capture') {
        if (!captures.has(c.key)) {
          if (!session) {
            let booted = null;
            try { booted = bootedUdid(udid); } catch (e) { skip(e.message); continue; }
            if (!booted) { skip('no booted simulator'); continue; }
            session = { ...stamp(), device: booted.name, runtime: booted.runtime, io: simulatorIo(booted.udid), dir };
          }
          try { captures.set(c.key, (await capture({ key: c.key, ...screens[c.key] }, session)).path); }
          catch (e) { captures.set(c.key, null); console.error(`${c.key}: ${e.message}`); }
        }
        const path = captures.get(c.key);
        if (!path) { skip(`capture of ${c.key} failed`); continue; }
        attachImage(doc, c.id, path);
        result.attached.push({ id: c.id, screen: c.screen, path, how: 'captured' });
      } else skip(c.note || 'nothing pictures this screen');
    }
    writeFileSync(pf, serialize(proposals)); if (existsSync(sf)) writeFileSync(sf, serialize(ssot));
    console.log(JSON.stringify(result, null, 2));
  } else if (cmd === 'stale') {
    // stale <proposals.md> [<ssot.md>] [--screens <screens.json>]: every picture in use, its age and staleness; nothing written.
    const [[pf, sf], opts] = flags(args);
    if (!pf) { console.error('usage: sync.mjs stale <proposals.md> [<ssot.md>] [--screens <screens.json>]'); process.exit(2); }
    const [proposals, ssot] = readPair(pf, sf);
    process.stdout.write(JSON.stringify(stalePictures(proposals, ssot, loadScreens(opts.screens || undefined)), null, 2));
  } else if (cmd === 'refresh') {
    // refresh <feature> <proposals.md> <ssot.md> [--screens <screens.json>]: retake every stale picture once, in place.
    const [[feature, pf, sf], opts] = flags(args);
    if (!feature || !pf || !sf) { console.error('usage: sync.mjs refresh <feature> <proposals.md> <ssot.md> [--screens <screens.json>] [--only <key,key>] [--udid <udid|name>]'); process.exit(2); }
    const screens = loadScreens(opts.screens || undefined);
    const [proposals, ssot] = readPair(pf, sf);
    const dir = imageDir(feature);
    let session = null; // the booted simulator, opened on the first retake
    const takePicture = async entry => {
      if (!session) { const booted = bootedUdid(typeof opts.udid === 'string' ? opts.udid : undefined); if (!booted) throw new Error('no booted simulator'); session = { ...stamp(), device: booted.name, runtime: booted.runtime, io: simulatorIo(booted.udid), dir }; }
      return capture(entry, session);
    };
    const only = typeof opts.only === 'string' ? commaList(opts.only) : undefined;
    const r = await refreshPictures(proposals, ssot, screens, { dir, takePicture, only });
    if (r.refreshed.some(x => x.from !== x.path)) { writeFileSync(pf, serialize(proposals)); if (existsSync(sf)) writeFileSync(sf, serialize(ssot)); }
    console.log(JSON.stringify(r, null, 2));
  } else if (cmd === 'wave') {
    // wave <feature> <issues dir> [--branch <b>] [--open | --close <n> --merged 02,04 --failed 06 --suite green|red]
    const [[feature, dir], opts] = flags(args);
    if (!feature || !dir) { console.error('usage: sync.mjs wave <feature> <issues dir> [--branch <branch>] [--open | --close <n> [--merged NN,NN] [--failed NN,NN] [--suite green|red]]'); process.exit(2); }
    const root = process.cwd();
    const logFile = join(dirname(dir.replace(/\/+$/, '')), 'waves.json');
    const log = existsSync(logFile) ? JSON.parse(readFileSync(logFile, 'utf8')) : [];
    const today = new Date().toISOString().slice(0, 10);
    const mark = (n, status) => { const f = ticketFiles(root, dir).find(x => basename(x).startsWith(n + '-')); if (f) writeFileSync(f, setTicketStatus(readFileSync(f, 'utf8'), status)); };
    if (opts.close) {
      const entry = waveClose(log, opts.close, { merged: commaList(opts.merged), failed: commaList(opts.failed), suite: opts.suite || '' });
      for (const n of entry.merged) mark(n, `done (wave ${entry.number}, ${today})`);
      for (const n of entry.failed) mark(n, `ready-for-agent (wave ${entry.number} failed, ${today})`);
      writeFileSync(logFile, JSON.stringify(log, null, 2));
      process.stdout.write(JSON.stringify(entry, null, 2));
    } else {
      const plan = wavePlan(feature, dir, { branch: opts.branch });
      if (opts.open && plan.wave.length) {
        // Mark the tickets, commit every ticket file of the feature so the worktrees see them, and take that commit as the base every agent checks against.
        const entry = waveOpen(log, { tickets: plan.wave.map(t => t.number), base: plan.base, branch: plan.branch });
        for (const t of plan.wave) mark(t.number, `in-progress (wave ${entry.number}, ${today})`);
        const add = spawnSync('git', ['add', '--', dir], { cwd: root, encoding: 'utf8' });
        const commit = add.status === 0 ? spawnSync('git', ['commit', '-q', '-m', `wave ${entry.number} opened for ${feature}: tickets ${entry.tickets.join(', ')} [skip ci]`, '--', dir], { cwd: root, encoding: 'utf8' }) : add;
        if (commit.status !== 0) { console.error(`wave --open could not commit the ticket files: ${(commit.stderr || commit.stdout || '').trim()}`); process.exit(1); }
        entry.base = plan.base = gitOut(root, 'rev-parse', 'HEAD');
        mkdirSync(dirname(logFile), { recursive: true }); writeFileSync(logFile, JSON.stringify(log, null, 2));
        plan.uncommitted = []; plan.number = entry.number; plan.startedAt = entry.startedAt;
      }
      process.stdout.write(JSON.stringify(plan, null, 2));
    }
  } else if (cmd === 'touched-screens') {
    // touched-screens --since <commit> [--screens <screens.json>] [<file>...]: the registry screens drawn from the files that changed since the commit (committed, uncommitted or untracked), plus any files given; keys as JSON
    const [files, opts] = flags(args);
    if (!opts.since && !files.length) { console.error('usage: sync.mjs touched-screens --since <commit> [--screens <screens.json>] [<file>...]'); process.exit(2); }
    // Committed since the commit, changed in the working tree, or not yet tracked (a new screen file counts too): `changedSince` over the whole tree.
    const changed = typeof opts.since === 'string' ? changedSince(opts.since, ['.']) : [];
    if (changed === null) { console.error(`touched-screens: ${opts.since} is not a commit this clone has`); process.exit(2); }
    process.stdout.write(JSON.stringify(touchedScreens([...new Set([...changed, ...files])], loadScreens(opts.screens || undefined))));
  } else if (cmd === 'simulator') {
    // simulator add <name> [--from <udid|name>] | drop <name|udid> | list [<prefix>]: a simulator per agent, copied from the dev one (app + data)
    const [[op, name], opts] = flags(args);
    if (op === 'add' && name) process.stdout.write(JSON.stringify(createSimulator(name, { from: typeof opts.from === 'string' ? opts.from : undefined })));
    else if (op === 'drop' && name) process.stdout.write(JSON.stringify(deleteSimulator(name)));
    else if (op === 'list') process.stdout.write(JSON.stringify(listSimulators(name || 'wave-'), null, 2));
    else { console.error('usage: sync.mjs simulator add <name> [--from <udid|name>] | drop <name|udid> | list [<prefix>]'); process.exit(2); }
  } else {
    console.error('usage: sync.mjs export|apply|answers|questions|linked|cite|pending|prepare|terms|question-first|fold|tickets|triage|next-id|images|asset|undrawn|draw|attach-svg|uncaptured|capture|attach-image|pictures|stale|refresh|wave|touched-screens|simulator ...'); process.exit(2);
  }
}
