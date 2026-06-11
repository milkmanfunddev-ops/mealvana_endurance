/**
 * jade-chat Edge Function
 *
 * Streaming AI endurance-nutrition coach (Jade) with persistent conversation
 * history and tool-based data access.
 *
 * POST /functions/v1/jade-chat
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Request body:
 *   {
 *     message: string                    — user turn (required)
 *     conversation_id?: string           — UUID of an existing conversation;
 *                                          omit to start a new one
 *     timezone?: string                  — IANA tz, e.g. "America/Chicago"
 *     location?: { latitude: number, longitude: number }
 *   }
 *
 * Response (200):
 *   - Content-Type: text/plain; charset=utf-8
 *   - Transfer-Encoding: chunked (streaming)
 *   - Header x-conversation-id: <UUID>   — new or echoed conversation id
 *   - Header Access-Control-Expose-Headers includes x-conversation-id
 *
 * New conversation: if conversation_id is absent, a jade_conversations row is
 * created whose title is the first ~60 characters of the user's message.
 *
 * History: the 30 most-recent jade_messages in the conversation are loaded and
 * fed to the model as prior context.
 *
 * Persistence: the user's message is saved before the model is called; the
 * assistant's full reply is saved in onFinish. A jade_calls usage row is also
 * inserted in onFinish (fire-and-forget).
 *
 * Error responses:
 *   400 — missing/invalid body
 *   401 — missing or invalid JWT
 *   403 — conversation does not belong to this user
 *   500 — missing AI_GATEWAY_API_KEY secret or unexpected server error
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { streamText } from 'npm:ai';
import { corsHeaders } from '../_shared/cors.ts';
import { errorResponse, validationError, serverError } from '../_shared/responses.ts';
import { JADE_MODEL } from '../_shared/ai/model.ts';
import { buildSystemPrompt } from '../_shared/jade/persona.ts';
import { makeJadeTools } from '../_shared/jade/tools.ts';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/** Maximum user-message length to prevent token abuse */
const MAX_MESSAGE_LENGTH = 4000;
/** Number of prior messages to load as model history */
const HISTORY_LIMIT = 30;
/** Maximum agent steps (tool call rounds) per response */
const MAX_STEPS = 8;
/** Title snippet length for new conversations */
const TITLE_MAX_CHARS = 60;

// ---------------------------------------------------------------------------
// CORS — extend base headers with x-conversation-id exposure
// ---------------------------------------------------------------------------

const chatCorsHeaders: Record<string, string> = {
  ...corsHeaders,
  'Access-Control-Expose-Headers': 'x-conversation-id',
};

// ---------------------------------------------------------------------------
// Auth helper
// ---------------------------------------------------------------------------

async function requireUser(req: Request) {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return { user: null, token: null, response: errorResponse('Missing authorization header', 401) };
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error } = await adminClient.auth.getUser(token);

  if (error || !user) {
    console.error('[jade-chat] Auth error:', error);
    return {
      user: null,
      token: null,
      response: errorResponse('Invalid or expired authentication token', 401),
    };
  }

  return { user, token, response: null };
}

// ---------------------------------------------------------------------------
// Baseline check — any non-deleted meal_logs in the last 14 days?
// ---------------------------------------------------------------------------

async function hasBaseline(serviceClient: ReturnType<typeof createClient>, userId: string, today: string): Promise<boolean> {
  const since = new Date(today);
  since.setDate(since.getDate() - 14);
  const sinceStr = since.toISOString().slice(0, 10);

  const { count, error } = await serviceClient
    .from('meal_logs')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_deleted', false)
    .gte('log_date', sinceStr);

  if (error) {
    console.error('[jade-chat] hasBaseline check error:', error);
    return false;
  }
  return (count ?? 0) > 0;
}

// ---------------------------------------------------------------------------
// "Today" in a given IANA timezone
// ---------------------------------------------------------------------------

function todayInTz(timezone: string): string {
  try {
    return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(new Date());
  } catch {
    return new Date().toISOString().slice(0, 10);
  }
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req: Request) => {
  // Handle CORS preflight — must use expanded headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: chatCorsHeaders });
  }

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed. Use POST.', 405);
  }

  // Validate AI Gateway key is configured before doing any real work
  const aiGatewayApiKey = Deno.env.get('AI_GATEWAY_API_KEY');
  if (!aiGatewayApiKey) {
    console.error('[jade-chat] AI_GATEWAY_API_KEY secret is not set');
    return errorResponse('AI service is not configured. Please contact support.', 500);
  }

  try {
    // ── Authenticate ────────────────────────────────────────────────────────
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse('Invalid authentication state', 401);

    // ── Parse body ──────────────────────────────────────────────────────────
    let body: {
      message?: unknown;
      conversation_id?: unknown;
      timezone?: unknown;
      location?: unknown;
    };
    try {
      body = await req.json();
    } catch {
      return validationError('Invalid JSON body');
    }

    const rawMessage = body.message;
    if (typeof rawMessage !== 'string' || rawMessage.trim().length === 0) {
      return validationError('message is required and must be a non-empty string');
    }
    if (rawMessage.length > MAX_MESSAGE_LENGTH) {
      return validationError(`message is too long (max ${MAX_MESSAGE_LENGTH} characters)`);
    }
    const message = rawMessage.trim();

    const rawConversationId = body.conversation_id;
    const conversationId =
      typeof rawConversationId === 'string' && rawConversationId.trim().length > 0
        ? rawConversationId.trim()
        : null;

    const timezone =
      typeof body.timezone === 'string' && body.timezone.trim().length > 0
        ? body.timezone.trim()
        : 'UTC';

    const location =
      body.location &&
      typeof (body.location as Record<string, unknown>).latitude === 'number' &&
      typeof (body.location as Record<string, unknown>).longitude === 'number'
        ? {
            latitude: (body.location as Record<string, unknown>).latitude as number,
            longitude: (body.location as Record<string, unknown>).longitude as number,
          }
        : undefined;

    const today = todayInTz(timezone);

    // ── Service-role client ─────────────────────────────────────────────────
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Resolve or create conversation ──────────────────────────────────────
    let resolvedConversationId: string;
    let isNewConversation = false;

    if (conversationId) {
      // Verify it belongs to this user and is not deleted
      const { data: conv, error: convError } = await serviceClient
        .from('jade_conversations')
        .select('id, user_id, is_deleted')
        .eq('id', conversationId)
        .maybeSingle();

      if (convError) {
        console.error('[jade-chat] conversation lookup error:', convError);
        return serverError(convError);
      }
      if (!conv) {
        return errorResponse('Conversation not found', 404);
      }
      if (conv.user_id !== user.id) {
        return errorResponse('Access denied: conversation does not belong to this user', 403);
      }
      if (conv.is_deleted) {
        return errorResponse('Conversation has been deleted', 410);
      }

      resolvedConversationId = conversationId;
    } else {
      // Create a new conversation — title = first ~60 chars of message
      const title = message.length > TITLE_MAX_CHARS
        ? `${message.slice(0, TITLE_MAX_CHARS).trimEnd()}…`
        : message;

      const { data: newConv, error: createError } = await serviceClient
        .from('jade_conversations')
        .insert({ user_id: user.id, title })
        .select('id')
        .single();

      if (createError || !newConv) {
        console.error('[jade-chat] conversation create error:', createError);
        return serverError(createError ?? new Error('Failed to create conversation'));
      }

      resolvedConversationId = newConv.id;
      isNewConversation = true;
    }

    // ── Persist the user's message ──────────────────────────────────────────
    const { error: userMsgError } = await serviceClient
      .from('jade_messages')
      .insert({
        conversation_id: resolvedConversationId,
        user_id: user.id,
        role: 'user',
        content: message,
      });

    if (userMsgError) {
      console.error('[jade-chat] user message persist error:', userMsgError);
      // Non-fatal — don't abort; log and continue
    }

    // ── Load prior conversation history ─────────────────────────────────────
    const { data: historyRows, error: historyError } = await serviceClient
      .from('jade_messages')
      .select('role, content')
      .eq('conversation_id', resolvedConversationId)
      .order('created_at', { ascending: false })
      .limit(HISTORY_LIMIT + 1); // +1 because we just inserted the user turn

    if (historyError) {
      console.error('[jade-chat] history load error:', historyError);
    }

    // Reverse to chronological order; exclude the message we just inserted
    // (we'll pass it as the last user turn, not in history, to avoid double-counting)
    const priorMessages = (historyRows ?? [])
      .reverse()
      .slice(0, -1) // drop the last element (the turn we just inserted)
      .map((row) => ({
        role: row.role as 'user' | 'assistant',
        content: row.content as string,
      }));

    // ── Build system prompt ─────────────────────────────────────────────────
    const baseline = await hasBaseline(serviceClient, user.id, today);
    const systemPrompt = buildSystemPrompt(baseline, today);

    // ── Build tools ─────────────────────────────────────────────────────────
    const tools = makeJadeTools({ serviceClient, userId: user.id, timezone, location });

    console.log(
      `[jade-chat] user=${user.id} conv=${resolvedConversationId} ` +
        `new=${isNewConversation} baseline=${baseline} model=${JADE_MODEL}`,
    );

    // ── Stream the reply ────────────────────────────────────────────────────
    const result = streamText({
      model: JADE_MODEL as Parameters<typeof streamText>[0]['model'],
      apiKey: aiGatewayApiKey,
      system: systemPrompt,
      messages: [
        ...priorMessages,
        { role: 'user', content: message },
      ],
      tools,
      maxSteps: MAX_STEPS,
      onFinish: async ({ text, usage }) => {
        // Persist assistant message
        const { error: assistantMsgError } = await serviceClient
          .from('jade_messages')
          .insert({
            conversation_id: resolvedConversationId,
            user_id: user.id,
            role: 'assistant',
            content: text,
          });

        if (assistantMsgError) {
          console.error('[jade-chat] assistant message persist error:', assistantMsgError);
        }

        // Bump conversation updated_at (fire-and-forget)
        serviceClient
          .from('jade_conversations')
          .update({ updated_at: new Date().toISOString() })
          .eq('id', resolvedConversationId)
          .then(({ error: bumpError }) => {
            if (bumpError) console.error('[jade-chat] conversation bump error:', bumpError);
          });

        // Log jade_calls usage (fire-and-forget)
        serviceClient
          .from('jade_calls')
          .insert({
            user_id: user.id,
            conversation_id: resolvedConversationId,
            function_name: 'jade-chat',
            model: JADE_MODEL,
            input_tokens: usage?.promptTokens ?? 0,
            output_tokens: usage?.completionTokens ?? 0,
          })
          .then(({ error: logError }) => {
            if (logError) console.error('[jade-chat] jade_calls log error:', logError);
          });

        console.log(
          `[jade-chat] onFinish user=${user.id} conv=${resolvedConversationId} ` +
            `in=${usage?.promptTokens ?? 0} out=${usage?.completionTokens ?? 0}`,
        );
      },
    });

    // ── Build streaming response with merged CORS + conversation-id headers ─
    const streamResponse = result.toTextStreamResponse();

    const responseHeaders = new Headers(streamResponse.headers);
    for (const [key, value] of Object.entries(chatCorsHeaders)) {
      responseHeaders.set(key, value);
    }
    responseHeaders.set('x-conversation-id', resolvedConversationId);

    return new Response(streamResponse.body, {
      status: streamResponse.status,
      headers: responseHeaders,
    });

  } catch (error) {
    console.error('[jade-chat] Fatal error:', error);
    return serverError(error);
  }
});
