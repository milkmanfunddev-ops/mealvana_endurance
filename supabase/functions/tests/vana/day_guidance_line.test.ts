/**
 * The Plan tab's fallback day note (`get_home` → `vana.text` when the plan holds no stored note) says its carb line once
 * and ends with one full stop (testing-wave ticket 55, Finding 09-002).
 *
 * The seam is `dayGuidanceLine`, the one place the fallback is assembled from a `day_guidance` part. The parts fed in
 * are shaped as `dayGuidance` produces them. No model and no database are involved.
 */
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { dayGuidanceLine } from '../../_shared/vana/tools.ts';

Deno.test('a body that already carries the carb line is not prefixed with it again', () => {
  const line = dayGuidanceLine({ label: 'Rest day', minCarbsG: 272, note: 'At least 272g carbs, protein at every meal. No need to top up around training.' });
  assertEquals(line, 'Rest day. At least 272g carbs, protein at every meal. No need to top up around training.');
});

Deno.test('every carb-bearing note dayGuidance writes comes out with one carb line and one full stop', () => {
  for (const note of [
    'Low-fiber, low-fat, high-carb: at least 300g carbs. Nothing new tonight.',
    'At least 300g carbs today; keep fat and fiber modest.',
    'At least 300g carbs; a real recovery meal within two hours of finishing.',
    'At least 300g carbs, protein at every meal.',
  ]) {
    const line = dayGuidanceLine({ label: 'Day', minCarbsG: 300, note })!;
    assertEquals(line.match(/300g carbs/g)?.length, 1, line);
    assertEquals(line.endsWith('.') && !line.endsWith('..'), true, line);
    assertEquals(line.includes(' — '), false, line);
  }
});

Deno.test('a body without the carb line gets it once, and still one full stop', () => {
  const line = dayGuidanceLine({ label: 'Race day', minCarbsG: 310, note: 'Race-morning breakfast from your pre-race formula; eat familiar food only.' });
  assertEquals(line, 'Race day. At least 310g carbs — Race-morning breakfast from your pre-race formula; eat familiar food only.');
});

Deno.test('no body, no line', () => {
  assertEquals(dayGuidanceLine({ label: 'Rest day', minCarbsG: 272, note: '' }), null);
  assertEquals(dayGuidanceLine({ label: 'Rest day', minCarbsG: 272, note: '   ' }), null);
});
