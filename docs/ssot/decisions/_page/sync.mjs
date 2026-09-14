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
//   node sync.mjs pending <decisions.md>                -> count of proposed/amended
//   node sync.mjs answers <question id> <decision id> <proposals.md> <ssot.md>

import { readFileSync, writeFileSync, existsSync } from 'node:fs';

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
export function toDocuments(doc, { order = 0 } = {}) {
  const feature = doc.head.feature;
  return doc.decisions.map((d, n) => ({
    id: d.id,
    feature,
    category: d.meta.category || 'Other',
    title: d.title,
    kind: d.meta.kind || 'decision',
    status: d.meta.status || 'proposed',
    linked: d.meta.linked || '',
    source: d.meta.source || '',
    screen: d.meta.screen || '',
    detail: d.meta.detail === 'yes',
    work: d.meta.work || '',
    image: d.meta.image && d.meta.image !== 'none' ? d.meta.image : '',
    imageCaption: d.meta.caption || '',
    context: d.parts.context || '',
    question: d.parts.question || '',
    decision: d.parts.decision || '',
    clauses: clauses(d.parts.decision || ''),
    why: d.parts.why || '',
    alternatives: d.parts.alternatives || '',
    touches: d.parts.touches || '',
    details: d.parts.details || '',
    original: d.parts.original || '',
    leeSaid: d.parts.leeSaid || '',
    order: order + n,
  }));
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
  const statusLine = line('Status');
  const s = statusLine.toLowerCase();
  const state = /wontfix/.test(s) ? 'dropped' : /^(done|built|verified|typed-postcode|send,|partly verified)/.test(s) ? 'done' : /needs-grilling|needs grilling/.test(s) ? 'needs grilling' : /ready/.test(s) ? 'ready' : /after|blocked/.test(s) ? 'waiting' : s ? 'other' : 'proposed';
  const owed = /owed|not yet (seen|looked)|awaiting a look|untested|unverified|not exercised|fails/.test(s);
  const cites = [...new Set((text.match(new RegExp(`\\b${idPrefix || '[a-z]+'}-\\d{3}\\b`, 'g')) || []))].sort();
  return { id: `${feature}-${num}`, feature, number: num, title, status: statusLine, state, owed, blockedBy: line('Blocked by'), next: line('Next'), cites, file, order: parseInt(num, 10) || 0 };
}

function nextId(proposals, ssot) {
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
        proposals.decisions.push({ id: nid, title: c.title || 'Untitled', meta: { category: v.category || 'Other', status: 'proposed', image: 'none', caption: '', screen: c.screen || '', source: `Lee, ${note}` }, parts: { context: c.context || '', decision: c.decision || '', why: c.why || '', alternatives: c.alternatives || 'none recorded', touches: c.touches || '' }, history: [{ date, note: 'added ' + note }] });
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
        d.history.push({ date, note: 'edited ' + note });
        applied.push({ id, to: 'amended ' + c.id });
      } else if (c.op === 'delete') {
        const d = take(c.id) || (inSsot(c.id) && inSsot(c.id).meta.status !== 'rejected' ? inSsot(c.id) : null);
        if (!d) { refused.push({ id, why: `unknown id ${c.id}` }); continue; }
        d.meta.status = 'rejected';
        d.history.push({ date, note: 'removed ' + note + (c.reason ? `: ${c.reason}` : '') });
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
  const links = (d.meta.linked || '').split(';').map(s => s.trim()).filter(Boolean);
  if (!links.includes(questionId)) links.push(questionId);
  d.meta.linked = links.join('; ');
  return { applied: [{ question: questionId, decision: decisionId }], refused: [] };
}

// ---- CLI ----
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
    const files = [], opts = {};
    for (let k = 0; k < args.length; k++) { if (args[k].startsWith('--')) { opts[args[k].slice(2)] = args[++k]; } else files.push(args[k]); }
    const assets = opts.assets && existsSync(opts.assets) ? JSON.parse(readFileSync(opts.assets, 'utf8')) : {};
    const { resolve } = await import('node:path'); const out = resolve(opts.out || 'docs-out'); mkdirSync(out, { recursive: true });
    let order = 0; const entries = [];
    for (const f of files) {
      const d = parse(readFileSync(f, 'utf8'));
      for (const doc of toDocuments(d, { order })) {
        const { id, ...body } = doc;
        body.imageAssetId = body.image && assets[body.image] ? assets[body.image] : '';
        writeFileSync(`${out}/${id}.json`, JSON.stringify(body, null, 2));
        entries.push({ op: 'set', collection: 'decisions', doc_id: id, file_path: `${out}/${id}.json` });
      }
      order += 1000;
    }
    // Tickets ride along: --tickets <feature>=<issues dir> (repeatable via commas).
    for (const spec of (opts.tickets || '').split(',').filter(Boolean)) {
      const [feature, dir] = spec.split('=');
      const { readdirSync } = await import('node:fs');
      for (const f of readdirSync(dir).filter(x => /^\d+-.*\.md$/.test(x)).sort()) {
        const t = ticketDocument(feature, `${dir}/${f}`, readFileSync(`${dir}/${f}`, 'utf8'));
        const { id, ...body } = t;
        writeFileSync(`${out}/ticket-${id}.json`, JSON.stringify(body, null, 2));
        entries.push({ op: 'set', collection: 'tickets', doc_id: id, file_path: `${out}/ticket-${id}.json` });
      }
    }
    const batches = []; for (let k = 0; k < entries.length; k += 50) batches.push(entries.slice(k, k + 50));
    writeFileSync(`${out}/_batches.json`, JSON.stringify(batches, null, 2));
    const images = [...new Set(entries.map(e => JSON.parse(readFileSync(e.file_path, 'utf8')).image).filter(Boolean))];
    writeFileSync(`${out}/_images.json`, JSON.stringify(images, null, 2));
    console.log(`${entries.length} documents in ${batches.length} batches; ${images.length} distinct images (${images.filter(i => !assets[i]).length} not yet uploaded)`);
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
  } else if (cmd === 'pending') {
    const d = parse(readFileSync(args[0], 'utf8'));
    console.log(d.decisions.filter(x => ['proposed', 'amended'].includes(x.meta.status)).length);
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
    const [feature, dir] = args; const { readdirSync } = await import('node:fs');
    const docs = readdirSync(dir).filter(x => /^\d+-.*\.md$/.test(x)).sort().map(f => ticketDocument(feature, `${dir}/${f}`, readFileSync(`${dir}/${f}`, 'utf8')));
    process.stdout.write(JSON.stringify(docs, null, 2));
  } else {
    console.error('usage: sync.mjs export|apply|answers|pending|prepare|terms|question-first|fold|tickets ...'); process.exit(2);
  }
}
