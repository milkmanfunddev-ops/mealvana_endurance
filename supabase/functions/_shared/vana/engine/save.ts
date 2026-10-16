/**
 * Box 7 · Save → receipt (code): every write comes back with proof (proposal v7 §4.7; README deltas 6 and 7).
 *
 * Tool results become a draft card (the athlete confirms inside it) or a receipt (server-authored from scripted.md).
 * Taps arrive with what the app saved; this module writes the receipt line, fires each milestone's confetti once,
 * records a decline (for good when an earlier visit declined it too), marks a dismissed card shown once, marks the block
 * dirty so Assemble rebuilds it, and tells the engine whether the tap completed a
 * step (→ the next step's agent runs with [receipt: …]) or cleared a card with intents pending (→ Route resumes).
 */
import type { MemoryStore } from './adapters.ts';
import type { FlowState } from './assemble.ts';
import { flowStateFor } from './assemble.ts';
import type { Card, ConversationState, FlowDeclaration, Milestone, Receipt, Snapshot, Tap, ToolOutcome } from './types.ts';
import type { ScriptedLines } from './scripted.ts';
import { receiptLine } from './scripted.ts';
import { applyDecline } from './route.ts';

export interface SaveOutcome { receipts: Receipt[]; confetti: Milestone[]; card: Card | null; declined: string[]; completedStep: string | null; trail: string[] }

/** A tool result inside a step, as the loop sees it: a card goes on screen, a receipt rides forward. */
export function fromTool(outcome: ToolOutcome, stepId: string, s: ConversationState): { card?: Card; receipt?: Receipt } {
  if (outcome.type === 'card') { s.cardOnScreen = { step: stepId, card: outcome.card.kind, id: outcome.card.id }; return { card: outcome.card }; }
  if (outcome.type === 'receipt') { s.blockDirty = true; return { receipt: { ...outcome.receipt, step: outcome.receipt.step ?? stepId } }; }
  return {};
}

/** Milestones whose step just flipped to done and were never celebrated, plus setup_done when the flow completes. */
export function milestonesFor(flow: FlowDeclaration, before: FlowState, after: FlowState, s: ConversationState): Milestone[] {
  const out: Milestone[] = [];
  for (const id of flow.order) {
    const m = flow.steps[id].milestone;
    if (m && m !== 'setup_done' && before.statuses[id] !== 'done' && after.statuses[id] === 'done' && !s.celebrated.includes(m)) out.push(m);
  }
  return out;
}

export function celebrate(s: ConversationState, ms: Milestone[]): Milestone[] {
  const fired = ms.filter((m) => !s.celebrated.includes(m));
  s.celebrated.push(...fired);
  return fired;
}

/**
 * Apply a tap. `before` is the flow state the card was shown from; `readAfter` re-reads the athlete's rows (the app
 * already wrote them) so the readers see the new status.
 */
export async function saveTap(tap: Tap, flow: FlowDeclaration, before: FlowState, s: ConversationState, readAfter: () => Promise<Snapshot>, lines: ScriptedLines, memory: MemoryStore): Promise<SaveOutcome> {
  const trail: string[] = [];
  const out: SaveOutcome = { receipts: [], confetti: [], card: null, declined: [], completedStep: null, trail };
  const step = flow.steps[tap.step];
  s.cardOnScreen = null;
  if (!step) { trail.push(`save: tap on unknown step ${tap.step}; nothing recorded`); return out; }

  if (tap.action === 'decline') {
    out.declined = applyDecline(s, flow, step.id, before.snapshot.steps);
    for (const id of out.declined) await memory.setStep(s.userId, id, s.declinedForGood.includes(id) ? 'declined_for_good' : 'declined');
    const forGood = out.declined.filter((id) => s.declinedForGood.includes(id));
    trail.push(`save: ${step.id} declined by tap${out.declined.length > 1 ? ` (also ${out.declined.slice(1).join(', ')})` : ''}${forGood.length ? `; for good, declined in an earlier visit too: ${forGood.join(', ')}` : ''}`);
    return out;
  }
  if (tap.action === 'dismiss') {
    // E3: shown once this visit; the step stays open and undeclined, Route passes it over until the athlete asks for it
    if (!s.shownThisVisit.includes(step.id)) s.shownThisVisit.push(step.id);
    trail.push(`save: ${step.id} card closed without a tap; shown once this visit, the step stays open, not a decline`);
    return out;
  }

  // save / connect / pin / choice: the app wrote; re-read and author the receipt
  s.blockDirty = true;
  const after = flowStateFor(flow, await readAfter(), s);
  const what = tap.saved?.what ?? tap.choice ?? step.id;
  out.receipts.push({ what, line: receiptLine(lines, what, tap.saved?.when ?? null, step.id === 'race'), step: step.id });
  const newly = milestonesFor(flow, before, after, s);
  out.confetti = celebrate(s, newly);
  if (after.statuses[step.id] === 'done') { out.completedStep = step.id; await memory.setStep(s.userId, step.id, 'done'); }
  trail.push(`save: ${step.id} ${tap.action} → receipt "${out.receipts[0].line}"${out.confetti.length ? `, confetti ${out.confetti.join('+')}` : ''}${out.completedStep ? ', step done' : ', step still open'}`);
  return out;
}
