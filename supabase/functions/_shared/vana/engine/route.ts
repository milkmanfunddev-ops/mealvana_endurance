/**
 * Box 4 · Route (code): intents + flow state → a plan of at most two steps (proposal v7 §4.4; README delta 3).
 *
 *   safety        → the shared sensitive step; the flow ends for this conversation.
 *   feedback      → the scripted acknowledgement (+ steer unless offers ended); feedback(flow) ends the offers;
 *                   a vent that ends in a question is a question: the active step answers it after the ack.
 *   declines      → the step is skipped in code; the next step's agent runs with [declined: …].
 *                   declines(all_connections) closes plan and wearable and ends the offers for the visit.
 *   asks(other), leaves_flow → the scripted off_flow line (+ steer); demand logged with the athlete's words.
 *                   leaves_flow starts the target flow instead when the active flow allows_jump.
 *   asks(app)     → the Answer shape.   asks(step), answers, chat → the active step's agent.
 *   leftovers     → pending on the row.  Priority: safety > feedback > writes > reads. Same shape = one step.
 *   situation     → fills `starts:` only when no flow is active. Read's label always wins over it.
 */
import type { FlowState } from './assemble.ts';
import type { ConversationState, FlowDeclaration, FlowId, Intent, Plan, PlanStep, Situation, StepDeclaration } from './types.ts';
import { SHARED } from './flows/shared.ts';
import { NONE_TARGETS } from './flows/none.ts';

export const MAX_STEPS_PER_TURN = 2;
const WRITE_SHAPES = new Set(['set_value', 'draft_record', 'choose', 'hand_off']);
/** Shapes whose reply ends in a card, which ends the turn: whatever is planned after them waits. */
const CARD_SHAPES = new Set(['draft_record', 'choose', 'hand_off']);

export type Flows = Partial<Record<FlowId, FlowDeclaration>>;

/** Which flow this turn runs: the active one, else the situation's `starts:`, else none. */
export function pickFlow(s: ConversationState, situation: Situation | null | undefined, flows: Flows, d: Parameters<FlowDeclaration['starts']>[1]): { flow: FlowDeclaration; why: string } {
  if (s.flow && flows[s.flow]) return { flow: flows[s.flow]!, why: `active flow ${s.flow}` };
  for (const id of ['orientation', 'meal_planning', 'debrief'] as FlowId[]) {
    const f = flows[id];
    if (f && f.starts(situation ?? null, d)) return { flow: f, why: `situation starts ${id}` };
  }
  return { flow: flows.none!, why: 'no flow active: the lobby' };
}

/** Apply a decline in code: this visit's list, the memory store's keyed setting, and any step it drags along. */
export function applyDecline(s: ConversationState, flow: FlowDeclaration, stepId: string): string[] {
  const out: string[] = [];
  const mark = (id: string) => { if (!s.declinedThisVisit.includes(id) && flow.steps[id]) { s.declinedThisVisit.push(id); out.push(id); } };
  mark(stepId);
  for (const also of flow.steps[stepId]?.onDecline?.alsoDecline ?? []) mark(also);
  return out;
}

const endsInQuestion = (m: string) => /\?\s*$/.test(m.trim());

export function route(intents: Intent[], fs: FlowState, s: ConversationState, message: string, flows: Flows): Plan {
  const flow = fs.flow;
  const why: string[] = [];
  const steps: PlanStep[] = [];
  const pending: Intent[] = [];
  let flowChanged = false;
  const stepFor = (step: StepDeclaration, its: Intent[], notes: string[] = [], writeAllowed = false): PlanStep => ({ flow: flow.id, step, intents: its, notes, writeAllowed });
  const steerFor = (): string | null => (s.offersEnded || !fs.step || fs.step.reply === 'scripted' ? null : fs.step.steer || null);
  const push = (p: PlanStep) => { if (steps.length < MAX_STEPS_PER_TURN) steps.push(p); else pending.push(...p.intents); };

  // 1 · safety first; the flow ends for the conversation.
  const safety = intents.find((i) => i.label === 'safety');
  if (safety) {
    s.safetyHit = safety.target ?? 'unspecified';
    why.push(`safety(${s.safetyHit}): sensitive step, the flow ends for this conversation`);
    return { steps: [stepFor(SHARED.sensitive, [safety])], pending: [], why, flowChanged: false };
  }
  if (s.safetyHit) {
    // nothing after a safety hit (hard rule 5): no flow step, no card; a direct question still gets the sensitive agent
    why.push('safety hit earlier: only the sensitive agent speaks');
    return { steps: [stepFor(SHARED.sensitive, intents)], pending: [], why, flowChanged: false };
  }

  // 2 · declines are recorded before anything else is planned: the next step is picked from the new state.
  const declines = intents.filter((i) => i.label === 'declines');
  const declinedNow: string[] = [];
  for (const d of declines) {
    if (d.target === 'all_connections') { declinedNow.push(...applyDecline(s, flow, 'plan'), ...applyDecline(s, flow, 'wearable')); s.offersEnded = true; why.push('declines(all_connections): plan + wearable closed, offers end this visit'); }
    else if (fs.step && fs.step.reply !== 'scripted') { declinedNow.push(...applyDecline(s, flow, fs.step.id)); why.push(`declines(${fs.step.id}): skipped in code`); }
  }
  // the step after the decline, from the declaration order
  const nextOpen = (): StepDeclaration | null => {
    const order = flow.order.filter((id) => !s.declinedThisVisit.includes(id));
    const real = order.filter((id) => flow.steps[id].reply !== 'scripted' && fs.statuses[id] !== 'done');
    const id = real[0] ?? order.find((x) => flow.steps[x].reply === 'scripted' && fs.statuses[x] !== 'done');
    return id ? flow.steps[id] : null;
  };
  const active = declinedNow.length ? nextOpen() : fs.step;
  const declineNote = declinedNow.length ? [`[declined: ${declinedNow.join(', ')}]`] : [];

  // 3 · feedback: scripted ack, then the active step only if the message ends in a question.
  const feedback = intents.find((i) => i.label === 'feedback');
  if (feedback) {
    if (feedback.target === 'flow') { s.offersEnded = true; why.push('feedback(flow): offers end this visit'); }
    push(stepFor(SHARED.feedback, [feedback]));
    why.push(`feedback(${feedback.target ?? '?'}): scripted acknowledgement`);
    if (endsInQuestion(message) && active && active.reply !== 'scripted') { push(stepFor(active, intents.filter((i) => i.label !== 'feedback'), declineNote)); why.push('vent ends in a question: the active step answers it'); }
    else pending.push(...intents.filter((i) => i.label !== 'feedback' && i.label !== 'declines'));
    return finish();
  }

  // 4 · the rest, in the athlete's order, with writes ahead of reads and same-shape merged.
  const rest = intents.filter((i) => i.label !== 'declines');
  const candidates: PlanStep[] = [];
  for (const it of rest) {
    const c = candidateFor(it);
    if (!c) continue;
    const same = candidates.find((x) => x.step.id === c.step.id);
    if (same) { same.intents.push(...c.intents); why.push(`${it.label}(${it.target ?? ''}): same shape, merged into ${c.step.id}`); }
    else candidates.push(c);
  }
  if (!candidates.length && active) candidates.push(stepFor(active, [], [], false));   // a bare decline: the next step speaks
  // writes before reads (a write rebuilds the block the read reads)
  candidates.sort((a, b) => Number(WRITE_SHAPES.has(b.step.shape)) - Number(WRITE_SHAPES.has(a.step.shape)));
  for (const c of candidates) push(c);
  if (steps[0]) steps[0].notes.unshift(...declineNote);
  return finish();

  function candidateFor(it: Intent): PlanStep | null {
    const target = it.target ?? '';
    switch (it.label) {
      case 'asks':
        if (target === 'other') { s.demand.push({ turn: s.turn, words: message, target }); why.push('asks(other): scripted off_flow, demand logged'); return offFlowStep(it); }
        if (target === 'app') { why.push('asks(app): Answer shape'); return stepFor(flow.answerStep, [it]); }
        if (flow.id === 'none') { const id = NONE_TARGETS[target]; if (id && flow.steps[id]) { why.push(`asks(${target}) in the lobby: ${id}`); return stepFor(flow.steps[id], [it], [], true); } why.push(`asks(${target}) in the lobby: Answer`); return stepFor(flow.answerStep, [it]); }
        return activeStep(it);
      case 'leaves_flow': {
        const target_ = flows[target as FlowId];
        if (target_ && (flow.allowsJump || flow.id === 'none')) { flowChanged = true; s.flow = target_.id; why.push(`leaves_flow(${target}): the flow allows the jump`); return { flow: target_.id, step: target_.steps[target_.order[0]] ?? target_.answerStep, intents: [it], notes: [], writeAllowed: false }; }
        s.demand.push({ turn: s.turn, words: message, target: `leaves_flow:${target}` }); why.push(`leaves_flow(${target}): allows_jump is no, scripted off_flow`); return offFlowStep(it);
      }
      case 'answers': return activeStep(it, true);
      case 'chat': return activeStep(it);
      default: return null;
    }
  }
  function activeStep(it: Intent, writeAllowed = false): PlanStep | null {
    if (!active) { why.push(`${it.label}: nothing open, Answer`); return stepFor(flow.answerStep, [it]); }
    if (active.reply === 'scripted') { why.push(`${it.label}: the ${active.id} line`); return stepFor(active, [it]); }
    why.push(`${it.label}(${it.target ?? ''}): the active step ${active.id}`);
    return stepFor(active, [it], [], writeAllowed || it.label === 'answers');
  }
  function offFlowStep(it: Intent): PlanStep { return stepFor(SHARED.off_flow, [it]); }
  function finish(): Plan {
    // the steer rides on scripted steps as a note
    for (const st of steps) if (st.step.reply === 'scripted') st.notes.push(`[steer: ${steerFor() ?? ''}]`);
    // [then: …]: a step whose shape ends in a card is told what waits after it (the later steps' intents and the
    // pending ones), so its words can say "then your weight"; the last step is told only what is pending
    const thenOf = (its: Intent[]) => `[then: ${its.map((p) => p.label + (p.target ? ` ${p.target}` : '')).join(', ')}]`;
    steps.forEach((st, i) => {
      const later = [...steps.slice(i + 1).flatMap((x) => x.intents), ...pending];
      if (later.length && (i < steps.length - 1 ? CARD_SHAPES.has(st.step.shape) : true)) st.notes.push(thenOf(later));
    });
    s.pending = pending;
    s.pendingWords = pending.length ? message : null;
    if (pending.length) why.push(`${pending.length} intent(s) pending on the row`);
    return { steps, pending, why, flowChanged };
  }
}
