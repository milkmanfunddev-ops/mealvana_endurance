// The round-file writer's assembly, pure and network-free so `node --test eval/tools/` covers
// it. The board (eval/board/README.md) reads these exact field names from round.json; the
// dimension slugs are pinned there and here, once.
//
// Weights and the cap mirror eval/rubric.md, which owns them. If rubric.md changes, change the
// table here to match — the tests assert the sum is 100 and the order is the rubric's.

export const DIMENSIONS = [
  { slug: 'dietitian-judgment', weight: 20 },
  { slug: 'task-success', weight: 15 },
  { slug: 'concision-restraint', weight: 10 },
  { slug: 'interactivity', weight: 10 },
  { slug: 'tool-use-data-ops', weight: 10 },
  { slug: 'memory-personalization', weight: 10 },
  { slug: 'reliability', weight: 10 },
  { slug: 'opener', weight: 5 },
  { slug: 'instruction-following', weight: 5 },
  { slug: 'recovery-boundaries', weight: 5 },
];

const SLUGS = DIMENSIONS.map((d) => d.slug);
const VALID_MARKS = new Set([0, 25, 50, 75, 100]);

export const ROBOTIC_CAP = 50;
export const PASS_AVERAGE = 90;
export const PASS_FLOOR = 80;

const IMP_ID = /^IMP-\d{3,}$/;

/** The weighted sum on the 0–100 scale (weights sum to 100). */
export function weightedMark(dimensions) {
  return DIMENSIONS.reduce((sum, d) => sum + dimensions[d.slug] * d.weight, 0) / 100;
}

/** One Run's Mark: the weighted sum, brought down to the robotic cap when the cap was applied
 *  (rubric.md: a Run that reads as a state machine is capped at 50 regardless of the
 *  dimensions; a sum already below 50 stays where it is). */
export function runMark(run) {
  const raw = weightedMark(run.dimensions);
  return run.robotic_cap_applied ? Math.min(raw, ROBOTIC_CAP) : raw;
}

/** Every problem with the Examiner's input, in one throw. The happy path returns the input
 *  normalized (defaults filled) so the writer and the tests share one shape. */
export function validateInput(input) {
  const problems = [];
  if (!input || typeof input !== 'object') throw new Error('input is not an object');
  if (!/^(\d{3}|pilot)$/.test(String(input.round ?? ''))) problems.push(`round "${input.round}" must be "001"-style or "pilot"`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.date ?? ''))) problems.push(`date "${input.date}" must be ISO YYYY-MM-DD`);
  if (!Array.isArray(input.runs) || input.runs.length === 0) problems.push('runs must list at least one Run');
  if (problems.length) throw new Error(problems.join('; '));

  const seenOriginal = new Set();
  const hasOriginal = new Set();
  for (const [i, run] of input.runs.entries()) {
    const at = `runs[${i}] (${run?.scenario ?? '?'})`;
    if (typeof run?.scenario !== 'string' || !/^[\w.-]+$/.test(run.scenario)) problems.push(`${at}: scenario must be a slug`);
    if (typeof run?.account !== 'string' || !run.account.trim()) problems.push(`${at}: account must be a slug from accounts.md`);
    if (typeof run?.verdict !== 'string' || !run.verdict.trim()) problems.push(`${at}: verdict text is required`);
    if (!run?.dimensions || typeof run.dimensions !== 'object') {
      problems.push(`${at}: dimensions object is required`);
      continue;
    }
    for (const key of Object.keys(run.dimensions)) {
      if (!SLUGS.includes(key)) problems.push(`${at}: "${key}" is not one of the ten dimension slugs`);
    }
    for (const d of DIMENSIONS) {
      const v = run.dimensions[d.slug];
      if (!(d.slug in run.dimensions)) problems.push(`${at}: dimension "${d.slug}" is missing`);
      else if (!VALID_MARKS.has(v)) problems.push(`${at}: dimension "${d.slug}" mark ${JSON.stringify(v)} is not 0/25/50/75/100`);
    }
    for (const id of run.improvements ?? []) {
      if (!IMP_ID.test(id)) problems.push(`${at}: improvement "${id}" is not an IMP-### id`);
    }
    if (run.rerun && !hasOriginal.has(run.scenario)) problems.push(`${at}: a rerun needs its original Run before it`);
    if (!run.rerun) {
      if (seenOriginal.has(run.scenario)) problems.push(`${at}: scenario "${run.scenario}" runs more than once; a second pass is a rerun`);
      seenOriginal.add(run.scenario);
      hasOriginal.add(run.scenario);
    }
  }
  if (problems.length) throw new Error(problems.join('; '));

  return {
    round: String(input.round),
    date: String(input.date),
    runs: input.runs.map((r) => ({
      scenario: r.scenario,
      account: r.account,
      rerun: r.rerun === true,
      dimensions: Object.fromEntries(DIMENSIONS.map((d) => [d.slug, r.dimensions[d.slug]])),
      robotic_cap_applied: r.robotic_cap_applied === true,
      verdict: r.verdict,
      improvements: r.improvements ?? [],
    })),
  };
}

/** The sidecar, in the field order eval/README.md documents. The average and the pass bar use
 *  each Scenario's effective Mark — the rerun's when one exists, else the Run's (round
 *  protocol step 7). */
export function buildSidecar(input) {
  const clean = validateInput(input);
  const runs = clean.runs.map((r) => ({
    scenario: r.scenario,
    account: r.account,
    rerun: r.rerun,
    dimensions: r.dimensions,
    weighted_mark: runMark(r),
    robotic_cap_applied: r.robotic_cap_applied,
    verdict: r.verdict,
    improvements: r.improvements,
  }));
  const effective = new Map();
  for (const r of runs) effective.set(r.scenario, r.rerun ? r.weighted_mark : (effective.has(r.scenario) ? effective.get(r.scenario) : r.weighted_mark));
  // rerun handling above keeps the FIRST (original) mark for a scenario with no rerun and the
  // rerun's when there is one — but an original listed AFTER its rerun is rejected by
  // validateInput, so order is safe.
  const marks = [...effective.values()];
  const average_mark = marks.reduce((s, m) => s + m, 0) / marks.length;
  const passed = average_mark >= PASS_AVERAGE && marks.every((m) => m >= PASS_FLOOR);
  return { round: clean.round, date: clean.date, runs, average_mark, passed };
}

// The exact string JSON.stringify would produce for the same number, so prose and sidecar
// never disagree on a Mark's digits.
const mark1 = (m) => String(m);

/** The prose half of the pair: the table of Runs and Marks, each Run's verdict, pass or fail. */
export function renderProse(sidecar) {
  const lines = [];
  lines.push(`# Round ${sidecar.round} — ${sidecar.date} — ${sidecar.passed ? 'PASS' : 'FAIL'}`, '');
  lines.push(
    `Average Mark ${mark1(sidecar.average_mark)}. Pass needs average >= ${PASS_AVERAGE} and no Run below ${PASS_FLOOR}.`,
    '',
  );
  lines.push('| Scenario | Account | Mark | Cap | Improvements |', '|---|---|---|---|---|');
  for (const r of sidecar.runs) {
    lines.push(`| ${r.scenario}${r.rerun ? ' (rerun)' : ''} | ${r.account} | ${mark1(r.weighted_mark)} | ${r.robotic_cap_applied ? 'robotic' : '—'} | ${r.improvements.join(', ') || '—'} |`);
  }
  lines.push('');
  for (const r of sidecar.runs) {
    lines.push(`## ${r.scenario}${r.rerun ? ' (rerun)' : ''} (${r.account})`, '');
    lines.push('| Dimension | Mark | Weight |', '|---|---|---|');
    for (const d of DIMENSIONS) lines.push(`| ${d.slug} | ${r.dimensions[d.slug]} | ${d.weight} |`);
    lines.push('', `Mark ${mark1(r.weighted_mark)}${r.robotic_cap_applied ? ` (robotic cap applied: capped at ${ROBOTIC_CAP}; the verdict says where the robot showed)` : ''}.`, '');
    lines.push(r.verdict, '');
    if (r.improvements.length) lines.push(`Improvements: ${r.improvements.join(', ')}`, '');
  }
  return lines.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd() + '\n';
}
