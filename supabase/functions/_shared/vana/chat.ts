/** Chat orchestration shared by `vana-chat` and the `jade-chat` alias:
 *  rate limit → context → conversation → tools → user-row persist → streamText → NDJSON, with the assistant row,
 *  `vana_calls` and `ai_usage` written from onFinish under EdgeRuntime.waitUntil.
 *  Cost posture: Haiku by default, ≤6 steps, ≤400 output tokens, ~250-token context block, compact tool outputs. */
import { streamText, convertToModelMessages, stepCountIs, type UIMessage } from 'npm:ai@6';
import { CHAT_MODEL, localDate, waitUntil } from './env.ts';
import type { VanaCtx } from './env.ts';
import { buildAthleteContext, contextBlock } from './context.ts';
import { makeVanaTools } from './tools.ts';
import { PLANNING_PROMPT, GENERAL_PROMPT, OPENERS } from './persona.ts';
import { checkRateLimit } from './rate-limit.ts';
import { logCall } from './log.ts';
import { logAiUsage } from '../ai/usage.ts';
import type { VanaPart, AthleteContext, ConversationSummary, ConversationKind } from './contracts.ts';
import { getConversationPlan } from './plan.ts';
import { ndjsonFromFullStream, ndjsonHeaders } from './stream.ts';

const MAX_OUTPUT_TOKENS = 400;
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

/** ≤2 sentences per text block — enforced here so Haiku overruns never reach the transcript. */
export function clampSentences(t: string, n = 2): string {
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
// deno-lint-ignore no-explicit-any
function partsFromSteps(text: string, steps: any[], maxSentences: number | null = 2): { parts: unknown[]; ui: VanaPart[] } {
  const parts: unknown[] = []; const ui: VanaPart[] = [];
  // interleave: each step's text (clamped) then its UI tool outputs, so the transcript reads in order
  let anyText = false;
  const clamp = (t: string) => (maxSentences == null ? t.replace(/\s+/g, ' ').trim() : clampSentences(t, maxSentences));
  for (const s of steps) {
    // Unclamped (general) mode: drop the model's pre-tool narration ("I'll pull up your plan.") — only the step that answers keeps its text.
    const narration = maxSentences == null && (s.toolCalls?.length ?? 0) > 0 && String(s.text ?? '').length < 160;
    const t = narration ? '' : clamp(String(s.text ?? '')); if (t) { parts.push({ type: 'text', text: t }); anyText = true; }
    for (const r of s.toolResults ?? []) {
      const out = (r as { output?: unknown; toolName?: string; toolCallId?: string; input?: unknown }).output;
      if (out && typeof out === 'object' && 'kind' in (out as object)) { ui.push(out as VanaPart); parts.push({ type: `tool-${(r as { toolName: string }).toolName}`, toolCallId: (r as { toolCallId?: string }).toolCallId ?? `${Date.now()}`, state: 'output-available', input: (r as { input?: unknown }).input ?? {}, output: out }); }
    }
  }
  if (!anyText && text.trim()) parts.unshift({ type: 'text', text: clamp(text) });
  return { parts, ui };
}
/** Planning gets the full athlete context block; general gets only name + date and fetches everything else through tools. */
const system = (kind: ConversationKind, ctx: AthleteContext, todayIso: string) => kind === 'general'
  ? `${promptFor(kind)}\n--- today ${todayIso} · athlete: ${ctx.profile.firstName ?? 'the athlete'} ---`
  : `${promptFor(kind)}\n--- CONTEXT (today ${todayIso}) ---\n${contextBlock(ctx)}`;

// ---------------------------------------------------------------- chat
/** Request body per 02-contract §5. */
export interface ChatBody { message?: string; conversation_id?: string | null; kind?: ConversationKind | string; timezone?: string; opener?: boolean; anchor_date?: string }
export interface ChatRunOpts {
  /** `ai_usage.function_name` / log tag: 'vana-chat' | 'jade-chat'. */
  functionName: string;
  /** false = ephemeral turn: no conversation row, nothing written (the legacy jade-chat opener). Default true. */
  persist?: boolean;
  /** Runs inside the onFinish persistence task after the usage rows are written (jade-chat's credit debit). */
  afterFinish?: (usage: { inputTokens: number; outputTokens: number }) => Promise<void>;
}
export type ChatOutcome = { ok: true; response: Response } | { ok: false; status: 400 | 429; body: Record<string, unknown> };

export async function runChat(v: VanaCtx, body: ChatBody, opts: ChatRunOpts): Promise<ChatOutcome> {
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

  const rl = await checkRateLimit(v.admin, v.userId, 'vana.chat');
  if (!rl.allowed) return { ok: false, status: 429, body: { error: 'rate_limited', retry_after_seconds: rl.retryAfterSeconds ?? 10, retryAfterSeconds: rl.retryAfterSeconds ?? 10 } };

  const opener = messages.length === 0;
  const last = [...messages].reverse().find((m) => m.role === 'user');
  const lastText = last ? textOf(last) : '';
  const [ctx, conv] = await Promise.all([
    buildAthleteContext(v, lastText || undefined, anchorDate),
    persist ? ensureConversation(v, body.conversation_id ?? null, kind) : Promise.resolve({ id: '', kind }),
  ]);
  const convId = conv.id; const convKind = conv.kind;
  // Planning writes land on this conversation's own draft; the context's PLAN line describes that draft, not the Plan tab's plan.
  const scope = convKind === 'meal_planning' && convId ? { conversationId: convId } : null;
  if (scope) { const draft = await getConversationPlan(v, convId, false); ctx.plan = { exists: !!draft && draft.meals.length > 0, status: draft?.status ?? 'draft', mealsLeft: draft ? draft.meals.reduce((s, m) => s + m.servingsLeft, 0) : 0, batchCooking: draft?.batchCooking ?? ctx.plan.batchCooking }; }
  const tools = makeVanaTools(v, ctx, convKind, { scope, shownIds: shownMealIds(messages) });
  const started = Date.now();
  if (last && !opener && persist) { await v.db.from('vana_messages').insert({ conversation_id: convId, user_id: v.userId, role: 'user', content: lastText, parts: last.parts }); await touch(v, convId, lastText); }
  const modelMessages = opener ? [{ role: 'user' as const, content: OPENERS[convKind] }] : await convertToModelMessages(messages);
  const general = convKind === 'general';
  const tag = `[${opts.functionName}]`;
  console.log(`${tag} user=${v.userId} conv=${convId || '(ephemeral)'} kind=${convKind} opener=${opener} model=${CHAT_MODEL}`);

  const result = streamText({
    model: CHAT_MODEL,
    system: system(convKind, ctx, anchorDate),
    messages: modelMessages,
    tools,
    maxOutputTokens: general ? 700 : MAX_OUTPUT_TOKENS,
    stopWhen: stepCountIs(general ? 8 : 6),
    onFinish: ({ text, steps, usage, totalUsage }) => {
      const u = totalUsage ?? usage;
      const inputTokens = u?.inputTokens ?? 0; const outputTokens = u?.outputTokens ?? 0;
      const task = (async () => {
        try {
          if (persist) {
            const { parts, ui } = partsFromSteps(text, steps as unknown[], general ? null : 2);
            const { error } = await v.db.from('vana_messages').insert({ conversation_id: convId, user_id: v.userId, role: 'assistant', content: (parts.find((p) => (p as { type: string }).type === 'text') as { text?: string } | undefined)?.text ?? clampSentences(text), parts, metadata: { ui_parts: ui, tool_calls: steps.flatMap((s) => (s.toolCalls ?? []).map((c) => c.toolName)), duration_ms: Date.now() - started, opener, kind: convKind } });
            if (error) console.error(`${tag} assistant message persist error:`, error.message);
            await touch(v, convId, opener ? (general ? 'Quick question' : "This week's plan") : undefined);
          }
          await logCall(v.admin, { userId: v.userId, conversationId: convId || null, functionName: opener ? `vana.opener.${convKind}` : `vana.chat.${convKind}`, model: CHAT_MODEL, inputTokens, outputTokens });
          await logAiUsage(v.admin, { userId: v.userId, functionName: opts.functionName, model: CHAT_MODEL, inputTokens, outputTokens });
          await opts.afterFinish?.({ inputTokens, outputTokens });
          console.log(`${tag} onFinish user=${v.userId} conv=${convId || '(ephemeral)'} in=${inputTokens} out=${outputTokens} steps=${steps.length} ${Date.now() - started}ms`);
        } catch (e) { console.error(`${tag} onFinish task failed:`, (e as Error).message); }
      })();
      waitUntil(task);
    },
  });
  const headers = ndjsonHeaders({ 'x-conversation-id': convId, 'x-vana-kind': convKind });
  return { ok: true, response: new Response(ndjsonFromFullStream(result.fullStream, { tag }), { status: 200, headers }) };
}
