/**
 * The plan opener's question rotates (Lee, 2026-09-16: every "New meal plan" and every + opened on the same "What sounds good
 * for dinners this week?" with the same four chips). The server picks one ANGLE per opener, never the one the athlete's last
 * openers used, and the prompt no longer names a question or labels the model can copy. Nothing here calls a model.
 */
import { assert, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { OPENER_ANGLES, pickAngle, angleLine } from '../../_shared/vana/opener.ts';
import { OPENERS, NEW_PLAN_OPENER } from '../../_shared/vana/persona.ts';
import { recentOpenerAngles } from '../../_shared/vana/chat.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

Deno.test('the prompt no longer hands the model a question or chip labels to copy', () => {
  for (const text of [OPENERS.meal_planning, NEW_PLAN_OPENER]) {
    assert(!text.includes('What sounds good for dinners this week?'), 'the fixed question is gone');
    assert(!text.includes('"Batch-cook staples"'), 'the example chips are gone');
    assertStringIncludes(text, 'on the ANGLE the server appends');
    assertStringIncludes(text, 'The question lives in askChoice only');
  }
});

Deno.test('pickAngle never repeats the excluded angles and covers every angle over enough draws', () => {
  const seen = new Set<string>();
  let i = 0;
  const seq = () => ((i++ * 0.37) % 1);
  for (let n = 0; n < 200; n++) seen.add(pickAngle(['dinners', 'rhythm'], seq).key);
  assert(!seen.has('dinners') && !seen.has('rhythm'));
  assertEquals(seen.size, OPENER_ANGLES.length - 2);
  assertEquals(new Set(OPENER_ANGLES.map((a) => a.key)).size, OPENER_ANGLES.length, 'keys are unique');
});

Deno.test('with every angle excluded, anything goes rather than nothing', () => {
  assert(pickAngle(OPENER_ANGLES.map((a) => a.key), () => 0.5));
});

Deno.test('the angle line asks once, by askChoice, in the model\'s own words', () => {
  const line = angleLine(OPENER_ANGLES[0]);
  assertStringIncludes(line, 'ask what they want dinners to be like this week');
  assertStringIncludes(line, 'never the words in this instruction');
  assertStringIncludes(line, 'asked ONCE, by askChoice');
});

Deno.test('recentOpenerAngles reads the athlete\'s last two opener rows, newest first, skipping rows without one', async () => {
  const v = testCtx({
    vana_messages: [
      { id: 'm1', user_id: TEST_USER_ID, role: 'assistant', content: 'a', created_at: '2026-09-14T10:00:00Z', metadata: { opener: true, opener_angle: 'dinners' } },
      { id: 'm2', user_id: TEST_USER_ID, role: 'assistant', content: 'b', created_at: '2026-09-15T10:00:00Z', metadata: { opener: false } },
      { id: 'm3', user_id: TEST_USER_ID, role: 'assistant', content: 'c', created_at: '2026-09-16T10:00:00Z', metadata: { opener: true, opener_angle: 'craving' } },
      { id: 'm4', user_id: TEST_USER_ID, role: 'user', content: 'd', created_at: '2026-09-16T11:00:00Z', metadata: null },
      { id: 'm0', user_id: TEST_USER_ID, role: 'assistant', content: 'z', created_at: '2026-09-10T10:00:00Z', metadata: { opener: true, opener_angle: 'rhythm' } },
    ],
  } as never);
  assertEquals(await recentOpenerAngles(v), ['craving', 'dinners']);
  assertEquals(await recentOpenerAngles(testCtx({ vana_messages: [] } as never)), []);
});
