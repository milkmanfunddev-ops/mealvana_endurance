/**
 * Vana engine — runTurn (proposal v7 §3 "one turn, drawn"; ratified 2026-10-15).
 *
 *   Gate → Assemble → Read → Route → Step loop (Check after each step) → Save → Memory
 *
 * Pure: everything outside comes through `Adapters`. One call per turn; the conversation row goes in through
 * RowStore and comes back on TurnResult.state. A tap costs no model call; a typed message costs Read + one step
 * agent (+1 on a Check retry, +1 per extra plan step). The flows are data (flows/*.ts); add one, change nothing here.
 */
import type { Adapters } from './adapters.ts';
import { assemble, cachedSnapshot, flowStateFor, type Assembled } from './assemble.ts';
import { newCounters } from './counters.ts';
import { gate } from './gate.ts';
import { runPlan, type PlanRun } from './loop.ts';
import { read } from './read.ts';
import { pickFlow, route, type Flows } from './route.ts';
import { saveTap } from './save.ts';
import { loadScripted } from './scripted.ts';
import type { ConversationState, FlowDeclaration, Intent, Plan, ReadResult, Snapshot, TurnInput, TurnResult } from './types.ts';
import { ORIENTATION } from './flows/orientation.ts';
import { NONE } from './flows/none.ts';

/** The message the app sends when the sheet opens with nobody having spoken: no Read, the first step with [opener]. */
export const OPENER = '[opened]';

export const DEFAULT_FLOWS: Flows = { orientation: ORIENTATION, none: NONE };

export function freshState(conversationId: string, userId: string): ConversationState {
  return { conversationId, userId, flow: null, step: null, declinedThisVisit: [], offersEnded: false, pending: [], pendingWords: null, safetyHit: null, history: [], block: null, blockDirty: false, celebrated: [], cardOnScreen: null, turn: 0, demand: [] };
}

export interface RunOptions { foreignNames?: string[] }

export async function runTurn(input: TurnInput, a: Adapters, flows: Flows = DEFAULT_FLOWS, opts: RunOptions = {}): Promise<TurnResult> {
  const counters = newCounters();
  const trail: string[] = [];
  const calls: TurnResult['calls'] = [];
  const s = (await a.rows.load(input.conversationId)) ?? freshState(input.conversationId, input.userId);
  s.turn++;
  const empty = (): TurnResult => ({ reply: { receipts: [], card: null, text: '', reactions: [], confetti: [] }, read: null, plan: null, counters, calls, state: s, trail });

  // 1 · Gate
  const g = await gate(input, a);
  if (!g.ok) { trail.push(`gate: refused (${g.reason})`); await a.rows.save(s); return empty(); }

  // which flow: the active one, else the situation's starts:, else the lobby
  const d0: Snapshot = cachedSnapshot(s.block) ?? await a.data.read(s.userId);
  const picked = pickFlow(s, input.situation, flows, d0);
  let flow: FlowDeclaration = picked.flow;
  if (s.flow !== flow.id) { trail.push(`route: ${picked.why}`); s.flow = flow.id; }

  // 2 · Assemble
  let assembled: Assembled = await assemble(s, flow, a);
  trail.push(...assembled.trail);
  const lines = await loadScripted(a.prompts);
  const reassemble = async () => { const r = await assemble(s, flow, a); return r; };
  const loopCtx = () => ({ a, s, flow, assembled, reassemble, lines, counters, message: '', foreignNames: opts.foreignNames, trail, calls });

  let readResult: ReadResult | null = null;
  let plan: Plan | null = null;
  let run: PlanRun | null = null;
  let athleteLine: string | null = null;

  if (g.kind === 'tap') {
    // 7 · Save first; a tap never sees a model
    const tap = input.tap!;
    const before = assembled.flowState;
    const saved = await saveTap(tap, flow, before, s, () => a.data.read(s.userId), lines, a.memory);
    trail.push(...saved.trail);
    athleteLine = `[tap: ${tap.action}${tap.saved ? ` — ${tap.saved.what}` : tap.choice ? ` — ${tap.choice}` : ''}]`;
    assembled = await assemble(s, flow, a); trail.push(...assembled.trail);
    const receiptLines = saved.receipts.map((r) => r.line);
    if (s.pending.length) {
      // a tap that clears a card with intents pending resumes the plan (no Read)
      const pend: Intent[] = s.pending; const words = s.pendingWords ?? ''; s.pending = []; s.pendingWords = null;
      plan = route(pend, assembled.flowState, s, words, flows);
      trail.push(`route: resumed ${pend.length} pending intent(s) after the tap`);
      if (saved.receipts.length && plan.steps[0]) plan.steps[0].notes.unshift(...saved.receipts.map((r) => `[receipt: ${r.line}]`));
      run = await runPlan(plan, { ...loopCtx(), assembled, message: words });
    } else if (saved.completedStep || saved.declined.length || tap.action === 'choice') {
      // a Save that completes a step (or a decline) continues to the next step's agent
      const next = assembled.flowState.step;
      if (next) {
        const notes = [...saved.receipts.map((r) => `[receipt: ${r.line}]`), ...(saved.declined.length ? [`[declined: ${saved.declined.join(', ')}]`] : [])];
        plan = { steps: [{ flow: flow.id, step: next, intents: [], notes, writeAllowed: false }], pending: [], why: [`tap on ${tap.step}: next step ${next.id}`], flowChanged: false };
        if (next.reply === 'scripted') plan.steps[0].notes.push('[steer: ]');
        run = await runPlan(plan, { ...loopCtx(), assembled, message: tap.choice ?? '' });
      } else trail.push('loop: nothing left after the tap; the receipt goes out alone');
    } else trail.push(`loop: tap on ${tap.step} (${tap.action}) changed no step; receipt only`);
    const reply = { receipts: receiptLines, card: run?.card ?? null, text: run?.text ?? '', reactions: run?.reactions ?? [], confetti: [...saved.confetti, ...(run?.confetti ?? [])] };
    return finish(reply);
  }

  // typed message
  const message = input.message!.trim();
  athleteLine = message;
  if (message.startsWith('[')) {
    // the opener or an app event: no Read; the active step with [opener]
    const next = assembled.flowState.step;
    if (!next) { trail.push('route: opened with nothing left to do'); return finish({ receipts: [], card: null, text: '', reactions: [], confetti: [] }); }
    plan = { steps: [{ flow: flow.id, step: next, intents: [], notes: assembled.flowState.opener ? ['[opener]'] : [], writeAllowed: false }], pending: [], why: [`${message}: no Read, the active step ${next.id}`], flowChanged: false };
    if (next.reply === 'scripted') plan.steps[0].notes.push('[steer: ]');
    run = await runPlan(plan, { ...loopCtx(), message: '' });
    return finish({ receipts: run.receipts, card: run.card, text: run.text, reactions: run.reactions, confetti: run.confetti });
  }

  // 3 · Read
  const r = await read(message, s.history, assembled.flowState.step?.id ?? null, a.prompts, a.model);
  readResult = r.result;
  counters.model_calls++; counters.read_label.push(...readResult.intents.map((i) => i.label + (i.target ? `(${i.target})` : '')));
  calls.push({ role: 'read', inputTokens: r.usage.inputTokens, outputTokens: r.usage.outputTokens, cachedTokens: r.usage.cachedTokens });
  for (const f of readResult.facts) { try { await a.memory.remember(s.userId, f, { source: 'read' }); } catch (e) { trail.push(`memory: could not remember "${f}" (${(e as Error).message})`); } }

  // 4 · Route, with any intents left pending from last turn ahead of this message's
  const carried = s.pending; s.pending = [];
  const intents = [...carried, ...readResult.intents];
  if (carried.length) { trail.push(`route: ${carried.length} pending intent(s) from last turn join this one`); counters.route_reroute++; }
  const flowBefore = s.flow;
  plan = route(intents, assembled.flowState, s, message, flows);
  if (plan.flowChanged && s.flow && s.flow !== flowBefore && flows[s.flow]) { flow = flows[s.flow]!; assembled = await assemble(s, flow, a); trail.push(`assemble: flow changed to ${flow.id}`, ...assembled.trail); }
  for (const id of s.declinedThisVisit) { try { await a.memory.setStep(s.userId, id, 'declined'); } catch (e) { trail.push(`memory: setStep(${id}) failed (${(e as Error).message})`); } }
  counters.intents_pending += plan.pending.length;

  // 5 · the loop
  run = await runPlan(plan, { ...loopCtx(), assembled, message });
  return finish({ receipts: run.receipts, card: run.card, text: run.text, reactions: run.reactions, confetti: run.confetti });

  async function finish(reply: TurnResult['reply']): Promise<TurnResult> {
    if (athleteLine) s.history.push({ role: 'athlete', text: athleteLine });
    const shown = [reply.receipts.join(' '), reply.text].filter(Boolean).join('\n');
    if (shown || reply.card) s.history.push({ role: 'vana', text: shown, cards: reply.card ? [reply.card.kind] : [] });
    s.step = flowStateFor(flow, assembled.snapshot, s).step?.id ?? null;
    if (plan?.why.length) trail.push(`route: ${plan.why.join('; ')}`);
    await a.rows.save(s);
    return { reply, read: readResult, plan, counters, calls, state: s, trail };
  }
}
