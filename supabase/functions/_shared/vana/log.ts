/** Call log → public.vana_calls (id, user_id, conversation_id, function_name, model, input_tokens, output_tokens).
 *  Service role: users can only SELECT their own rows. Never throws. */
import type { Db } from './env.ts';

export async function logCall(admin: Db, row: { userId: string; conversationId?: string | null; functionName: string; model: string; inputTokens?: number; outputTokens?: number }) {
  try {
    const { error } = await admin.from('vana_calls').insert({ user_id: row.userId, conversation_id: row.conversationId ?? null, function_name: row.functionName, model: row.model, input_tokens: row.inputTokens ?? null, output_tokens: row.outputTokens ?? null });
    if (error) console.error('[vana] vana_calls insert failed:', error.message);
  } catch (e) { console.error('[vana] vana_calls insert threw:', (e as Error).message); }
}
