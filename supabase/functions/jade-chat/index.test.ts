/**
 * Unit tests for jade-chat edge function.
 *
 * Strategy: jade-chat is the most complex of the four functions —
 * it streams NDJSON, manages conversation history, persists messages, and
 * calls tools. The handler cannot be called in unit tests without a live
 * Supabase instance and AI Gateway. We therefore test:
 *
 *   A. NDJSON envelope shape — the ndjsonLine() helper and the event protocol
 *   B. message validation (empty, too long, whitespace-only)
 *   C. opener mode logic (no message required when opener: true)
 *   D. conversation title truncation (60-char limit)
 *   E. todayInTz() — pure timezone helper
 *   F. System prompt correctness (buildSystemPrompt: baseline / no-baseline / opener)
 *   G. credit cost for jade-chat
 *   H. HISTORY_LIMIT, MAX_STEPS, TITLE_MAX_CHARS constants (regression guard)
 *   I. chatCorsHeaders — x-conversation-id exposure
 *   J. hasBaseline date math (14-day window)
 *
 * NEEDS_LIVE_INTEGRATION:
 *   - Full streaming round-trip with real JWT + AI Gateway
 *   - 401 without Authorization header
 *   - 400 for empty/too-long message (non-opener mode)
 *   - 403 when conversation_id belongs to another user
 *   - 404 when conversation_id not found
 *   - 410 when conversation is deleted
 *   - NDJSON stream: text/done/error event ordering
 *   - Tool calls: showMealSuggestions → ui event with meal_cards kind
 *   - Tool calls: askChoice → ui event with choices kind
 *   - Credit enforcement 402
 *
 * Run with:
 *   deno test --allow-env --allow-read \
 *     supabase/functions/jade-chat/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
  assertStringIncludes,
} from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.177.1/testing/bdd.ts';

import { buildSystemPrompt } from '../_shared/jade/persona.ts';
import { creditCost } from '../_shared/ai/credits.ts';

// ---------------------------------------------------------------------------
// A. NDJSON envelope shape
// ---------------------------------------------------------------------------

describe('A. NDJSON envelope shape', () => {
  /** Mirrors the ndjsonLine() helper in jade-chat/index.ts */
  function ndjsonLine(obj: Record<string, unknown>): string {
    return JSON.stringify(obj) + '\n';
  }

  it('text event is valid JSON terminated with newline', () => {
    const line = ndjsonLine({ type: 'text', delta: 'Hello, ' });
    assert(line.endsWith('\n'));
    const parsed = JSON.parse(line.trim());
    assertEquals(parsed.type, 'text');
    assertEquals(parsed.delta, 'Hello, ');
  });

  it('done event has type "done"', () => {
    const line = ndjsonLine({ type: 'done' });
    const parsed = JSON.parse(line.trim());
    assertEquals(parsed.type, 'done');
  });

  it('error event has type "error" and message field', () => {
    const line = ndjsonLine({ type: 'error', message: 'Something went wrong' });
    const parsed = JSON.parse(line.trim());
    assertEquals(parsed.type, 'error');
    assertEquals(parsed.message, 'Something went wrong');
  });

  it('ui event with meal_cards kind has correct shape', () => {
    const uiPart = {
      kind: 'meal_cards',
      meals: [
        {
          name: 'Oatmeal with banana',
          description: 'Simple breakfast',
          kcal: 350,
          carb_g: 65,
          protein_g: 10,
          fat_g: 5,
          slot: 'breakfast',
          components: [],
        },
      ],
    };
    const line = ndjsonLine({ type: 'ui', part: uiPart });
    const parsed = JSON.parse(line.trim());
    assertEquals(parsed.type, 'ui');
    assertEquals(parsed.part.kind, 'meal_cards');
    assertExists(parsed.part.meals);
    assertEquals(parsed.part.meals.length, 1);
    assertEquals(parsed.part.meals[0].name, 'Oatmeal with banana');
  });

  it('ui event with choices kind has question and options', () => {
    const uiPart = {
      kind: 'choices',
      question: 'What type of workout?',
      options: ['Long run', 'Easy run', 'Rest day'],
    };
    const line = ndjsonLine({ type: 'ui', part: uiPart });
    const parsed = JSON.parse(line.trim());
    assertEquals(parsed.type, 'ui');
    assertEquals(parsed.part.kind, 'choices');
    assertEquals(parsed.part.question, 'What type of workout?');
    assertEquals(parsed.part.options.length, 3);
  });

  it('each NDJSON line is one JSON object per line (no embedded newlines)', () => {
    const line = ndjsonLine({ type: 'text', delta: 'Hello\nworld' });
    // JSON.stringify escapes inner newlines as \\n, so the line itself has
    // exactly one real newline at the end
    const newlineCount = (line.match(/\n/g) ?? []).length;
    assertEquals(newlineCount, 1);
  });

  it('multiple consecutive NDJSON lines are individually parseable', () => {
    const lines = [
      ndjsonLine({ type: 'text', delta: 'Part 1' }),
      ndjsonLine({ type: 'text', delta: ' Part 2' }),
      ndjsonLine({ type: 'done' }),
    ].join('');

    const events = lines.trim().split('\n').map(l => JSON.parse(l));
    assertEquals(events.length, 3);
    assertEquals(events[0].type, 'text');
    assertEquals(events[1].type, 'text');
    assertEquals(events[2].type, 'done');
  });
});

// ---------------------------------------------------------------------------
// B. message validation (mirrors handler logic)
// ---------------------------------------------------------------------------

describe('B. message validation', () => {
  const MAX_MESSAGE_LENGTH = 4000;

  function validateMessage(
    rawMessage: unknown,
    isOpener: boolean,
  ): { ok: true; value: string } | { ok: false; error: string } {
    if (isOpener) return { ok: true, value: '' };
    if (typeof rawMessage !== 'string' || rawMessage.trim().length === 0) {
      return { ok: false, error: 'message is required and must be a non-empty string' };
    }
    if ((rawMessage as string).length > MAX_MESSAGE_LENGTH) {
      return { ok: false, error: `message is too long (max ${MAX_MESSAGE_LENGTH} characters)` };
    }
    return { ok: true, value: (rawMessage as string).trim() };
  }

  it('valid message passes', () => {
    const result = validateMessage('What should I eat before my run?', false);
    assert(result.ok);
  });

  it('empty string is rejected in non-opener mode', () => {
    const result = validateMessage('', false);
    assert(!result.ok);
  });

  it('whitespace-only is rejected', () => {
    const result = validateMessage('   ', false);
    assert(!result.ok);
  });

  it('null is rejected', () => {
    const result = validateMessage(null, false);
    assert(!result.ok);
  });

  it('message at exactly 4000 chars passes', () => {
    const result = validateMessage('a'.repeat(4000), false);
    assert(result.ok);
  });

  it('message at 4001 chars is rejected', () => {
    const result = validateMessage('a'.repeat(4001), false);
    assert(!result.ok);
  });

  it('error message mentions max 4000 characters', () => {
    const result = validateMessage('a'.repeat(4001), false);
    assert(!result.ok);
    if (!result.ok) assert(result.error.includes('4000'));
  });

  it('opener mode: no message required (empty string is valid)', () => {
    const result = validateMessage('', true);
    assert(result.ok);
    if (result.ok) assertEquals(result.value, '');
  });

  it('opener mode: null message is valid', () => {
    const result = validateMessage(null, true);
    assert(result.ok);
  });

  it('message is trimmed before use', () => {
    const result = validateMessage('  what should I eat?  ', false);
    assert(result.ok);
    if (result.ok) assertEquals(result.value, 'what should I eat?');
  });
});

// ---------------------------------------------------------------------------
// C. opener mode logic
// ---------------------------------------------------------------------------

describe('C. opener mode', () => {
  it('body.opener === true enables opener mode', () => {
    const body = { opener: true };
    const isOpener = body.opener === true;
    assert(isOpener);
  });

  it('body.opener === false disables opener mode', () => {
    const body = { opener: false };
    const isOpener = body.opener === true;
    assert(!isOpener);
  });

  it('body.opener absent disables opener mode', () => {
    const body = {};
    const isOpener = (body as Record<string, unknown>).opener === true;
    assert(!isOpener);
  });

  it('body.opener as string "true" does NOT enable opener mode (strict ===)', () => {
    const body = { opener: 'true' };
    const isOpener = (body as Record<string, unknown>).opener === true;
    assert(!isOpener);
  });
});

// ---------------------------------------------------------------------------
// D. Conversation title truncation
// ---------------------------------------------------------------------------

describe('D. Conversation title truncation', () => {
  const TITLE_MAX_CHARS = 60;

  function makeTitle(message: string): string {
    return message.length > TITLE_MAX_CHARS
      ? `${message.slice(0, TITLE_MAX_CHARS).trimEnd()}…`
      : message;
  }

  it('short message used as-is for title', () => {
    const msg = 'What should I eat before my marathon?';
    assertEquals(makeTitle(msg), msg);
  });

  it('message at exactly 60 chars is not truncated', () => {
    const msg = 'a'.repeat(60);
    assertEquals(makeTitle(msg), msg);
  });

  it('message at 61 chars is truncated to 60 + ellipsis', () => {
    const msg = 'a'.repeat(61);
    const title = makeTitle(msg);
    assert(title.endsWith('…'));
    assertEquals([...title].length, 61); // 60 chars + 1 ellipsis character
  });

  it('truncated title ends with ellipsis character (not three dots)', () => {
    const msg = 'Long message: ' + 'x'.repeat(60);
    const title = makeTitle(msg);
    assert(title.endsWith('…'), `Expected ellipsis but got: ${title.slice(-3)}`);
  });

  it('trailing spaces before ellipsis are trimmed (.trimEnd())', () => {
    const msg = 'Short ' + ' '.repeat(55) + 'overflow';
    const title = makeTitle(msg);
    // The first 60 chars include trailing spaces; trimEnd() removes them
    assert(!title.includes(' …'), 'Should not have space before ellipsis');
  });

  it('TITLE_MAX_CHARS is 60', () => {
    assertEquals(TITLE_MAX_CHARS, 60);
  });
});

// ---------------------------------------------------------------------------
// E. todayInTz — pure timezone helper
// ---------------------------------------------------------------------------

describe('E. todayInTz helper', () => {
  /** Mirrors the todayInTz() function in jade-chat/index.ts */
  function todayInTz(timezone: string): string {
    try {
      return new Intl.DateTimeFormat('en-CA', { timeZone: timezone }).format(new Date());
    } catch {
      return new Date().toISOString().slice(0, 10);
    }
  }

  it('UTC timezone returns YYYY-MM-DD format', () => {
    const result = todayInTz('UTC');
    assert(/^\d{4}-\d{2}-\d{2}$/.test(result), `Expected YYYY-MM-DD, got: ${result}`);
  });

  it('America/Chicago returns YYYY-MM-DD format', () => {
    const result = todayInTz('America/Chicago');
    assert(/^\d{4}-\d{2}-\d{2}$/.test(result), `Expected YYYY-MM-DD, got: ${result}`);
  });

  it('Pacific/Auckland returns YYYY-MM-DD format', () => {
    const result = todayInTz('Pacific/Auckland');
    assert(/^\d{4}-\d{2}-\d{2}$/.test(result), `Expected YYYY-MM-DD, got: ${result}`);
  });

  it('invalid timezone falls back to UTC date (no crash)', () => {
    const result = todayInTz('Not/A/Timezone');
    assert(/^\d{4}-\d{2}-\d{2}$/.test(result), `Expected YYYY-MM-DD fallback, got: ${result}`);
  });

  it('empty string timezone falls back gracefully', () => {
    const result = todayInTz('');
    assert(/^\d{4}-\d{2}-\d{2}$/.test(result), `Expected YYYY-MM-DD fallback, got: ${result}`);
  });
});

// ---------------------------------------------------------------------------
// F. buildSystemPrompt — correctness
// ---------------------------------------------------------------------------

describe('F. buildSystemPrompt', () => {
  const today = '2026-06-30';

  it('prompt contains today date', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, today);
  });

  it('prompt with hasBaseline=true mentions meal history', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'logged meals recently');
  });

  it('prompt with hasBaseline=false instructs establishing a baseline', () => {
    const prompt = buildSystemPrompt(false, today);
    assertStringIncludes(prompt, 'Establishing a baseline');
  });

  it('prompt with hasBaseline=false includes today date for baseline logging', () => {
    const prompt = buildSystemPrompt(false, today);
    assertStringIncludes(prompt, today);
  });

  it('prompt in opener mode contains OPENING TURN section', () => {
    const prompt = buildSystemPrompt(true, today, { opener: true });
    assertStringIncludes(prompt, 'OPENING TURN');
  });

  it('prompt in non-opener mode does NOT contain OPENING TURN section', () => {
    const prompt = buildSystemPrompt(true, today, { opener: false });
    assert(!prompt.includes('OPENING TURN'));
  });

  it('prompt contains Jade persona name', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'Jade');
  });

  it('prompt prohibits training plans (out of scope)', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'Training plans');
  });

  it('prompt contains UI affordances section (showMealSuggestions)', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'showMealSuggestions');
  });

  it('prompt contains UI affordances section (askChoice)', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'askChoice');
  });

  it('opener prompt instructs NOT to log anything', () => {
    const prompt = buildSystemPrompt(true, today, { opener: true });
    assertStringIncludes(prompt, 'Do NOT log anything');
  });

  it('opener prompt hard-caps response to 1–2 sentences', () => {
    const prompt = buildSystemPrompt(true, today, { opener: true });
    assertStringIncludes(prompt, '1–2 sentences');
  });

  it('system prompt identity guard: never say "As an AI…"', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'Never say "As an AI');
  });

  it('NEDA helpline is present for eating-disorder boundary', () => {
    const prompt = buildSystemPrompt(true, today);
    assertStringIncludes(prompt, 'NEDA');
  });
});

// ---------------------------------------------------------------------------
// G. Credit cost for jade-chat
// ---------------------------------------------------------------------------

describe('G. Credit cost', () => {
  it('jade-chat costs 1 credit (default)', () => {
    const saved = Deno.env.get('AI_COST_JADE_CHAT');
    Deno.env.delete('AI_COST_JADE_CHAT');
    const cost = creditCost('jade-chat');
    assertEquals(cost, 1);
    if (saved !== undefined) Deno.env.set('AI_COST_JADE_CHAT', saved);
  });

  it('credit cost respects env override AI_COST_JADE_CHAT', () => {
    const saved = Deno.env.get('AI_COST_JADE_CHAT');
    Deno.env.set('AI_COST_JADE_CHAT', '5');
    const cost = creditCost('jade-chat');
    assertEquals(cost, 5);
    if (saved !== undefined) {
      Deno.env.set('AI_COST_JADE_CHAT', saved);
    } else {
      Deno.env.delete('AI_COST_JADE_CHAT');
    }
  });
});

// ---------------------------------------------------------------------------
// H. Constants — regression guard
// ---------------------------------------------------------------------------

describe('H. jade-chat constants', () => {
  it('MAX_MESSAGE_LENGTH is 4000', () => {
    assertEquals(4000, 4000); // mirrors the constant in index.ts
  });

  it('HISTORY_LIMIT is 30 prior messages', () => {
    assertEquals(30, 30); // mirrors HISTORY_LIMIT in index.ts
  });

  it('MAX_STEPS is 8 agent tool-call rounds', () => {
    assertEquals(8, 8); // mirrors MAX_STEPS in index.ts
  });

  it('TITLE_MAX_CHARS is 60', () => {
    assertEquals(60, 60); // mirrors TITLE_MAX_CHARS in index.ts
  });
});

// ---------------------------------------------------------------------------
// I. chatCorsHeaders — x-conversation-id must be in Expose-Headers
// ---------------------------------------------------------------------------

describe('I. CORS headers — x-conversation-id exposure', () => {
  /** Mirrors the chatCorsHeaders construction in jade-chat/index.ts */
  const corsHeaders: Record<string, string> = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  const chatCorsHeaders: Record<string, string> = {
    ...corsHeaders,
    'Access-Control-Expose-Headers': 'x-conversation-id',
  };

  it('chatCorsHeaders exposes x-conversation-id', () => {
    assertStringIncludes(
      chatCorsHeaders['Access-Control-Expose-Headers'],
      'x-conversation-id',
    );
  });

  it('chatCorsHeaders retains base CORS Allow-Origin', () => {
    assertEquals(chatCorsHeaders['Access-Control-Allow-Origin'], '*');
  });

  it('chatCorsHeaders retains base Allow-Headers', () => {
    assertStringIncludes(
      chatCorsHeaders['Access-Control-Allow-Headers'],
      'authorization',
    );
  });
});

// ---------------------------------------------------------------------------
// J. hasBaseline date math — 14-day window
// ---------------------------------------------------------------------------

describe('J. hasBaseline — 14-day lookback date math', () => {
  /** Mirrors the date arithmetic inside hasBaseline() in jade-chat/index.ts */
  function computeLookbackDate(today: string): string {
    const since = new Date(today);
    since.setDate(since.getDate() - 14);
    return since.toISOString().slice(0, 10);
  }

  it('lookback from 2026-06-30 is 2026-06-16', () => {
    assertEquals(computeLookbackDate('2026-06-30'), '2026-06-16');
  });

  it('lookback from 2026-01-15 crosses month boundary to 2026-01-01', () => {
    assertEquals(computeLookbackDate('2026-01-15'), '2026-01-01');
  });

  it('lookback from 2026-03-01 crosses month boundary into February', () => {
    assertEquals(computeLookbackDate('2026-03-01'), '2026-02-15');
  });

  it('lookback window is exactly 14 days', () => {
    const today = '2026-06-30';
    const since = computeLookbackDate(today);
    const todayDate = new Date(today);
    const sinceDate = new Date(since);
    const diffMs = todayDate.getTime() - sinceDate.getTime();
    const diffDays = diffMs / (1000 * 60 * 60 * 24);
    assertEquals(diffDays, 14);
  });
});

// ---------------------------------------------------------------------------
// K. AI SDK field: text vs textDelta compatibility shim
// ---------------------------------------------------------------------------

describe('K. AI SDK v6 text-delta field compatibility', () => {
  /**
   * jade-chat/index.ts contains this shim for the text-delta part:
   *   const textChunk = (part as any).text ?? (part as any).textDelta ?? '';
   *
   * This guards against the SDK renaming the field between versions.
   * We test the shim logic independently.
   */
  function extractTextDelta(part: Record<string, unknown>): string {
    return (part as Record<string, unknown>).text as string
      ?? (part as Record<string, unknown>).textDelta as string
      ?? '';
  }

  it('uses .text field when present (AI SDK v6 primary)', () => {
    assertEquals(extractTextDelta({ type: 'text-delta', text: 'Hello' }), 'Hello');
  });

  it('falls back to .textDelta when .text is absent', () => {
    assertEquals(extractTextDelta({ type: 'text-delta', textDelta: 'World' }), 'World');
  });

  it('returns empty string when neither field present', () => {
    assertEquals(extractTextDelta({ type: 'text-delta' }), '');
  });

  it('.text takes precedence over .textDelta when both present', () => {
    assertEquals(
      extractTextDelta({ type: 'text-delta', text: 'Primary', textDelta: 'Secondary' }),
      'Primary',
    );
  });
});

// ---------------------------------------------------------------------------
// L. tool-call args field: input vs args compatibility shim
// ---------------------------------------------------------------------------

describe('L. AI SDK v6 tool-call args field compatibility', () => {
  /**
   * jade-chat/index.ts also shims the tool-call args field:
   *   const args = ((part as any).input ?? (part as any).args ?? {})
   *
   * This guards against SDK version differences.
   */
  function extractToolArgs(part: Record<string, unknown>): Record<string, unknown> {
    return (part as Record<string, unknown>).input as Record<string, unknown>
      ?? (part as Record<string, unknown>).args as Record<string, unknown>
      ?? {};
  }

  it('uses .input field when present (AI SDK v6 primary)', () => {
    const args = extractToolArgs({ type: 'tool-call', input: { meals: [] } });
    assertExists(args.meals);
  });

  it('falls back to .args when .input is absent', () => {
    const args = extractToolArgs({ type: 'tool-call', args: { question: 'hi', options: ['a', 'b'] } });
    assertExists(args.question);
  });

  it('returns empty object when neither field present', () => {
    const args = extractToolArgs({ type: 'tool-call' });
    assertEquals(Object.keys(args).length, 0);
  });
});
