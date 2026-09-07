/** Embeddings via the AI Gateway. Every per-user path passes the ctx so the call is rate-limited (vana.embed) and logged to
 *  vana_calls; the content-pipeline scripts embed with their own REST calls and never come through here. */
import { embed, embedMany, gateway } from 'npm:ai@6';
import { EMBED_MODEL } from './env.ts';
import type { VanaCtx } from './env.ts';
import { assertRateLimit } from './rate-limit.ts';
import { logCall } from './log.ts';

const embedModel = () => gateway.textEmbeddingModel(EMBED_MODEL);

export async function embedText(v: VanaCtx, text: string): Promise<number[]> {
  await assertRateLimit(v.admin, v.userId, 'vana.embed');
  const { embedding, usage } = await embed({ model: embedModel(), value: text.slice(0, 4000) });
  await logCall(v.admin, { userId: v.userId, functionName: 'vana.embed', model: EMBED_MODEL, inputTokens: usage?.tokens });
  return embedding;
}
export async function embedTexts(v: VanaCtx, texts: string[]): Promise<number[][]> {
  if (!texts.length) return [];
  await assertRateLimit(v.admin, v.userId, 'vana.embed');
  const { embeddings, usage } = await embedMany({ model: embedModel(), values: texts.map((t) => t.slice(0, 4000)) });
  await logCall(v.admin, { userId: v.userId, functionName: 'vana.embed', model: EMBED_MODEL, inputTokens: usage?.tokens });
  return embeddings;
}
/** pgvector wants a JSON-ish string through PostgREST. */
export const vec = (e: number[]) => JSON.stringify(e);
