// Unit tests for the transcript renderer: server rows (vana_conversations / vana_messages
// shapes, as written by supabase/functions/_shared/vana/chat.ts) → markdown. The dev pull is
// the end-to-end check, not these. Run with: node --test eval/tools/
import test from 'node:test';
import assert from 'node:assert/strict';
import { renderTranscript } from './lib/transcript.mjs';

const conversation = {
  id: '11111111-1111-1111-1111-111111111111',
  kind: 'meal_planning',
  title: 'race week fuelling',
  created_at: '2026-09-20T10:00:00.000000+00:00',
  last_message_at: '2026-09-20T10:05:00.000000+00:00',
};

const userRow = (over = {}) => ({
  id: 'u1',
  role: 'user',
  content: 'what should I eat before Saturday?',
  parts: [{ type: 'text', text: 'what should I eat before Saturday?' }],
  metadata: { situation: 'Plan tab · Sat Sep 27' },
  created_at: '2026-09-20T10:01:00.000000+00:00',
  ...over,
});

const assistantRow = (over = {}) => ({
  id: 'a1',
  role: 'assistant',
  content: 'Let me look at your plan.',
  parts: [
    { type: 'text', text: 'Let me look at your plan.' },
    { type: 'tool-readPlan', toolCallId: 't1', state: 'output-available', input: { week: '2026-09-27' }, output: { kind: 'hand-off', label: 'Open plan' } },
  ],
  metadata: { tool_calls: ['readPlan'], duration_ms: 3200, opener: false, kind: 'meal_planning' },
  created_at: '2026-09-20T10:01:03.000000+00:00',
  ...over,
});

test('the header carries the conversation, account, and counts', () => {
  const md = renderTranscript({ conversation, account: 'test@test.com', userId: '22222222-2222-2222-2222-222222222222', messages: [userRow(), assistantRow()] });
  assert.match(md, /# Transcript: race week fuelling/);
  assert.match(md, /11111111-1111-1111-1111-111111111111/);
  assert.match(md, /test@test\.com/);
  assert.match(md, /meal_planning/);
  assert.match(md, /Messages: 2 \(1 athlete, 1 Vana\)/);
});

test('a user turn shows its text and the screen line that rode on it', () => {
  const md = renderTranscript({ conversation, account: 'a@b.c', userId: 'x', messages: [userRow()] });
  assert.match(md, /what should I eat before Saturday\?/);
  assert.match(md, /Plan tab · Sat Sep 27/);
  assert.match(md, /Athlete/);
});

test('a Vana turn shows its text, its tool call with input and output, and metadata', () => {
  const md = renderTranscript({ conversation, account: 'a@b.c', userId: 'x', messages: [assistantRow()] });
  assert.match(md, /Let me look at your plan\./);
  assert.match(md, /Vana/);
  assert.match(md, /tool readPlan/);
  assert.match(md, /"week": "2026-09-27"/);
  assert.match(md, /"kind": "hand-off"/);
  assert.match(md, /3\.2s/);
});

test('an opener turn shows the opener flag, the variant, and the hidden opener prompt', () => {
  const md = renderTranscript({
    conversation, account: 'a@b.c', userId: 'x',
    messages: [assistantRow({
      metadata: { tool_calls: [], duration_ms: 900, opener: true, opener_variant: 'v2', kind: 'general', opener_prompt: 'Write the opener for Lee.', situation: 'Meals tab' },
    })],
  });
  assert.match(md, /opener/);
  assert.match(md, /v2/);
  assert.match(md, /Write the opener for Lee\./);
  assert.match(md, /Meals tab/);
});

test('a huge tool output is truncated with a marker unless full is asked for', () => {
  const big = 'x'.repeat(5000);
  const row = assistantRow({
    parts: [
      { type: 'text', text: 'Here you go.' },
      { type: 'tool-mealPicker', toolCallId: 't2', state: 'output-available', input: {}, output: { kind: 'picker', meals: big } },
    ],
    metadata: { tool_calls: ['mealPicker'], duration_ms: 100, kind: 'meal_planning' },
  });
  const clipped = renderTranscript({ conversation, account: 'a@b.c', userId: 'x', messages: [row] }, { maxPartChars: 1000 });
  assert.match(clipped, /truncated/);
  assert.doesNotMatch(clipped, /x{5000}/);
  const full = renderTranscript({ conversation, account: 'a@b.c', userId: 'x', messages: [row] }, { maxPartChars: null });
  assert.match(full, /x{5000}/);
});

test('a legacy assistant row (content only, no parts) still renders its text', () => {
  const md = renderTranscript({ conversation, account: 'a@b.c', userId: 'x', messages: [assistantRow({ parts: null })] });
  assert.match(md, /Let me look at your plan\./);
});

test('no leaked undefined or null placeholders', () => {
  const md = renderTranscript({ conversation, account: 'a@b.c', userId: 'x', messages: [userRow(), assistantRow()] });
  assert.doesNotMatch(md, /undefined|NaN/);
});
