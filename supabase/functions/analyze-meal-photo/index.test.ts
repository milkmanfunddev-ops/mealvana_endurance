/**
 * Unit tests for analyze-meal-photo edge function.
 *
 * Strategy: the handler is registered via `serve()` and calls:
 *   - Supabase admin client (auth.getUser) — requires SUPABASE_URL/SERVICE_KEY
 *   - Supabase storage (download from meal-photos bucket) — requires network
 *   - AI SDK generateObject (Vercel AI Gateway) — requires AI_GATEWAY_API_KEY
 *
 * None of these are available in local unit tests. We therefore test:
 *   1. The MealAnalysisSchema Zod shape — validates that the contract the
 *      function returns is correct and the schema constraints are enforced.
 *   2. photo_path authorization logic (user-id prefix check) — pure logic
 *      we can reason about directly.
 *   3. MIME type inference from path extension — pure function.
 *   4. Confidence enum values — the schema constrains these; wrong values
 *      would cause Zod to throw and we'd return a malformed response.
 *   5. Base64 encoding correctness — the chunked base64 logic handles large
 *      images; we can unit-test the algorithm independently.
 *   6. Error classification: not_food detection logic.
 *
 * NEEDS_LIVE_INTEGRATION:
 *   - Full round-trip with real JWT + storage + AI Gateway
 *   - 401 without Authorization header
 *   - 403 when photo_path doesn't start with user.id
 *   - 422 when model returns { not_food: true }
 *   - Storage download failure → 500
 *   - Credit enforcement 402
 *
 * Run with:
 *   deno test --allow-env --allow-read \
 *     supabase/functions/analyze-meal-photo/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
  assertThrows,
} from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.177.1/testing/bdd.ts';
import { z } from 'npm:zod@3';

import { MealAnalysisRequestSchema, MealAnalysisSchema, MealItemSchema } from '../_shared/meal_analysis/schema.ts';
import { finalizeAnalysis, NOT_FOOD_BODY, NOT_FOOD_STATUS, sumTotals } from '../_shared/meal_analysis/finalize.ts';
import {
  MEAL_ANALYSIS_CACHE_OPTIONS,
  MEAL_PHOTO_INSTRUCTIONS,
  mealPhotoPrompt,
} from '../_shared/meal_analysis/prompt.ts';
import { ANALYZE_MEAL_PHOTO_MODEL } from '../_shared/ai/model.ts';

// ---------------------------------------------------------------------------
// A. MealAnalysisSchema — shape validation
// ---------------------------------------------------------------------------

describe('A. MealAnalysisSchema — shape and constraints', () => {
  const validAnalysis = {
    name: 'Grilled chicken with rice and salad',
    suggested_slot: 'lunch',
    confidence: 'high',
    items: [
      {
        name: 'Grilled chicken breast',
        portion: '150g',
        calories: 248,
        carb_g: 0,
        protein_g: 46,
        fat_g: 5.3,
        sodium_mg: 120,
      },
      {
        name: 'White rice',
        portion: '1 cup cooked',
        calories: 206,
        carb_g: 45,
        protein_g: 4,
        fat_g: 0.4,
        sodium_mg: 2,
      },
    ],
    totals: {
      calories: 454,
      carb_g: 45,
      protein_g: 50,
      fat_g: 5.7,
      sodium_mg: 122,
    },
    notes: 'Sauce portion estimated',
  };

  it('valid analysis passes schema parse', () => {
    const result = MealAnalysisSchema.safeParse(validAnalysis);
    assert(result.success, `Schema parse failed: ${JSON.stringify((result as z.SafeParseError<unknown>).error?.issues)}`);
  });

  it('name field is required', () => {
    const { name: _n, ...withoutName } = validAnalysis;
    const result = MealAnalysisSchema.safeParse(withoutName);
    assert(!result.success);
  });

  it('suggested_slot must be one of breakfast/lunch/dinner/snack', () => {
    const badSlot = { ...validAnalysis, suggested_slot: 'brunch' };
    const result = MealAnalysisSchema.safeParse(badSlot);
    assert(!result.success);
  });

  it('confidence must be low/medium/high', () => {
    const badConf = { ...validAnalysis, confidence: 'uncertain' };
    const result = MealAnalysisSchema.safeParse(badConf);
    assert(!result.success);
  });

  it('items array must have at least one item', () => {
    const noItems = { ...validAnalysis, items: [] };
    const result = MealAnalysisSchema.safeParse(noItems);
    assert(!result.success);
  });

  it('negative calories is rejected (nonnegative constraint)', () => {
    const negCal = {
      ...validAnalysis,
      items: [{ ...validAnalysis.items[0], calories: -10 }],
    };
    const result = MealAnalysisSchema.safeParse(negCal);
    assert(!result.success);
  });

  it('negative carb_g is rejected', () => {
    const negCarb = {
      ...validAnalysis,
      items: [{ ...validAnalysis.items[0], carb_g: -5 }],
    };
    const result = MealAnalysisSchema.safeParse(negCarb);
    assert(!result.success);
  });

  it('calories must be an integer (int constraint)', () => {
    const floatCal = {
      ...validAnalysis,
      items: [{ ...validAnalysis.items[0], calories: 248.5 }],
    };
    const result = MealAnalysisSchema.safeParse(floatCal);
    assert(!result.success, 'Non-integer calories should fail the int() constraint');
  });

  it('notes field is optional', () => {
    const { notes: _notes, ...withoutNotes } = validAnalysis;
    const result = MealAnalysisSchema.safeParse(withoutNotes);
    assert(result.success);
  });

  it('totals.calories must be nonnegative integer', () => {
    const negTotals = { ...validAnalysis, totals: { ...validAnalysis.totals, calories: -1 } };
    const result = MealAnalysisSchema.safeParse(negTotals);
    assert(!result.success);
  });

  it('all four suggested_slot values are valid', () => {
    for (const slot of ['breakfast', 'lunch', 'dinner', 'snack']) {
      const result = MealAnalysisSchema.safeParse({ ...validAnalysis, suggested_slot: slot });
      assert(result.success, `slot '${slot}' should be valid`);
    }
  });

  it('all three confidence values are valid', () => {
    for (const conf of ['low', 'medium', 'high']) {
      const result = MealAnalysisSchema.safeParse({ ...validAnalysis, confidence: conf });
      assert(result.success, `confidence '${conf}' should be valid`);
    }
  });
});

// ---------------------------------------------------------------------------
// B. photo_path authorization logic
// ---------------------------------------------------------------------------

describe('B. photo_path authorization — user-id prefix check', () => {
  const userId = 'abc-123-user-id';

  it('path starting with userId/ is authorized', () => {
    const photoPath = `${userId}/some-uuid.jpg`;
    assert(photoPath.startsWith(`${userId}/`));
  });

  it('path starting with a different userId is denied', () => {
    const photoPath = `other-user-id/some-uuid.jpg`;
    assert(!photoPath.startsWith(`${userId}/`));
  });

  it('path equal to userId (no trailing slash) is denied', () => {
    // Without the trailing slash, startsWith still passes — this is a gotcha.
    // The code uses `${user.id}/` with the slash so `userId` alone is denied.
    const photoPath = userId;
    assert(!photoPath.startsWith(`${userId}/`));
  });

  it('path with userId embedded elsewhere is denied', () => {
    const photoPath = `attacker/${userId}/photo.jpg`;
    assert(!photoPath.startsWith(`${userId}/`));
  });

  it('empty photo_path is denied (does not start with userId/)', () => {
    const photoPath = '';
    assert(!photoPath.startsWith(`${userId}/`));
  });

  it('photo_path with different uuid but correct userId is authorized', () => {
    const photoPath = `${userId}/00000000-0000-0000-0000-000000000000.png`;
    assert(photoPath.startsWith(`${userId}/`));
  });
});

// ---------------------------------------------------------------------------
// C. MIME type inference from path extension
// ---------------------------------------------------------------------------

describe('C. MIME type inference from extension', () => {
  /** Mirrors the mimeType logic in analyze-meal-photo/index.ts */
  function inferMimeType(photoPath: string): string {
    const ext = photoPath.split('.').pop()?.toLowerCase();
    return ext === 'png' ? 'image/png'
      : ext === 'webp' ? 'image/webp'
      : ext === 'gif' ? 'image/gif'
      : 'image/jpeg';
  }

  it('.jpg → image/jpeg', () => {
    assertEquals(inferMimeType('user/photo.jpg'), 'image/jpeg');
  });

  it('.jpeg → image/jpeg', () => {
    assertEquals(inferMimeType('user/photo.jpeg'), 'image/jpeg');
  });

  it('.png → image/png', () => {
    assertEquals(inferMimeType('user/photo.png'), 'image/png');
  });

  it('.webp → image/webp', () => {
    assertEquals(inferMimeType('user/photo.webp'), 'image/webp');
  });

  it('.gif → image/gif', () => {
    assertEquals(inferMimeType('user/photo.gif'), 'image/gif');
  });

  it('no extension → image/jpeg (default)', () => {
    assertEquals(inferMimeType('user/photo'), 'image/jpeg');
  });

  it('unknown extension → image/jpeg (default)', () => {
    assertEquals(inferMimeType('user/photo.bmp'), 'image/jpeg');
  });

  it('UPPERCASE extension (after .toLowerCase()) → correct MIME', () => {
    // The code does .toLowerCase() before the comparison
    assertEquals(inferMimeType('user/photo.PNG'), 'image/png');
  });
});

// ---------------------------------------------------------------------------
// D. Chunked base64 encoding — the production code uses chunked encoding
//    to avoid call-stack overflow on large images. Verify it matches btoa()
//    for small inputs.
// ---------------------------------------------------------------------------

describe('D. Chunked base64 encoding correctness', () => {
  /** Mirrors the chunked base64 encoding in analyze-meal-photo/index.ts */
  function chunkedBase64(uint8: Uint8Array, chunkSize = 8192): string {
    let binary = '';
    for (let i = 0; i < uint8.length; i += chunkSize) {
      binary += String.fromCharCode(...uint8.subarray(i, i + chunkSize));
    }
    return btoa(binary);
  }

  it('small payload encodes identically to naive btoa()', () => {
    const data = new TextEncoder().encode('Hello, world!');
    const naive = btoa(String.fromCharCode(...data));
    const chunked = chunkedBase64(data, 8192);
    assertEquals(chunked, naive);
  });

  it('empty payload encodes to empty base64 string', () => {
    const data = new Uint8Array(0);
    const result = chunkedBase64(data);
    assertEquals(result, '');
  });

  it('chunk boundary: payload exactly chunkSize bytes encodes correctly', () => {
    const chunkSize = 8192;
    const data = new Uint8Array(chunkSize).fill(65); // all 'A'
    const naive = btoa(String.fromCharCode(...data));
    const chunked = chunkedBase64(data, chunkSize);
    assertEquals(chunked, naive);
  });

  it('chunk boundary: payload exactly chunkSize+1 bytes spans two chunks', () => {
    const chunkSize = 8;  // use tiny chunk to test boundary
    const data = new Uint8Array(9).fill(66); // 9 bytes, crosses chunk boundary
    const naive = btoa(String.fromCharCode(...data));
    const chunked = chunkedBase64(data, chunkSize);
    assertEquals(chunked, naive);
  });
});

// ---------------------------------------------------------------------------
// E. "Not food" is an answer now (ai-cost ticket 08, mp-473)
//
// It used to be a zod parse failure the function string-matched, and the
// section that stood here recorded why that never fired: zod says "Required at
// items", not "not_food", so a landscape photo came back a 500. `not_food` is
// part of the schema the model answers in, so the flag arrives intact.
// ---------------------------------------------------------------------------

describe('E. not food', () => {
  it('the model can answer with the flag and no items, and the schema takes it', () => {
    const parsed = MealAnalysisRequestSchema.safeParse({
      name: 'A dog on a sofa',
      not_food: true,
      items: [],
    });
    assert(parsed.success, 'the not-food answer is a valid model answer, not a parse failure');
  });

  it('the flag returns the not-food answer and no macros', () => {
    const final = finalizeAnalysis(
      MealAnalysisRequestSchema.parse({ name: 'A dog on a sofa', not_food: true, items: [] }),
    );
    assertEquals(final, { notFood: true });
  });

  it('a photo the model returned no items for is the same answer', () => {
    assertEquals(
      finalizeAnalysis(MealAnalysisRequestSchema.parse({ name: 'Unclear', items: [] })),
      { notFood: true },
    );
  });

  it('the body is a code and a 422, never prose — the line is content-managed', () => {
    assertEquals(NOT_FOOD_BODY, { error: 'not_food' });
    assertEquals(NOT_FOOD_STATUS, 422);
  });

  it('a real meal is never the not-food answer', () => {
    const final = finalizeAnalysis(MealAnalysisRequestSchema.parse({
      name: 'Burrito',
      suggested_slot: 'lunch',
      confidence: 'high',
      items: [{ name: 'Burrito', portion: '1', calories: 640, carb_g: 72, protein_g: 30, fat_g: 24, sodium_mg: 1200 }],
    }));
    assert(!final.notFood);
  });
});

// ---------------------------------------------------------------------------
// E2. Prompt shape: instructions first with a one-hour marker, photo last
// ---------------------------------------------------------------------------

describe('E2. Prompt shape', () => {
  const prompt = mealPhotoPrompt({
    base64Image: 'BASE64BYTES',
    mediaType: 'image/jpeg',
    description: '  a big plate of ramen  ',
  });

  it('the instructions come first, in a system message, and hold no athlete text', () => {
    assertEquals(prompt.system.role, 'system');
    assertEquals(prompt.system.content, MEAL_PHOTO_INSTRUCTIONS);
    assert(!MEAL_PHOTO_INSTRUCTIONS.includes('ramen'));
    assert(!MEAL_PHOTO_INSTRUCTIONS.includes('BASE64BYTES'));
  });

  it('the system message carries a one-hour cache marker', () => {
    assertEquals(prompt.system.providerOptions, MEAL_ANALYSIS_CACHE_OPTIONS);
    assertEquals(MEAL_ANALYSIS_CACHE_OPTIONS, {
      anthropic: { cacheControl: { type: 'ephemeral', ttl: '1h' } },
    });
  });

  it('the photo and the words typed with it are last, and nothing follows them', () => {
    assertEquals(prompt.messages.length, 1, "the athlete's input is the only message");
    assertEquals(prompt.messages[0], {
      role: 'user',
      content: [
        { type: 'image', image: 'BASE64BYTES', mediaType: 'image/jpeg' },
        { type: 'text', text: 'a big plate of ramen' },
      ],
    });
  });

  it('a photo with no words sends the photo alone', () => {
    const bare = mealPhotoPrompt({ base64Image: 'B', mediaType: 'image/png' });
    assertEquals(bare.messages[0].content, [{ type: 'image', image: 'B', mediaType: 'image/png' }]);
    assertEquals(bare.system, prompt.system, 'the cached prefix does not move with the words');
  });

  it('two different photos send byte-identical instructions', () => {
    const a = mealPhotoPrompt({ base64Image: 'AAA', mediaType: 'image/jpeg' });
    const b = mealPhotoPrompt({ base64Image: 'BBB', mediaType: 'image/png', description: 'lunch' });
    assertEquals(a.system, b.system);
  });

  it('the instructions still carry the wording the estimates depend on', () => {
    assert(MEAL_PHOTO_INSTRUCTIONS.includes('do NOT underestimate'));
    assert(MEAL_PHOTO_INSTRUCTIONS.includes('endurance athlete'));
    assert(MEAL_PHOTO_INSTRUCTIONS.includes('Do NOT compute totals'));
    assert(MEAL_PHOTO_INSTRUCTIONS.includes('Never return a placeholder item'));
  });
});

// ---------------------------------------------------------------------------
// E3. The function adds up the totals; the model's are ignored (mp-473)
// ---------------------------------------------------------------------------

describe('E3. Totals are ours', () => {
  it("a mismatched model answer is thrown away and the items are summed", () => {
    const final = finalizeAnalysis(MealAnalysisRequestSchema.parse({
      name: 'Plate',
      suggested_slot: 'dinner',
      confidence: 'medium',
      items: [
        { name: 'Rice', portion: '2 cups', calories: 410, carb_g: 89.5, protein_g: 8.4, fat_g: 0.8, sodium_mg: 4 },
        { name: 'Chicken thigh', portion: '1', calories: 280, carb_g: 0, protein_g: 26.1, fat_g: 19.2, sodium_mg: 320 },
      ],
      totals: { calories: 99999, carb_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0 },
    }));
    assert(!final.notFood);
    if (final.notFood) return;
    assertEquals(final.analysis.totals, {
      calories: 690,
      carb_g: 89.5,
      protein_g: 34.5,
      fat_g: 20,
      sodium_mg: 324,
    });
    assert(MealAnalysisSchema.safeParse(final.analysis).success, 'the app still gets its own shape');
  });

  it('a partial model totals object is ignored too, not merged', () => {
    const items = [{ name: 'Toast', portion: '2 slices', calories: 160, carb_g: 30, protein_g: 6, fat_g: 2, sodium_mg: 290 }];
    const final = finalizeAnalysis(
      MealAnalysisRequestSchema.parse({ name: 'Toast', items, totals: { calories: 5 } }),
    );
    assert(!final.notFood);
    if (final.notFood) return;
    assertEquals(final.analysis.totals, sumTotals(items));
  });
});

// ---------------------------------------------------------------------------
// F. AI_COACH_MODEL default value
// ---------------------------------------------------------------------------

describe('F. ANALYZE_MEAL_PHOTO_MODEL default', () => {
  it('resolves to Sonnet when env not set', () => {
    // This function reads ANALYZE_MEAL_PHOTO_MODEL, not AI_COACH_MODEL — and it
    // asserts the REAL exported constant rather than re-typing the fallback,
    // which is what let the earlier Haiku swap slip past this test unchanged.
    assertEquals(Deno.env.get('ANALYZE_MEAL_PHOTO_MODEL'), undefined);
    assertEquals(ANALYZE_MEAL_PHOTO_MODEL, 'anthropic/claude-sonnet-4.6');
  });
});
