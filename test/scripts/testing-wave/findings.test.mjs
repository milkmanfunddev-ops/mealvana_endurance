// node --test test/scripts/testing-wave/   (all.mjs makes the folder runnable on Node 22)
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
const template = join(root, 'scripts/testing-wave/finding.template.md');

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

test('a three-digit ticket makes, reads and indexes its Findings', () => {
  const dir = folder({ '111-001-a.md': finding({ id: '111-001', ticket: '111' }), '11-001-b.md': finding({ id: '11-001' }) });
  copyFileSync(template, join(dir, 'TEMPLATE.md'));
  const made = newFinding(dir, '111', 'Cancel shows an error', { kind: 'bug', run: 'w30-20260925T2103Z' });
  assert.equal(made.split('/').pop(), '111-002-cancel-shows-an-error.md');
  assert.match(readFileSync(made, 'utf8'), /^- ticket: 111$/m);
  const found = readFindings(dir);
  assert.deepEqual(found.map(f => f.id).sort(), ['11-001', '111-001', '111-002']);
  assert.deepEqual(found.filter(f => f.id !== '111-002').flatMap(f => f.errors), []);
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

// ---------------------------------------------------------------------------------------------
// Rounds. A round is one folder under .scratch/testing-wave/rounds/<name>/ (issues/, findings/,
// runs/, app-build.json, TRIAGE.md). Every case points the script at a temp rounds folder through
// TESTING_WAVE_ROUNDS, so nothing here touches the repo's own .scratch/.

const roundsRoot = () => mkdtempSync(join(tmpdir(), 'rounds-'));
const cliIn = (rounds, args, env = {}) =>
  spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', env: { ...process.env, TESTING_WAVE_ROUND: '', ...env, TESTING_WAVE_ROUNDS: rounds } });

test('round new lays out a round folder from the templates', () => {
  const rounds = roundsRoot();
  const r = cliIn(rounds, ['round', 'new', 'develop-2026-10']);
  assert.equal(r.status, 0, r.stderr);
  const dir = join(rounds, 'develop-2026-10');
  for (const sub of ['issues', 'findings', 'runs']) assert.ok(existsSync(join(dir, sub)), sub);
  assert.deepEqual(JSON.parse(readFileSync(join(dir, 'app-build.json'), 'utf8')), { sha: null, built_at: null, simulator: null });
  assert.match(readFileSync(join(dir, 'TRIAGE.md'), 'utf8'), /^# .*develop-2026-10/);
  assert.match(readFileSync(join(dir, 'findings/INDEX.md'), 'utf8'), /0 Findings/);
  // The Finding template travels with the round, so `findings.mjs new` works in it at once.
  assert.match(readFileSync(join(dir, 'findings/TEMPLATE.md'), 'utf8'), /^- kind:/m);
});

test('round new is idempotent: a second run keeps what the round already holds', () => {
  const rounds = roundsRoot();
  cliIn(rounds, ['round', 'new', 'develop-2026-10']);
  const dir = join(rounds, 'develop-2026-10');
  writeFileSync(join(dir, 'TRIAGE.md'), '# Triage\n\nLee ruled 02-001 wontfix.\n');
  writeFileSync(join(dir, 'app-build.json'), JSON.stringify({ sha: 'abc1234', built_at: 'x', simulator: 'y' }));
  writeFileSync(join(dir, 'findings/02-001-a.md'), finding({ id: '02-001' }));
  const r = cliIn(rounds, ['round', 'new', 'develop-2026-10']);
  assert.equal(r.status, 0, r.stderr);
  assert.match(readFileSync(join(dir, 'TRIAGE.md'), 'utf8'), /Lee ruled 02-001 wontfix/);
  assert.equal(JSON.parse(readFileSync(join(dir, 'app-build.json'), 'utf8')).sha, 'abc1234');
  assert.ok(existsSync(join(dir, 'findings/02-001-a.md')));
});

test('round new refuses a name that is not a plain folder name', () => {
  const rounds = roundsRoot();
  for (const bad of ['../up', 'a/b', 'Has Space', '']) {
    const r = cliIn(rounds, ['round', 'new', bad]);
    assert.notEqual(r.status, 0, bad);
  }
  assert.deepEqual(readdirSync(rounds), []);
});

// Two rounds, each with one Finding whose title says which round it is in.
function twoRounds() {
  const rounds = roundsRoot();
  for (const [name, title] of [['mealplanning-2026-09', 'Old round finding'], ['develop-2026-10', 'New round finding']]) {
    mkdirSync(join(rounds, name, 'findings'), { recursive: true });
    mkdirSync(join(rounds, name, 'runs/02'), { recursive: true });
    writeFileSync(join(rounds, name, 'runs/02/paywall.png'), '');
    writeFileSync(join(rounds, name, 'findings/02-001-a.md'), finding({ id: '02-001', title, status: 'closed' }));
  }
  return rounds;
}

test('index reads the newest round when none is named', () => {
  const rounds = twoRounds();
  const r = cliIn(rounds, ['index']);
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /New round finding/);
  assert.ok(existsSync(join(rounds, 'develop-2026-10/findings/INDEX.md')));
  assert.ok(!existsSync(join(rounds, 'mealplanning-2026-09/findings/INDEX.md')));
});

test('index reads the round named by --round, or by TESTING_WAVE_ROUND', () => {
  const rounds = twoRounds();
  assert.match(cliIn(rounds, ['index', '--round', 'mealplanning-2026-09']).stdout, /Old round finding/);
  assert.match(cliIn(rounds, ['index'], { TESTING_WAVE_ROUND: 'mealplanning-2026-09' }).stdout, /Old round finding/);
  // The flag wins over the variable.
  assert.match(cliIn(rounds, ['index', '--round', 'develop-2026-10'], { TESTING_WAVE_ROUND: 'mealplanning-2026-09' }).stdout, /New round finding/);
});

test('a round that does not exist is an error, not an empty index', () => {
  const r = cliIn(twoRounds(), ['index', '--round', 'nope-2026-11']);
  assert.notEqual(r.status, 0);
  assert.notEqual(r.status, 1);
  assert.match(r.stderr, /nope-2026-11/);
});

test('new files the Finding in the round folder', () => {
  const rounds = roundsRoot();
  cliIn(rounds, ['round', 'new', 'develop-2026-10']);
  const r = cliIn(rounds, ['new', '29', 'Cold start shows a red screen', '--kind', 'bug', '--run', 'w1-20261006T1000Z']);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout.trim(), join(rounds, 'develop-2026-10/findings/29-001-cold-start-shows-a-red-screen.md'));
});

// ---------------------------------------------------------------------------------------------
// Ledgers. `findings.mjs ledger <round>` turns a round's Findings into rows of
// docs/testing-wave/BUGS.md (bug, ssot-conflict) and COVERAGE.md (followup-test, idea, and one row
// per retest draft). --docs points it at a temp docs folder here.

const triaged = (text, extra = {}) => finding({ ...extra }) + `\n**Triage.**\n${text}\n`;
function ledgerRound() {
  const wave = mkdtempSync(join(tmpdir(), 'ledger-src-'));
  const dir = join(wave, 'findings');
  mkdirSync(dir);
  const files = {
    '02-001-a.md': finding({ id: '02-001', title: 'Sign-up screen freezes', status: 'open' }),
    '02-002-b.md': triaged('Fix ticket 33 (Lee, 2026-09-25). Closed by the retest after it merges.', { id: '02-002', title: 'Name field keeps old text', status: 'triaged' }),
    '02-003-c.md': triaged('Fix ticket 46 (Lee, 2026-09-25). Closed by the retest after it merges.\nMoved to retest ticket 115 when 91 was split (Lee, 2026-09-25).\n\nRun by retest ticket 115 (run w32-20260925T2219Z, build e3367d2c): pass.', { id: '02-003', title: 'Timeline is empty | after resubscribe', status: 'closed' }),
    '03-001-d.md': triaged("Won't fix (Lee, 2026-09-25): the build lock was removed on 2026-09-24; the wave lead builds once.", { id: '03-001', title: 'Lock released early', status: 'wontfix' }),
    '03-002-e.md': triaged('Closed (2026-09-26 triage): fixed by `f8ea7233`; the index reads every file.', { id: '03-002', title: 'Index skipped 1xx files', status: 'closed' }),
    '03-003-f.md': triaged('Run by retest ticket 88 (run w29, build e3367d2c): fail, filed as 88-012; closed here, the new Finding carries it.', { id: '03-003', title: 'Retest failed and moved on', status: 'closed' }),
    '04-001-g.md': finding({ id: '04-001', title: 'Read-only mode exists', kind: 'ssot-conflict', status: 'triaged', decision: 'mp-457', quote: '> no read-only mode' }),
    '05-001-h.md': triaged('Picked for retest ticket 92 (Lee, 2026-09-25).', { id: '05-001', title: 'Try a cold relaunch', kind: 'followup-test', status: 'triaged' }),
    '05-002-i.md': finding({ id: '05-002', title: 'Dark mode paywall', kind: 'idea', status: 'open' }),
    'TEMPLATE.md': readFileSync(template, 'utf8'),
    'INDEX.md': '# index\n',
  };
  for (const [name, text] of Object.entries(files)) writeFileSync(join(dir, name), text);
  mkdirSync(join(wave, 'retest-drafts'));
  writeFileSync(join(wave, 'retest-drafts/143-retest-shopping.md'), '# 143: Retest: the Shopping tab offline copy\n\n**Status:** ready-for-agent\n');
  return wave;
}
const docsDir = () => mkdtempSync(join(tmpdir(), 'docs-'));
const ledgerCli = (docs, ...args) => spawnSync(process.execPath, [cli, 'ledger', ...args, '--docs', docs], { encoding: 'utf8' });
const rowsOf = text => text.split('\n').filter(l => /^\| [^-\s|]/.test(l) && !/^\| id \|/.test(l));
const rowFor = (text, id) => rowsOf(text).find(l => l.startsWith(`| ${id} |`));

test('ledger writes bugs and SSOT conflicts to BUGS.md with status and fix ticket', () => {
  const docs = docsDir();
  const r = ledgerCli(docs, '--from', ledgerRound(), '--round', 'mealplanning-2026-09');
  assert.equal(r.status, 0, r.stderr);
  const bugs = readFileSync(join(docs, 'BUGS.md'), 'utf8');
  assert.match(bugs, /^\| id \| round \| ticket \| title \| kind \| status \| fix ticket \|$/m);
  assert.equal(rowsOf(bugs).length, 7);
  assert.equal(rowFor(bugs, '02-001'), '| 02-001 | mealplanning-2026-09 | 02 | Sign-up screen freezes | bug | open |  |');
  assert.equal(rowFor(bugs, '02-002'), '| 02-002 | mealplanning-2026-09 | 02 | Name field keeps old text | bug | triaged | 33 |');
  // A passed retest names the build the fix was verified on; a pipe in a title is escaped.
  assert.equal(rowFor(bugs, '02-003'), '| 02-003 | mealplanning-2026-09 | 02 | Timeline is empty \\| after resubscribe | bug | fixed @e3367d2c | 46 |');
  assert.match(rowFor(bugs, '03-001'), /\| wontfix: Lee, 2026-09-25: the build lock was removed on 2026-09-24; the wave lead builds once\. \|/);
  assert.match(rowFor(bugs, '03-002'), /\| fixed @f8ea7233 \|/);
  // Closed without a fix (the retest failed and a new Finding took it over) stays plain closed.
  assert.match(rowFor(bugs, '03-003'), /\| bug \| closed \|/);
  assert.match(rowFor(bugs, '04-001'), /\| ssot-conflict \| triaged \|/);
  assert.equal(rowFor(bugs, '05-001'), undefined);
});

test('ledger writes follow-up tests, ideas and retest drafts to COVERAGE.md', () => {
  const docs = docsDir();
  ledgerCli(docs, '--from', ledgerRound(), '--round', 'mealplanning-2026-09');
  const cov = readFileSync(join(docs, 'COVERAGE.md'), 'utf8');
  assert.match(cov, /^\| id \| round \| ticket \| title \| kind \| status \|$/m);
  assert.equal(rowsOf(cov).length, 3);
  assert.equal(rowFor(cov, '05-001'), '| 05-001 | mealplanning-2026-09 | 05 | Try a cold relaunch | followup-test | triaged |');
  assert.equal(rowFor(cov, '05-002'), '| 05-002 | mealplanning-2026-09 | 05 | Dark mode paywall | idea | open |');
  assert.equal(rowFor(cov, 'retest-143'), '| retest-143 | mealplanning-2026-09 | 143 | Retest: the Shopping tab offline copy | retest-draft | ready-for-agent |');
  assert.equal(rowFor(cov, '02-001'), undefined);
});

test('ledger is idempotent and updates a changed status in place', () => {
  const docs = docsDir();
  const src = ledgerRound();
  ledgerCli(docs, '--from', src, '--round', 'mealplanning-2026-09');
  // Hand-written text above the generated rows survives every re-run.
  const bugsPath = join(docs, 'BUGS.md');
  writeFileSync(bugsPath, readFileSync(bugsPath, 'utf8').replace(/^# .*$/m, '$&\n\nLee\'s note: read the wontfix rows first.'));
  const before = readFileSync(bugsPath, 'utf8');
  ledgerCli(docs, '--from', src, '--round', 'mealplanning-2026-09');
  assert.equal(readFileSync(bugsPath, 'utf8'), before);
  // Triage moves 02-001 to wontfix: the row changes where it stands, nothing is added.
  writeFileSync(join(src, 'findings/02-001-a.md'), triaged("Won't fix (Lee, 2026-10-06): not reproducible.", { id: '02-001', title: 'Sign-up screen freezes', status: 'wontfix' }));
  const r = ledgerCli(docs, '--from', src, '--round', 'mealplanning-2026-09');
  assert.equal(r.status, 0, r.stderr);
  const after = readFileSync(bugsPath, 'utf8');
  assert.equal(rowsOf(after).length, rowsOf(before).length);
  assert.equal(rowsOf(after).indexOf(rowFor(after, '02-001')), rowsOf(before).indexOf(rowFor(before, '02-001')));
  assert.match(rowFor(after, '02-001'), /\| wontfix: Lee, 2026-10-06: not reproducible\. \|/);
  assert.match(after, /Lee's note: read the wontfix rows first\./);
});

test('a second round appends its own rows; the same Finding id in two rounds is two rows', () => {
  const docs = docsDir();
  ledgerCli(docs, '--from', ledgerRound(), '--round', 'mealplanning-2026-09');
  const rounds = roundsRoot();
  cliIn(rounds, ['round', 'new', 'develop-2026-10']);
  writeFileSync(join(rounds, 'develop-2026-10/findings/02-001-x.md'), finding({ id: '02-001', title: 'Develop sign-up freezes' }));
  const r = spawnSync(process.execPath, [cli, 'ledger', 'develop-2026-10', '--docs', docs], { encoding: 'utf8', env: { ...process.env, TESTING_WAVE_ROUNDS: rounds } });
  assert.equal(r.status, 0, r.stderr);
  const rows = rowsOf(readFileSync(join(docs, 'BUGS.md'), 'utf8'));
  assert.equal(rows.length, 8);
  assert.equal(rows.filter(l => l.startsWith('| 02-001 |')).length, 2);
  assert.match(rows.at(-1), /\| 02-001 \| develop-2026-10 \| 02 \| Develop sign-up freezes \|/);
});

test('ledger needs a round name', () => {
  const r = ledgerCli(docsDir(), '--from', ledgerRound());
  assert.equal(r.status, 64);
  assert.match(r.stderr, /usage/);
});

test('a closing line that names the fix commit in backticks counts as fixed at that commit', () => {
  const wave = mkdtempSync(join(tmpdir(), 'ledger-src-'));
  mkdirSync(join(wave, 'findings'));
  writeFileSync(join(wave, 'findings/02-007-a.md'), triaged('Fix ticket 57 (Lee, 2026-09-25). Closed by the retest after it merges.\n\nClosed by the wave lead (2026-09-25, from code): ticket 57 (`38e8f1b3`) removed the built-in key.', { id: '02-007', title: 'Stale key', status: 'closed' }));
  writeFileSync(join(wave, 'findings/09-003-b.md'), triaged('Fix ticket 69 (Lee, 2026-09-25).\n\nClosed by the wave lead (2026-09-25, SQL on dev): `meal_library` AD-001 has no photo.', { id: '09-003', title: 'Striped photo', status: 'closed' }));
  const docs = docsDir();
  assert.equal(ledgerCli(docs, '--from', wave, '--round', 'r-2026-09').status, 0);
  const bugs = readFileSync(join(docs, 'BUGS.md'), 'utf8');
  assert.match(rowFor(bugs, '02-007'), /\| fixed @38e8f1b3 \| 57 \|/);
  assert.match(rowFor(bugs, '09-003'), /\| closed \| 69 \|/);
});
