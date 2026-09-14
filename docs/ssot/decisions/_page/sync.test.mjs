// node --test docs/ssot/decisions/_page/sync.test.mjs
//
// Every case feeds a markdown fixture and checks the markdown or documents that
// come out. None of them inspects how the parser walks lines.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse, serialize, apply, answers, questionFirst, fold, clauses, toDocuments, ticketDocument, triage, nextId, assetId, staleImages, recordAsset } from './sync.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const cli = join(here, 'sync.mjs');

const fixture = `# Proposed decisions: Sample

Feature: sm
Feature name: Sample

## sm-001 · The sheet has one height
- category: Sheet
- status: proposed
- image: none
- caption:
- screen: Vana sheet
- source: ticket 08

**Context.** The sheet rises over the screen. The export drew three heights. The question was how many heights the sheet has.

**Decision.** 1. One height.
2. Full screen only by its button.

**Why.** Simpler.

**What else was considered.** Three heights.

**What it touches.** VanaSheet.

## sm-002 · Drags come from the export
- category: Sheet
- status: proposed
- image: none
- caption:
- screen: Vana sheet
- source: ticket 08; vana-sheet.md

**Context.** Pixel thresholds. The question was what distances move the sheet.

**Decision.** 24 px up expands.

**Why.** The export's numbers.

**What else was considered.** none recorded

**What it touches.** VanaSheet.
`;

const questionFixture = `# Proposed decisions: Sample

Feature: sm
Feature name: Sample

## sm-010 · Which entry points continue a conversation
- category: Vana
- kind: question
- status: open
- linked: sm-002
- image: none
- caption:
- screen: Vana chat
- source: Lee on the page 2026-09-13

**Context.** Vana can be reached from several places.

**Question.** Which entry points continue and which start fresh?

**Why.** Two entry points disagreeing lands the athlete somewhere unexpected.

**What it touches.** Vana chat.

## sm-011 · New meal plan starts a new conversation
- category: Vana
- status: proposed
- image: none
- caption:
- screen: Vana chat
- source: grill 2026-09-14

**Context.** The button on the Plan tab.

**Question.** Does New meal plan continue today's thread?

**Decision.** No. It starts a new conversation.

**Why.** That is what the button says.

**What else was considered.** Continuing today's thread.

**What it touches.** Plan tab.
`;

const emptySsot = () => ({ title: 'Decisions: Sample', head: { feature: 'sm', 'feature name': 'Sample' }, decisions: [], preamble: [] });
const at = '2026-09-14T10:00:00Z';

test('round trip is byte-identical', () => {
  assert.equal(serialize(parse(fixture)), fixture);
  assert.equal(serialize(parse(questionFixture)), questionFixture);
});

test('approve moves a section from proposals to the record with a dated status line', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  const r = apply({ 'sm-001': { verdict: 'approve', at } }, proposals, ssot);
  assert.deepEqual(r.applied, [{ id: 'sm-001', to: 'approved' }]);
  assert.deepEqual(proposals.decisions.map(d => d.id), ['sm-002']);
  const text = serialize(ssot);
  assert.match(text, /^## sm-001 · The sheet has one height$/m);
  assert.match(text, /^- status: approved$/m);
  assert.match(text, /^> 2026-09-14 approved$/m);
  assert.doesNotMatch(serialize(proposals), /sm-001/);
});

test('approve on an already-approved id marks it withdrawn and keeps the earlier history line', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  apply({ 'sm-001': { verdict: 'approve', at } }, proposals, ssot);
  const r = apply({ 'sm-001': { verdict: 'approve', at: '2026-09-15T10:00:00Z' } }, proposals, ssot);
  assert.deepEqual(r.applied, [{ id: 'sm-001', to: 'withdrawn' }]);
  const text = serialize(ssot);
  assert.match(text, /^- status: withdrawn$/m);
  assert.match(text, /^> 2026-09-14 approved\n> 2026-09-15 withdrawn$/m);
});

test('reject records the reason in the record file', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  const r = apply({ 'sm-002': { verdict: 'reject', text: 'the export was wrong', at } }, proposals, ssot);
  assert.deepEqual(r.applied, [{ id: 'sm-002', to: 'rejected' }]);
  const text = serialize(ssot);
  assert.match(text, /^- status: rejected$/m);
  assert.match(text, /^> 2026-09-14 rejected: the export was wrong$/m);
  assert.doesNotMatch(serialize(proposals), /sm-002/);
});

test('amend produces a proposal carrying the original, Lee\'s words, and the rewrite', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  const r = apply({ 'sm-001': { verdict: 'amend', text: 'keep it simple', dropped: [2], at } }, proposals, ssot);
  assert.deepEqual(r.applied, [{ id: 'sm-001', to: 'amended' }]);
  assert.equal(ssot.decisions.length, 0);
  const d = proposals.decisions[0];
  d.parts.decision = '1. One height.'; // the skill's rewrite
  const text = serialize(proposals);
  assert.match(text, /^- status: amended$/m);
  assert.match(text, /^\*\*Original\.\*\* 1\. One height\.\n2\. Full screen only by its button\.$/m);
  assert.match(text, /^\*\*Lee said\.\*\* Dropped clause 2\. keep it simple$/m);
  assert.match(text, /^\*\*Decision\.\*\* 1\. One height\.$/m);
  assert.equal(serialize(parse(text)), text);
});

test('an unknown id is refused and nothing is written', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  const before = serialize(ssot);
  const r = apply({ 'sm-999': { verdict: 'approve', at }, 'sm-998': { verdict: 'reject', text: 'x', at }, 'sm-997': { verdict: 'amend', text: 'y', at } }, proposals, ssot);
  assert.equal(r.applied.length, 0);
  assert.deepEqual(r.refused.map(x => x.id).sort(), ['sm-997', 'sm-998', 'sm-999']);
  assert.equal(serialize(proposals), fixture);
  assert.equal(serialize(ssot), before);
});

test('the CLI writes only the two named files', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const pf = join(dir, 'decisions.md'), sf = join(dir, 'ssot.md'), other = join(dir, 'other.md'), vf = join(dir, 'verdicts.json');
  writeFileSync(pf, fixture); writeFileSync(other, fixture);
  writeFileSync(vf, JSON.stringify({ verdicts: { 'sm-001': { verdict: 'approve', at, by: 'Lee' } } }));
  const out = JSON.parse(execFileSync('node', [cli, 'apply', vf, pf, sf], { encoding: 'utf8' }));
  assert.deepEqual(out.applied, [{ id: 'sm-001', to: 'approved' }]);
  assert.equal(readFileSync(other, 'utf8'), fixture);
  assert.match(readFileSync(sf, 'utf8'), /^> 2026-09-14 approved by Lee$/m);
  assert.doesNotMatch(readFileSync(pf, 'utf8'), /sm-001/);
});

test('a verdict carrying `by` names the giver in the history line; one without still applies', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  const r = apply({ 'sm-001': { verdict: 'approve', at, by: 'Xuan' }, 'sm-002': { verdict: 'reject', text: 'no', at } }, proposals, ssot);
  assert.equal(r.applied.length, 2);
  const text = serialize(ssot);
  assert.match(text, /^> 2026-09-14 approved by Xuan$/m);
  assert.match(text, /^> 2026-09-14 rejected: no$/m);
  const r2 = apply({ 'sm-001': { verdict: 'approve', at, by: 'Lee' } }, proposals, ssot);
  assert.deepEqual(r2.applied, [{ id: 'sm-001', to: 'withdrawn' }]);
  assert.match(serialize(ssot), /^> 2026-09-14 withdrawn by Lee$/m);
  const p2 = parse(fixture);
  apply({ 'sm-001': { verdict: 'amend', text: 'shorter', at, by: 'Lee' } }, p2, emptySsot());
  assert.match(serialize(p2), /^> 2026-09-14 amended by Lee$/m);
  const p3 = parse(fixture);
  apply({ 'sm-001': { verdict: 'amend', text: 'shorter', at } }, p3, emptySsot());
  assert.match(serialize(p3), /^> 2026-09-14 amended$/m);
});

test('answers closes an open question and links the decision back', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  const r = answers('sm-010', 'sm-011', proposals, ssot, '2026-09-14');
  assert.deepEqual(r, { applied: [{ question: 'sm-010', decision: 'sm-011' }], refused: [] });
  const text = serialize(proposals);
  const q = text.slice(text.indexOf('## sm-010'), text.indexOf('## sm-011'));
  assert.match(q, /^- status: answered$/m);
  assert.match(q, /^> 2026-09-14 answered by sm-011$/m);
  const d = text.slice(text.indexOf('## sm-011'));
  assert.match(d, /^- linked: sm-010$/m);
  assert.equal(serialize(parse(text)), text);
});

test('answers finds the decision in the record and keeps an existing link', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  apply({ 'sm-011': { verdict: 'approve', at } }, proposals, ssot);
  ssot.decisions[0].meta.linked = 'sm-002';
  const r = answers('sm-010', 'sm-011', proposals, ssot, '2026-09-14');
  assert.equal(r.applied.length, 1);
  assert.match(serialize(ssot), /^- linked: sm-002; sm-010$/m);
  assert.match(serialize(proposals), /^- status: answered$/m);
});

test('answers refuses a question that is not open, and unknown ids', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  assert.equal(answers('sm-011', 'sm-011', proposals, ssot).refused[0].why, 'not an open question');
  assert.equal(answers('sm-010', 'sm-999', proposals, ssot).refused[0].why, 'unknown decision sm-999');
  assert.equal(answers('sm-999', 'sm-011', proposals, ssot).refused[0].why, 'unknown question sm-999');
  answers('sm-010', 'sm-011', proposals, ssot, '2026-09-14');
  const again = answers('sm-010', 'sm-011', proposals, ssot, '2026-09-15');
  assert.equal(again.refused[0].why, 'not an open question');
  assert.equal(serialize(proposals).match(/^> /gm).length, 1);
});

test('the answers CLI writes the link both ways and leaves other files alone', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const pf = join(dir, 'decisions.md'), sf = join(dir, 'ssot.md'), other = join(dir, 'other.md');
  writeFileSync(pf, questionFixture); writeFileSync(sf, serialize(emptySsot())); writeFileSync(other, questionFixture);
  const out = JSON.parse(execFileSync('node', [cli, 'answers', 'sm-010', 'sm-011', pf, sf], { encoding: 'utf8' }));
  assert.equal(out.applied.length, 1);
  const p = readFileSync(pf, 'utf8');
  assert.match(p, /^- status: answered$/m);
  assert.match(p, /^- linked: sm-010$/m);
  assert.equal(readFileSync(other, 'utf8'), questionFixture);
  assert.equal(readFileSync(sf, 'utf8'), serialize(emptySsot()));
  // A second run finds the question closed: exit 1, nothing written.
  let err;
  try { execFileSync('node', [cli, 'answers', 'sm-010', 'sm-011', pf, sf], { encoding: 'utf8', stdio: 'pipe' }); } catch (e) { err = e; }
  assert.equal(err?.status, 1);
  assert.match(String(err.stdout), /not an open question/);
  assert.equal(readFileSync(pf, 'utf8'), p);
});

test('the mealplanning record and proposals round-trip byte-identical', { skip: !existsSync(join(here, '..', 'mealplanning.md')) }, () => {
  for (const f of [join(here, '..', 'mealplanning.md'), join(here, '..', '..', '..', '..', '.scratch', 'mealplanning', 'decisions.md')]) {
    if (!existsSync(f)) continue;
    const text = readFileSync(f, 'utf8');
    assert.equal(serialize(parse(text)), text, f);
  }
});

test('questionFirst lifts the closing question and is idempotent', () => {
  const doc = parse(fixture);
  assert.equal(questionFirst(doc), 2);
  assert.equal(doc.decisions[0].parts.question, 'How many heights the sheet has.');
  assert.equal(doc.decisions[0].parts.context, 'The sheet rises over the screen. The export drew three heights.');
  assert.equal(questionFirst(doc), 0);
  const again = parse(serialize(doc));
  assert.equal(again.decisions[0].parts.question, 'How many heights the sheet has.');
});

test('a numbered decision is a clause list, prose is not', () => {
  const doc = parse(fixture);
  assert.deepEqual(clauses(doc.decisions[0].parts.decision), ['One height.', 'Full screen only by its button.']);
  assert.deepEqual(clauses(doc.decisions[1].parts.decision), []);
  const docs = toDocuments(doc);
  assert.equal(docs[0].clauses.length, 2);
  assert.equal(docs[0].detail, false);
});

test('fold replaces members with one new proposal and refuses ruled-on ids', () => {
  const doc = parse(fixture);
  const ssot = { decisions: [] };
  const plan = [{ from: ['sm-001', 'sm-002'], into: { title: 'The sheet', question: 'How does the sheet size and move?', context: 'One card.', decision: '1. One height.\n2. Standard drag.', why: 'Simpler.', touches: 'VanaSheet', details: '24 px up expands.', detail: true, work: 'pending' } }];
  const r = fold(plan, doc, ssot, '2026-09-14');
  assert.deepEqual(r.folded, [{ id: 'sm-003', from: ['sm-001', 'sm-002'] }]);
  assert.equal(doc.decisions.length, 1);
  const d = doc.decisions[0];
  assert.equal(d.id, 'sm-003');
  assert.equal(d.meta.source, 'ticket 08; vana-sheet.md');
  assert.equal(d.meta.detail, 'yes');
  assert.equal(d.meta.work, 'pending');
  assert.deepEqual(d.history, [{ date: '2026-09-14', note: 'folded from sm-001, sm-002' }]);
  const text = serialize(doc);
  assert.match(text, /\*\*Details\.\*\* 24 px up expands\./);
  assert.equal(serialize(parse(text)), text);
  const r2 = fold([{ from: ['sm-003', 'sm-999'], into: { title: 'x' } }], doc, ssot);
  assert.equal(r2.refused.length, 1);
  assert.equal(doc.decisions.length, 1);
});

test('fold refuses a member that is no longer proposed', () => {
  const doc = parse(fixture);
  doc.decisions[1].meta.status = 'open';
  const r = fold([{ from: ['sm-001', 'sm-002'], into: { title: 'x', decision: 'y' } }], doc, { decisions: [] });
  assert.equal(r.folded.length, 0);
  assert.match(r.refused[0].why, /sm-002 is open/);
  assert.equal(doc.decisions.length, 2);
});

test('ticketDocument reads the three header lines and cited ids', () => {
  const t = ticketDocument('mp', '.scratch/mealplanning/issues/09-the-companion.md', `# 09: The companion that speaks first

**Status:** done (2026-09-11)
**Blocked by:** None
**Next:** ticket 10.

Cites mp-082 and mp-083, and mp-082 again.
`, 'mp');
  assert.equal(t.id, 'mp-09');
  assert.equal(t.title, 'The companion that speaks first');
  assert.equal(t.state, 'done');
  assert.equal(t.owed, false);
  assert.deepEqual(t.cites, ['mp-082', 'mp-083']);
  const u = ticketDocument('mp', 'x/12-meal-plan-moments.md', '# 12: Moments\n\n**Status:** needs-grilling (not ready)\n**Blocked by:** 10\n');
  assert.equal(u.state, 'needs grilling');
  const v = ticketDocument('mp', 'x/11-launcher.md', '# 11: L\n\n**Status:** built 2026-09-11; the simulator check is still owed\n');
  assert.equal(v.state, 'done');
  assert.equal(v.owed, true);
  const w = ticketDocument('kd', 'x/09-legacy.md', '# 09: A draft\n\n**What to build:** x\n');
  assert.equal(w.state, 'proposed');
});

test('a page document says who ruled and when, from its last verdict line', () => {
  const ssot = emptySsot();
  const proposals = parse(fixture);
  apply({ 'sm-001': { verdict: 'approve', at, by: 'Xuan' }, 'sm-002': { verdict: 'reject', text: 'too early', at } }, proposals, ssot);
  const [a, b] = toDocuments(ssot);
  assert.deepEqual(a.ruled, { status: 'approved', by: 'Xuan', date: '2026-09-14' });
  assert.deepEqual(b.ruled, { status: 'rejected', by: '', date: '2026-09-14' });
  // A fold line is history but not a ruling; a proposal with no verdict has no ruling.
  const folded = parse(fixture.replace('**What it touches.** VanaSheet.\n\n## sm-002', '**What it touches.** VanaSheet.\n\n> 2026-09-13 folded from sm-090, sm-091\n\n## sm-002'));
  assert.equal(toDocuments(folded)[0].ruled, null);
  assert.equal(toDocuments(folded)[1].ruled, null);
  // The latest ruling wins: approved then withdrawn shows withdrawn.
  apply({ 'sm-001': { verdict: 'approve', at: '2026-09-15T10:00:00Z', by: 'Lee' } }, proposals, ssot, '2026-09-15');
  assert.deepEqual(toDocuments(ssot)[0].ruled, { status: 'withdrawn', by: 'Lee', date: '2026-09-15' });
  // Change cards name their acceptor too; the reason after ':' never leaks into the name.
  const p2 = parse(fixture), s2 = emptySsot();
  apply({ c1: { verdict: 'change', accepted: true, by: 'Xuan', at, change: { op: 'edit', id: 'sm-001', title: 'Two heights' } },
          c2: { verdict: 'change', accepted: true, by: 'Xuan', at, change: { op: 'delete', id: 'sm-002', reason: 'stale: numbers moved' } } }, p2, s2);
  assert.match(serialize(p2), /^> 2026-09-14 edited from the category discussion on 2026-09-14 by Xuan$/m);
  assert.match(serialize(s2), /^> 2026-09-14 removed from the category discussion on 2026-09-14 by Xuan: stale: numbers moved$/m);
  assert.deepEqual(toDocuments(p2)[0].ruled, { status: 'edited', by: 'Xuan', date: '2026-09-14' });
  assert.deepEqual(toDocuments(s2)[0].ruled, { status: 'removed', by: 'Xuan', date: '2026-09-14' });
});

test('triage splits verdicts into clear-cut ones and ones carrying the ratifier\'s words', () => {
  const verdicts = {
    'sm-001': { verdict: 'approve', at, by: 'Lee' },
    'sm-002': { verdict: 'withdraw', at, by: 'Lee' },
    'sm-003': { verdict: 'reject', text: 'too early', at, by: 'Lee' },
    'sm-004': { verdict: 'reject', text: 'why not the other way?', at, by: 'Lee' },
    'sm-005': { verdict: 'amend', text: 'one height only', dropped: [2], at, by: 'Lee' },
    'change-1': { verdict: 'change', accepted: true, change: { op: 'add', title: 'X' }, at, by: 'Lee' },
    'change-2': { verdict: 'change', accepted: false, change: { op: 'add', title: 'Y' }, at, by: 'Lee' },
    'term-1': { verdict: 'term', term: 'Moment', definition: 'A time Vana speaks first.', at, by: 'Lee' },
  };
  const t = triage(verdicts);
  assert.deepEqual(Object.keys(t.clear), ['sm-001', 'sm-002', 'sm-003']);
  assert.deepEqual(Object.keys(t.words), ['sm-004', 'sm-005', 'change-1', 'term-1']);
  assert.deepEqual(Object.keys(t.other), ['change-2']);
  assert.equal(t.words['sm-004'].pile, 'a rejection that asks a question');
  // The CLI writes the two piles as files apply and terms can take as they are.
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  writeFileSync(join(dir, 'verdicts.json'), JSON.stringify({ sentAt: at, verdicts }));
  const out = execFileSync('node', [cli, 'triage', join(dir, 'verdicts.json'), '--out', dir], { encoding: 'utf8' });
  assert.match(out, /3 clear, 4 with words, 1 other/);
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(join(dir, 'clear.json'), 'utf8')).verdicts), ['sm-001', 'sm-002', 'sm-003']);
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(join(dir, 'words.json'), 'utf8')).verdicts), ['sm-004', 'sm-005', 'change-1', 'term-1']);
  // Only rewrites reach apply after the yes; a question-shaped reject never lands in the record.
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(join(dir, 'rewrites.json'), 'utf8')).verdicts), ['sm-005', 'change-1']);
});

test('next-id counts past both files and never reuses a number', () => {
  const proposals = parse(fixture), ssot = emptySsot();
  assert.equal(nextId(proposals, ssot), 'sm-003');
  apply({ 'sm-002': { verdict: 'approve', at } }, proposals, ssot);
  assert.equal(nextId(proposals, ssot), 'sm-003');
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  writeFileSync(join(dir, 'p.md'), serialize(proposals)); writeFileSync(join(dir, 's.md'), serialize(ssot));
  assert.equal(execFileSync('node', [cli, 'next-id', join(dir, 'p.md'), join(dir, 's.md')], { encoding: 'utf8' }).trim(), 'sm-003');
  // A feature with no record yet counts from its proposals alone.
  assert.equal(execFileSync('node', [cli, 'next-id', join(dir, 'p.md'), join(dir, 'missing.md')], { encoding: 'utf8' }).trim(), 'sm-002');
});

test('an image uploads once and again only when the file changes', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const a = join(dir, 'a.png'), b = join(dir, 'b.png');
  writeFileSync(a, 'AAA'); writeFileSync(b, 'BBB');
  // The old shape (path -> id) still resolves and is never re-uploaded on its own.
  const assets = { [a]: '0123456789abcdef0123456789abcdef' };
  assert.equal(assetId(assets, a), '0123456789abcdef0123456789abcdef');
  assert.deepEqual(staleImages(assets, [a, b, join(dir, 'gone.png')]), [
    { path: b, why: 'new' },
    { path: join(dir, 'gone.png'), why: 'file missing' },
  ]);
  recordAsset(assets, b, 'fedcba9876543210fedcba9876543210');
  assert.equal(assetId(assets, b), 'fedcba9876543210fedcba9876543210');
  assert.match(assets[b].sha256, /^[0-9a-f]{64}$/);
  assert.deepEqual(staleImages(assets, [b]), []);
  writeFileSync(b, 'BBB2');
  assert.deepEqual(staleImages(assets, [b]), [{ path: b, why: 'changed' }]);
  // CLI: images lists what to upload; asset records one upload.
  const af = join(dir, 'assets.json'); writeFileSync(af, JSON.stringify(assets));
  const imgs = join(dir, '_images.json'); writeFileSync(imgs, JSON.stringify([a, b]));
  assert.deepEqual(JSON.parse(execFileSync('node', [cli, 'images', af, imgs], { encoding: 'utf8' })), [{ path: b, why: 'changed' }]);
  execFileSync('node', [cli, 'asset', af, b, '00000000000000000000000000000000']);
  assert.deepEqual(JSON.parse(execFileSync('node', [cli, 'images', af, imgs], { encoding: 'utf8' })), []);
  assert.equal(JSON.parse(readFileSync(af, 'utf8'))[b].id, '00000000000000000000000000000000');
  // prepare resolves imageAssetId through either shape.
  const md = fixture.replace('- image: none\n- caption:\n- screen: Vana sheet\n- source: ticket 08\n', `- image: ${b}\n- caption:\n- screen: Vana sheet\n- source: ticket 08\n`);
  writeFileSync(join(dir, 'p.md'), md);
  execFileSync('node', [cli, 'prepare', join(dir, 'p.md'), '--assets', af, '--out', join(dir, 'out')]);
  assert.equal(JSON.parse(readFileSync(join(dir, 'out', 'sm-001.json'), 'utf8')).imageAssetId, '00000000000000000000000000000000');
});
