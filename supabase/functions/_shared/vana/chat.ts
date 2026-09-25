/** Chat orchestration shared by `vana-chat` and the `jade-chat` alias:
 *  rate limit → context → conversation → tools → user-row persist → streamText → NDJSON, with the assistant row,
 *  `vana_calls` and `ai_usage` written from onFinish under EdgeRuntime.waitUntil.
 *  Cost posture: Haiku by default, ≤6 steps, ≤900 output tokens, ~250-token context block, and the model is sent only what it
 *  reads (mp-471): every tool has a compact model-facing form that the replay uses too (tools.ts modelView), the assistant row
 *  stores each part once, and a turn ends on the step that asked a choice, handed off or filed feedback silently.
 *  The repeated prefix is cached (mp-276, mp-420 clauses 4 and 5): the prompt order is fixed (tools, persona, context,
 *  messages); the persona and the context are two system messages with their own cache markers, so a context rebuild
 *  (every plan write) keeps the tools and persona readable; the tail rides on Anthropic's automatic cache_control; the
 *  call is pinned to Anthropic and carries the conversation as its session; the context block is built once per
 *  conversation and reused (context-cache.ts); a stored conversation replays as the bytes first sent (the screen line
 *  and the opener's hidden first message are stored with the transcript); and the cache-read token count is logged
 *  per call so a zero is visible.
 *  Brevity is a prompt rule (persona.ts VOICE registers), not a server trim: a clamp only cuts text after it was paid for.
 *  The only server cut is a generous runaway guard so a looping turn never floods the transcript (Lee, 2026-09-03). */
import { streamText, convertToModelMessages, stepCountIs, hasToolCall, type UIMessage, type ModelMessage, type SystemModelMessage } from 'npm:ai@6.0.277';
import { CHAT_MODEL, localDate, waitUntil } from './env.ts';
import type { VanaCtx } from './env.ts';
import { buildAthleteContext, contextBlock } from './context.ts';
import { cachedContext } from './context-cache.ts';
import { makeVanaTools } from './tools.ts';
import { PLANNING_PROMPT, GENERAL_PROMPT, OPENERS, NEW_PLAN_OPENER, NEW_PLAN_STANDING, checkinOpener, debriefOpener } from './persona.ts';
import { completeCall, reserveCall } from './rate-limit.ts';
import { readSummaries, writeSummary, writeOnIdle, defaultExtractDeps, defaultSummaryDeps, type ExtractDeps, type StoredSummary, type SummaryDeps } from './extract.ts';
import { inViewSection, resolveSituation, SITUATION_MARK, type Situation } from './situation.ts';
import { asInputMode, callMetrics, logCall, type InputMode } from './log.ts';
import { subscriberState } from './subscriber.ts';
import { logAiUsage } from '../ai/usage.ts';
import type { VanaPart, AthleteContext, ConversationSummary, ConversationPlan, ConversationKind } from './contracts.ts';
import { getConversationPlan, getPlan, snapshotPlan } from './plan.ts';
import { addDays, weekStartFor } from './env.ts';
import { pickOpener, pendingDebrief, NEW_PLAN_SITUATION, OPENER_REPLAY_ID_PREFIX, type OpenerVariant } from './opener.ts';
import { getPlanPeriod } from './memory.ts';
import { generalOpener, type GeneralOpenerVariant } from './moment.ts';
import type { MealPlan } from './contracts.ts';
import { ndjsonFromFullStream, ndjsonHeaders, cacheReadTokens } from './stream.ts';

/** Anthropic's automatic prompt caching, through the gateway: a top-level `cache_control` the API places on the last
 *  cacheable block and moves forward as the conversation grows (mp-276 clause 1). With the prefix stable — tools,
 *  persona, context, then the history — every turn after the first reads the one before it. It marks ONE block, so
 *  on its own a context rebuild threw the tools and persona away with the context (the 09-20 audit: 43% read on a
 *  planning turn; the ticket 07 probe: 0% on every rebuilt turn). The two system messages below carry the other two
 *  markers; this one stays for the tail. */
export const CACHE_PROVIDER_OPTIONS = { anthropic: { cacheControl: { type: 'ephemeral' as const } } };
/** The persona's cache lifetime (mp-420 clause 4; the research put the saving at low traffic on the shared prefix). One
 *  hour costs twice the input price to write against 1.25× for five minutes, and is refreshed free on every read. It
 *  must sit before the five-minute markers, which it does: the persona is the first block after the tools. Null turns
 *  it off without changing the shape. The dev probe (ticket 07) is where "does the setting survive the gateway" is read:
 *  Anthropic's usage reports `cache_creation.ephemeral_1h_input_tokens` and the gateway hands it back as it is. */
export const PERSONA_CACHE_TTL: '1h' | null = '1h';
/** What every chat call carries: the automatic marker for the tail, and the gateway pinned to Anthropic itself
 *  (`only`). The gateway's routing plan lists Bedrock and Vertex as live fallbacks for the same model id, and a request
 *  it moved there cannot read a cache written at Anthropic — the athlete would pay a cold prefix for a provider hiccup
 *  we never asked for. Pinned, an Anthropic outage is a refused call (`ai_unavailable`), which is the honest answer. */
export const chatProviderOptions = () => ({ ...CACHE_PROVIDER_OPTIONS, gateway: { only: ['anthropic'] } });
/** The session header a chat call carries: one id per conversation, so the gateway can keep a conversation's requests
 *  together. The gateway reports nothing back about it (the ticket 07 probe found no echo), so this is asked for and
 *  not proven; the provider pin above is what the cache actually rests on. An ephemeral turn has no conversation. */
export const chatHeaders = (conversationId: string): Record<string, string> => (conversationId ? { 'x-session-affinity': conversationId } : {});

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
/** The tools whose call is the end of what Vana has to say (mp-471): a question asked, a hand-off offered, feedback
 *  filed. After any tool call the SDK runs the model again over the whole prompt; after one of these that step wrote
 *  nothing on 94 of 94 dev turns (the 09-20 audit, B1) — every opener paid for it. The picker is NOT one: the persona
 *  writes its two sentences after suggestMeals, in the step that follows. */
export const TERMINAL_TOOLS = ['askChoice', 'handOff', 'saveFeedback'] as const;
const isTerminal = (name: string | undefined) => (TERMINAL_TOOLS as readonly string[]).includes(name ?? '');
/** What stops a turn: its step limit, its token ceiling, a question asked, a hand-off, and — when the message was a
 *  pure vent, so the reply is the content-managed row alone — feedback filed. A complaint that also asks something keeps
 *  its answering step (silenceAfterFeedback). Each is the pinned SDK's own condition; any one ends the loop, and the
 *  step's tools have already run. `hasToolCall` reads the LAST step only, so setSetting-then-askChoice stops on the fork. */
export const chatStopWhen = (general: boolean, silenceFeedback = false) => [
  stepCountIs(general ? 8 : 6), tokenBudgetIs(TURN_TOKEN_CEILING),
  hasToolCall('askChoice'), hasToolCall('handOff'), ...(silenceFeedback ? [hasToolCall('saveFeedback')] : []),
];
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
/** The user's conversations, most recent activity first. `offset` is the page start (ticket 126, 88-021): the app asks for
 *  the next page when its list nears the end, and an empty page says the list is done. */
export async function listConversations(v: VanaCtx, limit = 30, kind?: ConversationKind, offset = 0): Promise<ConversationSummary[]> {
  let q = v.db.from('vana_conversations').select('id, kind, title, summary, last_message_at, created_at').eq('user_id', v.userId).eq('is_deleted', false);
  if (kind) q = q.eq('kind', kind);
  const { data } = await q.order('last_message_at', { ascending: false, nullsFirst: false }).order('created_at', { ascending: false }).range(offset, offset + limit - 1);
  // deno-lint-ignore no-explicit-any
  const rows: Omit<ConversationSummary, 'plan'>[] = (data ?? []).map((r: any) => ({ id: r.id, kind: r.kind === 'general' ? 'general' : 'meal_planning', title: r.title, summary: r.summary, lastMessageAt: r.last_message_at, createdAt: r.created_at }));
  const plans = await conversationPlans(v, rows.filter((r) => r.kind === 'meal_planning').map((r) => r.id));
  return rows.map((r) => ({ ...r, plan: plans.get(r.id) ?? null }));
}
/** The plan each planning conversation holds (`ConversationPlan`): the app titles the row by its week and state
 *  (testing-wave 97, 16-006 / 18-007). A conversation can hold several (`startNewPlan` archives one and opens another):
 *  the confirmed one wins, else the newest that has meals, else the newest. One read for the whole list. */
async function conversationPlans(v: VanaCtx, conversationIds: string[]): Promise<Map<string, ConversationPlan>> {
  const out = new Map<string, ConversationPlan>();
  if (conversationIds.length === 0) return out;
  const { data, error } = await v.db.from('meal_plans').select('conversation_id, week_start, status, updated_at, created_at, plan_meals(count)')
    .eq('user_id', v.userId).eq('is_deleted', false).in('conversation_id', conversationIds);
  if (error) { console.error('[vana] conversationPlans:', error.message); return out; }
  type Row = { conversation_id: string; week_start: string; status: MealPlan['status']; updated_at: string; created_at: string; plan_meals: { count: number }[] | null };
  const rows = ((data ?? []) as Row[]).map((r) => ({ ...r, mealCount: r.plan_meals?.[0]?.count ?? 0 }));
  const later = (a: string, b: string) => (a > b ? -1 : a < b ? 1 : 0);
  rows.sort((a, b) =>
    (a.status === 'confirmed' ? 0 : 1) - (b.status === 'confirmed' ? 0 : 1) ||
    (a.mealCount > 0 ? 0 : 1) - (b.mealCount > 0 ? 0 : 1) ||
    later(a.updated_at, b.updated_at) || later(a.created_at, b.created_at));
  for (const r of rows) if (!out.has(r.conversation_id)) out.set(r.conversation_id, { weekStart: r.week_start, status: r.status, mealCount: r.mealCount });
  return out;
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
/** A user message as the model first read it: the text, then the screen line that rode on it (mp-420 clause 5). The
 *  line is a text part of its own, which is the shape `withSituation` gives the newest message, so the stored turn and
 *  the sent turn are the same bytes. A row from before the line was stored has one part, as it always did. */
const userReplay = (id: string, text: string, situation: unknown): UIMessage =>
  ({ id, role: 'user', parts: [{ type: 'text', text }, ...(typeof situation === 'string' && situation ? [{ type: 'text', text: situation }] : [])] } as UIMessage);
/** Stored rows → UIMessage[] (parts column preferred; legacy content + metadata.ui_parts otherwise).
 *  The opener's hidden first message is not a row — the app would draw it — but the opener's assistant row carries it
 *  (`metadata.opener_prompt`, with the screen line under `metadata.situation`), and it comes back here in front of
 *  that row, so the next turn replays the conversation exactly as the opener sent it (mp-420 clause 5). */
export async function conversationMessages(v: VanaCtx, conversationId: string): Promise<{ kind: ConversationKind; messages: UIMessage[] }> {
  const [{ data }, kind] = await Promise.all([v.db.from('vana_messages').select('id, role, content, metadata, parts, created_at').eq('conversation_id', conversationId).eq('user_id', v.userId).order('created_at'), conversationKind(v, conversationId)]);
  // deno-lint-ignore no-explicit-any
  const messages = (data ?? []).flatMap((r: any): UIMessage[] => {
    if (r.role === 'user') return [userReplay(r.id, r.content ?? '', r.metadata?.situation)];
    const openerPrompt = typeof r.metadata?.opener_prompt === 'string' && r.metadata.opener_prompt ? [userReplay(`${OPENER_REPLAY_ID_PREFIX}${r.id}`, r.metadata.opener_prompt, r.metadata?.situation)] : [];
    if (Array.isArray(r.parts) && r.parts.length) return [...openerPrompt, { id: r.id, role: 'assistant', parts: r.parts } as UIMessage];
    const ui = (r.metadata?.ui_parts ?? []) as VanaPart[];
    const parts: unknown[] = [];
    if (r.content) parts.push({ type: 'text', text: r.content });
    ui.forEach((p, i) => parts.push({ type: 'tool-legacy', toolCallId: `${r.id}:${i}`, state: 'output-available', input: {}, output: p }));
    return [...openerPrompt, { id: r.id, role: 'assistant', parts } as UIMessage];
  });
  return { kind, messages };
}
/** The opener's hidden first message, as the model reads it: a user message whose text is the scripted instruction.
 *  Built as a UI message and sent through the same conversion as a stored turn, so the first send and every replay
 *  are one path (mp-420 clause 5). */
export const openerMessage = (text: string): UIMessage => ({ id: 'opener', role: 'user', parts: [{ type: 'text', text }] } as UIMessage);
/** The user row for a turn. The screen line is stored beside the text (`metadata.situation`), never inside it: the app
 *  reads `content` and draws that alone, and the model reads both (userReplay). */
export function userMessageRow(i: { conversationId: string; userId: string; text: string; parts: unknown[]; situation: string | null }) {
  return { conversation_id: i.conversationId, user_id: i.userId, role: 'user' as const, content: i.text, parts: i.parts, metadata: i.situation ? { situation: i.situation } : null };
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
    // A step whose only tools are terminal (askChoice, handOff, saveFeedback) is not narrating: its text is what the question or
    // the hand-off is about (a moment's opener names the session there), the stream already showed it, and the turn ends on it.
    const calls = (s.toolCalls ?? []) as { toolName?: string }[];
    const asking = calls.length > 0 && calls.every((c) => isTerminal(c.toolName));
    const narration = maxSentences == null && calls.length > 0 && !asking && String(s.text ?? '').length < 160;
    // A silenced feedback turn keeps no prose at all — not after the row, and not the step that filed it either.
    const filing = silenceFeedback && calls.some((c) => c.toolName === 'saveFeedback');
    const t = narration || filing || (filed && silenceFeedback) ? '' : clamp(String(s.text ?? '')); if (t) { parts.push({ type: 'text', text: t }); anyText = true; }
    for (const r of s.toolResults ?? []) {
      const out = (r as { output?: unknown; toolName?: string; toolCallId?: string; input?: unknown }).output;
      if (out && typeof out === 'object' && 'kind' in (out as object)) { if ((out as { kind?: string }).kind === 'feedback_saved') filed = true; ui.push(out as VanaPart); parts.push({ type: `tool-${(r as { toolName: string }).toolName}`, toolCallId: (r as { toolCallId?: string }).toolCallId ?? `${Date.now()}`, state: 'output-available', input: (r as { input?: unknown }).input ?? {}, output: out }); }
    }
  }
  if (!anyText && text.trim() && !(filed && silenceFeedback)) parts.unshift({ type: 'text', text: clamp(text) });
  return { parts, ui };
}
/** The assistant row for a finished turn. The tool outputs live in `parts` and nowhere else: `metadata.ui_parts` used to
 *  hold every UI part a second time (a picker row was 24 KB on disk and 82,000 characters over PostgREST — the 09-20
 *  audit, F3), and no reader takes it once `parts` exists (conversationMessages and the app's fetchMessages read `parts`
 *  first). `content` keeps the first text block so a legacy reader still has a line. */
/** `openerPrompt` / `situation`: on an opener, the hidden first message and the screen line it carried, stored on this
 *  row so the next turn replays them (conversationMessages). The app reads neither key. */
// deno-lint-ignore no-explicit-any
export function assistantMessageRow(i: { conversationId: string; userId: string; text: string; parts: unknown[]; steps: any[]; started: number; opener: boolean; openerVariant: string; newPlan: boolean; kind: ConversationKind; planSnapshot: unknown | null; openerPrompt?: string | null; situation?: string | null }) {
  const firstText = (i.parts.find((p) => (p as { type: string }).type === 'text') as { text?: string } | undefined)?.text;
  return {
    conversation_id: i.conversationId, user_id: i.userId, role: 'assistant' as const,
    content: firstText ?? (i.parts.length ? '' : clampSentences(i.text)),
    parts: i.parts,
    metadata: { tool_calls: i.steps.flatMap((s) => (s.toolCalls ?? []).map((c: { toolName: string }) => c.toolName)), duration_ms: Date.now() - i.started, opener: i.opener, opener_variant: i.opener ? i.openerVariant : undefined, new_plan: i.newPlan || undefined, kind: i.kind, plan_snapshot: i.planSnapshot ?? undefined,
      opener_prompt: i.opener && i.openerPrompt ? i.openerPrompt : undefined, situation: i.opener && i.situation ? i.situation : undefined },
  };
}
/** The stored history as the model reads it: the same conversion the first send used, with the tools passed so every
 *  stored tool part is replayed through its `toModelOutput` — the compact form, not the part the app drew (mp-471).
 *  Without the tools the SDK replays the stored output whole, and a picker's 24-meal tail rides on every later turn. */
export function replayModelMessages(messages: UIMessage[], tools: Parameters<typeof convertToModelMessages>[1] extends { tools?: infer T } | undefined ? T : never): Promise<ModelMessage[]> {
  return convertToModelMessages(messages, { tools });
}
/** The day's name, so "Saturday" in a past conversation can be read against today without date arithmetic. */
const weekdayOf = (iso: string) => ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][new Date(`${iso}T12:00:00Z`).getUTCDay()];
/** Both kinds get the same block (the Voodoo Doll, 2026-09-09). Only the prompt above it differs.
 *  Before this, general mode carried a first name and a date, and everything else had to be fetched
 *  by a tool call the model might not make.
 *  Order is fixed and stable within a day: persona, then the context (the API renders tools before this
 *  system text, and the messages after it). Nothing per-message goes in here — the Situation rides on the
 *  user message (`withSituation`) — or the cached prefix would break on every turn (mp-276 clause 3).
 *  Two system messages, not one (mp-420 clause 4): the persona is the same bytes for every athlete and every turn,
 *  the context changes on a plan write or a new day. With a marker on each, a rebuild misses only the context and
 *  the messages after it; the tools and persona in front of it (about 12,000 tokens) are read from the cache. The
 *  standing extra (NEW PLAN, DEBRIEF PENDING) belongs to the context message, since it changes when the context does. */
export function systemMessages(kind: ConversationKind, ctx: AthleteContext, todayIso: string, extra = '', personaTtl: '1h' | null = PERSONA_CACHE_TTL): SystemModelMessage[] {
  return [
    { role: 'system', content: promptFor(kind), providerOptions: { anthropic: { cacheControl: personaTtl ? { type: 'ephemeral', ttl: personaTtl } : { type: 'ephemeral' } } } },
    { role: 'system', content: `--- CONTEXT (today ${todayIso}, ${weekdayOf(todayIso)}) ---\n${contextBlock(ctx)}${extra}`, providerOptions: { anthropic: { cacheControl: { type: 'ephemeral' } } } },
  ];
}
/** The two system messages as one string, in order — what the tests that read the prompt as text look at. */
export const systemPrompt = (kind: ConversationKind, ctx: AthleteContext, todayIso: string, extra = '') =>
  systemMessages(kind, ctx, todayIso, extra).map((m) => m.content).join('\n');

/** The marked line the Situation becomes on the message, with the in-view section (mp-273 clause 2) under it. Null
 *  when there is no situation. This exact string is what a user row stores (`userMessageRow`) and what the opener's
 *  row keeps, so a replay carries the line the model first read. */
export const situationNote = (situation: string | null | undefined, section?: string | null): string | null =>
  situation ? `${SITUATION_MARK}${situation}]${section ? `\n${section}` : ''}` : null;
/** The Situation (which screen they are on) travels with the message, so it is appended to the last user turn as a
 *  marked line, not written into the system prompt: the prefix stays byte-identical across turns and only the newest
 *  message carries what changes per message. Stored with that message's row, it replays on every later turn as sent. */
export function withSituation<M extends { role: string; content: unknown }>(messages: M[], situation: string | null | undefined, section?: string | null): M[] {
  const note = situationNote(situation, section);
  if (!note) return messages;
  const i = messages.map((m) => m.role).lastIndexOf('user');
  if (i < 0) return messages;
  const m = messages[i];
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
  /** Runs inside the onFinish persistence task after the usage rows are written, with what the turn cost in the shape the
   *  budget settles from (mp-436): the tokens both ways, the cache both directions, the gateway's own charge, the model. */
  afterFinish?: (usage: FinishedUsage) => Promise<void>;
  /** Runs when the stream fails before it finished: the turn's reservation comes back (mp-436, ticket 09). */
  onFailure?: (error: unknown) => Promise<void>;
  /** Whether this turn draws the athlete's budget (mp-420 clause 6) — recorded on the call row so "what did the budget
   *  actually pay for" is answerable. Since ticket 09 every turn does, the scripted opener included (mp-430 clause 1). */
  debited?: boolean;
  /** Receives the turn's full trace when it finishes, or its error when the stream failed. The evals harness
   *  (`supabase/functions/evals/vana/`) is the only caller; production leaves it unset. */
  onTrace?: (t: TurnTrace) => void;
}
/** What a finished turn cost, as handed to `afterFinish`. */
export interface FinishedUsage { inputTokens: number; outputTokens: number; cacheReadTokens: number | null; cacheWriteTokens: number | null; gatewayCostUsd: number | null; model: string }
/** One finished (or failed) turn as the evals harness stores it: everything the prompt was built from — persona, Doll,
 *  situation, the exact model message array, the tools offered — and everything that came back (steps with their raw
 *  pre-clamp text and tool inputs/outputs, usage). Built at the only seam where both exist. Production never passes
 *  `onTrace`, so this costs nothing there; when real-trace sampling is added later it can reuse the same payload. */
export interface TurnTrace {
  kind: ConversationKind; opener: boolean; openerVariant: string; newPlan: boolean;
  functionName: string; model: string; anchorDate: string;
  situation: string | null; inView: string | null; openerText: string | null;
  doll: AthleteContext; contextReused: boolean;
  system: { persona: string; context: string };
  tools: string[]; modelMessages: ModelMessage[];
  durationMs: number;
  text: string; steps: unknown[]; usage: unknown; totalUsage: unknown;
  error?: string;
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
  // The screen line this turn carries, stored with the row it rides on (mp-420 clause 5).
  const note = situationNote(situation, inView);
  if (last && !opener && persist) { await v.db.from('vana_messages').insert(userMessageRow({ conversationId: convId, userId: v.userId, text: lastText, parts: last.parts, situation: note })); await touch(v, convId, lastText); }
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
  // The opener's first message goes through the same conversion a stored turn does, so its replay is the same bytes.
  const replayed = opener ? [openerMessage(openerText)] : await replayHistory(v, convId, messages);
  const modelMessages = withSituation(await replayModelMessages(replayed, tools), situation, inView);
  const general = convKind === 'general';
  const tag = `[${opts.functionName}]`;
  console.log(`${tag} user=${v.userId} conv=${convId || '(ephemeral)'} kind=${convKind} opener=${opener}${opener ? `/${openerVariant}${newPlan ? '/new_plan' : ''}` : ''} model=${CHAT_MODEL} context=${reused ? 'reused' : 'built'}`);

  const system = systemMessages(convKind, ctx, anchorDate, extraContext);
  const result = streamText({
    model: CHAT_MODEL,
    system,
    messages: modelMessages,
    tools,
    maxOutputTokens: MAX_OUTPUT_TOKENS,
    // deno-lint-ignore no-explicit-any
    stopWhen: chatStopWhen(general, silenceFeedback) as any,
    providerOptions: chatProviderOptions(),
    headers: chatHeaders(convId),
    // A stream that fails is a call the athlete did not get: its reservation goes back. The hold settles once, so an
    // onFinish that follows an error changes nothing.
    onError: ({ error }) => { console.error(`${tag} stream error:`, (error as Error)?.message ?? error); opts.onTrace?.({ kind: convKind, opener, openerVariant, newPlan, functionName: opts.functionName, model: CHAT_MODEL, anchorDate, situation: note, inView, openerText: opener ? openerText : null, doll: ctx, contextReused: reused, system: { persona: String(system[0].content), context: String(system[1].content) }, tools: Object.keys(tools), modelMessages, durationMs: Date.now() - started, text: '', steps: [], usage: null, totalUsage: null, error: String((error as Error)?.message ?? error) }); if (opts.onFailure) waitUntil(opts.onFailure(error).catch((e) => console.error(`${tag} onFailure threw:`, (e as Error).message))); },
    onFinish: ({ text, steps, usage, totalUsage }) => {
      const u = totalUsage ?? usage;
      const inputTokens = u?.inputTokens ?? 0; const outputTokens = u?.outputTokens ?? 0;
      const cacheRead = cacheReadTokens(u) ?? 0;
      // What the turn cost us, out of what the SDK handed back: the cache both directions, the steps, the FIRST step's
      // prompt (the only one that can read the shared prefix from cache) and the gateway's own charge (mp-420 clause 6).
      const metrics = callMetrics(steps as unknown[], u);
      // Called before the persistence task so a harness sees the trace the moment the stream ends; the rows it also
      // waits on are written by the task below (its inserts land on the harness's fake db).
      opts.onTrace?.({ kind: convKind, opener, openerVariant, newPlan, functionName: opts.functionName, model: CHAT_MODEL, anchorDate, situation: note, inView, openerText: opener ? openerText : null, doll: ctx, contextReused: reused, system: { persona: String(system[0].content), context: String(system[1].content) }, tools: Object.keys(tools), modelMessages, durationMs: Date.now() - started, text, steps: steps as unknown[], usage, totalUsage });
      const task = (async () => {
        try {
          if (persist) {
            const { parts } = partsFromSteps(text, steps as unknown[], general ? null : RUNAWAY_SENTENCES, silenceFeedback);
            for (const t of trailingParts) parts.push({ type: 'tool-feedbackPrompt', toolCallId: `server-${Date.now()}`, state: 'output-available', input: {}, output: t });
            // plan_snapshot: the draft after this turn, so an edit-rewind can restore it (plan Phase 6.1)
            const planSnapshot = scope ? await snapshotPlan(v, scope) : null;
            const { error } = await v.db.from('vana_messages').insert(assistantMessageRow({ conversationId: convId, userId: v.userId, text, parts, steps: steps as unknown[], started, opener, openerVariant, newPlan, kind: convKind, planSnapshot, openerPrompt: opener ? openerText : null, situation: note }));
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
          await opts.afterFinish?.({ inputTokens, outputTokens, cacheReadTokens: metrics.cacheReadTokens ?? null, cacheWriteTokens: metrics.cacheWriteTokens ?? null, gatewayCostUsd: metrics.gatewayCostUsd ?? null, model: CHAT_MODEL });
          console.log(`${tag} onFinish user=${v.userId} conv=${convId || '(ephemeral)'} in=${inputTokens} cache_read=${cacheRead} out=${outputTokens} steps=${steps.length} ${Date.now() - started}ms`);
        } catch (e) { console.error(`${tag} onFinish task failed:`, (e as Error).message); }
      })();
      waitUntil(task);
    },
  });
  const headers = ndjsonHeaders({ 'x-conversation-id': convId, 'x-vana-kind': convKind });
  return { ok: true, response: new Response(ndjsonFromFullStream(result.fullStream, { tag, trailingParts, silenceAfterFeedback: silenceFeedback }), { status: 200, headers }) };
}
