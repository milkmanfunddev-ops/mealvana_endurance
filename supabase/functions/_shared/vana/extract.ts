/**
 * Lazy extraction — the margin notes Vana keeps without being asked.
 *
 * There is no scheduler. When a conversation opens, the athlete's most recent conversation that has
 * not been read back yet is fed to ONE Haiku call with the margin-note rule and a strict schema:
 * zero to three sentences, plus one episode sentence. The sentences go through the deduped writer;
 * the episode is a keyed Memory and also fills the conversation's summary column so a list preview
 * has something to show. `read_back_at` is stamped so a conversation is never extracted twice.
 *
 * Nothing is announced. Extracted Memories produce no card and no mention — the flat list in Vana
 * settings is the audit trail.
 *
 * The opener's synthetic user message is never stored, so a transcript begins with Vana's own first
 * turn. Nothing here may depend on that message existing.
 *
 * The episode half also runs on its own, over a conversation the athlete is still in: see
 * `writeOpenEpisode`.
 */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import { TOOL_MODEL } from './env.ts';
import type { VanaCtx } from './env.ts';
import { episodeFor, listMemories, rememberFact } from './memory.ts';
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

/** The athlete's most recent conversation still waiting to be read back, excluding the one they just opened. */
export async function pendingReadBack(v: VanaCtx, exceptConversationId: string): Promise<string | null> {
  const { data } = await v.db.from('vana_conversations').select('id')
    .eq('user_id', v.userId).eq('is_deleted', false).is('read_back_at', null).neq('id', exceptConversationId)
    .order('last_message_at', { ascending: false }).limit(1).maybeSingle();
  return data?.id ? String(data.id) : null;
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
 * Reads one conversation back. Claims it first by stamping `read_back_at`, so two concurrent
 * openers cannot both pay for the same extraction; on failure the claim is released.
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
      await rememberFact(v, { kind: m.kind, fact, confidence: 0.7, source: 'conversation', key: null });
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

/** Reads back whatever is pending for this athlete. Never throws — it runs in the background of an opener. */
export async function readBackPrevious(v: VanaCtx, openingConversationId: string, deps: ExtractDeps = defaultExtractDeps): Promise<ExtractOutcome | null> {
  try {
    const id = await pendingReadBack(v, openingConversationId);
    if (!id) return null;
    return await extractConversation(v, id, deps);
  } catch { return null; }
}

/** The one place an episode is written, whoever wrote it: keyed by conversation, so the sentence
 *  written mid-conversation is the row lazy extraction later rewrites, never a second one. */
async function writeEpisode(v: VanaCtx, conversationId: string, episode: string): Promise<void> {
  await rememberFact(v, { kind: 'episode', key: conversationId, fact: episode, confidence: 0.9, source: 'conversation' });
  // The summary column is read by client and server and was written by nothing; the episode fills it for list previews.
  await v.db.from('vana_conversations').update({ summary: episode }).eq('id', conversationId).eq('user_id', v.userId);
}

// ---------------------------------------------------------------- the episode of an open conversation

export const EpisodeZ = z.object({ episode: ExtractionZ.shape.episode });

export const OPEN_EPISODE_SYSTEM = `You read the opening turns of a conversation between an endurance athlete and Vana, their nutrition assistant. The conversation is still going, and these turns are about to leave what Vana can see. Your sentence is what replaces them.

THE EPISODE — exactly one sentence, at most 25 words, saying what the athlete established in these turns. Keep the specifics a later reply would need: a name, a number, a day, a plan, a constraint. "Building a race-week menu for Sunday's 10K; partner cooks Tuesdays, budget $80." Not a list of topics. Write nothing else — no memories, no advice.`;

export interface EpisodeDeps {
  generate: (input: { system: string; prompt: string }) => Promise<{ object: { episode: string }; inputTokens?: number; outputTokens?: number }>;
}
export const defaultEpisodeDeps: EpisodeDeps = {
  generate: async ({ system, prompt }) => {
    const { object, usage } = await generateObject({ model: TOOL_MODEL, schema: EpisodeZ, maxOutputTokens: 120, system, prompt });
    return { object, inputTokens: usage?.inputTokens, outputTokens: usage?.outputTokens };
  },
};

/**
 * The extractor's episode half, for a conversation the athlete is still in. The history cap calls it
 * the first time it bites; the next turn finds the episode and prepends it.
 *
 * It reads the opening half of the transcript: what falls out of view soonest. Not only the rows
 * dropped this turn — at the crossing that is one row, usually Vana's first line. Not the whole
 * transcript either — the recent half is still in view, and the first live run on dev (2026-09-10)
 * showed a sentence written from all of it lists the latest topics and drops the opening, which is
 * the one thing it exists to keep. It does not stamp `read_back_at`: the
 * conversation's margin notes are still owed, and lazy extraction later rewrites the same episode row
 * from the finished transcript.
 *
 * Never throws — it runs in the background of a turn, where nobody is listening.
 */
export async function writeOpenEpisode(v: VanaCtx, conversationId: string, deps: EpisodeDeps = defaultEpisodeDeps): Promise<string | null> {
  try {
    const rl = await checkRateLimit(v.admin, v.userId, 'vana.episode');
    if (!rl.allowed) return null;   // no episode written, so the next turn tries again
    const lines = await transcriptOf(v, conversationId);
    if (!lines.length) return null;
    const opening = lines.slice(0, Math.ceil(lines.length / 2));
    const { object, inputTokens, outputTokens } = await deps.generate({ system: OPEN_EPISODE_SYSTEM, prompt: `--- OPENING TURNS ---\n${conversationText(opening)}` });
    await logCall(v.admin, { userId: v.userId, conversationId, functionName: 'vana.episode', model: TOOL_MODEL, inputTokens, outputTokens });
    const episode = object.episode.trim() || null;
    // Whatever landed while the model was thinking wins: lazy extraction's sentence comes from the
    // finished transcript, and a concurrent turn's is as good as this one. Never overwrite.
    if (!episode || await episodeFor(v, conversationId)) return null;
    await writeEpisode(v, conversationId, episode);
    return episode;
  } catch (e) {
    console.error('[vana] open-conversation episode failed:', (e as Error).message);
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
