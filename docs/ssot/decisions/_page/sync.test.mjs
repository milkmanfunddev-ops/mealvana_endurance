// node --test docs/ssot/decisions/_page/sync.test.mjs
//
// Every case feeds a markdown fixture and checks the markdown or documents that
// come out. None of them inspects how the parser walks lines.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse, serialize, apply, answers, openQuestions, answeredLinks, specCitations, questionFirst, fold, clauses, toDocuments, ticketDocument, triage, nextId, assetId, staleImages, recordAsset, pendingIn, ticketPlan, publishTickets, svgCheck, undrawn, attachSvg, uncaptured, attachImage, readSidecar, changedSince, captureStatus, stalePictures, refreshPictures, dropAsset, ticketFrontier, designRenderings, touchedScreens, setTicketStatus, wavePlan, waveOpen, waveClose, elapsed } from './sync.mjs';
import { matchScreen, findElement, runDrive, capture, sidecar, loadScreens, runtimeName, bootedUdid, createSimulator, deleteSimulator, listSimulators, claimSimulator, releaseSimulator } from './capture.mjs';
import { draw, TOKENS } from './diagram.mjs';

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

test('openQuestions lists only open questions, in file order, across both files', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  ssot.decisions.push({ ...parse(questionFixture).decisions[0], id: 'sm-005', title: 'An older question in the record' });
  const qs = openQuestions(proposals, ssot);
  assert.deepEqual(qs.map(q => q.id), ['sm-010', 'sm-005']);
  assert.equal(qs[0].title, 'Which entry points continue a conversation');
  assert.equal(qs[0].linked, 'sm-002');
  assert.equal(qs[0].question, 'Which entry points continue and which start fresh?');
  assert.equal(qs[0].touches, 'Vana chat.');
  answers('sm-010', 'sm-011', proposals, ssot, '2026-09-14');
  assert.deepEqual(openQuestions(proposals, ssot).map(q => q.id), ['sm-005']);
});

test('the questions CLI prints open questions as JSON and writes nothing', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const pf = join(dir, 'decisions.md'), sf = join(dir, 'ssot.md');
  writeFileSync(pf, questionFixture); writeFileSync(sf, serialize(emptySsot()));
  const out = JSON.parse(execFileSync('node', [cli, 'questions', pf, sf], { encoding: 'utf8' }));
  assert.deepEqual(out.map(q => q.id), ['sm-010']);
  assert.equal(readFileSync(pf, 'utf8'), questionFixture);
  const none = JSON.parse(execFileSync('node', [cli, 'questions', pf, join(dir, 'missing.md')], { encoding: 'utf8' }));
  assert.equal(none.length, 1);
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

test('answeredLinks lists decisions that answered a question, and flags ones later ruled out', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  assert.deepEqual(answeredLinks(proposals, ssot), []);           // sm-010 is still open
  answers('sm-010', 'sm-011', proposals, ssot, '2026-09-14');
  const links = answeredLinks(proposals, ssot);
  assert.deepEqual(links.map(l => [l.id, l.question, l.status, l.stale]), [['sm-011', 'sm-010', 'proposed', false]]);
  assert.equal(links[0].title, 'New meal plan starts a new conversation');
  assert.equal(links[0].questionTitle, 'Which entry points continue a conversation');
  apply({ 'sm-011': { verdict: 'reject', text: 'not yet', at } }, proposals, ssot);
  const after = answeredLinks(proposals, ssot);
  assert.deepEqual(after.map(l => [l.id, l.status, l.stale]), [['sm-011', 'rejected', true]]);
});

const specFixture = `# Sample

## Problem Statement

People lose track.

## Implementation Decisions

**One height.** The sheet has one height. (sm-001)

**Drags.** Thresholds come from the export. (sm-002)

- A bullet with no id behind it.

**Two ids.** One good, one nobody knows. (sm-001, sm-999)

**Mixed.** One that stands and one that fell, plus prose with a sha-256 in it. (sm-001, sm-002)

## Testing Decisions

- Seam: the sync module. (sm-011)

## Out of Scope

Nothing here counts. (sm-002)
`;

test('specCitations reads the two decision sections and sorts paragraphs by what they cite', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  ssot.decisions.push({ ...parse(fixture).decisions[0], meta: { ...parse(fixture).decisions[0].meta, status: 'approved' } });
  ssot.decisions.push({ ...parse(fixture).decisions[1], meta: { ...parse(fixture).decisions[1].meta, status: 'rejected' } });
  const r = specCitations(specFixture, proposals, ssot);
  assert.deepEqual(r.paragraphs.map(p => [p.section, p.ids]), [
    ['Implementation Decisions', ['sm-001']],
    ['Implementation Decisions', ['sm-002']],
    ['Implementation Decisions', []],
    ['Implementation Decisions', ['sm-001', 'sm-999']],
    ['Implementation Decisions', ['sm-001', 'sm-002']],
    ['Testing Decisions', ['sm-011']],
  ]);
  assert.deepEqual(r.statuses, { 'sm-001': 'approved', 'sm-002': 'rejected', 'sm-011': 'proposed', 'sm-999': 'unknown' });
  assert.deepEqual(r.rejected.map(p => [p.text.slice(0, 9), p.gone]), [['**Drags.*', ['sm-002']], ['**Mixed.*', ['sm-002']]]);
  assert.deepEqual(r.uncited.map(p => p.text), ['- A bullet with no id behind it.']);
  assert.deepEqual(r.unknown, ['sm-999']);
  assert.deepEqual(r.pending, ['sm-011']);
  assert.deepEqual(r.pendingSpec, []);
  proposals.decisions[1].meta.category = 'Spec';
  assert.deepEqual(specCitations(specFixture, proposals, ssot).pendingSpec, ['sm-011']);
});

test('specCitations names answered-question decisions the spec never states', () => {
  const proposals = parse(questionFixture), ssot = emptySsot();
  answers('sm-010', 'sm-011', proposals, ssot, '2026-09-14');
  assert.deepEqual(specCitations(specFixture, proposals, ssot).unstated, []);
  assert.deepEqual(specCitations(specFixture.replace('(sm-011)', ''), proposals, ssot).unstated, ['sm-011']);
});

test('the linked and cite CLIs print JSON and write nothing', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const pf = join(dir, 'decisions.md'), sf = join(dir, 'ssot.md'), spec = join(dir, 'spec.md');
  writeFileSync(pf, questionFixture); writeFileSync(sf, serialize(emptySsot())); writeFileSync(spec, specFixture);
  execFileSync('node', [cli, 'answers', 'sm-010', 'sm-011', pf, sf]);
  const linked = JSON.parse(execFileSync('node', [cli, 'linked', pf, sf], { encoding: 'utf8' }));
  assert.deepEqual(linked.map(l => l.id), ['sm-011']);
  const cite = JSON.parse(execFileSync('node', [cli, 'cite', spec, pf, sf], { encoding: 'utf8' }));
  assert.deepEqual(cite.pending, ['sm-011']);
  assert.deepEqual(cite.unknown, ['sm-001', 'sm-002', 'sm-999']);
  assert.equal(readFileSync(spec, 'utf8'), specFixture);
});

const ticketFixture = `# Proposed decisions: Sample

Feature: sm
Feature name: Sample

## sm-020 · Ticket 03: The sync module learns the plan
- category: Tickets
- status: proposed
- image: none
- screen: none (tooling)
- source: tickets sm 2026-09-14
- ticket: 03
- depends: sm-001, sm-004

**Context.** The problem statement. Slice 1 of 3.

**Question.** Is this the right first slice?

**Decision.** An agent runs the plan command and sees edges. Blocked by nothing.

**Why.** Everything else reads the plan.

**What else was considered.** Folding it into 04.

**What it touches.** docs/ssot/decisions/_page/sync.mjs, docs/ssot/decisions/README.md

**Details.** - [ ] The plan lists every ticket
- [ ] Overlaps are edges

## sm-021 · Ticket 04: The skill publishes the files
- category: Tickets
- status: proposed
- image: none
- screen: none (tooling)
- source: tickets sm 2026-09-14
- ticket: 04
- depends: sm-001

**Context.** The problem statement. Slice 2 of 3.

**Question.** Is this the right second slice?

**Decision.** Lee runs the skill and files appear.

**Why.** The files are what implement reads.

**What else was considered.** none recorded

**What it touches.** .claude/skills/to-tickets-lee/, docs/ssot/decisions/_page/sync.mjs

**Details.** - [ ] Files carry the header lines

## sm-022 · Ticket 05: The page shows the edges
- category: Tickets
- status: proposed
- image: none
- screen: Work page
- source: tickets sm 2026-09-14
- ticket: 05
- blocked: 03
- depends: sm-004
- model: fable

**Context.** The problem statement. Slice 3 of 3.

**Question.** Is this the right third slice?

**Decision.** The Work page draws the edges.

**Why.** Lee sees them.

**What else was considered.** none recorded

**What it touches.** docs/ssot/decisions/_page/index.html

**Details.** - [ ] Edges drawn

## sm-023 · A rule that is not a ticket
- category: Spec
- status: proposed
- image: none
- screen: none
- source: spec sm 2026-09-14

**Context.** c

**Question.** q

**Decision.** d

**Why.** w

**What else was considered.** none recorded

**What it touches.** t
`;

test('pendingIn counts the proposed and amended cards of one category, with their ids', () => {
  const proposals = parse(ticketFixture);
  assert.deepEqual(pendingIn(proposals, 'Spec'), { category: 'Spec', count: 1, ids: ['sm-023'] });
  assert.deepEqual(pendingIn(proposals, 'Tickets').ids, ['sm-020', 'sm-021', 'sm-022']);
  const ssot = emptySsot();
  apply({ 'sm-023': { verdict: 'amend', text: 'shorter', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  assert.equal(pendingIn(proposals, 'Spec').count, 1);
  apply({ 'sm-023': { verdict: 'approve', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  assert.equal(pendingIn(proposals, 'Spec').count, 0);
  assert.deepEqual(pendingIn(proposals, 'Nothing'), { category: 'Nothing', count: 0, ids: [] });
});

test('ticketPlan turns overlapping touches into blocking edges, lower number first', () => {
  const proposals = parse(ticketFixture), ssot = emptySsot();
  const plan = ticketPlan('sm', proposals, ssot);
  assert.deepEqual(plan.tickets.map(t => t.number), ['03', '04', '05']);
  const [t3, t4, t5] = plan.tickets;
  assert.deepEqual(t3.blockedBy, []);
  assert.deepEqual(t4.blockedBy, ['03']);
  assert.deepEqual(t4.overlaps, [{ with: '03', on: 'docs/ssot/decisions/_page/sync.mjs' }]);
  assert.deepEqual(t5.blockedBy, ['03']);
  assert.deepEqual(t5.declared, ['03']);
  assert.deepEqual(t5.overlaps, []);
  assert.deepEqual(t3.depends, ['sm-001', 'sm-004']);
  assert.deepEqual(t3.touches, ['docs/ssot/decisions/_page/sync.mjs', 'docs/ssot/decisions/README.md']);
  assert.deepEqual(plan.pending, ['sm-020', 'sm-021', 'sm-022']);
  assert.deepEqual(plan.approved, []);
  assert.deepEqual(plan.forward, []);
  const docs = toDocuments(proposals);
  assert.deepEqual(plan.tickets.map(t => t.model), ['opus', 'opus', 'fable'], 'a card without a model line is built on Opus');
  assert.equal(docs[2].decision, 'The Work page draws the edges.\n\nBlocked by: 03.\n\nBuilt by: Fable.');
  assert.equal(docs[0].decision, 'An agent runs the plan command and sees edges. Blocked by nothing.\n\nBlocked by: nothing, it can start at once.\n\nBuilt by: Opus.');
  assert.equal(docs[3].decision, 'd');
  assert.deepEqual([docs[2].ticket, docs[2].blocked, docs[2].depends], ['05', '03', 'sm-004']);
});

test('ticketPlan flags a declared blocker that is not a lower number, and publishTickets refuses it', () => {
  const proposals = parse(ticketFixture.replace('- blocked: 03', '- blocked: 05')), ssot = emptySsot();
  assert.deepEqual(ticketPlan('sm', proposals, ssot).forward, [{ ticket: '05', blockedBy: '05' }]);
  for (const id of ['sm-020', 'sm-021', 'sm-022', 'sm-023']) apply({ [id]: { verdict: 'approve', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const r = publishTickets('sm', proposals, ssot, dir, { next: '/implement-lee sm' });
  assert.deepEqual(r.refused, ['sm-022']);
  assert.match(r.why['sm-022'], /not a lower number/);
  assert.equal(readdirSync(dir).length, 0);
});

test('publishTickets refuses a ticket that depends on a rejected decision', () => {
  const proposals = parse(ticketFixture + `
## sm-004 · A rule the tickets lean on
- category: Sheet
- status: proposed

**Decision.** d
`), ssot = emptySsot();
  for (const id of ['sm-020', 'sm-021', 'sm-022', 'sm-023']) apply({ [id]: { verdict: 'approve', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  apply({ 'sm-004': { verdict: 'reject', text: 'no', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const r = publishTickets('sm', proposals, ssot, dir, { next: '/implement-lee sm' });
  assert.deepEqual(r.refused, ['sm-020', 'sm-022']);
  assert.equal(r.why['sm-020'], 'depends on sm-004, which no longer stands');
  assert.equal(readdirSync(dir).length, 0);
});

test('publishTickets refuses a ticket card whose model is neither opus nor fable', () => {
  const proposals = parse(ticketFixture.replace('- model: fable', '- model: haiku')), ssot = emptySsot();
  for (const id of ['sm-020', 'sm-021', 'sm-022', 'sm-023']) apply({ [id]: { verdict: 'approve', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const r = publishTickets('sm', proposals, ssot, dir, { next: '/implement-lee sm' });
  assert.deepEqual(r.refused, ['sm-022']);
  assert.equal(r.why['sm-022'], 'model haiku is not one of opus, fable');
  assert.equal(readdirSync(dir).length, 0);
});

test('ticketPlan treats a directory as touching everything under it', () => {
  const proposals = parse(ticketFixture.replace('**What it touches.** .claude/skills/to-tickets-lee/, docs/ssot/decisions/_page/sync.mjs', '**What it touches.** docs/ssot/decisions/_page/'));
  const plan = ticketPlan('sm', proposals, emptySsot());
  assert.deepEqual(plan.tickets[1].overlaps, [{ with: '03', on: 'docs/ssot/decisions/_page/' }]);
  assert.deepEqual(plan.tickets[2].overlaps, [{ with: '04', on: 'docs/ssot/decisions/_page/index.html' }]);
  assert.deepEqual(plan.tickets[2].blockedBy, ['03', '04']);
});

test('publishTickets refuses while any ticket card is pending and writes nothing', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const proposals = parse(ticketFixture), ssot = emptySsot();
  apply({ 'sm-020': { verdict: 'approve', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  const r = publishTickets('sm', proposals, ssot, dir, { next: '/implement-lee sm' });
  assert.deepEqual(r.refused, ['sm-021', 'sm-022']);
  assert.deepEqual(r.written, []);
  assert.equal(existsSync(join(dir, '03-the-sync-module-learns-the-plan.md')), false);
});

test('publishTickets writes one file per approved card with the header lines, the edges, the ids and a Next line', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const proposals = parse(ticketFixture), ssot = emptySsot();
  const ok = (id) => ({ verdict: 'approve', at: 't', by: 'Lee' });
  apply({ 'sm-020': ok(), 'sm-021': ok(), 'sm-022': ok(), 'sm-023': { verdict: 'reject', text: 'no', at: 't', by: 'Lee' } }, proposals, ssot, '2026-09-14');
  const r = publishTickets('sm', proposals, ssot, dir, { next: '/implement-lee sm' });
  assert.deepEqual(r.refused, []);
  assert.deepEqual(r.written.map(w => w.file.split('/').pop()), ['03-the-sync-module-learns-the-plan.md', '04-the-skill-publishes-the-files.md', '05-the-page-shows-the-edges.md']);
  const t4 = readFileSync(join(dir, '04-the-skill-publishes-the-files.md'), 'utf8');
  assert.match(t4, /^# 04: The skill publishes the files\n\n\*\*Status:\*\* ready-for-agent\n\*\*Blocked by:\*\* 03 \(touches docs\/ssot\/decisions\/_page\/sync.mjs\)\.\n\*\*Next:\*\* `\/implement-lee sm`\n\*\*Model:\*\* opus\n/);
  assert.match(t4, /\*\*What to build:\*\* Lee runs the skill and files appear\./);
  assert.match(t4, /\*\*Decisions:\*\* sm-001; approved as sm-021\./);
  assert.match(t4, /\*\*Touches:\*\* \.claude\/skills\/to-tickets-lee\/, docs\/ssot\/decisions\/_page\/sync\.mjs/);
  assert.match(t4, /- \[ \] Files carry the header lines\n/);
  assert.match(t4, /\nNext: \/implement-lee sm\n$/);
  const t3 = readFileSync(join(dir, '03-the-sync-module-learns-the-plan.md'), 'utf8');
  assert.match(t3, /\*\*Blocked by:\*\* None \(can start immediately\)\.\n/);
  assert.match(t3, /\*\*Decisions:\*\* sm-001, sm-004; approved as sm-020\./);
  const t5 = readFileSync(join(dir, '05-the-page-shows-the-edges.md'), 'utf8');
  assert.match(t5, /\*\*Blocked by:\*\* 03\.\n/);
  assert.match(t5, /^\*\*Model:\*\* fable$/m);
  assert.equal(ticketDocument('sm', join(dir, '05-the-page-shows-the-edges.md'), t5, 'sm').model, 'fable');
  // a declared edge that is also an overlap keeps the overlap evidence
  const both = parse(ticketFixture.replace('- ticket: 04\n- depends: sm-001', '- ticket: 04\n- blocked: 03\n- depends: sm-001')), bothSsot = emptySsot();
  for (const id of ['sm-020', 'sm-021', 'sm-022', 'sm-023']) apply({ [id]: { verdict: 'approve', at: 't', by: 'Lee' } }, both, bothSsot, '2026-09-14');
  const dir2 = mkdtempSync(join(tmpdir(), 'ssot-'));
  publishTickets('sm', both, bothSsot, dir2, { next: '/implement-lee sm' });
  assert.match(readFileSync(join(dir2, '04-the-skill-publishes-the-files.md'), 'utf8'), /\*\*Blocked by:\*\* 03 \(touches docs\/ssot\/decisions\/_page\/sync\.mjs\)\.\n/);
  // the Work page reads what was written
  const doc = ticketDocument('sm', join(dir, '04-the-skill-publishes-the-files.md'), t4, 'sm');
  assert.equal(doc.state, 'ready');
  assert.deepEqual(doc.cites, ['sm-001', 'sm-021']);
  assert.equal(doc.next, '`/implement-lee sm`');
  // a second run writes nothing over an existing file
  const again = publishTickets('sm', proposals, ssot, dir, { next: '/implement-lee sm' });
  assert.deepEqual(again.written, []);
  assert.deepEqual(again.skipped.map(s => s.id), ['sm-020', 'sm-021', 'sm-022']);
});

test('the pending, ticket-plan and publish-tickets CLIs', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const pf = join(dir, 'decisions.md'), sf = join(dir, 'ssot.md'), issues = join(dir, 'issues');
  writeFileSync(pf, ticketFixture); writeFileSync(sf, serialize(emptySsot()));
  assert.equal(execFileSync('node', [cli, 'pending', pf], { encoding: 'utf8' }).trim(), '4');
  assert.deepEqual(JSON.parse(execFileSync('node', [cli, 'pending', pf, 'Spec'], { encoding: 'utf8' })), { category: 'Spec', count: 1, ids: ['sm-023'] });
  const plan = JSON.parse(execFileSync('node', [cli, 'ticket-plan', 'sm', pf, sf], { encoding: 'utf8' }));
  assert.deepEqual(plan.tickets.map(t => t.blockedBy), [[], ['03'], ['03']]);
  const refused = JSON.parse(execFileSync('node', [cli, 'publish-tickets', 'sm', pf, sf, issues, '--next', '/implement-lee sm'], { encoding: 'utf8' }));
  assert.equal(refused.refused.length, 3);
  assert.equal(existsSync(issues), false);
});

// Drawn pictures: a screenless card carries `- svg: <path>` to a file the generator drew.
const screenless = fixture.replace('- screen: Vana sheet\n- source: ticket 08\n', '- screen: none (algorithm/data)\n- source: ticket 08\n');
const paywallSpec = { kind: 'timeline', title: 'A new account', steps: [{ at: 'Day 1', label: 'Whole app open', tone: 'ok' }, { at: 'Day 7', label: 'Last trial day', tone: 'pending' }, { at: 'Day 8', label: 'Launcher opens the paywall', tone: 'no' }], example: ['Signed up 1 Sep: trial ends 7 Sep, paywall from 8 Sep.'] };

test('an svg meta line round-trips byte-identical and reaches the page document', () => {
  const md = screenless.replace('- image: none\n- caption:\n- screen: none (algorithm/data)\n', '- image: none\n- caption:\n- svg: docs/ssot/decisions/images/sm/sm-001.svg\n- screen: none (algorithm/data)\n');
  assert.equal(serialize(parse(md)), md);
  const [d1, d2] = toDocuments(parse(md));
  assert.equal(d1.svgPath, 'docs/ssot/decisions/images/sm/sm-001.svg');
  assert.equal(d1.svg, '');
  assert.equal(d2.svgPath, '');
  const [r1] = toDocuments(parse(md), { readSvg: p => `<svg data-from="${p}"></svg>` });
  assert.equal(r1.svg, '<svg data-from="docs/ssot/decisions/images/sm/sm-001.svg"></svg>');
});

test('svgCheck refuses raster, stock links and colour outside the page tokens', () => {
  assert.deepEqual(svgCheck('<svg xmlns="http://www.w3.org/2000/svg"><rect fill="var(--card, #FFFFFF)" stroke="var(--line, #DDD8C8)"/><text fill="var(--ink)">x</text></svg>').problems, []);
  assert.match(svgCheck('<svg><rect fill="#FF0000"/></svg>').problems.join(' '), /#FF0000/);
  assert.match(svgCheck('<svg><rect style="fill:rgb(1,2,3)"/></svg>').problems.join(' '), /rgb\(/);
  assert.match(svgCheck('<svg><text fill="red">x</text></svg>').problems.join(' '), /red/);
  assert.match(svgCheck('<svg><rect fill="var(--brand)"/></svg>').problems.join(' '), /--brand/);
  assert.match(svgCheck('<svg><image href="a.png"/></svg>').problems.join(' '), /image/);
  assert.match(svgCheck('<svg><rect fill="url(data:image/png;base64,AAA)"/></svg>').problems.join(' '), /data:/);
  assert.match(svgCheck('<div>not an svg</div>').problems.join(' '), /<svg/);
  assert.ok(TOKENS.includes('accent') && TOKENS.includes('ground-2'));
});

test('draw turns a timeline spec into an svg that passes the check and carries every label', () => {
  const svg = draw(paywallSpec);
  assert.deepEqual(svgCheck(svg).problems, []);
  for (const s of ['A new account', 'Day 1', 'Day 7', 'Day 8', 'Whole app open', 'Launcher opens the paywall', 'Signed up 1 Sep']) assert.ok(svg.includes(s), s);
  assert.doesNotMatch(svg, /<image|<foreignObject/);
});

test('draw lays out a flow of boxes and arrows with a worked example', () => {
  const svg = draw({ kind: 'flow', title: 'Sync', rows: [[{ id: 'a', label: 'Local write' }, { id: 'b', label: 'Upload\nqueue', tone: 'accent' }], [{ id: 'c', label: 'Remote ack', tone: 'ok' }]], edges: [{ from: 'a', to: 'b', label: 'dirty' }, { from: 'b', to: 'c' }], example: ['Athlete logs 3 meals offline: 3 dirty rows, one upload, 3 acks.'] });
  assert.deepEqual(svgCheck(svg).problems, []);
  for (const s of ['Local write', 'Upload', 'queue', 'Remote ack', 'dirty', '3 dirty rows']) assert.ok(svg.includes(s), s);
  assert.equal((svg.match(/<rect class="dg-box/g) || []).length, 3);
  assert.equal((svg.match(/marker-end/g) || []).length, 2);
  assert.throws(() => draw({ kind: 'flow', rows: [[{ id: 'a', label: 'A' }]], edges: [{ from: 'a', to: 'zz' }] }), /zz/);
});

test('undrawn lists screenless cards without a picture, skipping questions and ruled-out ones', () => {
  const proposals = parse(screenless);
  const ssot = parse(screenless.replace('sm-001', 'sm-003').replace('sm-002', 'sm-004').replace('- status: proposed\n- image: none\n- caption:\n- screen: none (algorithm/data)', '- status: rejected\n- image: none\n- caption:\n- screen: none (algorithm/data)'));
  ssot.decisions[1].meta.screen = 'none (algorithm/data)'; ssot.decisions[1].meta.status = 'approved'; ssot.decisions[1].meta.svg = 'x.svg';
  const q = parse(questionFixture); q.decisions[0].meta.screen = 'none (algorithm/data)'; proposals.decisions.push(q.decisions[0]);
  assert.deepEqual(undrawn(proposals, ssot), [{ id: 'sm-001', title: 'The sheet has one height', file: 'proposals' }]);
});

test('attach-svg checks the file, sets the meta line after caption, and prepare inlines it', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const md = join(dir, 'p.md'); writeFileSync(md, screenless);
  const good = join(dir, 'sm-001.svg'); writeFileSync(good, draw(paywallSpec));
  const bad = join(dir, 'bad.svg'); writeFileSync(bad, '<svg><rect fill="#123456"/></svg>');
  assert.throws(() => execFileSync('node', [cli, 'attach-svg', md, 'sm-001', bad], { stdio: 'pipe' }), /#123456/);
  assert.equal(readFileSync(md, 'utf8'), screenless);
  assert.throws(() => execFileSync('node', [cli, 'attach-svg', md, 'sm-009', good], { stdio: 'pipe' }), /sm-009/);
  execFileSync('node', [cli, 'attach-svg', md, 'sm-001', good]);
  const after = readFileSync(md, 'utf8');
  assert.ok(after.includes(`- caption:\n- svg: ${good}\n- screen: none (algorithm/data)`), after);
  assert.equal(serialize(parse(after)), after);
  // Attaching again replaces the line rather than adding a second one.
  execFileSync('node', [cli, 'attach-svg', md, 'sm-001', good]);
  assert.equal(readFileSync(md, 'utf8'), after);
  // The pure function on a doc.
  const doc = parse(screenless); assert.equal(attachSvg(doc, 'sm-002', 'y.svg'), true); assert.equal(attachSvg(doc, 'sm-404', 'y.svg'), false);
  assert.deepEqual(Object.keys(doc.decisions[1].meta), ['category', 'status', 'image', 'caption', 'svg', 'screen', 'source']);
  // prepare inlines the file; the undrawn CLI no longer lists the card.
  execFileSync('node', [cli, 'prepare', md, '--out', join(dir, 'out')]);
  const body = JSON.parse(readFileSync(join(dir, 'out', 'sm-001.json'), 'utf8'));
  assert.match(body.svg, /^<svg/); assert.ok(body.svg.includes('Day 8'));
  assert.equal(body.svgPath, good);
  assert.deepEqual(JSON.parse(execFileSync('node', [cli, 'undrawn', md], { encoding: 'utf8' })), []);
  // draw CLI: spec in, svg out, checked.
  const spec = join(dir, 'spec.json'); writeFileSync(spec, JSON.stringify(paywallSpec));
  execFileSync('node', [cli, 'draw', spec, join(dir, 'drawn.svg')]);
  assert.equal(readFileSync(join(dir, 'drawn.svg'), 'utf8'), draw(paywallSpec));
});

// Captured pictures (ticket 08). The registry is data, the drive is a list of steps, and the
// simulator is a fake io here: the tests check what is matched, tapped and written.
const screens = {
  timeline: { match: ['Timeline', 'Home shell', 'Main tabs'], drive: [{ tap: 'Timeline', type: 'Button' }] },
  'meal-detail': { match: ['Meal detail'], drive: [{ tap: 'Food', type: 'Button' }, { tap: 'Meals' }, { tapAfter: 'RECENTS', type: 'GenericElement' }] },
  'vana-sheet': { match: ['Vana sheet'], reuse: 'goldens/vana_sheet_open_light.png' },
  paywall: { match: ['Paywall'], note: 'no drive gets there' },
};
const el = (type, AXLabel, x, y) => ({ type, AXLabel, frame: { x, y, width: 40, height: 20 } });

test('matchScreen takes the card\'s screen line: exact phrase per comma part first, then a contained one', () => {
  assert.equal(matchScreen('Home shell', screens).key, 'timeline');
  assert.equal(matchScreen('Main tabs, Plan tab, coach formulas', screens).key, 'timeline');
  assert.equal(matchScreen('Vana sheet, full-screen Vana chat', screens).key, 'vana-sheet');
  assert.equal(matchScreen('Meal detail screen (Recipe)', screens).key, 'meal-detail');
  assert.equal(matchScreen('none (algorithm/data)', screens), null);
  assert.equal(matchScreen('Kroger cart', screens), null);
  // The real registry matches every screen the mealplanning record names today.
  const real = loadScreens();
  for (const s of ['Vana chat', 'Settings', 'Calendar sheet over the Plan tab', 'Meal detail', 'Home shell', 'Coach formula feedback, Vana chat', 'Vana sheet on a recovery moment', 'Meals tab', 'Cooking mode', 'Vana chat after feedback', 'Vana chat, shake sheet', 'Plan tab', 'Main tabs, Plan tab, coach formulas', 'Vana sheet, full-screen Vana chat', 'Paywall', 'Any screen with the launcher', 'Vana sheet', 'Settings, Plan tab']) assert.ok(matchScreen(s, real), s);
  assert.equal(matchScreen('Vana sheet on a recovery moment', real).key, 'vana-sheet-moment');
  assert.equal(matchScreen('Any screen with the launcher', real).key, 'launcher');
  // The fallback takes the longest phrase, whatever order the registry lists its screens in.
  const reversed = Object.fromEntries(Object.entries(real).reverse());
  assert.equal(matchScreen('Vana conversations list screen', real).key, 'vana-conversations');
  assert.equal(matchScreen('Vana conversations list screen', reversed).key, 'vana-conversations');
  // Vana settings is its own screen since ai-cost wave 5, so its phrase matches exactly, not through 'Settings'.
  assert.equal(matchScreen('Vana settings', real).key, 'vana-settings');
  assert.equal(matchScreen('Coach formula feedback, Vana chat', real).key, 'vana-chat');
});

test('findElement prefers the exact first-line label over a substring, honours type, and tapAfter takes the next element of a type', () => {
  const tree = [el('Application', 'App', 0, 0), el('Button', '+ Add Food', 100, 200), el('Button', 'Food\nFood', 130, 800), el('StaticText', 'RECENTS\nSee all', 10, 300), el('StaticText', 'x', 0, 0), el('GenericElement', 'Rice bowl', 20, 330), el('GenericElement', 'Quinoa bowl', 200, 330)];
  assert.equal(findElement(tree, { tap: 'Food' }).AXLabel, 'Food\nFood');
  assert.equal(findElement(tree, { tap: 'add food' }).AXLabel, '+ Add Food');
  assert.equal(findElement(tree, { tap: 'Food', type: 'StaticText' }), null);
  assert.equal(findElement(tree, { tapAfter: 'RECENTS', type: 'GenericElement' }).AXLabel, 'Rice bowl');
  assert.equal(findElement(tree, { tapAfter: 'nowhere' }), null);
  // An element with an empty frame is off screen and never tapped.
  assert.equal(findElement([el('Application', '', 0, 0), { type: 'Button', AXLabel: 'Ghost', frame: { x: 0, y: 0, width: 0, height: 0 } }], { tap: 'Ghost' }), null);
});

test('runDrive launches fresh, taps each step at the element centre, and names the step that found nothing', async () => {
  const log = [];
  const io = { launch: async () => log.push('launch'), tree: async () => [el('Button', 'Food\nFood', 100, 800), el('StaticText', 'Meals', 200, 120)], tap: async (x, y) => log.push(`tap ${x},${y}`), wait: async ms => log.push(`wait ${ms}`) };
  await runDrive([{ tap: 'Food', type: 'Button' }, { wait: 500 }, { tap: 'Meals', settle: 100 }], io, { settle: 10 });
  assert.deepEqual(log, ['launch', 'tap 120,810', 'wait 10', 'wait 500', 'tap 220,130', 'wait 100']);
  await assert.rejects(runDrive([{ tap: 'Nope' }], io, { settle: 0 }), /"tap":"Nope"/);
});

test('capture saves the png beside a sidecar carrying commit and app version, and attach-image records them on the card', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const io = { launch: async () => {}, tree: async () => [el('Button', 'Timeline', 50, 800)], tap: async () => {}, wait: async () => {}, screenshot: p => writeFileSync(p, 'png') };
  const r = await capture({ key: 'timeline', ...screens.timeline }, { dir, commit: 'abc1234', version: '1.26.0+1', device: 'iPhone 17 Pro', runtime: 'iOS 26.2', io });
  assert.equal(r.path, join(dir, 'timeline.png'));
  assert.equal(readFileSync(join(dir, 'timeline.png'), 'utf8'), 'png');
  const side = JSON.parse(readFileSync(join(dir, 'timeline.json'), 'utf8'));
  assert.equal(side.commit, 'abc1234'); assert.equal(side.appVersion, '1.26.0+1'); assert.equal(side.screen, 'Timeline'); assert.equal(side.key, 'timeline');
  assert.equal(runtimeName('com.apple.CoreSimulator.SimRuntime.iOS-26-2'), 'iOS 26.2'); assert.match(side.capturedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.deepEqual(readSidecar(join(dir, 'timeline.png')), side);
  assert.equal(readSidecar(join(dir, 'missing.png')), null);
  await assert.rejects(capture({ key: 'paywall', ...screens.paywall }, { dir, io }), /no drive/);
  // attach-image on a card: image line set, one dated history line naming the version and commit.
  const md = join(dir, 'p.md'); writeFileSync(md, fixture);
  execFileSync('node', [cli, 'attach-image', md, 'sm-001', join(dir, 'timeline.png'), '--caption', 'The timeline']);
  const after = readFileSync(md, 'utf8');
  assert.ok(after.includes(`- image: ${join(dir, 'timeline.png')}\n- caption: The timeline\n`), after);
  assert.match(after, /> \d{4}-\d{2}-\d{2} picture captured at 1\.26\.0\+1, abc1234\n/);
  assert.equal(serialize(parse(after)), after);
  assert.throws(() => execFileSync('node', [cli, 'attach-image', md, 'sm-001', join(dir, 'nothing.png')], { stdio: 'pipe' }), /file missing/);
  // A reused golden has no sidecar: the history line names the file instead.
  const doc = parse(fixture);
  assert.equal(attachImage(doc, 'sm-001', 'goldens/vana_sheet_open_light.png', { today: '2026-09-14' }), true);
  assert.equal(doc.decisions[0].meta.image, 'goldens/vana_sheet_open_light.png');
  assert.deepEqual(doc.decisions[0].history.at(-1), { date: '2026-09-14', note: 'picture reused from goldens/vana_sheet_open_light.png' });
  assert.equal(attachImage(doc, 'sm-404', 'x.png'), false);
  // A card without an image line gets one after status.
  const bare = parse(fixture); delete bare.decisions[0].meta.image; delete bare.decisions[0].meta.caption;
  attachImage(bare, 'sm-001', 'x.png', { captured: null, caption: 'c' });
  assert.deepEqual(Object.keys(bare.decisions[0].meta), ['category', 'status', 'image', 'caption', 'screen', 'source']);
  // prepare carries the sidecar into the page document.
  execFileSync('node', [cli, 'prepare', md, '--out', join(dir, 'out')]);
  const body = JSON.parse(readFileSync(join(dir, 'out', 'sm-001.json'), 'utf8'));
  assert.equal(body.captured.commit, 'abc1234'); assert.equal(body.image, join(dir, 'timeline.png'));
});

test('uncaptured lists screen cards with no picture and says how each would get one', () => {
  const first = () => parse(fixture).decisions[0]; // screen "Vana sheet", image none
  const card = (id, meta) => ({ ...first(), id, meta: { ...first().meta, ...meta } });
  const proposals = { decisions: [first()] };
  const ssot = { decisions: [card('sm-002', { screen: 'Paywall' }), card('sm-003', { screen: 'Home shell', status: 'approved' }), card('sm-004', { screen: 'Home shell', status: 'rejected' }), card('sm-005', { screen: 'Home shell', image: 'have.png' }), card('sm-006', { screen: 'Kroger cart' })] };
  const q = parse(questionFixture).decisions[0]; q.meta.screen = 'Home shell'; proposals.decisions.push(q);
  const out = uncaptured(proposals, ssot, screens);
  assert.deepEqual(out.map(o => [o.id, o.file, o.how, o.key, o.path]), [
    ['sm-001', 'proposals', 'reuse', 'vana-sheet', 'goldens/vana_sheet_open_light.png'],
    ['sm-002', 'record', 'none', 'paywall', ''],
    ['sm-003', 'record', 'capture', 'timeline', ''],
    ['sm-006', 'record', 'none', '', ''],
  ]);
  assert.equal(out[1].note, 'no drive gets there');
  assert.equal(out[3].note, 'no screen in screens.json matches');
  // A registry reuse that is stale, on a screen with a drive, is captured instead of reattached.
  const { root } = repo();
  const staleGolden = uncaptured({ decisions: [first()] }, { decisions: [] }, agedScreens, { root });
  assert.deepEqual(staleGolden.map(o => [o.id, o.how, o.key, o.path]), [['sm-001', 'capture', 'vana-sheet', '']]);
  const noDrive = { ...agedScreens, 'vana-sheet': { ...agedScreens['vana-sheet'], drive: undefined } };
  assert.equal(uncaptured({ decisions: [first()] }, { decisions: [] }, noDrive, { root })[0].how, 'reuse', 'with no drive the stale golden is still better than nothing');
});

// A throwaway git repo: pubspec at 1.25.0, a golden and a screen file committed, then the screen edited at 1.26.0.
function repo() {
  const root = mkdtempSync(join(tmpdir(), 'ssot-git-'));
  const git = (...a) => execFileSync('git', a, { cwd: root, encoding: 'utf8', env: { ...process.env, GIT_AUTHOR_DATE: '2026-09-01T10:00:00Z', GIT_COMMITTER_DATE: '2026-09-01T10:00:00Z', GIT_AUTHOR_NAME: 't', GIT_AUTHOR_EMAIL: 't@t', GIT_COMMITTER_NAME: 't', GIT_COMMITTER_EMAIL: 't@t' } }).trim();
  git('init', '-q');
  const put = (p, s) => { execFileSync('mkdir', ['-p', join(root, dirname(p))]); writeFileSync(join(root, p), s); };
  put('pubspec.yaml', 'name: app\nversion: 1.25.0+3\n');
  put('goldens/vana_sheet_open_light.png', 'golden v1');
  put('lib/features/sheet/sheet.dart', 'v1');
  put('lib/features/timeline/timeline.dart', 'v1');
  git('add', '-A'); git('commit', '-q', '-m', 'first');
  const first = git('rev-parse', '--short', 'HEAD');
  put('pubspec.yaml', 'name: app\nversion: 1.26.0+1\n');
  put('lib/features/sheet/sheet.dart', 'v2');
  git('add', '-A'); git('commit', '-q', '-m', 'second');
  const second = git('rev-parse', '--short', 'HEAD');
  return { root, git, put, first, second };
}
const agedScreens = {
  timeline: { match: ['Timeline'], code: ['lib/features/timeline'], drive: [{ tap: 'Timeline', type: 'Button' }] },
  'vana-sheet': { match: ['Vana sheet'], reuse: 'goldens/vana_sheet_open_light.png', code: ['lib/features/sheet/sheet.dart'], drive: [{ tap: 'Vana', type: 'Button' }] },
  paywall: { match: ['Paywall'], code: ['lib/features/paywall'] },
};

test('changedSince lists the files under the screen\'s code that changed after the commit, including uncommitted edits', () => {
  const { root, put, first, second } = repo();
  assert.deepEqual(changedSince(first, ['lib/features/sheet/sheet.dart'], { root }), ['lib/features/sheet/sheet.dart']);
  assert.deepEqual(changedSince(first, ['lib/features/timeline'], { root }), []);
  assert.deepEqual(changedSince(second, ['lib/features/sheet'], { root }), []);
  put('lib/features/timeline/timeline.dart', 'v2 uncommitted');
  assert.deepEqual(changedSince(second, ['lib/features/timeline'], { root }), ['lib/features/timeline/timeline.dart']);
  put('lib/features/timeline/new_widget.dart', 'untracked');
  assert.deepEqual(changedSince(second, ['lib/features/timeline'], { root }), ['lib/features/timeline/new_widget.dart', 'lib/features/timeline/timeline.dart'], 'a new file under the screen counts');
  assert.equal(changedSince('0000000', ['lib'], { root }), null, 'a commit this repo never had');
  assert.equal(changedSince('', ['lib'], { root }), null);
});

test('captureStatus reads a sidecar for a capture and git for a reused golden, and marks either stale from the screen\'s code', () => {
  const { root, put, first, second } = repo();
  // A golden has no sidecar: its age is the commit that last touched it, and the app version pubspec had then.
  const golden = captureStatus('goldens/vana_sheet_open_light.png', agedScreens, { root });
  assert.equal(golden.how, 'reused'); assert.equal(golden.key, 'vana-sheet'); assert.equal(golden.commit, first);
  assert.equal(golden.appVersion, '1.25.0+3'); assert.equal(golden.capturedAt, '2026-09-01T10:00:00.000Z');
  assert.equal(golden.stale, true); assert.deepEqual(golden.changed, ['lib/features/sheet/sheet.dart']);
  // A capture carries its sidecar; its screen's code is untouched since, so it is fresh.
  put('images/f/timeline.png', 'png');
  put('images/f/timeline.json', JSON.stringify({ screen: 'Timeline', key: 'timeline', commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-14T16:00:00.000Z' }));
  const cap = captureStatus('images/f/timeline.png', agedScreens, { root });
  assert.equal(cap.how, 'captured'); assert.equal(cap.commit, second); assert.equal(cap.stale, false); assert.deepEqual(cap.changed, []);
  // A screen with no code list, or a commit git does not know, says nothing about staleness.
  put('images/f/other.png', 'png'); put('images/f/other.json', JSON.stringify({ key: 'other', commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-14T16:00:00.000Z' }));
  assert.equal(captureStatus('images/f/other.png', agedScreens, { root }).stale, null);
  put('images/f/timeline.json', JSON.stringify({ key: 'timeline', commit: 'abcdef0', appVersion: '1.20.0', capturedAt: '2026-08-01T00:00:00.000Z' }));
  assert.equal(captureStatus('images/f/timeline.png', agedScreens, { root }).stale, null);
  // An untracked file with no sidecar has no age at all.
  put('images/f/loose.png', 'png');
  assert.equal(captureStatus('images/f/loose.png', agedScreens, { root }), null);
});

test('stalePictures groups the cards by picture and says which pictures a refresh would retake', () => {
  const { root, put, second } = repo();
  put('images/f/timeline.png', 'png');
  put('images/f/timeline.json', JSON.stringify({ key: 'timeline', commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-14T16:00:00.000Z' }));
  const first = () => parse(fixture).decisions[0];
  const card = (id, meta) => ({ ...first(), id, meta: { ...first().meta, ...meta } });
  const proposals = { decisions: [card('sm-001', { image: 'goldens/vana_sheet_open_light.png' }), card('sm-002', { image: 'goldens/vana_sheet_open_light.png', status: 'rejected' })] };
  const ssot = { decisions: [card('sm-003', { screen: 'Timeline', image: 'images/f/timeline.png', status: 'approved' }), card('sm-004', { screen: 'Paywall', image: 'none', status: 'approved' }), card('sm-005', { screen: 'none (algorithm)', image: 'none', svg: 'x.svg', status: 'approved' })] };
  const out = stalePictures(proposals, ssot, agedScreens, { root });
  assert.deepEqual(out.map(p => [p.path, p.key, p.how, p.stale, p.cards, p.refresh]), [
    ['goldens/vana_sheet_open_light.png', 'vana-sheet', 'reused', true, ['sm-001'], 'capture'],
    ['images/f/timeline.png', 'timeline', 'captured', false, ['sm-003'], 'capture'],
  ]);
  assert.equal(out[0].appVersion, '1.25.0+3');
});

test('refreshPictures retakes every stale picture once, in place, re-points cards that used a golden, and leaves fresh ones alone', async () => {
  const { root, put, first: firstCommit, second } = repo();
  put('images/f/timeline.png', 'old png');
  put('images/f/timeline.json', JSON.stringify({ key: 'timeline', commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-14T16:00:00.000Z' }));
  put('images/f/meal-detail.png', 'old png');
  put('images/f/meal-detail.json', JSON.stringify({ key: 'meal-detail', commit: firstCommit, appVersion: '1.25.0+3', capturedAt: '2026-09-01T16:00:00.000Z' }));
  const screens = { ...agedScreens, 'meal-detail': { match: ['Meal detail'], code: ['lib/features/sheet'], drive: [{ tap: 'Meals' }] } };
  const first = () => parse(fixture).decisions[0];
  const card = (id, meta) => ({ ...first(), id, meta: { ...first().meta, ...meta } });
  const proposals = { decisions: [card('sm-001', { image: 'goldens/vana_sheet_open_light.png' })] };
  const ssot = { decisions: [card('sm-003', { screen: 'Timeline', image: 'images/f/timeline.png', status: 'approved' }), card('sm-006', { screen: 'Meal detail', image: 'images/f/meal-detail.png', status: 'approved' }), card('sm-007', { screen: 'Meal detail', image: 'images/f/meal-detail.png', status: 'approved' })] };
  const taken = [];
  const takePicture = async entry => { taken.push(entry.key); const png = join(root, 'images/f', `${entry.key}.png`); writeFileSync(png, `new ${entry.key}`); writeFileSync(png.replace(/\.png$/, '.json'), JSON.stringify({ key: entry.key, commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-15T09:00:00.000Z' })); return { path: `images/f/${entry.key}.png` }; };
  const r = await refreshPictures(proposals, ssot, screens, { root, dir: 'images/f', takePicture, today: '2026-09-15' });
  assert.deepEqual(taken, ['vana-sheet', 'meal-detail'], 'one capture per stale screen, the fresh timeline untouched');
  assert.deepEqual(r.refreshed.map(x => [x.key, x.from, x.path, x.cards]), [
    ['vana-sheet', 'goldens/vana_sheet_open_light.png', 'images/f/vana-sheet.png', ['sm-001']],
    ['meal-detail', 'images/f/meal-detail.png', 'images/f/meal-detail.png', ['sm-006', 'sm-007']],
  ]);
  assert.deepEqual(r.fresh, ['images/f/timeline.png']);
  assert.deepEqual(r.skipped, []);
  assert.equal(readFileSync(join(root, 'images/f/timeline.png'), 'utf8'), 'old png');
  assert.equal(readFileSync(join(root, 'images/f/meal-detail.png'), 'utf8'), 'new meal-detail');
  // The golden's cards now point at the capture, with one dated line saying so; in-place retakes write no line.
  assert.equal(proposals.decisions[0].meta.image, 'images/f/vana-sheet.png');
  assert.deepEqual(proposals.decisions[0].history.at(-1), { date: '2026-09-15', note: 'picture refreshed at 1.26.0+1, ' + second + ', replacing goldens/vana_sheet_open_light.png' });
  assert.equal(ssot.decisions[1].meta.image, 'images/f/meal-detail.png');
  assert.equal(ssot.decisions[1].history.length, first().history.length);
  // A stale picture whose screen has no drive is reported, not retaken.
  const noDrive = { decisions: [card('sm-008', { screen: 'Paywall', image: 'goldens/vana_sheet_open_light.png', status: 'approved' })] };
  const screens2 = { ...screens, 'vana-sheet': { ...screens['vana-sheet'], drive: undefined } };
  const r2 = await refreshPictures({ decisions: [] }, noDrive, screens2, { root, dir: 'images/f', takePicture, today: '2026-09-15' });
  assert.deepEqual(r2.skipped.map(s => [s.path, s.why]), [['goldens/vana_sheet_open_light.png', 'vana-sheet has no drive']]);
  // A failed drive skips too and never touches the file.
  const r3 = await refreshPictures({ decisions: [card('sm-009', { image: 'goldens/vana_sheet_open_light.png' })] }, { decisions: [] }, screens, { root, dir: 'images/f', takePicture: async () => { throw new Error('nothing matched Vana'); }, today: '2026-09-15' });
  assert.deepEqual(r3.skipped.map(s => [s.path, s.why]), [['goldens/vana_sheet_open_light.png', 'capture of vana-sheet failed: nothing matched Vana']]);
});

test('recordAsset hands back the asset it replaced, and dropAsset removes a path nobody references', () => {
  const dir = mkdtempSync(join(tmpdir(), 'ssot-'));
  const png = join(dir, 'a.png'); writeFileSync(png, 'one');
  const assets = {};
  assert.equal(recordAsset(assets, png, 'id1'), '');
  writeFileSync(png, 'two');
  assert.equal(recordAsset(assets, png, 'id2'), 'id1');
  assert.equal(assets[png].id, 'id2');
  assert.equal(dropAsset(assets, png), 'id2');
  assert.equal(dropAsset(assets, png), '');
  assert.deepEqual(assets, {});
  // The images CLI names assets under a prepared feature's image folder that no document references, with the id to delete;
  // another feature's pictures and goldens elsewhere in the repo are left alone.
  const old = 'docs/ssot/decisions/images/sm/old.png';
  const af = join(dir, 'assets.json'); writeFileSync(af, JSON.stringify({ [png]: { id: 'id9', sha256: 'x' }, [old]: 'bare', 'docs/ssot/decisions/images/other/x.png': 'o', 'goldens/g.png': 'g' }));
  const imf = join(dir, '_images.json'); writeFileSync(imf, JSON.stringify([png])); writeFileSync(join(dir, '_features.json'), JSON.stringify(['sm']));
  const out = JSON.parse(execFileSync('node', [cli, 'images', af, imf], { encoding: 'utf8' }));
  assert.deepEqual(out, [{ path: png, why: 'changed' }, { path: old, why: 'unreferenced', id: 'bare' }]);
  const printed = JSON.parse(execFileSync('node', [cli, 'asset', af, png, 'id10'], { encoding: 'utf8' }));
  assert.deepEqual(printed, { path: png, id: 'id10', replaced: 'id9' });
  const dropped = JSON.parse(execFileSync('node', [cli, 'asset', af, old, '--drop'], { encoding: 'utf8' }));
  assert.deepEqual(dropped, { path: old, dropped: 'bare' });
  assert.deepEqual(Object.keys(JSON.parse(readFileSync(af, 'utf8'))), [png, 'docs/ssot/decisions/images/other/x.png', 'goldens/g.png']);
});

test('prepare carries age and staleness into the page document, and the stale and refresh CLIs read the real registry', () => {
  const { root, put, first } = repo();
  const md = `# Proposed decisions: Sample\n\nFeature: sm\nFeature name: Sample\n\n## sm-001 · The sheet has one height\n- category: Sheet\n- status: proposed\n- image: goldens/vana_sheet_open_light.png\n- screen: Vana sheet\n\n**Decision.** One.\n`;
  put('p.md', md); put('_page/screens.json', JSON.stringify(agedScreens));
  execFileSync('node', [cli, 'prepare', 'p.md', '--screens', '_page/screens.json', '--out', 'out'], { cwd: root });
  const body = JSON.parse(readFileSync(join(root, 'out', 'sm-001.json'), 'utf8'));
  assert.equal(body.captured.how, 'reused'); assert.equal(body.captured.commit, first); assert.equal(body.captured.stale, true); assert.equal(body.captured.appVersion, '1.25.0+3');
  const stale = JSON.parse(execFileSync('node', [cli, 'stale', 'p.md', '--screens', '_page/screens.json'], { cwd: root, encoding: 'utf8' }));
  assert.deepEqual(stale.map(p => [p.path, p.stale, p.cards]), [['goldens/vana_sheet_open_light.png', true, ['sm-001']]]);
  assert.equal(readFileSync(join(root, 'p.md'), 'utf8'), md, 'stale writes nothing');
  // The real registry: every screen with a drive or a reuse names the code it shows.
  const real = loadScreens();
  for (const [k, e] of Object.entries(real)) if (e.drive || e.reuse) assert.ok(Array.isArray(e.code) && e.code.length, `${k} names no code`);
  for (const e of Object.values(real)) for (const p of e.code || []) assert.ok(existsSync(join(here, '../../../..', p)), `${p} is not in the repo`);
});

// ---- /implement-lee: waves in worktrees (ticket 10) ----

const ticketFile = (n, title, status, blocked, body = '') => `# ${n}: ${title}\n\n**Status:** ${status}\n**Blocked by:** ${blocked}\n**Next:** \`/implement-lee sm\`\n\n**What to build:** ${title}.\n\n**Decisions:** sm-001; approved as sm-010.\n\n**Touches:** lib/features/sheet\n\n${body}- [ ] it works\n\nNext: /implement-lee sm\n`;

test('ticketFrontier takes the tickets whose blockers are all done, and says what the rest wait on', () => {
  const docs = [
    ['01-a.md', ticketFile('01', 'A', 'done', 'None (can start immediately).')],
    ['02-b.md', ticketFile('02', 'B', 'ready-for-agent', '01.')],
    ['03-c.md', ticketFile('03', 'C', 'ready-for-agent', '01 (touches lib/features/sheet), 02.')],
    ['04-d.md', ticketFile('04', 'D', 'ready-for-agent', 'None (can start immediately).')],
    ['05-e.md', ticketFile('05', 'E', 'in-progress', '01.')],
    ['06-f.md', ticketFile('06', 'F', 'wontfix', '01.')],
    ['07-g.md', ticketFile('07', 'G', 'ready-for-agent', '05, 06.')],
  ].map(([f, t]) => ticketDocument('sm', f, t));
  const f = ticketFrontier(docs);
  assert.deepEqual(f.done, ['01']);
  assert.deepEqual(f.frontier, ['02', '04'], 'unblocked and ready, in ticket order');
  assert.deepEqual(f.building, ['05']);
  assert.deepEqual(f.blocked, [{ number: '03', waitingOn: ['02'] }, { number: '07', waitingOn: ['05'] }], 'a done or dropped blocker no longer holds; 06 is dropped');
  assert.deepEqual(f.dropped, ['06']);
});

test('designRenderings lists the design renderings a ticket cites, once each', () => {
  const text = 'Match `docs/ssot/spec/design/renderings/pre-workout@v2.html` (see docs/ssot/spec/design/renderings/pre-workout@v2.html and docs/ssot/spec/design/renderings/macro-dashboard@v1.html). The spec is docs/ssot/spec/design/components/vana-sheet.md.';
  assert.deepEqual(designRenderings(text), ['docs/ssot/spec/design/renderings/pre-workout@v2.html', 'docs/ssot/spec/design/renderings/macro-dashboard@v1.html']);
  assert.deepEqual(designRenderings('nothing cited'), []);
});

test('touchedScreens maps changed files to the registry screens drawn from them', () => {
  const files = ['lib/features/sheet/sheet.dart', 'lib/features/sheet/widgets/x.dart', 'test/sheet_test.dart', 'lib/features/paywall/paywall.dart'];
  assert.deepEqual(touchedScreens(files, agedScreens), ['vana-sheet', 'paywall']);
  assert.deepEqual(touchedScreens(['docs/x.md'], agedScreens), []);
  // The CLI reads what changed since a commit, committed or not, plus any files named.
  const { root, put, first } = repo();
  put('_page/screens.json', JSON.stringify(agedScreens)); put('lib/features/paywall/p.dart', 'x');
  const keys = JSON.parse(execFileSync('node', [cli, 'touched-screens', '--since', first, '--screens', '_page/screens.json'], { cwd: root, encoding: 'utf8' }));
  assert.deepEqual(keys, ['vana-sheet', 'paywall'], 'sheet.dart moved in the second commit, paywall in the working tree');
  assert.throws(() => execFileSync('node', [cli, 'touched-screens', '--since', 'nosuchcommit', '--screens', '_page/screens.json'], { cwd: root, stdio: 'pipe' }), /not a commit/);
  assert.deepEqual(JSON.parse(execFileSync('node', [cli, 'touched-screens', 'lib/features/timeline/t.dart', '--screens', '_page/screens.json'], { cwd: root, encoding: 'utf8' })), ['timeline']);
});

test('setTicketStatus rewrites only the Status header line', () => {
  const t = ticketFile('02', 'B', 'ready-for-agent', '01.');
  const out = setTicketStatus(t, 'in-progress (wave 1, 2026-09-15)');
  assert.match(out, /^\*\*Status:\*\* in-progress \(wave 1, 2026-09-15\)$/m);
  assert.equal(out.replace(/^\*\*Status:\*\*.*$/m, 'S'), t.replace(/^\*\*Status:\*\*.*$/m, 'S'));
  assert.throws(() => setTicketStatus('# 02: no header\n', 'done'), /Status/);
});

test('refreshPictures with `only` retakes those screens whether stale or not and leaves the rest alone', async () => {
  const { root, put, second } = repo();
  put('images/f/timeline.png', 'old png');
  put('images/f/timeline.json', JSON.stringify({ key: 'timeline', commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-14T16:00:00.000Z' }));
  const first = () => parse(fixture).decisions[0];
  const card = (id, meta) => ({ ...first(), id, meta: { ...first().meta, ...meta } });
  const proposals = { decisions: [card('sm-001', { image: 'goldens/vana_sheet_open_light.png' })] };
  const ssot = { decisions: [card('sm-003', { screen: 'Timeline', image: 'images/f/timeline.png', status: 'approved' })] };
  const taken = [];
  const takePicture = async entry => { taken.push(entry.key); const png = join(root, 'images/f', `${entry.key}.png`); writeFileSync(png, `new ${entry.key}`); writeFileSync(png.replace(/\.png$/, '.json'), JSON.stringify({ key: entry.key, commit: second, appVersion: '1.26.0+1', capturedAt: '2026-09-15T09:00:00.000Z' })); return { path: `images/f/${entry.key}.png` }; };
  const r = await refreshPictures(proposals, ssot, agedScreens, { root, dir: 'images/f', takePicture, only: ['timeline'], today: '2026-09-15' });
  assert.deepEqual(taken, ['timeline'], 'the fresh timeline is retaken because the wave touched it; the stale golden is not in `only`');
  assert.deepEqual(r.refreshed.map(x => x.key), ['timeline']);
  assert.deepEqual(r.fresh, ['goldens/vana_sheet_open_light.png']);
  assert.equal(readFileSync(join(root, 'images/f/timeline.png'), 'utf8'), 'new timeline');
});

test('wavePlan reads the ticket files, names a branch and worktree per frontier ticket, and lists uncommitted ticket files', () => {
  const { root, put, git } = repo();
  put('.scratch/sm/issues/01-a.md', ticketFile('01', 'A', 'done', 'None.'));
  put('.scratch/sm/issues/02-the-sheet.md', ticketFile('02', 'The sheet', 'ready-for-agent', '01.', 'Match `docs/ssot/spec/design/renderings/pre-workout@v2.html`.\n\n'));
  put('.scratch/sm/issues/03-c.md', ticketFile('03', 'C', 'ready-for-agent', '02.'));
  git('add', '-A'); git('commit', '-q', '-m', 'tickets');
  put('.scratch/sm/issues/04-d.md', ticketFile('04', 'D', 'ready-for-agent', 'None.').replace('\n\n**What to build:**', '\n**Model:** fable\n\n**What to build:**'));
  const base = git('rev-parse', 'HEAD');
  const plan = wavePlan('sm', '.scratch/sm/issues', { root, branch: 'main' });
  assert.equal(plan.base, base);
  assert.equal(plan.branch, 'main');
  assert.deepEqual(plan.done, ['01']);
  assert.deepEqual(plan.blocked, [{ number: '03', waitingOn: ['02'] }]);
  assert.deepEqual(plan.wave.map(t => [t.number, t.title, t.branch, t.renderings, t.file]), [
    ['02', 'The sheet', 'wave/sm/02-the-sheet', ['docs/ssot/spec/design/renderings/pre-workout@v2.html'], '.scratch/sm/issues/02-the-sheet.md'],
    ['04', 'D', 'wave/sm/04-d', [], '.scratch/sm/issues/04-d.md'],
  ]);
  assert.deepEqual(plan.wave.map(t => t.model), ['opus', 'fable'], 'a ticket file without a Model line is built on Opus');
  assert.ok(plan.wave.every(t => t.worktree.startsWith(join(dirname(root), basename(root) + '-waves', 'sm', t.number))), 'worktrees sit beside the clone, never inside it');
  assert.deepEqual(plan.uncommitted, ['.scratch/sm/issues/04-d.md'], 'a ticket the worktrees cannot see');
  // The CLI, with --open, records the wave and marks its tickets in progress.
  const out = JSON.parse(execFileSync('node', [cli, 'wave', 'sm', '.scratch/sm/issues', '--branch', 'main', '--open'], { cwd: root, encoding: 'utf8' }));
  assert.equal(out.number, 1);
  // --open commits every ticket file of the feature (the marks and the one that was untracked) and takes that commit as the base.
  const opened = git('rev-parse', 'HEAD');
  assert.notEqual(opened, base); assert.equal(out.base, opened); assert.deepEqual(out.uncommitted, []);
  assert.equal(git('status', '--porcelain', '--', '.scratch/sm/issues'), '', 'nothing under the tickets dir is left uncommitted');
  assert.match(git('log', '-1', '--format=%s'), /^wave 1 opened for sm: tickets 02, 04 \[skip ci\]$/);
  assert.match(readFileSync(join(root, '.scratch/sm/issues/02-the-sheet.md'), 'utf8'), /^\*\*Status:\*\* in-progress \(wave 1/m);
  assert.match(readFileSync(join(root, '.scratch/sm/issues/04-d.md'), 'utf8'), /^\*\*Status:\*\* in-progress \(wave 1/m);
  const log = JSON.parse(readFileSync(join(root, '.scratch/sm/waves.json'), 'utf8'));
  assert.deepEqual(log[0].tickets, ['02', '04']); assert.equal(log[0].base, opened); assert.ok(log[0].startedAt);
  // A second plan sees them building, not on the frontier.
  const again = wavePlan('sm', '.scratch/sm/issues', { root, branch: 'main' });
  assert.deepEqual(again.wave, []); assert.deepEqual(again.building, ['02', '04']);
  // Close: elapsed time, the outcome, and the tickets' final status.
  const closed = JSON.parse(execFileSync('node', [cli, 'wave', 'sm', '.scratch/sm/issues', '--close', '1', '--merged', '02', '--suite', 'green'], { cwd: root, encoding: 'utf8' }));
  assert.equal(closed.number, 1); assert.deepEqual(closed.merged, ['02']); assert.deepEqual(closed.failed, ['04'], 'a wave ticket named in neither list failed'); assert.equal(closed.suite, 'green'); assert.match(closed.elapsed, /^\d+m$/);
  assert.match(readFileSync(join(root, '.scratch/sm/issues/02-the-sheet.md'), 'utf8'), /^\*\*Status:\*\* done \(wave 1/m);
  assert.match(readFileSync(join(root, '.scratch/sm/issues/04-d.md'), 'utf8'), /^\*\*Status:\*\* ready-for-agent \(wave 1 failed/m, 'a failed ticket goes back on the frontier');
});

test('waveOpen and waveClose keep one log per feature and elapsed reads as hours and minutes', () => {
  const log = [];
  const w = waveOpen(log, { tickets: ['02', '04'], base: 'abc', branch: 'main', now: '2026-09-15T10:00:00.000Z' });
  assert.equal(w.number, 1);
  const w2 = waveOpen(log, { tickets: ['03'], base: 'def', branch: 'main', now: '2026-09-15T11:00:00.000Z' });
  assert.equal(w2.number, 2);
  const c = waveClose(log, 1, { merged: ['02', '04'], failed: [], suite: 'green', now: '2026-09-15T11:32:00.000Z' });
  assert.deepEqual(c.failed, []);
  assert.equal(c.elapsed, '1h 32m'); assert.equal(c.closedAt, '2026-09-15T11:32:00.000Z'); assert.equal(log[0].closedAt, c.closedAt);
  assert.throws(() => waveClose(log, 9, { now: '2026-09-15T11:32:00.000Z' }), /wave 9/);
  assert.equal(elapsed('2026-09-15T10:00:00Z', '2026-09-15T10:07:30Z'), '7m');
  assert.equal(elapsed('2026-09-15T10:00:00Z', '2026-09-15T12:00:00Z'), '2h 0m');
});

test('bootedUdid takes the simulator named (booting it), else SSOT_SIMULATOR, else the first booted one', () => {
  const calls = [];
  const list = { devices: { 'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
    { udid: 'AAA', name: 'iPhone 17 Pro', state: 'Booted', deviceTypeIdentifier: 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro' },
    { udid: 'BBB', name: 'wave-sm-02', state: 'Shutdown', deviceTypeIdentifier: 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro' },
  ] } };
  const run = a => { calls.push(a.join(' ')); return a[0] === 'list' ? JSON.stringify(list) : ''; };
  assert.deepEqual(bootedUdid(undefined, { run }), { udid: 'AAA', name: 'iPhone 17 Pro', runtime: 'iOS 26.2' });
  assert.deepEqual(bootedUdid('wave-sm-02', { run }), { udid: 'BBB', name: 'wave-sm-02', runtime: 'iOS 26.2' });
  assert.ok(calls.includes('boot BBB'), 'a shut-down simulator named by the caller is booted');
  assert.throws(() => bootedUdid('nope', { run }), /no simulator is called nope/);
  process.env.SSOT_SIMULATOR = 'BBB';
  try { assert.equal(bootedUdid(undefined, { run }).udid, 'BBB'); } finally { delete process.env.SSOT_SIMULATOR; }
});

test('createSimulator copies the dev simulator: same type and runtime, app installed from its bundle, data container copied; deleteSimulator removes it', () => {
  const calls = [], copies = [];
  const list = { devices: { 'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
    { udid: 'AAA', name: 'iPhone 17 Pro', state: 'Booted', deviceTypeIdentifier: 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro' },
    { udid: 'CCC', name: 'wave-sm-04', state: 'Booted', deviceTypeIdentifier: 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro' },
  ] } };
  const run = a => {
    calls.push(a.join(' '));
    if (a[0] === 'list') return JSON.stringify(list);
    if (a[0] === 'create') return 'NEW-1\n';
    if (a[0] === 'get_app_container') return a[3] === 'data' ? `/sims/${a[1]}/data\n` : `/sims/${a[1]}/Runner.app\n`;
    return '';
  };
  const made = createSimulator('wave-sm-02', { run, copy: (s, d) => copies.push([s, d]) });
  assert.deepEqual(made, { udid: 'NEW-1', name: 'wave-sm-02', from: 'AAA', runtime: 'iOS 26.2' });
  assert.deepEqual(calls.slice(1), [
    'create wave-sm-02 com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-2',
    'boot NEW-1',
    'get_app_container AAA com.milkman.mealvanaendurance.dev',
    'install NEW-1 /sims/AAA/Runner.app',
    'get_app_container AAA com.milkman.mealvanaendurance.dev data',
    'get_app_container NEW-1 com.milkman.mealvanaendurance.dev data',
  ]);
  assert.deepEqual(copies, [['/sims/AAA/data', '/sims/NEW-1/data']]);
  assert.throws(() => createSimulator('wave-sm-04', { run }), /already exists/);
  assert.throws(() => createSimulator('x', { run, from: 'ZZZ' }), /no simulator is called ZZZ/);
  calls.length = 0;
  assert.deepEqual(deleteSimulator('wave-sm-04', { run }), { deleted: true, udid: 'CCC', name: 'wave-sm-04' });
  assert.deepEqual(calls.slice(1), ['shutdown CCC', 'delete CCC']);
  assert.deepEqual(deleteSimulator('gone', { run }), { deleted: false });
  assert.deepEqual(listSimulators('wave-', { run }).map(d => d.name), ['wave-sm-04']);
});

test('runDrive dismisses the first-launch notification prompt before the first step', async () => {
  const taps = [];
  let asked = true;
  const io = {
    async launch() {},
    async tree() { return asked ? [{ type: 'Button', AXLabel: "Don\u2019t Allow", frame: { x: 0, y: 100, width: 100, height: 40 } }, { type: 'Button', AXLabel: 'Allow', frame: { x: 100, y: 100, width: 100, height: 40 } }] : [{ type: 'Button', AXLabel: 'Timeline', frame: { x: 0, y: 0, width: 50, height: 50 } }]; },
    async tap(x, y) { taps.push([x, y]); asked = false; },
    async wait() {},
  };
  await runDrive([{ tap: 'Timeline', type: 'Button' }], io);
  assert.deepEqual(taps, [[50, 120], [25, 25]], "Don't Allow first (iOS curls the apostrophe), then the drive's own step");
});

test('the simulator pool: a free device is reused with fresh dev data, a new one is made only under the cap, the cap means waiting, release frees, drop forgets', () => {
  const path = join(tmpdir(), `ssot-claims-test-${process.pid}.json`);
  try { rmSync(path, { force: true }); } catch {}
  const pool = [];
  const list = () => ({ devices: { 'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
    { udid: 'DEV', name: 'iPhone 17 Pro', state: 'Booted', deviceTypeIdentifier: 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro' },
    ...pool,
  ] } });
  const calls = [], copies = [];
  let made = 0;
  const run = a => {
    calls.push(a.join(' '));
    if (a[0] === 'list') return JSON.stringify(list());
    if (a[0] === 'create') { made++; pool.push({ udid: `P${made}`, name: a[1], state: 'Shutdown', deviceTypeIdentifier: 'x' }); return `P${made}\n`; }
    if (a[0] === 'boot') { const d = pool.find(x => x.udid === a[1]); if (d) d.state = 'Booted'; return ''; }
    if (a[0] === 'get_app_container') return a[3] === 'data' ? `/sims/${a[1]}/data\n` : `/sims/${a[1]}/Runner.app\n`;
    if (a[0] === 'delete') { const i = pool.findIndex(x => x.udid === a[1]); pool.splice(i, 1); return ''; }
    return '';
  };
  const opts = { path, run, cap: 2, copy: (s, d) => copies.push([s, d]), now: () => '2026-09-15T16:00:00Z' };
  // Nothing exists: the first claim makes wave-pool-1.
  const a = claimSimulator('mealplanning-13', opts);
  assert.deepEqual(a, { udid: 'P1', name: 'wave-pool-1', from: 'DEV', runtime: 'iOS 26.2', reused: false, owner: 'mealplanning-13' });
  // The same owner asking again gets the same device, nothing new made.
  assert.deepEqual(claimSimulator('mealplanning-13', opts), { udid: 'P1', name: 'wave-pool-1', reused: true, owner: 'mealplanning-13' });
  // A second owner: still under the cap, so wave-pool-2 is made.
  const b = claimSimulator('mealplanning-18', opts);
  assert.equal(b.name, 'wave-pool-2'); assert.equal(b.reused, false);
  // A third owner at the cap waits, and is told who holds what.
  assert.deepEqual(claimSimulator('mealplanning-22', opts), { waiting: true, cap: 2, held: [{ name: 'wave-pool-1', owner: 'mealplanning-13' }, { name: 'wave-pool-2', owner: 'mealplanning-18' }] });
  assert.equal(made, 2, 'nothing is created at the cap');
  assert.deepEqual(listSimulators('wave-', { run, path }).map(d => [d.name, d.owner]), [['wave-pool-1', 'mealplanning-13'], ['wave-pool-2', 'mealplanning-18']]);
  // Release one; the waiting owner gets it back with the dev data copied over again.
  assert.deepEqual(releaseSimulator('wave-pool-1', { path, run }), { released: true, udid: 'P1', name: 'wave-pool-1', owner: 'mealplanning-13' });
  copies.length = 0;
  const c = claimSimulator('mealplanning-22', opts);
  assert.deepEqual(c, { udid: 'P1', name: 'wave-pool-1', reused: true, owner: 'mealplanning-22' });
  assert.deepEqual(copies, [['/sims/DEV/data', '/sims/P1/data']], 'a reused device gets the dev data again');
  assert.equal(made, 2);
  // Releasing something unclaimed says so; dropping a device forgets its claim.
  assert.equal(releaseSimulator('wave-pool-1', { path, run }).released, true);
  assert.equal(releaseSimulator('wave-pool-1', { path, run }).released, false);
  assert.deepEqual(deleteSimulator('wave-pool-2', { run, path }).deleted, true);
  assert.deepEqual(listSimulators('wave-', { run, path }).map(d => [d.name, d.owner]), [['wave-pool-1', null]]);
  // A claim on a device that vanished is dropped, so the slot is free again.
  claimSimulator('mealplanning-24', opts); // takes wave-pool-1
  pool.splice(0, 1); // the device disappears outside the tooling
  assert.equal(claimSimulator('mealplanning-25', opts).name, 'wave-pool-1', 'the stale claim is dropped and the name is free');
  assert.throws(() => claimSimulator('', opts), /needs an owner/);
  rmSync(path, { force: true });
});
