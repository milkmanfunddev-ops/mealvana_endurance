// Unit tests for the round-file writer's assembly: weights, robotic-cap override, rerun
// averaging, pass bar, and prose/sidecar consistency. Run with:
//   node --test eval/tools/
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  DIMENSIONS,
  ROBOTIC_CAP,
  buildSidecar,
  renderProse,
  validateInput,
  weightedMark,
} from './lib/round.mjs';

const all75 = Object.fromEntries(DIMENSIONS.map((d) => [d.slug, 75]));

const run = (over = {}) => ({
  scenario: 'pre-run-breakfast-reframe',
  account: 'test',
  dimensions: { ...all75 },
  verdict: 'Solid Run. One late clarifying question.',
  improvements: ['IMP-001'],
  ...over,
});

const input = (over = {}) => ({
  round: '001',
  date: '2026-09-26',
  runs: [run()],
  ...over,
});

test('the ten slugs match the board contract and the rubric weights sum to 100', () => {
  assert.deepEqual(
    DIMENSIONS.map((d) => d.slug),
    [
      'dietitian-judgment',
      'task-success',
      'concision-restraint',
      'interactivity',
      'tool-use-data-ops',
      'memory-personalization',
      'reliability',
      'opener',
      'instruction-following',
      'recovery-boundaries',
    ],
  );
  assert.equal(DIMENSIONS.reduce((s, d) => s + d.weight, 0), 100);
  // rubric.md weights, in rubric order
  assert.deepEqual(
    DIMENSIONS.map((d) => d.weight),
    [20, 15, 10, 10, 10, 10, 10, 5, 5, 5],
  );
});

test('weightedMark is the weight-weighted sum of the dimension marks', () => {
  assert.equal(weightedMark(all75), 75);
  const dims = { ...all75, 'dietitian-judgment': 100, reliability: 0 };
  // 75 + (100-75)*0.20 + (0-75)*0.10 = 75 + 5 - 7.5 = 72.5
  assert.equal(weightedMark(dims), 72.5);
});

test('buildSidecar computes the weighted mark and passes a clean round', () => {
  const sidecar = buildSidecar(input());
  assert.equal(sidecar.round, '001');
  assert.equal(sidecar.date, '2026-09-26');
  assert.equal(sidecar.runs.length, 1);
  const r = sidecar.runs[0];
  assert.equal(r.scenario, 'pre-run-breakfast-reframe');
  assert.equal(r.account, 'test');
  assert.equal(r.rerun, false);
  assert.equal(r.robotic_cap_applied, false);
  assert.equal(r.weighted_mark, 75);
  assert.deepEqual(r.improvements, ['IMP-001']);
  // dimensions come out in canonical order
  assert.deepEqual(Object.keys(r.dimensions), DIMENSIONS.map((d) => d.slug));
  assert.equal(sidecar.average_mark, 75);
  assert.equal(sidecar.passed, false); // average 75 < 90
});

test('a passing round needs average >= 90 and no effective mark below 80', () => {
  const pass = buildSidecar(input({ runs: [run({ dimensions: { ...all75, 'dietitian-judgment': 100 } })] }));
  assert.equal(pass.runs[0].weighted_mark, 80);
  assert.equal(pass.passed, false); // 80 < 90
  const high = buildSidecar(input({ runs: [run({ dimensions: { ...all75, 'dietitian-judgment': 100, 'task-success': 100 } })] }));
  assert.equal(high.average_mark, 83.75); // 75 + 25*0.20 + 25*0.15
  assert.equal(high.passed, false);
  const all100 = buildSidecar(input({ runs: [run({ dimensions: Object.fromEntries(DIMENSIONS.map((d) => [d.slug, 100])) })] }));
  assert.equal(all100.average_mark, 100);
  assert.equal(all100.passed, true);
});

test('the robotic cap brings a higher weighted mark down to 50', () => {
  const sidecar = buildSidecar(input({ runs: [run({ robotic_cap_applied: true })] }));
  assert.equal(sidecar.runs[0].robotic_cap_applied, true);
  assert.equal(sidecar.runs[0].weighted_mark, ROBOTIC_CAP);
  assert.equal(sidecar.average_mark, 50);
});

test('the robotic cap does not lift a weighted mark that was already below 50', () => {
  const dims = Object.fromEntries(DIMENSIONS.map((d) => [d.slug, 25]));
  const sidecar = buildSidecar(input({ runs: [run({ dimensions: dims, robotic_cap_applied: true })] }));
  assert.equal(sidecar.runs[0].weighted_mark, 25);
});

test('a rerun does not overwrite the original and the average uses the rerun mark', () => {
  const sidecar = buildSidecar(input({
    runs: [
      run({ verdict: 'original verdict' }),
      run({ rerun: true, verdict: 'rerun verdict', improvements: ['IMP-002'] }),
    ],
  }));
  assert.equal(sidecar.runs.length, 2);
  assert.equal(sidecar.runs[0].rererun, undefined);
  assert.equal(sidecar.runs[0].rerun, false);
  assert.equal(sidecar.runs[1].rerun, true);
  assert.equal(sidecar.runs[0].verdict, 'original verdict');
  assert.equal(sidecar.runs[1].verdict, 'rerun verdict');
  // both marks are 75 here; make the rerun differ to see the average follow it
  const moved = buildSidecar(input({
    runs: [
      run(),
      run({ rerun: true, dimensions: { ...all75, 'dietitian-judgment': 0 } }),
    ],
  }));
  assert.equal(moved.runs[0].weighted_mark, 75);
  assert.equal(moved.runs[1].weighted_mark, 60); // 75 - 75*0.20
  assert.equal(moved.average_mark, 60); // the rerun's mark, not the mean of both
});

test('validateInput rejects malformed input with every problem named', () => {
  assert.throws(() => validateInput({}), /round/);
  assert.throws(() => validateInput({ round: '1', date: '2026-09-26', runs: [] }), /round/);
  assert.throws(() => validateInput(input({ runs: [] })), /at least one Run/);
  assert.throws(
    () => validateInput(input({ runs: [run({ dimensions: { ...all75, bogus: 50 } })] })),
    /bogus/,
  );
  assert.throws(
    () => validateInput(input({ runs: [run({ dimensions: { ...all75, reliability: 60 } })] })),
    /reliability/,
  );
  // a missing dimension is a problem too
  const short = { ...all75 };
  delete short.opener;
  assert.throws(() => validateInput(input({ runs: [run({ dimensions: short })] })), /opener/);
  assert.throws(
    () => validateInput(input({ runs: [run({ improvements: ['IMPROVEMENT-1'] })] })),
    /IMPROVEMENT-1/,
  );
  assert.throws(
    () => validateInput(input({ runs: [run({ rerun: true })] })),
    /rerun.*pre-run-breakfast-reframe|pre-run-breakfast-reframe.*rerun/,
  );
  assert.throws(
    () => validateInput(input({ runs: [run(), run()] })),
    /pre-run-breakfast-reframe.*once|twice/,
  );
  // happy paths
  assert.ok(validateInput(input()));
  assert.ok(validateInput(input({ round: 'pilot' })));
});

test('renderProse and the sidecar tell one story', () => {
  const sidecar = buildSidecar(input({
    runs: [
      run({ verdict: 'Top defect: opener was generic.' }),
      run({ rerun: true, verdict: 'Rerun verdict text.', improvements: ['IMP-001', 'IMP-004'] }),
    ],
  }));
  const prose = renderProse(sidecar);
  // round, date, pass/fail and the average all appear
  assert.match(prose, /Round 001/);
  assert.match(prose, /2026-09-26/);
  assert.match(prose, /FAIL/);
  assert.match(prose, /75/);
  // every run row: scenario, account, mark, rerun marker, improvements
  assert.match(prose, /pre-run-breakfast-reframe/);
  assert.match(prose, /\(rerun\)/);
  assert.match(prose, /IMP-004/);
  // both verdicts appear verbatim
  assert.match(prose, /Top defect: opener was generic\./);
  assert.match(prose, /Rerun verdict text\./);
  // every dimension mark appears next to its slug
  for (const d of DIMENSIONS) assert.match(prose, new RegExp(`\\| ${d.slug} \\| 75 \\| ${d.weight} \\|`));
  // no leftover undefined/null leaked into the prose
  assert.doesNotMatch(prose, /undefined|null|NaN/);
});

test('a passing round says PASS', () => {
  const sidecar = buildSidecar(input({ runs: [run({ dimensions: Object.fromEntries(DIMENSIONS.map((d) => [d.slug, 100])) })] }));
  assert.match(renderProse(sidecar), /PASS/);
});
