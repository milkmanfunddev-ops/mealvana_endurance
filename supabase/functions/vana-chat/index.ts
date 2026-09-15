/**
 * vana-chat Edge Function — Vana, the meal-planning / general nutrition chat (Pro feature).
 *
 * POST /functions/v1/vana-chat        Auth: Supabase user JWT
 * Body: { message?, conversation_id?, kind: 'meal_planning' | 'general', timezone?, opener?, anchor_date? }
 *   opener: true (or a planning conversation with no message) → Vana writes the scripted first turn.
 *   idle: true with conversation_id → no turn: 202 {idle, conversation_id}; the conversation's episode and missed margin
 *   notes are written once in the background (mp-288). Not charged.
 * Response: application/x-ndjson — see _shared/vana/stream.ts for the line protocol. Headers `x-conversation-id`,
 *   `x-vana-kind` are set before the first byte.
 * Pre-stream errors: 401 {error:'unauthenticated'} · 400 {error:'message_required'|'invalid_body'} ·
 *   403 {error:'pro_required'} · 402 {error:'insufficient_credits', …} · 429 {error:'rate_limited', retry_after_seconds}.
 * Persistence: vana_conversations / vana_messages (content + parts + metadata), vana_calls + ai_usage per model call —
 *   all from onFinish under EdgeRuntime.waitUntil.
 * Credits (mp-281 §1, ticket 20): a message turn costs one credit — ensureAndCheckCredits before the call (402 when the
 *   wallet is empty, which the app's one handler turns into the top-up sheet), debitForUsage after it. The scripted
 *   opener is Vana speaking first, not the athlete asking: it is never charged.
 * Contract: docs/implement_mealplanning/02-contract.md · spec: 03-backend.md.
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { authenticate } from '../_shared/vana/auth.ts';
import { requirePro } from '../_shared/vana/entitlement.ts';
import { runChat, type ChatBody } from '../_shared/vana/chat.ts';
import { RateLimitedError } from '../_shared/vana/rate-limit.ts';
import { debitForUsage, ensureAndCheckCredits, insufficientCreditsBody } from '../_shared/ai/credits.ts';

/** Maximum user-message length to prevent token abuse (same as jade-chat). */
const MAX_MESSAGE_LENGTH = 4000;

initSentry();

serve(withSentry(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { ...corsHeaders, 'Access-Control-Expose-Headers': 'x-conversation-id, x-vana-kind' } });
  if (req.method !== 'POST') return errorResponse('Method not allowed. Use POST.', 405);
  if (!Deno.env.get('AI_GATEWAY_API_KEY')) { console.error('[vana-chat] AI_GATEWAY_API_KEY secret is not set'); return errorResponse('AI service is not configured. Please contact support.', 500); }

  const auth = await authenticate(req);
  if (!auth.ok) return jsonResponse({ error: auth.error }, auth.status);
  const v = auth.v;

  let body: ChatBody;
  try { body = (await req.json()) as ChatBody; } catch { return jsonResponse({ error: 'invalid_body' }, 400); }
  if (body.message != null && (typeof body.message !== 'string' || body.message.length > MAX_MESSAGE_LENGTH)) return jsonResponse({ error: 'invalid_body', details: `message must be a string of at most ${MAX_MESSAGE_LENGTH} characters` }, 400);
  if (body.kind != null && body.kind !== 'meal_planning' && body.kind !== 'general') return jsonResponse({ error: 'invalid_body', details: "kind must be 'meal_planning' or 'general'" }, 400);

  const pro = await requirePro(v.admin, v.userId);
  if (!pro.ok) return jsonResponse({ error: pro.reason }, 403);

  // A turn the athlete sends is a debiting call; the opener (no message) is not.
  const charged = body.opener !== true && typeof body.message === 'string' && body.message.trim().length > 0;
  if (charged) {
    const credit = await ensureAndCheckCredits(v.admin, v.userId, 'vana-chat');
    if (!credit.allowed) return jsonResponse(insufficientCreditsBody(credit), 402);
  }

  try {
    const run = await runChat(v, body, {
      functionName: 'vana-chat',
      afterFinish: charged ? async () => { await debitForUsage(v.admin, v.userId, 'vana-chat'); } : undefined,
    });
    if (!run.ok) return jsonResponse(run.body, run.status);
    return run.response;
  } catch (e) {
    if (e instanceof RateLimitedError) return jsonResponse({ error: 'rate_limited', retry_after_seconds: e.retryAfterSeconds }, 429);
    console.error('[vana-chat] Fatal error:', e);
    return serverError(e);
  }
}));
