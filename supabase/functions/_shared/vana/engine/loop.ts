/**
 * Box 5 · the step loop (proposal v7 §4.4 "the step loop", §4.5 passes; README deltas 4 and 8).
 *
 * Runs the Plan in sequence. A model step = shared persona + the block + the shape prompt + the step section + the last
 * ~10 shown lines (past cards as "(card: …)" notes) + the message with its bracketed notes. Inside a step the engine
 * owns the pass loop, so prepareStep's three jobs are plain code: compact replay (a tool result goes back as its
 * one-line view), the forced first tool, and the forced landing (no tools on the last pass). A card ends the turn; a
 * receipt rides to the next step as [just done: …]; intermediate steps' words are dropped; the block is rebuilt between
 * a write and a read; the last step's words are the reply. Check runs after every step; [GUARD] once, then the safe line.
 */
import type { Adapters, ChatMessage, Usage } from './adapters.ts';
import type { Assembled } from './assemble.ts';
import type { Card, ConversationState, Counters, FlowDeclaration, Line, Milestone, ModelCallLog, Plan, PlanStep, Receipt, ToolSpec } from './types.ts';
import { checkReply, guardMessage, parseGuardReply, type Violation } from './check.ts';
import { bindArguments, TURN_TOKEN_CEILING } from './gate.ts';
import { caught } from './counters.ts';
import { celebrate, fromTool } from './save.ts';
import { feedbackLine, offFlowLine, type ScriptedLines } from './scripted.ts';

export const HISTORY_WINDOW = 10;
const SHAPE_STEM: Record<string, string> = { answer: 'shape-answer', set_value: 'shape-set-value', draft_record: 'shape-draft-record', choose: 'shape-choose', hand_off: 'shape-hand-off' };

export interface LoopContext {
  a: Adapters;
  s: ConversationState;
  flow: FlowDeclaration;
  assembled: Assembled;
  reassemble: () => Promise<Assembled>;
  lines: ScriptedLines;
  counters: Counters;
  message: string;
  foreignNames?: string[];
  trail: string[];
  calls: ModelCallLog[];
}

export interface StepRun { stepId: string; text: string; cards: Card[]; receipts: Receipt[]; reactions: string[]; toolsCalled: string[]; violations: Violation[]; passes: number; safeLine: boolean }
export interface PlanRun { steps: StepRun[]; receipts: string[]; card: Card | null; text: string; reactions: string[]; confetti: Milestone[]; endedBy: 'card' | 'words' | 'empty' }

const stripTitle = (md: string) => md.replace(/^# .*\n+/, '').trim();

/** The step agent's history: the last shown lines, athlete as user, Vana as assistant with her cards as notes. */
export function historyMessages(history: Line[]): ChatMessage[] {
  const shown = history.slice(-HISTORY_WINDOW);
  const out: ChatMessage[] = shown.map((l) => l.role === 'athlete'
    ? { role: 'user' as const, content: l.text }
    : { role: 'assistant' as const, content: [l.text, ...(l.cards ?? []).map((c) => `(card: ${c})`)].filter(Boolean).join('\n') || '…' });
  if (out[0]?.role === 'assistant') out.unshift({ role: 'user', content: history.length > shown.length ? '[earlier turns pruned]' : '[opened]' });
  return out;
}

const addUsage = (ctx: LoopContext, u: Usage, role: 'step' | 'guard', step: string, pass: number) => {
  ctx.counters.model_calls++; ctx.counters.tokens_per_pass.push(u.inputTokens + u.outputTokens);
  ctx.calls.push({ role, step, pass, inputTokens: u.inputTokens, outputTokens: u.outputTokens, cachedTokens: u.cachedTokens });
};

export async function runPlan(plan: Plan, ctx: LoopContext): Promise<PlanRun> {
  const runs: StepRun[] = [];
  const receipts: Receipt[] = [];
  const confetti: Milestone[] = [];
  let card: Card | null = null;
  let endedBy: PlanRun['endedBy'] = 'empty';
  let justDone: string[] = [];
  for (let i = 0; i < plan.steps.length; i++) {
    const ps = plan.steps[i];
    const notes = [...ps.notes, ...justDone.map((j) => `[just done: ${j}]`)];
    ctx.counters.steps_run++;
    const run = ps.step.reply === 'scripted' ? await runScripted(ps, notes, ctx) : await runStepAgent(ps, notes, ctx);
    runs.push(run);
    receipts.push(...run.receipts);
    ctx.counters.receipts += run.receipts.length;
    if (run.cards.length) { card = run.cards[0]; ctx.counters.cards_shown++; endedBy = 'card'; }
    else if (run.text) endedBy = 'words';
    if (ps.step.milestone === 'setup_done' && run.cards.length) confetti.push(...celebrate(ctx.s, ['setup_done']));
    if (card) {
      // a card ends the turn: what was planned after it waits on the row
      const left = plan.steps.slice(i + 1).flatMap((p) => p.intents);
      if (left.length) { ctx.s.pending = [...left, ...ctx.s.pending]; ctx.s.pendingWords = ctx.message; ctx.counters.intents_pending += left.length; ctx.trail.push(`loop: card from ${ps.step.id} ends the turn; ${left.length} intent(s) pending`); }
      break;
    }
    if (run.receipts.length && i < plan.steps.length - 1) {
      // a write rebuilds the block before the next step reads it
      justDone = run.receipts.map((r) => r.what);
      ctx.assembled = await ctx.reassemble();
      ctx.trail.push(...ctx.assembled.trail);
    } else justDone = [];
  }
  const last = runs[runs.length - 1];
  return {
    steps: runs, receipts: receipts.map((r) => r.line), card, text: last?.text ?? '', reactions: runs.flatMap((r) => r.reactions), confetti, endedBy,
  };
}

// ---------------------------------------------------------------- scripted steps
async function runScripted(ps: PlanStep, notes: string[], ctx: LoopContext): Promise<StepRun> {
  const steer = (notes.find((n) => n.startsWith('[steer: ')) ?? '').replace(/^\[steer:\s*/, '').replace(/\]$/, '').trim() || null;
  const run: StepRun = { stepId: ps.step.id, text: '', cards: [], receipts: [], reactions: [], toolsCalled: [], violations: [], passes: 0, safeLine: false };
  if (ps.step.scripted === 'off_flow') run.text = offFlowLine(ctx.lines, steer);
  if (ps.step.scripted === 'feedback') {
    const r = await ctx.a.tools.run({ name: 'saveFeedback', input: { message: ctx.message, about: ps.intents[0]?.target ?? 'app' } }, toolCtx(ctx, ps.step.id));
    run.toolsCalled.push('saveFeedback');
    if (r.type === 'error') ctx.trail.push(`loop: saveFeedback failed (${r.message}); the ack still goes out, the words are kept on the row`);
    run.text = feedbackLine(ctx.lines, steer);
  }
  if (ps.step.scripted === 'wrap') {
    const r = await ctx.a.tools.run({ name: 'setupRecap', input: {} }, toolCtx(ctx, ps.step.id));
    run.toolsCalled.push('setupRecap');
    const { card } = fromTool(r, ps.step.id, ctx.s);
    if (card) run.cards.push(card); else ctx.trail.push(`loop: setupRecap returned no card (${r.type}); the wrap line goes out alone`);
    run.text = ctx.lines.wrap;
  }
  run.violations = checkReply(run.text, [], { ...checkCtx(ctx, ps, run), scripted: true });
  for (const v of run.violations) caught(ctx.counters, v.rule);
  return run;
}

// ---------------------------------------------------------------- model steps
const toolCtx = (ctx: LoopContext, step: string) => ({ userId: ctx.s.userId, conversationId: ctx.s.conversationId, step, words: ctx.message });

function checkCtx(ctx: LoopContext, ps: PlanStep, run: StepRun, writeRefused: string[] = []) {
  return {
    snapshot: ctx.assembled.snapshot, step: ps.step, toolsCalled: run.toolsCalled, receipts: run.receipts, cards: run.cards,
    earlier: ctx.s.history.filter((l) => l.role === 'vana').map((l) => l.text),
    athleteWords: [...ctx.s.history.filter((l) => l.role === 'athlete').map((l) => l.text), ctx.message],
    foreignNames: ctx.foreignNames, safetyHit: !!ctx.s.safetyHit, writeRefused,
  };
}

async function systemMessages(ps: PlanStep, ctx: LoopContext): Promise<ChatMessage[]> {
  const p = ctx.a.prompts;
  const shared = stripTitle(await p.get('shared'));
  const shape = ps.step.section === 'sensitive' ? '' : SHAPE_STEM[ps.step.shape] ? stripTitle(await p.get(SHAPE_STEM[ps.step.shape]).catch(() => '')) : '';
  const section = ps.step.section ? stripTitle(await p.get(ps.step.section)) : '';
  return [
    { role: 'system', content: shared, cache: true },
    { role: 'system', content: ctx.assembled.block, cache: true },
    { role: 'system', content: [shape, section].filter(Boolean).join('\n\n') },
  ];
}

async function runStepAgent(ps: PlanStep, notes: string[], ctx: LoopContext): Promise<StepRun> {
  const run: StepRun = { stepId: ps.step.id, text: '', cards: [], receipts: [], reactions: [], toolsCalled: [], violations: [], passes: 0, safeLine: false };
  const writeRefused: string[] = [];
  const system = await systemMessages(ps, ctx);
  const history = historyMessages(ctx.s.history);
  const userMessage = [...notes.filter((n) => !n.startsWith('[steer:')), ctx.message].filter(Boolean).join(' ');
  const thread: ChatMessage[] = [...system, ...history, { role: 'user', content: userMessage }];
  const specs: ToolSpec[] = ctx.a.tools.specs(ps.step.tools.map((t) => t.name));
  const kindOf = (name: string) => ps.step.tools.find((t) => t.name === name)?.kind ?? 'read';
  const max = ctx.flow.maxPasses;
  let spent = 0;
  const words: string[] = [];
  let landed = false;

  for (let pass = 1; pass <= max; pass++) {
    const last = pass === max;
    const forced = pass === 1 && ps.step.forcedFirstTool && specs.some((t) => t.name === ps.step.forcedFirstTool) ? { name: ps.step.forcedFirstTool } : null;
    const r = await ctx.a.model.generate({ messages: thread, tools: last ? [] : specs, toolChoice: last ? 'none' : forced ?? 'auto', role: 'step', step: ps.step.id });
    run.passes = pass;
    addUsage(ctx, r.usage, 'step', ps.step.id, pass);
    spent += r.usage.inputTokens + r.usage.outputTokens;
    if (r.text.trim()) words.push(r.text.trim());
    if (last) { if (r.toolCalls.length) ctx.trail.push(`loop: ${ps.step.id} tried a tool on the landing pass; ignored`); ctx.counters.forced_landing++; landed = true; break; }
    if (!r.toolCalls.length) break;   // the model wrote words and stopped
    thread.push({ role: 'assistant', content: [r.text, ...r.toolCalls.map((c) => `(calling ${c.name} ${JSON.stringify(c.input)})`)].filter(Boolean).join('\n') });
    let ended = false;
    for (const raw of r.toolCalls) {
      const kind = kindOf(raw.name);
      if (!specs.some((t) => t.name === raw.name)) { thread.push({ role: 'tool', content: `${raw.name}: not a tool of this step` }); continue; }
      if (kind === 'write' && !ps.writeAllowed) { writeRefused.push(raw.name); thread.push({ role: 'tool', content: `${raw.name}: refused — the athlete has not said yes to this; ask, or show the card` }); continue; }
      const { call, disagreement, dropped } = bindArguments(ps.step, raw, ctx.assembled.snapshot);
      if (disagreement) { ctx.counters.bound_arg_disagreement++; ctx.trail.push(`gate: ${call.name} bound over the model (${dropped.join('; ')})`); }
      const outcome = await ctx.a.tools.run(call, toolCtx(ctx, ps.step.id));
      run.toolsCalled.push(call.name);
      if (outcome.type === 'error') { thread.push({ role: 'tool', content: `${call.name}: ${outcome.message}` }); continue; }
      if (kind === 'react' && outcome.type === 'view') { run.reactions.push(String((outcome.data as { emoji?: string })?.emoji ?? outcome.view)); thread.push({ role: 'tool', content: outcome.view }); continue; }
      const { card, receipt } = fromTool(outcome, ps.step.id, ctx.s);
      if (card) { run.cards.push(card); ended = true; thread.push({ role: 'tool', content: `(card: ${card.kind} shown; it ends your reply)` }); break; }
      if (receipt) { run.receipts.push(receipt); thread.push({ role: 'tool', content: `[receipt: ${receipt.line}]` }); continue; }
      if (outcome.type === 'view') thread.push({ role: 'tool', content: outcome.view });   // compact replay: the one-line view, never the raw result
    }
    if (ended) {
      // "text after a widget is text": a card with no words yet gets one landing pass, tools off
      if (!words.length && pass < max) {
        const land = await ctx.a.model.generate({ messages: thread, tools: [], toolChoice: 'none', role: 'step', step: ps.step.id });
        run.passes++; addUsage(ctx, land.usage, 'step', ps.step.id, run.passes);
        if (land.text.trim()) words.push(land.text.trim());
        ctx.counters.forced_landing++; landed = true;
      }
      break;
    }
    if (spent > TURN_TOKEN_CEILING) { ctx.trail.push(`loop: ${ps.step.id} hit the token ceiling after pass ${pass}; landing`); ctx.counters.pass_cap_hit++; break; }
  }
  if (run.passes >= max && !landed) ctx.counters.pass_cap_hit++;
  run.text = words.join('\n').replace(/<thinking>[\s\S]*?(<\/thinking>|$)/gi, '').replace(/^\s*\[GUARD\]\s*/i, '').trim();

  // 6 · Check, [GUARD] once, then the safe line
  const captions = run.cards.map((c) => c.caption ?? '').filter(Boolean);
  run.violations = checkReply(run.text, captions, checkCtx(ctx, ps, run, writeRefused));
  for (const v of run.violations) caught(ctx.counters, v.rule);
  const textual = run.violations.filter((v) => v.rule !== 'write_without_yes');
  if (textual.length) {
    const captioned = run.cards.filter((c) => c.caption);
    const g = await ctx.a.model.generate({ messages: [...thread, { role: 'user', content: guardMessage(textual, ctx.flow.lines(ctx.assembled.snapshot), captioned.length) }], tools: [], toolChoice: 'none', role: 'guard', step: ps.step.id });
    addUsage(ctx, g.usage, 'guard', ps.step.id, run.passes + 1);
    const parsed = parseGuardReply(g.text, captioned.length);
    const draft = run.text;
    run.text = parsed.words;
    captioned.forEach((c, i) => { if (parsed.captions[i]) c.caption = parsed.captions[i]!; });
    const still = checkReply(run.text, run.cards.map((c) => c.caption ?? '').filter(Boolean), checkCtx(ctx, ps, run, [])).filter((v) => v.rule !== 'write_without_yes');
    if (still.length) { run.text = ctx.lines.safe; run.safeLine = true; ctx.counters.check_safe_line++; ctx.trail.push(`check: ${ps.step.id} failed twice (${still.map((v) => v.rule).join(', ')}); safe line sent`); }
    else { ctx.counters.check_retry_fixed++; ctx.trail.push(`check: ${ps.step.id} rewrote once (${textual.map((v) => v.rule).join(', ')}): "${draft.slice(0, 60)}…" → ok`); }
  }
  return run;
}
