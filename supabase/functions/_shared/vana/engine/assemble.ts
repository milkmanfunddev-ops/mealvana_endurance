/**
 * Box 2 · Assemble (code): one function, once per turn, before any model runs (proposal v7 §4.2; README block layout).
 *
 * Builds the flow state Route reads (active flow, step, each step's status from its reader, declined this visit,
 * pending, first meeting, opener, safety hit) and the block the step agent sees: TODAY / NEXT 7 DAYS, the Doll
 * (Lee's lines, handed in by the caller on the Snapshot), the active flow's lines, and the FLOW line.
 *
 * The block and the Snapshot it was built from are cached on the row and reused until a write marks them dirty, the
 * day changes, or the flow changes (the one case Assemble runs again mid-turn). Read sees none of this.
 */
import type { Adapters } from './adapters.ts';
import type { Block, ConversationState, FlowDeclaration, Snapshot, StepDeclaration } from './types.ts';
import { addDays, fmtDate } from './dates.ts';

export type StepStatus = 'open' | 'done' | 'declined';
export interface FlowState {
  flow: FlowDeclaration;
  /** The first open step in order, or null when every step is done or declined (the wrap, for orientation). */
  step: StepDeclaration | null;
  statuses: Record<string, StepStatus>;
  /** The rows the statuses were read from (Route needs the earlier visits' declines to make a second one permanent). */
  snapshot: Snapshot;
  declinedThisVisit: string[];
  declinedForGood: string[];
  /** Shown once this visit (closed without a tap): open, but not the step until the athlete asks for it. */
  shownThisVisit: string[];
  done: string[];
  pending: ConversationState['pending'];
  firstMeeting: boolean;
  opener: boolean;
  safetyHit: string | null;
  flowEnded: boolean;
  /** Every non-scripted step is done or declined: the flow has reached its wrap. */
  complete: boolean;
}

export interface Assembled { snapshot: Snapshot; flowState: FlowState; block: string; rebuilt: boolean; trail: string[] }

export const cachedSnapshot = (b: Block | null): Snapshot | null => (b && 'snapshot' in b ? (b as Block & { snapshot: Snapshot }).snapshot : null);

/** The steps the client's 0/N setup widget counts: the real steps minus those declared `widget: false` (the week planner, E1). */
export const widgetSteps = (flow: FlowDeclaration): string[] => flow.order.filter((id) => flow.steps[id].reply !== 'scripted' && flow.steps[id].widget !== false);

export function statusOf(_flow: FlowDeclaration, step: StepDeclaration, d: Snapshot, s: ConversationState): StepStatus {
  // this visit's no, or a second no across visits (never offered again), or one recorded for good in an earlier visit
  if (s.declinedThisVisit.includes(step.id) || s.declinedForGood.includes(step.id) || d.steps[step.id] === 'declined_for_good') return 'declined';
  if (step.id === 'wrap') return s.celebrated.includes('setup_done') ? 'done' : 'open';
  return step.status(d) === 'done' ? 'done' : 'open';
}

export function flowStateFor(flow: FlowDeclaration, d: Snapshot, s: ConversationState): FlowState {
  const statuses: Record<string, StepStatus> = {};
  for (const id of flow.order) statuses[id] = statusOf(flow, flow.steps[id], d, s);
  const real = flow.order.filter((id) => flow.steps[id].reply !== 'scripted');
  const complete = real.every((id) => statuses[id] !== 'open');
  // a card shown once this visit is not re-offered: its step stays open but is passed over (E3)
  const nextId = flow.order.find((id) => statuses[id] === 'open' && !s.shownThisVisit.includes(id) && (flow.steps[id].reply !== 'scripted' || complete));
  const spoken = s.history.some((l) => l.role === 'vana');
  return {
    flow, step: nextId ? flow.steps[nextId] : null, statuses, snapshot: d, declinedThisVisit: [...s.declinedThisVisit], declinedForGood: [...s.declinedForGood],
    shownThisVisit: [...s.shownThisVisit], done: flow.order.filter((id) => statuses[id] === 'done'), pending: [...s.pending],
    firstMeeting: !d.profile.metVana && !spoken, opener: !spoken, safetyHit: s.safetyHit, flowEnded: s.flowEnded, complete,
  };
}

/** The FLOW line, rebuilt every turn (it is the one tier that changes with the conversation). */
export function flowLine(fs: FlowState, d: Snapshot): string {
  const forGood = [...new Set([...Object.entries(d.steps).filter(([, v]) => v === 'declined_for_good').map(([k]) => k), ...fs.declinedForGood])];
  const declinedBefore = Object.entries(d.steps).filter(([k, v]) => v === 'declined' && !forGood.includes(k)).map(([k]) => k);
  return `- FLOW: ${fs.flow.id} · step: ${fs.step?.id ?? 'none'} · done: ${fs.done.join(', ') || 'none'} · declined this visit: ${fs.declinedThisVisit.join(', ') || 'none'}${declinedBefore.length ? ` · declined before: ${declinedBefore.join(', ')}` : ''}${forGood.length ? ` · declined for good: ${forGood.join(', ')}` : ''}${fs.shownThisVisit.length ? ` · shown once: ${fs.shownThisVisit.join(', ')}` : ''} · pending: ${fs.pending.map((i) => i.label + (i.target ? `(${i.target})` : '')).join(', ') || 'none'} · first meeting: ${fs.firstMeeting ? 'yes' : 'no'} · opener: ${fs.opener ? 'yes' : 'no'} · safety hit: ${fs.safetyHit ?? 'none'}${fs.flowEnded ? ' (flow ended)' : ''}`;
}

/** The cached tier: TODAY, NEXT 7 DAYS, the Doll, the flow's lines. Byte-identical until something real changes. */
export function blockText(flow: FlowDeclaration, d: Snapshot): string {
  return [
    'ATHLETE FILE',
    `- TODAY: ${fmtDate(d.today)} ${d.today.slice(0, 4)}`,
    `- NEXT 7 DAYS: ${Array.from({ length: 7 }, (_, i) => { const x = addDays(d.today, i + 1); return `${fmtDate(x)} = ${x}`; }).join(' · ')}`,
    ...d.doll,
    ...flow.lines(d),
  ].join('\n');
}

export async function assemble(s: ConversationState, flow: FlowDeclaration, a: Pick<Adapters, 'data' | 'clock'>): Promise<Assembled> {
  const today = a.clock.today();
  const trail: string[] = [];
  const cached = cachedSnapshot(s.block);
  const stale = !s.block || !cached || s.blockDirty || s.block.day !== today || s.block.flow !== flow.id;
  let snapshot = cached!;
  if (stale) {
    snapshot = await a.data.read(s.userId);
    const why = !s.block ? 'no block on the row' : s.blockDirty ? 'a write marked it dirty' : s.block!.day !== today ? 'a new day' : s.block!.flow !== flow.id ? `flow changed to ${flow.id}` : 'no cached snapshot';
    trail.push(`assemble: rebuilt the block (${why})`);
    s.block = { text: blockText(flow, snapshot), day: today, flow: flow.id, snapshot } as Block;
    s.blockDirty = false;
  }
  const fs = flowStateFor(flow, snapshot, s);
  return { snapshot, flowState: fs, block: `${s.block!.text}\n${flowLine(fs, snapshot)}`, rebuilt: stale, trail };
}
