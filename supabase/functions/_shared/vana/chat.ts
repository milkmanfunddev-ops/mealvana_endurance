/** Chat orchestration shared by `vana-chat` and the `jade-chat` alias:
 *  rate limit → context → conversation → tools → user-row persist → streamText → NDJSON, with the assistant row,
 *  `vana_calls` and `ai_usage` written from onFinish under EdgeRuntime.waitUntil.
 *  Cost posture: Haiku by default, ≤6 steps, ≤700 output tokens, ~250-token context block, compact tool outputs.
 *  The repeated prefix is cached (mp-276): the gateway call carries Anthropic's automatic cache_control, the prompt
 *  order is fixed (tools, persona, context, messages), the context block is built once per conversation and reused
 *  (context-cache.ts), and the cache-read token count is logged per call so a zero is visible.
 *  Brevity is a prompt rule (persona.ts VOICE registers), not a server trim: a clamp only cuts text after it was paid for.
 *  The only server cut is a generous runaway guard so a looping turn never floods the transcript (Lee, 2026-09-03). */
import { streamText, convertToModelMessages, stepCountIs, type UIMessage } from 'npm:ai@6.0.277';
import { CHAT_MODEL, localDate, waitUntil } from './env.ts';
import type { VanaCtx } from './env.ts';
import { buildAthleteContext, contextBlock } from './context.ts';
import { cachedContext } from './context-cache.ts';
import { makeVanaTools } from './tools.ts';
import { PLANNING_PROMPT, GENERAL_PROMPT, OPENERS, NEW_PLAN_OPENER, NEW_PLAN_STANDING, checkinOpener, debriefOpener } from './persona.ts';
import { completeCall, reserveCall } from './rate-limit.ts';
import { readSummaries, writeSummary, writeOnIdle, defaultExtractDeps, defaultSummaryDeps, type ExtractDeps, type StoredSummary, type SummaryDeps } from './extract.ts';
import { inViewSection, resolveSituation, type Situation } from './situation.ts';
import { asInputMode, callMetrics, logCall, type InputMode } from './log.ts';
import { subscriberState } from './subscriber.ts';
import { logAiUsage } from '../ai/usage.ts';
import type { VanaPart, AthleteContext, ConversationSummary, ConversationKind } from './contracts.ts';
import { getConversationPlan, getPlan, snapshotPlan } from './plan.ts';
import { addDays, weekStartFor } from './env.ts';
import { pickOpener, pendingDebrief, NEW_PLAN_SITUATION, type OpenerVariant } from './opener.ts';
import { getPlanPeriod } from './memory.ts';
import { generalOpener, type GeneralOpenerVariant } from './moment.ts';
import type { MealPlan } from './contracts.ts';
import { ndjsonFromFullStream, ndjsonHeaders, cacheReadTokens } from './stream.ts';

/** Anthropic's automatic prompt caching, through the gateway: a top-level `cache_control` the API places on the last
 *  cacheable block and moves forward as the conversation grows (mp-276 clause 1). With the prefix stable — tools,
 *  persona, context, then the history — every turn after the first reads the one before it. */
export const CACHE_PROVIDER_OPTIONS = { anthropic: { cacheControl: { type: 'ephemeral' as const } } };

const MAX_OUTPUT_TOKENS = 900;
/** The most a single turn may spend, input and output across every step, before the loop is stopped (mp-469 criterion 4).
 *  The step limit alone bounds the number of model calls, not their size: six steps that each replay a long history are
 *  six long calls. This is a runaway guard, not a budget: the count includes cached input, and on dev (14 days to
 *  2026-09-21) a planning turn ran 22k at the median and 85k at most, so the ceiling sits well clear of a real turn. */
export const TURN_TOKEN_CEILING = 150_000;
const stepTokens = (u?: { inputTokens?: number; outputTokens?: number; totalTokens?: number }) =>
  u?.totalTokens ?? (u?.inputTokens ?? 0) + (u?.outputTokens ?? 0);
/** A stop condition on spend: the turn ends once the steps so far have cost `ceiling` tokens. A usage the provider did
 *  not report reads as zero — an unknown cost never stops a turn that has not run. */
export const tokenBudgetIs = (ceiling: number) => ({ steps }: { steps: Array<{ usage?: { inputTokens?: number; outputTokens?: number; totalTokens?: number } }> }) =>
  steps.reduce((s, x) => s + stepTokens(x.usage), 0) >= ceiling;
/** What stops a turn: its step limit AND its token ceiling (either one ends the loop). */
export const chatStopWhen = (general: boolean) => [stepCountIs(general ? 8 : 6), tokenBudgetIs(TURN_TOKEN_CEILING)];
/** Runaway guard, not a style rule: a well-behaved planning turn never comes near it (PRESENTING is ≤4 sentences). */
export const RUNAWAY_SENTENCES = 8;
const textOf = (m: UIMessage) => m.parts.filter((p): p is { type: 'text'; text: string } => p.type === 'text').map((p) => p.text).join('\n');
/** Meal ids already shown in this conversation's pickers / staples widgets — "other options" must not repeat them. */
export function shownMealIds(messages: UIMessage[]): string[] {
  const ids = new Set<string>();
  for (const m of messages) for (const p of m.parts as { type: string; state?: string; output?: unknown }[]) {
    if (!p.type.startsWith('tool-') || p.state !== 'output-available') continue;
    const out = p.output as { kind?: string; meals?: { id?: string }[] } | undefined;
    if ((out?.kind === 'meal_picker' || out?.kind === 'staples') && Array.isArray(out.meals)) for (const x of out.meals) if (x?.id) ids.add(String(x.id));
  }
  return [...ids];
}
const promptFor = (kind: ConversationKind) => (kind === 'general' ? GENERAL_PROMPT : PLANNING_PROMPT);

// Opener variants (plan Phase 3) live in opener.ts — pure, so tests import them without the AI SDK.
async function loadOpenerInput(v: VanaCtx, t: string) {
  const period = await getPlanPeriod(v); // mp-269: the week and the cook dates read the athlete's start day and period length
  const ws = weekStartFor(t, period.weekStart);
  // The period before this one is a period back, not a fixed week (mp-269 clause 2).
  const [current, previous] = await Promise.all([getPlan(v, ws), getPlan(v, addDays(ws, -period.periodDays))]);
  const stamp = async (p: MealPlan | null) => { if (!p) return null; const { data } = await v.db.from('meal_plans').select('checkin_done_at, debrief_done_at').eq('id', p.id).maybeSingle(); return { ...p, checkinDoneAt: data?.checkin_done_at ?? null, debriefDoneAt: data?.debrief_done_at ?? null }; };
  return { today: t, current: await stamp(current), previous: await stamp(previous), periodDays: period.periodDays };
}

/** History is chunked, never sliding (mp-277 clause 1). Every message stays verbatim up to this many. */
export const VERBATIM_CAP = 40;
/** At the cap the oldest chunk becomes one summary message and the last chunk stays verbatim; the same again
 *  every chunk after that, rolling the previous summary in. */
export const SUMMARY_CHUNK = 20;
/** The summary for a boundary is written this many messages before the count reaches it, so it exists by then
 *  and no turn waits for a model call. */
export const SUMMARY_LEAD = 10;
/** The index the replay applies at `count` messages: the stored summary covering [0, index) stands in for them
 *  and the rest stay verbatim. Zero under the cap; then the greatest chunk boundary leaving a full chunk verbatim. */
export const summaryIndexAt = (count: number) => count < VERBATIM_CAP ? 0 : Math.floor((count - SUMMARY_CHUNK) / SUMMARY_CHUNK) * SUMMARY_CHUNK;
/** The index whose summary is due by `count` messages: SUMMARY_LEAD ahead of the boundary it is applied at. */
export const summaryDueAt = (count: number) => count < SUMMARY_CHUNK + SUMMARY_LEAD ? 0 : Math.floor((count - SUMMARY_LEAD) / SUMMARY_CHUNK) * SUMMARY_CHUNK;

const summaryMessage = (p: StoredSummary): UIMessage =>
  ({ id: `summary-${p.index}`, role: 'user', parts: [{ type: 'text', text: `Earlier in this conversation (messages 1–${p.index}, summarised): ${p.text}` }] } as UIMessage);
/** The messages a turn replays, given what the row holds: under the cap, or with nothing stored that can stand in,
 *  every message verbatim (nothing is invented and nothing is lost — a missing summary only costs tokens); else the
 *  newest stored summary at or under the applied index, then the messages after it. The pending roll written ten
 *  ahead is stored beside the applied one and is not used until its own boundary. */
export function compactHistory(messages: UIMessage[], parts: StoredSummary[]): UIMessage[] {
  const applied = summaryIndexAt(messages.length);
  if (applied === 0) return messages;
  const part = parts.filter((p) => p.index > 0 && p.index <= applied && p.text.trim()).sort((a, b) => b.index - a.index)[0];
  if (!part) return messages;
  return [summaryMessage(part), ...messages.slice(part.index)];
}
export interface ReplayDeps {
  summary: SummaryDeps;
  /** Where the summary write runs. EdgeRuntime.waitUntil in production; a test records it. */
  background: (p: Promise<unknown>) => void;
}
const defaultReplayDeps: ReplayDeps = { summary: defaultSummaryDeps, background: waitUntil };
/** The history a turn replays, and the summary that keeps it whole. Reads the row once a summary could be due or
 *  applied; when the boundary due by now has no summary yet — the lead write at thirty, or one that failed or was
 *  rate-limited — it is written in the background from the messages in hand, and this turn never waits for it.
 *  The cached prefix (mp-276) changes only when a boundary is crossed: once per chunk. */
export async function replayHistory(v: VanaCtx, conversationId: string, messages: UIMessage[], deps: ReplayDeps = defaultReplayDeps): Promise<UIMessage[]> {
  const due = summaryDueAt(messages.length);
  if (!due || !conversationId) return messages;
  const { index, parts } = await readSummaries(v, conversationId);
  if (index < due) deps.background(writeSummary(v, conversationId, due, messages, deps.summary));
  return compactHistory(messages, parts);
}

/** Keeps the first `n` sentences of a text block. Planning turns use it only as the RUNAWAY_SENTENCES guard. */
export function clampSentences(t: string, n = RUNAWAY_SENTENCES): string {
  const parts = t.replace(/\s+/g, ' ').trim().match(/[^.!?]+[.!?]+(\s|$)|[^.!?]+$/g) ?? [t];
  return parts.slice(0, n).join('').trim();
}

// ---------------------------------------------------------------- conversations (vana_conversations / vana_messages, RLS-scoped)
export async function listConversations(v: VanaCtx, limit = 30, kind?: ConversationKind): Promise<ConversationSummary[]> {
  let q = v.db.from('vana_conversations').select('id, kind, title, summary, last_message_at, created_at').eq('user_id', v.userId).eq('is_deleted', false);
  if (kind) q = q.eq('kind', kind);
  const { data } = await q.order('last_message_at', { ascending: false, nullsFirst: false }).order('created_at', { ascending: false }).limit(limit);
  // deno-lint-ignore no-explicit-any
  return (data ?? []).map((r: any) => ({ id: r.id, kind: r.kind === 'general' ? 'general' : 'meal_planning', title: r.title, summary: r.summary, lastMessageAt: r.last_message_at, createdAt: r.created_at }));
}
/** Conversations this user had before `exceptId` (which is the one being opened). Counts deleted ones too — a deleted chat
 *  was still a conversation, and the shake tip is a first-ever thing. Any error reads as "not first" (never re-tip on a hiccup). */
export async function priorConversationCount(v: VanaCtx, exceptId: string): Promise<number> {
  const { count, error } = await v.db.from('vana_conversations').select('id', { count: 'exact', head: true }).eq('user_id', v.userId).neq('id', exceptId);
  if (error) { console.error('[vana] priorConversationCount:', error.message); return 1; }
  return count ?? 1;
}
/** Whether the conversation already holds a turn. An opener written into one (a moment's, VM-1) starts a new exchange, not
 *  the conversation: it is not the first turn. */
/** Whether this conversation was opened from "New meal plan": its opener row carries metadata.new_plan (see the insert in runChat). */
export async function conversationIsNewPlan(v: VanaCtx, conversationId: string): Promise<boolean> {
  const { data } = await v.db.from('vana_messages').select('metadata').eq('conversation_id', conversationId).eq('role', 'assistant').order('created_at', { ascending: true }).limit(3);
  return (data ?? []).some((r: { metadata?: { new_plan?: unknown } | null }) => r.metadata?.new_plan === true);
}
export async function conversationHasTurns(v: VanaCtx, conversationId: string): Promise<boolean> {
  if (!conversationId) return false;
  const { data } = await v.db.from('vana_messages').select('id').eq('conversation_id', conversationId).eq('user_id', v.userId).limit(1);
  return (data ?? []).length > 0;
}
export async function createConversation(v: VanaCtx, kind: ConversationKind = 'meal_planning'): Promise<string> {
  const { data, error } = await v.db.from('vana_conversations').insert({ user_id: v.userId, title: null, kind, last_message_at: new Date().toISOString() }).select('id').single();
  if (error) throw new Error(error.message); return data.id as string;
}
export async function conversationKind(v: VanaCtx, conversationId: string): Promise<ConversationKind> {
  const { data } = await v.db.from('vana_conversations').select('kind').eq('id', conversationId).eq('user_id', v.userId).maybeSingle();
  return data?.kind === 'general' ? 'general' : 'meal_planning';
}
/** An existing, non-deleted conversation of the caller's, else a fresh one (a foreign or stale id is invisible under RLS → fresh). */
export async function ensureConversation(v: VanaCtx, conversationId?: string | null, kind: ConversationKind = 'meal_planning'): Promise<{ id: string; kind: ConversationKind }> {
  if (conversationId) { const { data } = await v.db.from('vana_conversations').select('id, kind').eq('id', conversationId).eq('user_id', v.userId).eq('is_deleted', false).maybeSingle(); if (data) return { id: data.id, kind: data.kind === 'general' ? 'general' : 'meal_planning' }; }
  return { id: await createConversation(v, kind), kind };
}
/** Stored rows → UIMessage[] (parts column preferred; legacy content + metadata.ui_parts otherwise). */
export async function conversationMessages(v: VanaCtx, conversationId: string): Promise<{ kind: ConversationKind; messages: UIMessage[] }> {
  const [{ data }, kind] = await Promise.all([v.db.from('vana_messages').select('id, role, content, metadata, parts, created_at').eq('conversation_id', conversationId).eq('user_id', v.userId).order('created_at'), conversationKind(v, conversationId)]);
  // deno-lint-ignore no-explicit-any
  const messages = (data ?? []).map((r: any) => {
    if (r.role === 'user') return { id: r.id, role: 'user', parts: [{ type: 'text', text: r.content ?? '' }] } as UIMessage;
    if (Array.isArray(r.parts) && r.parts.length) return { id: r.id, role: 'assistant', parts: r.parts } as UIMessage;
    const ui = (r.metadata?.ui_parts ?? []) as VanaPart[];
    const parts: unknown[] = [];
    if (r.content) parts.push({ type: 'text', text: r.content });
    ui.forEach((p, i) => parts.push({ type: 'tool-legacy', toolCallId: `${r.id}:${i}`, state: 'output-available', input: {}, output: p }));
    return { id: r.id, role: 'assistant', parts } as UIMessage;
  });
  return { kind, messages };
}
async function touch(v: VanaCtx, convId: string, firstUserText?: string) {
  const patch: Record<string, unknown> = { last_message_at: new Date().toISOString(), updated_at: new Date().toISOString() };
  if (firstUserText) { const { data } = await v.db.from('vana_conversations').select('title').eq('id', convId).maybeSingle(); if (!data?.title) patch.title = firstUserText.replace(/\s+/g, ' ').slice(0, 60); }
  await v.db.from('vana_conversations').update(patch).eq('id', convId);
}
/** The server-authored feedback acknowledgement (ticket 01, 2026-09-10).
 *
 * On a turn that files feedback the content-managed `feedback_saved` row IS the reply, and the model's own prose is
 * dropped. The persona asks for silence and the model does not hold it: three prompt variants ran to 3–5 sentences and
 * troubleshot, and the explicit "no apology, no promise" list primed the very behaviours it forbade. It gets worse as
 * the Doll gets better — with the complaint in MEMORIES, Vana reads that she has been corrected before and apologises
 * for it. The user story is "I am not troubleshot when I was venting"; the harm is the diagnosing and the promising,
 * and the sentence count was only ever a proxy.
 *
 * This is not the clamp that was rejected. A clamp keeps whichever sentence came first, which in the worst run was
 * "You're right, and I apologize" with the acknowledgement last. This drops the prose entirely and keeps the line the
 * content system owns — the same precedent as the first-conversation `feedback_prompt`, which is server-authored
 * precisely so the model cannot paraphrase it away.
 *
 * The one thing a question mark buys is an answer. A message that is both a complaint and a question — "why do you
 * keep suggesting fish?" — still gets its prose; only a pure vent is answered by the row alone. */
export const silenceAfterFeedback = (userMessage: string) => !userMessage.includes('?');

// deno-lint-ignore no-explicit-any
export function partsFromSteps(text: string, steps: any[], maxSentences: number | null = RUNAWAY_SENTENCES, silenceFeedback = false): { parts: unknown[]; ui: VanaPart[] } {
  const parts: unknown[] = []; const ui: VanaPart[] = [];
  // interleave: each step's text (runaway-guarded) then its UI tool outputs, so the transcript reads in order
  let anyText = false;
  let filed = false;   // a feedback_saved output has landed; with silenceFeedback, no later text is kept
  const clamp = (t: string) => (maxSentences == null ? t.replace(/\s+/g, ' ').trim() : clampSentences(t, maxSentences));
  for (const s of steps) {
    // Unclamped (general) mode: drop the model's pre-tool narration ("I'll pull up your plan.") — only the step that answers keeps its text.
    // A step whose only tool is askChoice is not narrating: its text is what the question is about (a moment's opener names the
    // session there), and the stream already showed it.
    const calls = (s.toolCalls ?? []) as { toolName?: string }[];
    const asking = calls.length > 0 && calls.every((c) => c.toolName === 'askChoice');
    const narration = maxSentences == null && calls.length > 0 && !asking && String(s.text ?? '').length < 160;
    const t = narration || (filed && silenceFeedback) ? '' : clamp(String(s.text ?? '')); if (t) { parts.push({ type: 'text', text: t }); anyText = true; }
    for (const r of s.toolResults ?? []) {
      const out = (r as { output?: unknown; toolName?: string; toolCallId?: string; input?: unknown }).output;
      if (out && typeof out === 'object' && 'kind' in (out as object)) { if ((out as { kind?: string }).kind === 'feedback_saved') filed = true; ui.push(out as VanaPart); parts.push({ type: `tool-${(r as { toolName: string }).toolName}`, toolCallId: (r as { toolCallId?: string }).toolCallId ?? `${Date.now()}`, state: 'output-available', input: (r as { input?: unknown }).input ?? {}, output: out }); }
    }
  }
  if (!anyText && text.trim() && !(filed && silenceFeedback)) parts.unshift({ type: 'text', text: clamp(text) });
  return { parts, ui };
}
/** The day's name, so "Saturday" in a past conversation can be read against today without date arithmetic. */
const weekdayOf = (iso: string) => ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][new Date(`${iso}T12:00:00Z`).getUTCDay()];
/** Both kinds get the same block (the Voodoo Doll, 2026-09-09). Only the prompt above it differs.
 *  Before this, general mode carried a first name and a date, and everything else had to be fetched
 *  by a tool call the model might not make.
 *  Order is fixed and stable within a day: persona, then the context (the API renders tools before this
 *  system text, and the messages after it). Nothing per-message goes in here — the Situation rides on the
 *  user message (`withSituation`) — or the cached prefix would break on every turn (mp-276 clause 3). */
export const systemPrompt = (kind: ConversationKind, ctx: AthleteContext, todayIso: string, extra = '') =>
  `${promptFor(kind)}\n--- CONTEXT (today ${todayIso}, ${weekdayOf(todayIso)}) ---\n${contextBlock(ctx)}${extra}`;

/** The Situation (which screen they are on) travels with the message, so it is appended to the last user turn as a
 *  marked line, not written into the system prompt: the prefix stays byte-identical across turns and only the newest
 *  message — never cached anyway — carries what changes per message. */
export function withSituation<M extends { role: string; content: unknown }>(messages: M[], situation: string | null | undefined, section?: string | null): M[] {
  if (!situation) return messages;
  const i = messages.map((m) => m.role).lastIndexOf('user');
  if (i < 0) return messages;
  // The in-view section (mp-273 clause 2) goes under the note, on the same message, for the same reason.
  const m = messages[i]; const note = `[SITUATION right now they are ${situation}]${section ? `\n${section}` : ''}`;
  const content = typeof m.content === 'string' ? `${m.content}\n\n${note}` : Array.isArray(m.content) ? [...m.content, { type: 'text', text: note }] : m.content;
  return [...messages.slice(0, i), { ...m, content }, ...messages.slice(i + 1)];
}

// ---------------------------------------------------------------- chat
/** Request body per 02-contract §5. */
export interface ChatBody { message?: string; conversation_id?: string | null; kind?: ConversationKind | string; timezone?: string; opener?: boolean; anchor_date?: string; situation?: Situation | null;
  /** The client says `conversation_id` is idle (mp-288): no turn, its episode and missed notes are written once. */
  idle?: boolean;
  /** With `opener`: the device raised a moment (vana-moment spec VM-1) — `{ kind, activity_id, window_minutes, branch?, next_activity_id? }`. */
  moment?: unknown;
  /** With `opener` on a planning conversation: the athlete tapped "New meal plan" on the Plan tab. The plan opener wins over a
   *  check-in or debrief, the screen's Situation is replaced by NEW_PLAN_SITUATION, and the opener text forbids raising the plan
   *  the week already holds (it is archived by confirm_meal_plan when this one is confirmed, never at open). Ignored otherwise. */
  new_plan?: boolean;
  /** `'tap' | 'typed'` — what the athlete did to send this message (mp-464 clause 7). Recorded on the call row so the
   *  saving the fixed-label chips make is measurable against the chip taps that still cost a turn. Anything else, and
   *  the scripted opener, is null: the request is never refused over it. */
  input_mode?: string }
export interface ChatRunOpts {
  /** `ai_usage.function_name` / log tag: 'vana-chat' | 'jade-chat'. */
  functionName: string;
  /** false = ephemeral turn: no conversation row, nothing written (the legacy jade-chat opener). Default true. */
  persist?: boolean;
  /** Runs inside the onFinish persistence task after the usage rows are written (jade-chat's credit debit). */
  afterFinish?: (usage: { inputTokens: number; outputTokens: number }) => Promise<void>;
  /** Whether this turn draws the athlete's budget (mp-420 clause 6) — the function's own `charged` decision, recorded on
   *  the call row so "what did the budget actually pay for" is answerable. The scripted opener is not charged today; the
   *  column is what will show that changing (spec: every call draws it down). Default false. */
  debited?: boolean;
}
export type ChatOutcome = { ok: true; response: Response } | { ok: false; status: 400 | 429; body: Record<string, unknown> };

/** The reply to an idle signal (schemas.ts IdleAckZ). Nothing waits on it (mp-288 clause 2). */
export interface IdleAck { idle: true; conversation_id: string | null }
/**
 * The idle signal, a flag on the chat call the way the opener flag rides it (mp-288 clause 1). Null when the body is
 * not one. Otherwise the conversation's episode and any margin notes the remember tool missed are written in the
 * background, once: the `read_back_at` claim makes a second signal write nothing (clause 3). The acknowledgement goes
 * back at once; the write finishes under `background`, so the summary exists before the next conversation opens.
 */
export function idleSignal(v: VanaCtx, body: ChatBody, background: (p: Promise<unknown>) => void = waitUntil, deps: ExtractDeps = defaultExtractDeps): IdleAck | null {
  if (body.idle !== true) return null;
  const id = typeof body.conversation_id === 'string' && body.conversation_id ? body.conversation_id : null;
  if (id) background(writeOnIdle(v, id, deps));
  return { idle: true, conversation_id: id };
}

export async function runChat(v: VanaCtx, body: ChatBody, opts: ChatRunOpts): Promise<ChatOutcome> {
  const idle = opts.persist !== false ? idleSignal(v, body) : null;
  if (idle) return { ok: true, response: new Response(JSON.stringify(idle), { status: 202, headers: { 'content-type': 'application/json' } }) };
  const kind: ConversationKind = body.kind === 'general' ? 'general' : 'meal_planning';
  const message = (body.message ?? '').trim();
  const anchorDate = body.anchor_date ?? localDate(body.timezone);
  const persist = opts.persist !== false;
  // History comes from the server: an existing conversation's rows + the new user turn. `opener` (or no message on a planning
  // conversation) means "write Vana's first turn".
  let messages: UIMessage[] = [];
  if (!body.opener) {
    if (body.conversation_id) messages = (await conversationMessages(v, body.conversation_id)).messages;
    if (message) messages.push({ id: `u-${Date.now()}`, role: 'user', parts: [{ type: 'text', text: message }] });
  }
  if (!messages.length && kind === 'general' && !body.opener) return { ok: false, status: 400, body: { error: 'message_required' } };
  // No free turn (mp-469 criterion 1). An empty message on a conversation that already holds turns used to replay the
  // whole history and store an answer: a full-price turn for a request that said nothing. Only `opener: true` — the
  // scripted first turn, including a moment's opener into an existing thread — may arrive without a message.
  if (!body.opener && !message && messages.length) return { ok: false, status: 400, body: { error: 'message_required' } };

  const opener = messages.length === 0;
  // What the athlete did to send this (mp-464 clause 7). The scripted opener is Vana speaking first, so it is neither a
  // tap nor typed; a body that says nothing (an older build) is null rather than a guess at 'typed'.
  const inputMode: InputMode | null = opener ? null : asInputMode(body.input_mode);
  // The bucket is the row, and the row goes in before the model (mp-430 clause 9): the reservation is this call's
  // `vana_calls` row, and `completeCall` writes its tokens when the turn finishes. An opener counts in its own bucket,
  // which is the one its row was always logged under.
  const bucket = opener ? 'vana.opener' : 'vana.chat';
  const loggedName = `${bucket}.${kind}`;
  const reserved = await reserveCall(v.admin, v.userId, bucket, { functionName: loggedName, model: CHAT_MODEL });
  if (!reserved.allowed) return { ok: false, status: 429, body: { error: 'rate_limited', retry_after_seconds: reserved.retryAfterSeconds, retryAfterSeconds: reserved.retryAfterSeconds } };
  const callId = reserved.callId;
  const last = [...messages].reverse().find((m) => m.role === 'user');
  const lastText = last ? textOf(last) : '';
  const conv = persist ? await ensureConversation(v, body.conversation_id ?? null, kind) : { id: '', kind };
  const convId = conv.id; const convKind = conv.kind;
  // A moment's opener lands in the day's conversation mid-thread (VM-1): that is not the conversation's first turn.
  const intoThread = opener && persist && !!body.conversation_id && (await conversationHasTurns(v, convId));
  // The opener reads what exists and never waits (mp-278): the memory table and the newest episodes as they stand.
  // Nothing is read back here; the previous conversation's episode was written when the client said it was idle,
  // and when it does not exist yet the opener leaves it out.
  // Planning writes land on this conversation's own draft; the context's PLAN line describes that draft, not the Plan tab's plan.
  const scope = convKind === 'meal_planning' && convId ? { conversationId: convId } : null;
  // Built once when the conversation opens and reused for its turns; a tool write or a new day rebuilds it (mp-276).
  const { ctx, reused } = await cachedContext(v, persist ? convId : null, anchorDate, async () => {
    const c = await buildAthleteContext(v, anchorDate);
    if (scope) { const draft = await getConversationPlan(v, convId, false); c.plan = { exists: !!draft && draft.meals.length > 0, status: draft?.status ?? 'draft', mealsLeft: draft ? draft.meals.reduce((s, m) => s + m.servingsLeft, 0) : 0, batchCooking: draft?.batchCooking ?? c.plan.batchCooking }; }
    return c;
  });
  // The Situation travels with the message and is resolved here from ids; it is never written anywhere, and it rides
  // on the user message rather than the block (see withSituation).
  // "New meal plan" from the Plan tab: the screen underneath is the plan being replaced, so its sentence and DAY PLAN section
  // are left out of this one turn (opener.ts NEW_PLAN_SITUATION); every later turn resolves the ids the client sends as usual.
  const newPlan = opener && convKind === 'meal_planning' && body.new_plan === true;
  // The intent outlives the opener: the opener row records new_plan, and every later turn of that conversation reads it back,
  // so the Plan tab underneath (the plan being replaced) never re-enters the situation and the model is told, every turn,
  // that a fresh plan is being built (Lee, 2026-09-16: one turn in, Vana pointed him back at the old plan).
  const newPlanConversation = newPlan || (convKind === 'meal_planning' && !opener && persist && !!convId && (await conversationIsNewPlan(v, convId)));
  const [situation, inView] = newPlanConversation ? [NEW_PLAN_SITUATION, null] : await Promise.all([resolveSituation(v, body.situation), inViewSection(v, body.situation, anchorDate)]);
  const tools = makeVanaTools(v, ctx, convKind, { scope, conversationId: convId || null, shownIds: shownMealIds(messages) });
  // A pure vent is answered by the content-managed row alone; a complaint that also asks something still gets its answer.
  const silenceFeedback = silenceAfterFeedback(lastText);
  const started = Date.now();
  if (last && !opener && persist) { await v.db.from('vana_messages').insert({ conversation_id: convId, user_id: v.userId, role: 'user', content: lastText, parts: last.parts }); await touch(v, convId, lastText); }
  let openerText: string = OPENERS[convKind]; let openerVariant: OpenerVariant['kind'] | GeneralOpenerVariant = 'plan'; let extraContext = '';
  // The athlete's very first conversation of any kind gets a server-authored `feedback_prompt` part after the opener
  // ("Give feedback for me here" → the app's own feedback sheet). Appended to the stream and the persisted row; the model
  // never sees or writes it, so it cannot be paraphrased away.
  const firstConversation = opener && persist && !intoThread && (await priorConversationCount(v, convId)) === 0;
  const trailingParts: VanaPart[] = firstConversation ? [{ kind: 'feedback_prompt' }] : [];
  // A moment's opener goes into the day's conversation even when it already has a thread (VM-1).
  if (convKind === 'general' && opener) ({ text: openerText, variant: openerVariant } = await generalOpener(v, body));
  if (convKind === 'meal_planning') {
    const openerInput = await loadOpenerInput(v, anchorDate);
    // The opener's synthetic user message is never stored, so later turns need the pending debrief restated in the context.
    if (newPlanConversation) extraContext = NEW_PLAN_STANDING;
    const pending = pendingDebrief(openerInput); if (pending && !newPlanConversation) extraContext = `\nDEBRIEF PENDING last week's plan id ${pending.id} (${pending.meals.length} meals: ${pending.meals.map((m) => m.name).join(', ')}) — recordDebrief has not been called yet`;
    const variant = opener ? pickOpener({ ...openerInput, newPlan }) : ({ kind: 'plan' } as OpenerVariant); openerVariant = variant.kind;
    if (newPlan) openerText = NEW_PLAN_OPENER;
    else if (variant.kind === 'checkin') { openerText = checkinOpener(variant.plan, variant.cookDate, variant.session, anchorDate); await v.db.from('meal_plans').update({ checkin_done_at: new Date().toISOString() }).eq('id', variant.plan.id).eq('user_id', v.userId); }
    else if (variant.kind === 'debrief') openerText = debriefOpener(variant.plan);
  }
  const replayed = opener ? messages : await replayHistory(v, convId, messages);
  const modelMessages = withSituation(opener ? [{ role: 'user' as const, content: openerText }] : await convertToModelMessages(replayed), situation, inView);
  const general = convKind === 'general';
  const tag = `[${opts.functionName}]`;
  console.log(`${tag} user=${v.userId} conv=${convId || '(ephemeral)'} kind=${convKind} opener=${opener}${opener ? `/${openerVariant}${newPlan ? '/new_plan' : ''}` : ''} model=${CHAT_MODEL} context=${reused ? 'reused' : 'built'}`);

  const result = streamText({
    model: CHAT_MODEL,
    system: systemPrompt(convKind, ctx, anchorDate, extraContext),
    messages: modelMessages,
    tools,
    maxOutputTokens: MAX_OUTPUT_TOKENS,
    // deno-lint-ignore no-explicit-any
    stopWhen: chatStopWhen(general) as any,
    providerOptions: CACHE_PROVIDER_OPTIONS,
    onFinish: ({ text, steps, usage, totalUsage }) => {
      const u = totalUsage ?? usage;
      const inputTokens = u?.inputTokens ?? 0; const outputTokens = u?.outputTokens ?? 0;
      const cacheRead = cacheReadTokens(u) ?? 0;
      // What the turn cost us, out of what the SDK handed back: the cache both directions, the steps, the FIRST step's
      // prompt (the only one that can read the shared prefix from cache) and the gateway's own charge (mp-420 clause 6).
      const metrics = callMetrics(steps as unknown[], u);
      const task = (async () => {
        try {
          if (persist) {
            const { parts, ui } = partsFromSteps(text, steps as unknown[], general ? null : RUNAWAY_SENTENCES, silenceFeedback);
            for (const t of trailingParts) { ui.push(t); parts.push({ type: 'tool-feedbackPrompt', toolCallId: `server-${Date.now()}`, state: 'output-available', input: {}, output: t }); }
            // plan_snapshot: the draft after this turn, so an edit-rewind can restore it (plan Phase 6.1)
            const planSnapshot = scope ? await snapshotPlan(v, scope) : null;
            const firstText = (parts.find((p) => (p as { type: string }).type === 'text') as { text?: string } | undefined)?.text;
            const { error } = await v.db.from('vana_messages').insert({ conversation_id: convId, user_id: v.userId, role: 'assistant', content: firstText ?? (parts.length ? '' : clampSentences(text)), parts, metadata: { ui_parts: ui, tool_calls: steps.flatMap((s) => (s.toolCalls ?? []).map((c) => c.toolName)), duration_ms: Date.now() - started, opener, opener_variant: opener ? openerVariant : undefined, new_plan: newPlan || undefined, kind: convKind, plan_snapshot: planSnapshot ?? undefined } });
            if (error) console.error(`${tag} assistant message persist error:`, error.message);
            await touch(v, convId, opener ? (general ? 'Quick question' : "This week's plan") : undefined);
          }
          // The reservation IS this call's row; its tokens land on it. Only a reservation the log could not write
          // (the limiter failed open) needs a row of its own.
          const functionName = `${bucket}.${convKind}`;
          // The plan and trial state as they stood at the call, read here and not on the athlete's path: this task
          // already runs after the response (mp-285 leaves `user_entitlements` the only place to ask).
          const sub = await subscriberState(v.admin, v.userId);
          const cost = { ...metrics, debited: opts.debited === true, inputMode, subscriberPeriodType: sub.periodType, subscriberActiveUntil: sub.activeUntil };
          if (callId) await completeCall(v.admin, callId, { inputTokens, outputTokens, functionName, conversationId: convId || null, ...cost });
          else await logCall(v.admin, { userId: v.userId, conversationId: convId || null, functionName, model: CHAT_MODEL, inputTokens, outputTokens, ...cost });
          // `ai_usage.cost_usd` exists for exactly this and was never filled from chat; the gateway's charge goes in both logs.
          await logAiUsage(v.admin, { userId: v.userId, functionName: opts.functionName, model: CHAT_MODEL, inputTokens, outputTokens, costUsd: metrics.gatewayCostUsd ?? null });
          await opts.afterFinish?.({ inputTokens, outputTokens });
          console.log(`${tag} onFinish user=${v.userId} conv=${convId || '(ephemeral)'} in=${inputTokens} cache_read=${cacheRead} out=${outputTokens} steps=${steps.length} ${Date.now() - started}ms`);
        } catch (e) { console.error(`${tag} onFinish task failed:`, (e as Error).message); }
      })();
      waitUntil(task);
    },
  });
  const headers = ndjsonHeaders({ 'x-conversation-id': convId, 'x-vana-kind': convKind });
  return { ok: true, response: new Response(ndjsonFromFullStream(result.fullStream, { tag, trailingParts, silenceAfterFeedback: silenceFeedback }), { status: 200, headers }) };
}
