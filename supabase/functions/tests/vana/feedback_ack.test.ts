/** The feedback acknowledgement is server-authored (ticket 01, 2026-09-10).
 *
 * The reply to a pure vent is the content-managed `feedback_saved` row and nothing else; the model's prose is dropped
 * server-side because three prompt variants could not hold silence. A complaint that also asks a question keeps its
 * prose, so the question still gets answered. These tests pin both halves without a database or a model call.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { partsFromSteps, silenceAfterFeedback } from '../../_shared/vana/chat.ts';

const feedbackStep = (text = '') => ({ text, toolCalls: [{ toolName: 'saveFeedback' }], toolResults: [{ toolName: 'saveFeedback', toolCallId: 'c1', input: {}, output: { kind: 'feedback_saved', message: 'you keep suggesting fish', sentiment: 'negative', about: 'vana' } }] });
const textStep = (text: string) => ({ text, toolCalls: [], toolResults: [] });
const texts = (parts: unknown[]) => parts.filter((p) => (p as { type: string }).type === 'text').map((p) => (p as { text: string }).text);

Deno.test('a vent is answered by the feedback row alone — the apology after it is dropped', () => {
  const { parts, ui } = partsFromSteps('', [feedbackStep(), textStep("You're right, and I apologize. I'll fix it.")], null, true);
  assertEquals(texts(parts), []);
  assertEquals(ui.map((p) => p.kind), ['feedback_saved']);
});

Deno.test('a complaint that also asks something keeps its prose — the question still gets answered', () => {
  const { parts } = partsFromSteps('', [feedbackStep(), textStep('Fish is filtered out of every search by your allergy setting.')], null, false);
  assertEquals(texts(parts), ['Fish is filtered out of every search by your allergy setting.']);
});

Deno.test('silencing starts at the feedback row, never before it', () => {
  const { parts } = partsFromSteps('', [textStep('Two dinners are left in the plan.'), feedbackStep(), textStep('Sorry about that.')], null, true);
  assertEquals(texts(parts), ['Two dinners are left in the plan.']);
});

Deno.test('a turn that files nothing is untouched by the flag', () => {
  const { parts } = partsFromSteps('', [textStep('At least 344g carbs today.')], null, true);
  assertEquals(texts(parts), ['At least 344g carbs today.']);
});

Deno.test('the aggregate-text fallback does not resurrect a silenced reply', () => {
  const { parts } = partsFromSteps("You're right, and I apologize.", [feedbackStep()], null, true);
  assertEquals(texts(parts), []);
});

Deno.test('a question mark is what buys an answer', () => {
  assert(silenceAfterFeedback('You keep suggesting fish and I have told you I do not eat it.'));
  assert(!silenceAfterFeedback('Why do you keep suggesting fish?'));
});
