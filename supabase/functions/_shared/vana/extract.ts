/**
 * Extraction at idle — the episode, and the margin notes the remember tool missed (mp-024's third writer).
 *
 * There is no scheduler and nothing runs when a conversation opens. The client says when a conversation
 * is idle (the sheet closes, the app goes to the background, a new conversation starts: mp-288), and
 * that conversation is fed to ONE Haiku call with the margin-note rule and a strict schema: zero to
 * three sentences, plus one episode sentence. The sentences go through the deduped writer; the episode
 * is a keyed Memory. `read_back_at` is stamped so a conversation is never extracted twice: a second
 * signal writes nothing. A signal that never arrives (offline) is dropped; the remember tool already
 * wrote that conversation's margin notes in the hot path (mp-277 clause 2).
 *
 * Nothing is announced. Extracted Memories produce no card and no mention — the flat list in Vana
 * settings is the audit trail.
 *
 * The opener's synthetic user message is never stored, so a transcript begins with Vana's own first
 * turn. Nothing here may depend on that message existing.
 *
 * A conversation still in progress is not read back; its history is chunked and the oldest chunk
 * summarised onto the conversation row instead (mp-277 clause 1): see `writeSummary`.
 */
import { generateObject } from 'npm:ai@6.0.277';
import { z } from 'npm:zod@3';
import { TOOL_MODEL } from './env.ts';
import type { VanaCtx } from './env.ts';
import { listMemories, rememberFact } from './memory.ts';
import { logCall } from './log.ts';
import { checkRateLimit } from './rate-limit.ts';

/** Zero to three margin notes, and always exactly one episode sentence. */
export const ExtractionZ = z.object({
  memories: z.array(z.object({
    kind: z.enum(['preference', 'constraint', 'pattern']),
    fact: z.string().min(3).max(200),
  })).max(3),
  episode: z.string().min(3).max(200),
});
export type Extraction = z.infer<typeof ExtractionZ>;

export const EXTRACTOR_SYSTEM = `You read one finished conversation between an endurance athlete and Vana, their nutrition assistant, and write what belongs in the athlete's file.

THE MARGIN-NOTE RULE — this is the whole job. A Memory is one sentence a good dietitian would write in the margin of this athlete's file, and only if it changes how Vana plans for them next time.
- Write: durable things about the person. "Partner is vegetarian." "Wednesdays are chaos — no time to cook." "Hates cilantro." "Cannot stomach gels on the bike." "Cooks for four."
- Do not write: what they asked ("asked about race-week carbs"), this week's plan ("wants 5 dinners", "more carbs Thursday"), anything already in the EXISTING list below, anything Vana said rather than the athlete, or a guess. Say nothing rather than reach.
- One sentence each, present tense, about the athlete, no hedging, no "the user".
Zero memories is the normal outcome. Most conversations contain none.

THE EPISODE — always exactly one sentence, at most 20 words, saying what this conversation was about, so it can stand in for the whole transcript later. "Planned three batch dinners around Saturday's long ride." "Asked what to eat before a hot half marathon."`;

/** What the extractor sees: the stored turns, oldest first. */
export interface TranscriptLine { role: 'user' | 'assistant'; text: string }

export interface ExtractDeps {
  /** The one model call. Injected so a test drives the writer from a fixed extraction. */
  generate: (input: { system: string; prompt: string }) => Promise<{ object: Extraction; inputTokens?: number; outputTokens?: number }>;
}
export const defaultExtractDeps: ExtractDeps = {
  generate: async ({ system, prompt }) => {
    const { object, usage } = await generateObject({ model: TOOL_MODEL, schema: ExtractionZ, maxOutputTokens: 400, system, prompt });
    return { object, inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens };
  },
};

/** A conversation is worth reading back once the athlete actually said something in it. */
const MIN_LINES = 2;

const conversationText = (lines: TranscriptLine[]) => lines.map((l) => `${l.role === 'user' ? 'ATHLETE' : 'VANA'}: ${l.text}`).join('\n');

export function extractionPrompt(lines: TranscriptLine[], existing: string[]): string {
  return [
    `--- EXISTING (already in the file; never repeat these) ---`,
    existing.length ? existing.map((f) => `- ${f}`).join('\n') : '- (nothing yet)',
    `--- CONVERSATION ---`,
    conversationText(lines),
  ].join('\n');
}

/** The stored turns of one conversation, oldest first, text only. */
export async function transcriptOf(v: VanaCtx, conversationId: string): Promise<TranscriptLine[]> {
  const { data } = await v.db.from('vana_messages').select('role, content, parts, created_at')
    .eq('conversation_id', conversationId).eq('user_id', v.userId).order('created_at');
  // deno-lint-ignore no-explicit-any
  return ((data ?? []) as any[]).map((r) => {
    const fromParts = Array.isArray(r.parts) ? r.parts.filter((p: { type?: string }) => p?.type === 'text').map((p: { text?: string }) => p.text ?? '').join(' ') : '';
    const text = String(r.content ?? '').trim() || fromParts.trim();
    return { role: r.role === 'user' ? 'user' as const : 'assistant' as const, text };
  }).filter((l) => l.text);
}

export interface ExtractOutcome { conversationId: string; memories: number; episode: string | null; skipped?: 'already-read' | 'too-short' | 'rate-limited' }

/**
 * Reads one conversation back. Claims it first by stamping `read_back_at`, so two signals racing
 * cannot both pay for the same extraction; on failure the claim is released.
 */
export async function extractConversation(v: VanaCtx, conversationId: string, deps: ExtractDeps = defaultExtractDeps): Promise<ExtractOutcome> {
  const claimed = await claim(v, conversationId);
  if (!claimed) return { conversationId, memories: 0, episode: null, skipped: 'already-read' };
  try {
    const lines = await transcriptOf(v, conversationId);
    // Release it: a conversation opened and abandoned after the opener is one stored line, and if
    // the athlete comes back to it later it must still be readable.
    if (lines.length < MIN_LINES) { await release(v, conversationId); return { conversationId, memories: 0, episode: null, skipped: 'too-short' }; }

    const rl = await checkRateLimit(v.admin, v.userId, 'vana.extract');
    if (!rl.allowed) { await release(v, conversationId); return { conversationId, memories: 0, episode: null, skipped: 'rate-limited' }; }

    const existing = (await listMemories(v, 40)).map((m) => m.fact);
    const started = Date.now();
    const { object, inputTokens, outputTokens } = await deps.generate({ system: EXTRACTOR_SYSTEM, prompt: extractionPrompt(lines, existing) });

    let written = 0;
    for (const m of object.memories.slice(0, 3)) {
      const fact = m.fact.trim();
      if (!fact) continue;
      await rememberFact(v, { kind: m.kind, fact, confidence: 0.7, source: 'conversation', key: null }, undefined, { quiet: true });
      written++;
    }
    const episode = object.episode.trim() || null;
    if (episode) await writeEpisode(v, conversationId, episode);
    await logCall(v.admin, { userId: v.userId, conversationId, functionName: 'vana.extract', model: TOOL_MODEL, inputTokens, outputTokens });
    console.log(`[vana] read back ${conversationId}: ${written} memory(ies) in ${Date.now() - started}ms`);
    return { conversationId, memories: written, episode };
  } catch (e) {
    await release(v, conversationId);   // a transient failure must not cost the conversation its one reading
    console.error('[vana] extraction failed:', (e as Error).message);
    throw e;
  }
}

/** What an idle signal writes (mp-288 clause 3): the conversation's episode and missed notes, once. A
 *  conversation already read back writes nothing. Never throws — it runs in the background of a
 *  request nobody waits on. */
export async function writeOnIdle(v: VanaCtx, conversationId: string, deps: ExtractDeps = defaultExtractDeps): Promise<ExtractOutcome | null> {
  try { return await extractConversation(v, conversationId, deps); } catch { return null; }
}

/** The one place an episode is written: a keyed Memory, one row per conversation. It no longer fills
 *  `vana_conversations.summary` — that column carries the rolling in-conversation summary, keyed by
 *  `summary_index` (mp-277 clause 1), and a second writer on it would be the race the decision rules out. */
async function writeEpisode(v: VanaCtx, conversationId: string, episode: string): Promise<void> {
  await rememberFact(v, { kind: 'episode', key: conversationId, fact: episode, confidence: 0.9, source: 'conversation' }, undefined, { quiet: true });
}

// ---------------------------------------------------------------- the rolling summary of an open conversation

/** One stored summary: the text standing in for messages [0, index). */
export interface StoredSummary { index: number; text: string }

export const SummaryZ = z.object({ summary: z.string().min(3).max(1500) });

export const SUMMARY_SYSTEM = `You read the opening of a conversation between an endurance athlete and Vana, their nutrition assistant. The conversation is still going, and these messages are about to leave what Vana can see. Your summary is what replaces them.

THE SUMMARY — one paragraph, at most 150 words, saying what these messages established, so a later reply can pick up exactly where they left off. Keep every specific a later reply would need: names, numbers, days, the meals they picked or turned down, constraints, decisions, anything they asked Vana to remember. When a PREVIOUS SUMMARY is given, fold it in: the paragraph must still carry what it carried. Not a list of topics, not advice, nothing Vana should do next. Write nothing else.`;

export interface SummaryDeps {
  generate: (input: { system: string; prompt: string }) => Promise<{ object: { summary: string }; inputTokens?: number; outputTokens?: number }>;
}
export const defaultSummaryDeps: SummaryDeps = {
  generate: async ({ system, prompt }) => {
    const { object, usage } = await generateObject({ model: TOOL_MODEL, schema: SummaryZ, maxOutputTokens: 400, system, prompt });
    return { object, inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens };
  },
};

/** How a part leads in the column, so the text says what it covers and the client preview still reads. */
const PART_LEAD = /^Through message (\d+): ([\s\S]+)$/;
/** The column, read: zero, one or two parts, oldest first. Text without a lead-in (an episode sentence
 *  written before the column was keyed) reads as nothing stored. */
export function parseSummaries(text: string | null | undefined): StoredSummary[] {
  if (!text) return [];
  const parts: StoredSummary[] = [];
  for (const para of text.split('\n\n')) {
    const m = para.trim().match(PART_LEAD);
    if (m) parts.push({ index: Number(m[1]), text: m[2].trim() });
  }
  return parts.sort((a, b) => a.index - b.index);
}
export const renderSummaries = (parts: StoredSummary[]) => parts.map((p) => `Through message ${p.index}: ${p.text}`).join('\n\n');

/** The row's summary and its key. A missing column (the migration not yet applied) reads as nothing stored. */
export async function readSummaries(v: VanaCtx, conversationId: string): Promise<{ index: number; parts: StoredSummary[] }> {
  const { data } = await v.db.from('vana_conversations').select('summary, summary_index').eq('id', conversationId).eq('user_id', v.userId).maybeSingle();
  return { index: Number(data?.summary_index ?? 0), parts: parseSummaries(data?.summary) };
}

/** The message text the summariser reads: what was said, plus the meals a picker showed, which is
 *  how "the one I picked in turn three" survives when the pick was a tap rather than a sentence. */
export function transcriptFromMessages(messages: { role: string; parts: unknown[] }[]): TranscriptLine[] {
  return messages.map((m) => {
    const text: string[] = [];
    for (const p of m.parts as { type?: string; text?: string; state?: string; output?: unknown }[]) {
      if (p?.type === 'text' && p.text?.trim()) text.push(p.text.trim());
      else if (p?.type?.startsWith('tool-') && p.state === 'output-available') {
        const out = p.output as { kind?: string; meals?: { name?: string }[] } | undefined;
        const names = Array.isArray(out?.meals) ? out!.meals.map((x) => x?.name).filter(Boolean) : [];
        if (out?.kind && names.length) text.push(`[${out.kind}: ${names.join(', ')}]`);
      }
    }
    return { role: m.role === 'user' ? 'user' as const : 'assistant' as const, text: text.join(' ').replace(/\s+/g, ' ').trim() };
  }).filter((l) => l.text);
}

export function summaryPrompt(previous: StoredSummary | null, lines: TranscriptLine[], from: number, to: number): string {
  return [
    ...(previous ? [`--- PREVIOUS SUMMARY (messages 1–${previous.index}) ---`, previous.text] : []),
    `--- MESSAGES ${from + 1}–${to} ---`,
    conversationText(lines),
  ].join('\n');
}

/**
 * Writes the summary standing in for messages [0, target) onto the conversation row, keyed by
 * `target` (mp-277 clause 1). The history replay schedules it ten messages before the boundary it
 * is applied at, so no turn waits for it. It rolls the newest stored summary in — the model reads
 * that summary plus the messages after it, never the whole transcript again — and keeps that
 * previous part beside the new one, because the previous part is still the one applied until the
 * count reaches the new boundary plus twenty.
 *
 * Never throws — it runs in the background of a turn, where nobody is listening. A write that finds
 * the row already at or past `target` (a concurrent turn's, or its own retry) leaves it alone.
 */
export async function writeSummary(v: VanaCtx, conversationId: string, target: number, messages: { role: string; parts: unknown[] }[], deps: SummaryDeps = defaultSummaryDeps): Promise<StoredSummary | null> {
  try {
    const before = await readSummaries(v, conversationId);
    if (before.index >= target) return null;
    const rl = await checkRateLimit(v.admin, v.userId, 'vana.summary');
    if (!rl.allowed) return null;   // nothing written, so the next turn schedules it again
    const previous = before.parts.filter((p) => p.index < target).at(-1) ?? null;
    const from = previous?.index ?? 0;
    const lines = transcriptFromMessages(messages.slice(from, target));
    if (!lines.length) return null;
    const { object, inputTokens, outputTokens } = await deps.generate({ system: SUMMARY_SYSTEM, prompt: summaryPrompt(previous, lines, from, target) });
    await logCall(v.admin, { userId: v.userId, conversationId, functionName: 'vana.summary', model: TOOL_MODEL, inputTokens, outputTokens });
    const text = object.summary.replace(/\s+/g, ' ').trim();
    if (!text) return null;
    // Whatever landed while the model was thinking wins if it is newer: never roll the row back.
    const now = await readSummaries(v, conversationId);
    if (now.index >= target) return null;
    const part = { index: target, text };
    const parts = [...(previous ? [previous] : []), part];
    await v.db.from('vana_conversations').update({ summary: renderSummaries(parts), summary_index: target }).eq('id', conversationId).eq('user_id', v.userId);
    return part;
  } catch (e) {
    console.error('[vana] conversation summary failed:', (e as Error).message);
    return null;
  }
}

async function claim(v: VanaCtx, conversationId: string): Promise<boolean> {
  const { data } = await v.db.from('vana_conversations').update({ read_back_at: new Date().toISOString() })
    .eq('id', conversationId).eq('user_id', v.userId).is('read_back_at', null).select('id');
  return Array.isArray(data) ? data.length > 0 : !!data;
}
async function release(v: VanaCtx, conversationId: string): Promise<void> {
  await v.db.from('vana_conversations').update({ read_back_at: null }).eq('id', conversationId).eq('user_id', v.userId);
}
