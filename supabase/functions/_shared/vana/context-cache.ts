/** The context block is assembled once when a conversation opens and reused for its turns (mp-276 clause 2).
 *
 *  An edge function keeps nothing between requests, so "once" means the built AthleteContext is stored on the
 *  conversation row (`vana_conversations.context`, with `context_day`) and read back on the next turn. It is
 *  rebuilt only when a tool writes (plan, memory, pantry, home — each of those call sites calls
 *  `invalidateContext`) or the athlete's day changes. Nothing else rebuilds it: not the message, not the clock.
 *  Per-message memory recall is not part of the block; `recallFacts` stays a tool.
 *
 *  This module owns no building of its own — the builder is passed in — so context.ts, plan.ts and memory.ts
 *  can all import it without a cycle. */
import type { AthleteContext } from './contracts.ts';
import type { VanaCtx } from './env.ts';

/** The stored context for `conversationId` on `day`, else `build()` stored for the next turn. An ephemeral turn
 *  (no conversation) builds every time and stores nothing. */
export async function cachedContext(v: VanaCtx, conversationId: string | null | undefined, day: string, build: () => Promise<AthleteContext>): Promise<{ ctx: AthleteContext; reused: boolean }> {
  if (!conversationId) return { ctx: await build(), reused: false };
  const { data } = await v.db.from('vana_conversations').select('context, context_day').eq('id', conversationId).eq('user_id', v.userId).maybeSingle();
  if (data?.context && String(data.context_day ?? '') === day) return { ctx: data.context as AthleteContext, reused: true };
  const ctx = await build();
  const { error } = await v.db.from('vana_conversations').update({ context: ctx, context_day: day }).eq('id', conversationId).eq('user_id', v.userId);
  if (error) console.error('[vana] context store failed:', error.message);
  return { ctx, reused: false };
}

/** A tool wrote something the block describes: every conversation of this athlete rebuilds on its next turn.
 *  Never throws — a failed invalidation costs one stale turn, not the write that just happened. */
export async function invalidateContext(v: VanaCtx): Promise<void> {
  try {
    const { error } = await v.db.from('vana_conversations').update({ context: null, context_day: null }).eq('user_id', v.userId).not('context', 'is', null);
    if (error) console.error('[vana] context invalidate failed:', error.message);
  } catch (e) { console.error('[vana] context invalidate threw:', (e as Error).message); }
}
