import { readFileSync, writeFileSync } from 'node:fs';
import { parse, serialize, fold, answers, nextId } from '/Users/leemartin/development/mealvana_endurance/docs/ssot/decisions/_page/sync.mjs';
import { plan, fresh } from './plan.mjs';
const PF = '.scratch/mealplanning/decisions.md', SF = 'docs/ssot/decisions/mealplanning.md';
const proposals = parse(readFileSync(PF, 'utf8')), ssot = parse(readFileSync(SF, 'utf8'));
const today = '2026-09-20';
const out = { folded: [], refused: [], answered: [], fresh: [] };
for (const step of plan) {
  // held cards (status open, not questions) were parked under mp-217; mp-277 answered it, so they fold like proposals
  for (const id of step.from) { const d = proposals.decisions.find(x => x.id === id); if (d && d.meta.status === 'open' && d.meta.kind !== 'question') { d.meta.status = 'proposed'; d.history.push({ date: today, note: 'released from hold for folding (mp-217 answered by mp-277)' }); } }
  const r = fold([step], proposals, ssot, today);
  out.refused.push(...r.refused);
  for (const f of r.folded) {
    out.folded.push(f);
    const card = proposals.decisions.find(d => d.id === f.id);
    if (step.answers?.length) card.history[0].note += `; answers ${step.answers.join(', ')}`;
    for (const q of step.answers || []) { const a = answers(q, f.id, proposals, ssot, today); out.answered.push(...a.applied); out.refused.push(...a.refused); }
  }
}
for (const step of fresh) {
  const into = step.into, id = nextId(proposals, ssot);
  const meta = { category: into.category, status: 'proposed', image: 'none', caption: '', screen: into.screen, source: into.source };
  if (into.work) meta.work = into.work;
  const parts = { question: into.question, context: into.context, decision: into.decision, why: into.why, alternatives: into.alternatives, touches: into.touches };
  if (into.details) parts.details = into.details;
  proposals.decisions.push({ id, title: into.title, meta, parts, history: [{ date: today, note: `proposed in the 09-20 clean-up; answers ${step.answers.join(', ')}` }] });
  out.fresh.push(id);
  for (const q of step.answers) { const a = answers(q, id, proposals, ssot, today); out.answered.push(...a.applied); out.refused.push(...a.refused); }
}
writeFileSync(PF, serialize(proposals));
console.log(JSON.stringify({ folded: out.folded, fresh: out.fresh, answered: out.answered.length, refused: out.refused }, null, 1));
