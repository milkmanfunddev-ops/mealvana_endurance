/**
 * Box 4 · Route (code): intents + flow state → a plan of at most two steps (proposal v7 §4.4; README delta 3; the
 * rulings of 2026-10-15 in ops/experiments/setup-chat/v7/ENGINE-RUNG1-decisions.md).
 *
 *   safety        → the shared sensitive step. Eating-disorder signs or distress end the flow for this conversation
 *                   (hard rule 5); a medical, injury or symptom hit hands the next turn back to the flow (Q6).
 *   feedback      → the scripted acknowledgement (+ steer unless offers ended); feedback(flow) ends the offers;
 *                   a vent that ends in a question is a question: the active step answers it after the ack.
 *   declines      → the step is skipped in code; the next step's agent runs with [declined: …]. A step declined in an
 *                   earlier visit too is declined for good (Q7a). declines(all_connections) closes plan and wearable
 *                   and ends the offers for the visit; declines(visit) ends them and the Answer agent closes.
 *   asks(other), leaves_flow → the scripted off_flow line (+ steer); demand logged with the athlete's words. The second
 *                   off-flow ask of a visit gets the scripted check-in instead of the steer, once (Q1a).
 *                   leaves_flow starts the target flow instead when the active flow allows_jump.
 *   asks(app)     → the Answer shape.   asks(step), answers, chat → the active step's agent.
 *   leftovers     → pending on the row, where they stay across typed turns, named once per reply via [then: …], until
 *                   a tap resumes them or a spoken decline drops them (Q3c).
 *   Priority: safety > feedback > writes > reads. Same shape = one step. The situation fills `starts:` only when no
 *   flow is active; Read's label always wins over it.
 */
import { flowStateFor, type FlowState } from './assemble.ts';
import { FLOW_ENDING_SAFETY } from './read.ts';
import type { ConversationState, FlowDeclaration, FlowId, Intent, Plan, PlanStep, Situation, Snapshot, StepDeclaration } from './types.ts';
import { SHARED } from './flows/shared.ts';
import { NONE_TARGETS } from './flows/none.ts';

export const MAX_STEPS_PER_TURN = 2;
/** Off-flow asks in a visit before the scripted check-in replaces the steer (Q1a: the count fires the question, never the stop). */
export const CHECK_IN_AFTER = 2;
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

/**
 * Apply a decline in code: this visit's list, "for good" when an earlier visit declined it too (`prior` is the memory
 * store's keyed settings as the Snapshot carries them), and any step it drags along.
 */
export function applyDecline(s: ConversationState, flow: FlowDeclaration, stepId: string, prior: Snapshot['steps'] = {}): string[] {
  const out: string[] = [];
  const mark = (id: string) => {
    if (!flow.steps[id] || s.declinedThisVisit.includes(id)) return;
    s.declinedThisVisit.push(id); out.push(id);
    if ((prior[id] === 'declined' || prior[id] === 'declined_for_good') && !s.declinedForGood.includes(id)) s.declinedForGood.push(id);
  };
  mark(stepId);
  for (const also of flow.steps[stepId]?.onDecline?.alsoDecline ?? []) mark(also);
  return out;
}

/** Does this message engage the card on screen (answers it, asks about it, declines it)? Anything else scrolls it off (E3). */
export const engagesCard = (intents: Intent[]): boolean => intents.some((i) => i.label === 'answers' || i.label === 'declines' || (i.label === 'asks' && i.target === 'step'));

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
  const sensitiveOnly = (its: Intent[]): Plan => ({ steps: [stepFor(SHARED.sensitive, its)], pending: [], why, flowChanged: false });

  // 1 · safety first. ED signs / distress end the flow for the conversation; a medical hit is one turn with the
  //     sensitive agent, then the athlete's next message decides (the sensitive prompt tells the agent not to push).
  const safety = intents.find((i) => i.label === 'safety');
  if (safety) {
    s.safetyHit = safety.target ?? 'unspecified';
    if (FLOW_ENDING_SAFETY.has(s.safetyHit)) { s.flowEnded = true; why.push(`safety(${s.safetyHit}): sensitive step, the flow ends for this conversation`); }
    else why.push(`safety(${s.safetyHit}): sensitive step; the flow carries on next turn if the athlete wants`);
    return sensitiveOnly([safety]);
  }
  if (s.flowEnded) { why.push(`flow ended (${s.safetyHit}): only the sensitive agent speaks`); return sensitiveOnly(intents); }
  if (s.safetyHit) { why.push(`safety(${s.safetyHit}) last turn: the athlete's message decides, the hit is cleared`); s.safetyHit = null; }

  // 2 · declines are recorded before anything else is planned: the next step is picked from the new state.
  //     A spoken decline is also the one thing that drops intents pending from an earlier card (Q3c).
  const declines = intents.filter((i) => i.label === 'declines');
  if (declines.length && s.pending.length) { why.push(`declines: ${s.pending.length} pending intent(s) dropped`); s.pending = []; s.pendingWords = null; }
  const declinedNow: string[] = [];
  let visitDeclined = false;
  for (const d of declines) {
    if (d.target === 'all_connections') { declinedNow.push(...applyDecline(s, flow, 'plan', fs.snapshot.steps), ...applyDecline(s, flow, 'wearable', fs.snapshot.steps)); s.offersEnded = true; why.push('declines(all_connections): plan + wearable closed, offers end this visit'); }
    else if (d.target === 'visit') { visitDeclined = true; s.offersEnded = true; why.push('declines(visit): offers end for the visit'); }
    else if (fs.step && fs.step.reply !== 'scripted') { declinedNow.push(...applyDecline(s, flow, fs.step.id, fs.snapshot.steps)); why.push(`declines(${fs.step.id}): skipped in code${s.declinedForGood.includes(fs.step.id) ? ', for good (declined in an earlier visit too)' : ''}`); }
  }
  // the step after the decline, from the new state (declined for good and shown-once steps are passed over)
  const active = declinedNow.length ? flowStateFor(flow, fs.snapshot, s).step : fs.step;
  const declinedNames = [...declinedNow, ...(visitDeclined ? ['visit'] : [])];
  const declineNote = declinedNames.length ? [`[declined: ${declinedNames.join(', ')}]`] : [];

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
    // the check-in line already carries the coming-soon sentence: it replaces any off_flow line in the same reply
    if (c.step.id === 'off_flow' && candidates.some((x) => x.step.id === 'check_in')) { candidates.find((x) => x.step.id === 'check_in')!.intents.push(it); continue; }
    if (c.step.id === 'check_in') { const i = candidates.findIndex((x) => x.step.id === 'off_flow'); if (i >= 0) { c.intents.unshift(...candidates[i].intents); candidates.splice(i, 1); } }
    const same = candidates.find((x) => x.step.id === c.step.id);
    if (same) { same.intents.push(...c.intents); why.push(`${it.label}(${it.target ?? ''}): same shape, merged into ${c.step.id}`); }
    else candidates.push(c);
  }
  if (!candidates.length) {
    if (visitDeclined) { why.push('declines(visit) alone: the Answer agent closes with [declined: visit]'); candidates.push(stepFor(flow.answerStep, [])); }
    else if (active) candidates.push(stepFor(active, [], [], false));   // a bare decline: the next step speaks
  }
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
  /** The off-flow line; on the visit's second off-flow ask the scripted check-in instead, once, unless offers already ended. */
  function offFlowStep(it: Intent): PlanStep {
    s.offFlowAsks++;
    if (s.offFlowAsks >= CHECK_IN_AFTER && !s.checkInAsked && !s.offersEnded) { s.checkInAsked = true; why.push(`off-flow ask ${s.offFlowAsks} this visit: the scripted check-in replaces the steer, once`); return stepFor(SHARED.check_in, [it]); }
    return stepFor(SHARED.off_flow, [it]);
  }
  function finish(): Plan {
    // the steer rides on scripted steps as a note; the check-in carries its own one question, no steer
    for (const st of steps) if (st.step.reply === 'scripted') st.notes.push(`[steer: ${st.step.id === 'check_in' ? '' : steerFor() ?? ''}]`);
    // [then: …]: a step whose shape ends in a card is told what waits after it (the later steps' intents, this turn's
    // leftovers and anything still pending from an earlier card), so its words can say "then your weight"; the last
    // step is told only what waits
    const carried = s.pending;
    const thenOf = (its: Intent[]) => `[then: ${its.map((p) => p.label + (p.target ? ` ${p.target}` : '')).join(', ')}]`;
    steps.forEach((st, i) => {
      const later = [...steps.slice(i + 1).flatMap((x) => x.intents), ...pending, ...carried];
      if (later.length && (i < steps.length - 1 ? CARD_SHAPES.has(st.step.shape) : true)) st.notes.push(thenOf(later));
    });
    s.pending = [...carried, ...pending];
    s.pendingWords = carried.length ? s.pendingWords : pending.length ? message : null;
    if (pending.length) why.push(`${pending.length} intent(s) pending on the row`);
    if (carried.length) why.push(`${carried.length} earlier intent(s) still pending, named in this reply`);
    return { steps, pending, why, flowChanged };
  }
}
