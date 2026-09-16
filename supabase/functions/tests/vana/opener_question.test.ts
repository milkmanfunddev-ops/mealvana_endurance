/**
 * The plan opener's question is Vana's own (mp-007: not forced to dinners; mp-008: the most relevant thing she holds).
 * Lee, 2026-09-16: every "New meal plan" and every + ended on the same "What sounds good for dinners this week?" with the
 * same four chips, because the prompt named that question and those labels as its example and the model copied them.
 * The prompt now names no question and no labels, and says the question is asked once, by askChoice. Nothing here calls a model.
 */
import { assert, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { OPENERS, NEW_PLAN_OPENER } from '../../_shared/vana/persona.ts';

Deno.test('the prompt hands the model no question and no chip labels to copy', () => {
  for (const text of [OPENERS.meal_planning, NEW_PLAN_OPENER]) {
    assert(!text.includes('What sounds good for dinners this week?'), 'the fixed question is gone');
    assert(!/"[A-Z][a-z-]+ [a-z]+"/.test(text.split('askChoice')[1] ?? ''), 'no quoted example labels after askChoice');
    assertStringIncludes(text, 'drafted from the CONTEXT and the situation');
    assertStringIncludes(text, 'never a stock question');
    assertStringIncludes(text, 'The question lives in askChoice only');
    assertStringIncludes(text, 'the prose ends on a statement, never on the question');
  }
});
