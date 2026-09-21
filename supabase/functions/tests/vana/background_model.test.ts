/**
 * The one setting the three background jobs read (mp-465 clause 3, ai-cost ticket 14).
 *
 * The memory extraction, the rolling conversation summary and the saved-meal ingredient list write
 * nothing the athlete reads, so their model is chosen for price alone. They share ONE setting,
 * `VANA_BACKGROUND_MODEL`, which is not `VANA_CHAT_MODEL` and not `VANA_TOOL_MODEL`: moving the
 * background jobs must never move Vana's conversation (clause 1) or the day notes (clause 5).
 *
 * The setting is read at CALL time, not at import time, so a deploy-time secret change takes effect
 * on the next invocation and a test can set it without re-importing the module graph.
 *
 * The last two cases read the job modules' source. There is no seam that reports which model string
 * `generateObject` was handed (the model is not part of the injected `generate` dep), so the wiring
 * is asserted where it is written. If a future refactor gives the jobs a model seam, replace these
 * two with a call-level assertion.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { BACKGROUND_MODEL_ENV, backgroundModel, CHAT_MODEL, TOOL_MODEL } from '../../_shared/vana/env.ts';

const HAIKU = 'anthropic/claude-haiku-4.5';

/** Runs `fn` with `VANA_BACKGROUND_MODEL` set (or cleared), then puts the environment back. */
function withSetting(value: string | null, fn: () => void): void {
  const saved = Deno.env.get(BACKGROUND_MODEL_ENV);
  if (value === null) Deno.env.delete(BACKGROUND_MODEL_ENV); else Deno.env.set(BACKGROUND_MODEL_ENV, value);
  try { fn(); } finally {
    if (saved === undefined) Deno.env.delete(BACKGROUND_MODEL_ENV); else Deno.env.set(BACKGROUND_MODEL_ENV, saved);
  }
}

Deno.test('the setting is absent by default and the three jobs fall back to Haiku 4.5', () => {
  withSetting(null, () => assertEquals(backgroundModel(), HAIKU));
});

Deno.test('the setting names the model when it is set', () => {
  withSetting('anthropic/claude-haiku-4.5-cheaper', () => assertEquals(backgroundModel(), 'anthropic/claude-haiku-4.5-cheaper'));
});

Deno.test('the setting is read at call time, so a second value takes effect without re-importing', () => {
  withSetting('a/one', () => assertEquals(backgroundModel(), 'a/one'));
  withSetting('a/two', () => assertEquals(backgroundModel(), 'a/two'));
});

Deno.test('the background setting is apart from the chat setting: moving one does not move the other', () => {
  withSetting('a/background-only', () => {
    assertEquals(backgroundModel(), 'a/background-only');
    // CHAT_MODEL is Vana's conversation (mp-465 clause 1) and TOOL_MODEL is what the day notes and the
    // pantry photo still read (clause 5); neither may follow the background setting.
    assertEquals(CHAT_MODEL, HAIKU);
    assertEquals(TOOL_MODEL, HAIKU);
  });
});

const read = (p: string) => Deno.readTextFileSync(new URL(p, import.meta.url));

Deno.test('the memory extraction, the rolling summary and the ingredient list all read the background setting', () => {
  for (const file of ['../../_shared/vana/extract.ts', '../../_shared/vana/saved-ingredients.ts']) {
    const src = read(file);
    assert(src.includes('backgroundModel'), `${file} does not read the background setting`);
    assert(!/\bTOOL_MODEL\b/.test(src), `${file} still reads TOOL_MODEL`);
    assert(!/\bCHAT_MODEL\b/.test(src), `${file} reads the chat setting`);
  }
  // Both extraction jobs live in extract.ts and each makes its own generateObject call; both must be moved.
  const extract = read('../../_shared/vana/extract.ts');
  assertEquals(
    extract.match(/generateObject\(\{ model: backgroundModel\(\)/g)?.length,
    2,
    'extract.ts should hand the background model to both generateObject calls (the extraction and the rolling summary)',
  );
  // And the ledger row records the model that was actually spent, not a stale constant.
  assert(/functionName: 'vana\.ingredients', model: backgroundModel\(\)/.test(read('../../_shared/vana/saved-ingredients.ts')));
});

Deno.test('the day notes keep their own setting (clause 5) — the background setting does not reach them', () => {
  const daynotes = read('../../_shared/vana/daynotes.ts');
  assert(/\bTOOL_MODEL\b/.test(daynotes), 'daynotes.ts should still read TOOL_MODEL');
  assert(!daynotes.includes('backgroundModel'), 'daynotes.ts must not follow the background setting');
});
