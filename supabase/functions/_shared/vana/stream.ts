/**
 * NDJSON writer shared by `vana-chat` and `jade-chat` — the wire protocol the Flutter client speaks
 * (docs/implement_mealplanning/02-contract.md §5; reference: the prototype's `POST /api/vana/chat-ndjson`).
 *
 * One JSON object per line, LF-terminated:
 *   {"type":"text","delta":"..."}                 — prose chunk; a "\n" delta separates two text blocks
 *   {"type":"ui","part":{"kind":...}}             — a VanaPart (every tool result that carries `kind`)
 *   {"type":"status","tool":"suggestMeals"}       — emitted when the model starts a tool call; drives "Finding options…"
 *   {"type":"done","usage":{"input_tokens":n,"output_tokens":n,"cache_read_tokens":n}}  — cache_read_tokens: the prompt-cache read (mp-276)
 *   {"type":"error","message":"...","code":"ai_unavailable"}   — `code` only when the fault is ours (mp-437)
 *
 * The Dart parser (`ai_coach_chat_repository._parseLine`) ignores unknown `type`s and ignores extra keys on `done`, so
 * the two additions over the original jade-chat envelope (`status`, `done.usage`) are backward compatible. `code` is
 * likewise additive: a client that does not read it falls back to the generic server-error copy.
 */
import { corsHeaders } from '../cors.ts';
import { AI_UNAVAILABLE, isGatewayRefusal } from '../ai/gateway_error.ts';

export type NdjsonLine =
  | { type: 'text'; delta: string }
  | { type: 'ui'; part: unknown }
  | { type: 'status'; tool: string }
  | { type: 'done'; usage?: { input_tokens: number | null; output_tokens: number | null; cache_read_tokens: number | null } }
  | { type: 'error'; message: string; code?: string };

const enc = new TextEncoder();
export const ndjsonLine = (l: NdjsonLine): Uint8Array => enc.encode(JSON.stringify(l) + '\n');

/** The prompt-cache read count out of an AI SDK v6 usage: `inputTokenDetails.cacheReadTokens`, or the deprecated
 *  `cachedInputTokens` an older provider still fills. Null when the provider said nothing; 0 is a real zero. */
// deno-lint-ignore no-explicit-any
export const cacheReadTokens = (usage: any): number | null => usage?.inputTokenDetails?.cacheReadTokens ?? usage?.cachedInputTokens ?? null;

export const errorMessage = (e: unknown) => (e instanceof Error ? e.message : typeof e === 'string' ? e : 'Vana hit an error');

/** The `error` line for [e]: the gateway refusing us carries `code: 'ai_unavailable'` so the client can tell
 *  "our key ran out" from "the athlete's wallet ran out" and never raise the top-up sheet (mp-437). */
export const errorLine = (e: unknown): NdjsonLine =>
  isGatewayRefusal(e)
    ? { type: 'error', message: errorMessage(e), code: AI_UNAVAILABLE }
    : { type: 'error', message: errorMessage(e) };

/** Headers every NDJSON chat response carries. `extra` = per-function headers (x-conversation-id, x-vana-kind). */
export function ndjsonHeaders(extra: Record<string, string> = {}): Headers {
  const h = new Headers(corsHeaders);
  h.set('Content-Type', 'application/x-ndjson; charset=utf-8');
  h.set('Cache-Control', 'no-cache');
  h.set('X-Accel-Buffering', 'no');   // suppress buffering in some reverse proxies
  h.set('Access-Control-Expose-Headers', Object.keys(extra).join(', ') || 'x-conversation-id');
  for (const [k, val] of Object.entries(extra)) h.set(k, val);
  return h;
}

export interface NdjsonOpts {
  /** Called with every UI part as it is emitted (persistence hooks). */
  onUiPart?: (part: unknown) => void;
  /** Log prefix, e.g. '[vana-chat]'. */
  tag?: string;
  /** Server-authored UI parts appended after the model's output, before `done` (the first conversation's feedback prompt). */
  trailingParts?: unknown[];
  /** Drop every text delta that follows a `feedback_saved` part: on a feedback turn the content-managed row IS the
   *  acknowledgement and the model was asked to write nothing. Prompt-only silence does not hold — see chat.ts. */
  silenceAfterFeedback?: boolean;
}

/**
 * Turn an AI SDK v6 `fullStream` into the NDJSON body. Text blocks are separated by a "\n" delta; tool results that
 * carry a `kind` become `ui` lines; `tool-input-start` becomes `status`; `finish` becomes `done` with usage; a stream
 * error becomes an `error` line followed by `done` so the client always sees the terminator.
 */
// deno-lint-ignore no-explicit-any
export function ndjsonFromFullStream(fullStream: AsyncIterable<any>, opts: NdjsonOpts = {}): ReadableStream<Uint8Array> {
  const tag = opts.tag ?? '[vana]';
  return new ReadableStream<Uint8Array>({
    async start(controller) {
      let textBlocks = 0;   // each step's text is its own block in the transcript; a newline keeps them apart when the client concatenates deltas
      let done = false;
      let filed = false;    // a feedback_saved part has gone out; with silenceAfterFeedback, nothing else may be said
      const push = (l: NdjsonLine) => { try { controller.enqueue(ndjsonLine(l)); } catch { /* closed */ } };
      try {
        for await (const part of fullStream) {
          const silenced = filed && opts.silenceAfterFeedback === true;
          if (part.type === 'text-start') { if (!silenced && textBlocks++ > 0) push({ type: 'text', delta: '\n' }); }
          else if (part.type === 'text-delta') { if (!silenced) push({ type: 'text', delta: part.text ?? part.textDelta ?? '' }); }
          else if (part.type === 'tool-input-start') push({ type: 'status', tool: part.toolName });
          else if (part.type === 'tool-result') { const out = part.output; if (out && typeof out === 'object' && 'kind' in out) { if ((out as { kind?: string }).kind === 'feedback_saved') filed = true; opts.onUiPart?.(out); push({ type: 'ui', part: out }); } }
          else if (part.type === 'error') { console.error(`${tag} fullStream error part:`, errorMessage(part.error)); push(errorLine(part.error)); }
          else if (part.type === 'finish') { for (const t of opts.trailingParts ?? []) push({ type: 'ui', part: t }); push({ type: 'done', usage: { input_tokens: part.totalUsage?.inputTokens ?? null, output_tokens: part.totalUsage?.outputTokens ?? null, cache_read_tokens: cacheReadTokens(part.totalUsage) } }); done = true; }
          // step-start / step-finish / tool-call / tool-input-delta carry nothing user-visible.
        }
      } catch (e) {
        console.error(`${tag} stream consumer error:`, errorMessage(e));
        push(errorLine(e));
      }
      if (!done) push({ type: 'done' });
      try { controller.close(); } catch { /* already closed */ }
    },
  });
}
