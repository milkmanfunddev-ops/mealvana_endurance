// node --test test/scripts/testing-wave/*.test.mjs   (Node 22 takes files or globs, not a folder)
//
// Every case writes hand-written Finding files into a temp folder and checks what
// the index script prints, writes and exits with. None of them looks at how it parses.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFindings, loopState, renderIndex, newFinding } from '../../../scripts/testing-wave/findings.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../../..');
const cli = join(root, 'scripts/testing-wave/findings.mjs');
const template = join(root, '.scratch/testing-wave/findings/TEMPLATE.md');

function finding({ id = '02-001', title = 'Something broke', kind = 'bug', status = 'open', ticket, run = 'w1-20260923T1405Z', screen = 'Paywall', decision = '', steps = '1. Open the paywall.', expected = 'No close button.', actual = 'A close button.', evidence = '- runs/02/paywall.png', quote = '' } = {}) {
  return `# ${id} · ${title}

- kind: ${kind}
- status: ${status}
- ticket: ${ticket ?? id.slice(0, 2)}
- run: ${run}
- screen: ${screen}
- decision: ${decision}

**Steps.**
${steps}

**Expected.**
${expected}

**Actual.**
${actual}

**Evidence.**
${evidence}

**Decision quote.**
${quote}
`;
}

// A findings folder inside a testing-wave folder, the way the repo has it, with the evidence file
// the default Finding cites (runs/02/paywall.png) in place.
function folder(files, evidence = ['runs/02/paywall.png']) {
  const wave = mkdtempSync(join(tmpdir(), 'testing-wave-'));
  const dir = join(wave, 'findings');
  mkdirSync(dir);
  for (const path of evidence) { mkdirSync(dirname(join(wave, path)), { recursive: true }); writeFileSync(join(wave, path), ''); }
  for (const [name, text] of Object.entries(files)) writeFileSync(join(dir, name), text);
  return dir;
}

function index(dir, ...args) {
  return spawnSync(process.execPath, [cli, 'index', dir, ...args], { encoding: 'utf8' });
}

test('the index groups every Finding by kind and status and writes INDEX.md', () => {
  const dir = folder({
    '02-001-close-button.md': finding({ id: '02-001', title: 'Paywall has a close button', status: 'closed' }),
    '04-001-read-only-mode.md': finding({ id: '04-001', title: 'Lapsed account gets a read-only mode', kind: 'ssot-conflict', status: 'triaged', decision: 'mp-457', quote: '> there is no read-only mode' }),
    '04-002-try-back-swipe.md': finding({ id: '04-002', title: 'Swipe back from the paywall', kind: 'followup-test', status: 'wontfix' }),
    '09-001-dark-mode.md': finding({ id: '09-001', title: 'Paywall in dark mode', kind: 'idea', status: 'closed' }),
    'TEMPLATE.md': readFileSync(template, 'utf8'),
  });
  const r = index(dir);
  const written = readFileSync(join(dir, 'INDEX.md'), 'utf8');
  assert.equal(r.stdout.trim(), written.trim());
  const at = s => written.indexOf(s);
  // Kinds in a fixed order, each with its statuses under it.
  assert.ok(at('## bug') < at('## ssot-conflict') && at('## ssot-conflict') < at('## followup-test') && at('## followup-test') < at('## idea'));
  assert.ok(at('### closed (1)') > at('## bug'));
  assert.match(written, /04-001.*Lapsed account gets a read-only mode.*mp-457/);
  assert.ok(at('04-001') > at('## ssot-conflict') && at('04-001') < at('## followup-test'));
  // The template is not a Finding.
  assert.doesNotMatch(written, /One line saying what happened/);
});

test('the loop is not finished while a Finding is open', () => {
  const dir = folder({
    '02-001-a.md': finding({ id: '02-001', status: 'closed' }),
    '02-002-b.md': finding({ id: '02-002', title: 'Code never arrived', status: 'open' }),
  });
  const r = index(dir);
  assert.equal(r.status, 1);
  assert.match(r.stdout, /not finished/i);
  assert.match(r.stdout, /02-002/);
});

test('the loop is not finished while a follow-up test waits, even once triaged', () => {
  const dir = folder({ '05-001-a.md': finding({ id: '05-001', kind: 'followup-test', status: 'triaged' }) });
  assert.equal(index(dir).status, 1);
});

test('a bug whose fix has not been retested keeps the loop going', () => {
  for (const status of ['triaged', 'fixing']) {
    const dir = folder({ '05-001-a.md': finding({ id: '05-001', status }) });
    assert.equal(index(dir).status, 1, status);
  }
});

test('the loop is finished when every Finding is closed or wontfix', () => {
  const dir = folder({
    '02-001-a.md': finding({ id: '02-001', status: 'closed' }),
    '03-001-b.md': finding({ id: '03-001', kind: 'followup-test', status: 'wontfix' }),
    '03-002-c.md': finding({ id: '03-002', kind: 'idea', status: 'closed' }),
  });
  const r = index(dir);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /finished/i);
  assert.doesNotMatch(r.stdout, /not finished/i);
});

test('an empty folder is a finished loop with nothing in it', () => {
  const r = index(folder({}));
  assert.equal(r.status, 0);
  assert.match(r.stdout, /0 Findings/);
});

test('a Finding with an unknown kind or status fails the index and names the file', () => {
  const dir = folder({
    '02-001-a.md': finding({ id: '02-001', kind: 'crash' }),
    '02-002-b.md': finding({ id: '02-002', status: 'done' }),
  });
  const r = index(dir);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /02-001-a\.md.*kind/);
  assert.match(r.stderr, /02-002-b\.md.*status/);
});

test('an SSOT conflict must cite the decision id and quote it', () => {
  const dir = folder({ '04-001-a.md': finding({ id: '04-001', kind: 'ssot-conflict', decision: '', quote: '' }) });
  const r = index(dir);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /decision id/);
  assert.match(r.stderr, /quote/);
});

test('a Finding whose ticket does not match its file name fails the index', () => {
  const dir = folder({ '02-001-a.md': finding({ id: '02-001', ticket: '07' }) });
  const r = index(dir);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /02-001-a\.md.*ticket/);
});

test('--out writes the index where it is told', () => {
  const dir = folder({ '02-001-a.md': finding({ id: '02-001', status: 'closed' }) });
  const out = join(mkdtempSync(join(tmpdir(), 'index-')), 'X.md');
  index(dir, '--out', out);
  assert.ok(existsSync(out));
  assert.ok(!existsSync(join(dir, 'INDEX.md')));
});

test('the functions answer the same as the CLI', () => {
  const dir = folder({
    '02-001-a.md': finding({ id: '02-001', status: 'closed' }),
    '02-002-b.md': finding({ id: '02-002', kind: 'followup-test', status: 'open' }),
  });
  const findings = readFindings(dir);
  assert.equal(findings.length, 2);
  const state = loopState(findings);
  assert.equal(state.finished, false);
  assert.deepEqual(state.blocking.map(f => f.id), ['02-002']);
  assert.match(renderIndex(findings), /## followup-test/);
});

test('new names the file after the ticket with the next free number and fills in the template', () => {
  const dir = folder({ '02-001-a.md': finding({ id: '02-001' }), '07-004-z.md': finding({ id: '07-004' }) });
  copyFileSync(template, join(dir, 'TEMPLATE.md'));
  const first = newFinding(dir, '2', 'Code never arrived', { kind: 'bug', run: 'w1-20260923T1405Z' });
  assert.equal(first.split('/').pop(), '02-002-code-never-arrived.md');
  const second = newFinding(dir, '07', 'try-dark-mode', { kind: 'followup-test', run: 'w1-20260923T1405Z' });
  assert.equal(second.split('/').pop(), '07-005-try-dark-mode.md');
  const text = readFileSync(first, 'utf8');
  assert.match(text, /^# 02-002 · Code never arrived/m);
  assert.match(text, /^- kind: bug$/m);
  assert.match(text, /^- status: open$/m);
  assert.match(text, /^- ticket: 02$/m);
  assert.match(text, /^- run: w1-20260923T1405Z$/m);
  // A freshly made Finding is a valid, open one: the loop is not finished.
  assert.equal(readFindings(dir).filter(f => f.id === '02-002').length, 1);
  assert.equal(loopState(readFindings(dir)).finished, false);
  assert.ok(readdirSync(dir).includes('07-005-try-dark-mode.md'));
});

test('new refuses an unknown kind', () => {
  const dir = folder({});
  copyFileSync(template, join(dir, 'TEMPLATE.md'));
  assert.throws(() => newFinding(dir, '02', 'x', { kind: 'crash', run: 'w1' }), /kind/);
});

test('a Finding whose evidence file is missing fails the index and names the path', () => {
  const dir = folder({ '08-001-a.md': finding({ id: '08-001', evidence: '- runs/08/console.log (the lost connection)\n- runs/02/paywall.png' }) });
  const r = index(dir);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /08-001-a\.md: evidence runs\/08\/console\.log does not exist/);
  assert.doesNotMatch(r.stderr, /paywall\.png/);
});

test('evidence may be a repo path, backticked, or prose with no path', () => {
  const dir = folder({ '08-001-a.md': finding({ id: '08-001', evidence: '- `runs/02/paywall.png` at 12:31Z\n- scripts/testing-wave/findings.mjs (the index)\n- the console, 12:28 to 12:36Z' }) });
  assert.equal(index(dir).status, 1);
});

// An SSOT conflict may cite a spec file and heading instead of a decision id (IMPROVEMENTS #37).
// The spec lives in a scratch repo root passed as `root` (or `--root`), never the real docs/ssot/.
function specRoot() {
  const root = mkdtempSync(join(tmpdir(), 'spec-root-'));
  const path = join(root, 'docs/ssot/spec/paywall/lapsed.md');
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, '# Lapsed accounts\n\n## When the plan ends\n\nA lapsed account sees the paywall full screen.\nThere is no read-only\nmode, and the user stays signed in.\n\n## Restore\n\nRestore is always offered.\n');
  return root;
}
const specConflict = (decision, quote = '> There is no read-only mode, and the user stays signed in.') =>
  ({ '04-001-a.md': finding({ id: '04-001', kind: 'ssot-conflict', decision, quote }) });

test('an SSOT conflict may cite a spec file and heading whose text holds the quote', () => {
  const root = specRoot();
  const dir = folder(specConflict('docs/ssot/spec/paywall/lapsed.md#When the plan ends'));
  const [f] = readFindings(dir, { root });
  assert.deepEqual(f.errors, []);
  const r = index(dir, '--root', root);
  assert.equal(r.status, 1, r.stderr);
  assert.match(r.stdout, /04-001.*decision: docs\/ssot\/spec\/paywall\/lapsed\.md#When the plan ends/);
});

test('a spec citation fails when the file is missing', () => {
  const r = index(folder(specConflict('docs/ssot/spec/paywall/nope.md#When the plan ends')), '--root', specRoot());
  assert.equal(r.status, 2);
  assert.match(r.stderr, /04-001-a\.md: .*docs\/ssot\/spec\/paywall\/nope\.md does not exist/);
});

test('a spec citation fails when the heading is not in the file', () => {
  const r = index(folder(specConflict('docs/ssot/spec/paywall/lapsed.md#When the trial ends')), '--root', specRoot());
  assert.equal(r.status, 2);
  assert.match(r.stderr, /04-001-a\.md: .*no heading "When the trial ends"/);
});

test('a spec citation fails when the quote is not in the file', () => {
  const r = index(folder(specConflict('docs/ssot/spec/paywall/lapsed.md#When the plan ends', '> A lapsed account keeps a read-only mode.')), '--root', specRoot());
  assert.equal(r.status, 2);
  assert.match(r.stderr, /04-001-a\.md: .*quote is not in docs\/ssot\/spec\/paywall\/lapsed\.md/);
});

test('a decision that is neither an id nor a spec reference is refused', () => {
  const r = index(folder(specConflict('docs/other/lapsed.md#When the plan ends')), '--root', specRoot());
  assert.equal(r.status, 2);
  assert.match(r.stderr, /decision id/);
});
