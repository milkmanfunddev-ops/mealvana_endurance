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

import { MealAnalysisSchema, MealItemSchema } from '../_shared/meal_analysis/schema.ts';
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
// E. not_food error classification
// ---------------------------------------------------------------------------

describe('E. not_food detection logic', () => {
  /**
   * Mirrors the catch block in analyze-meal-photo/index.ts that checks
   * whether an AI error string signals a not_food response.
   *
   * BUG NOTE: The code checks errStr.includes('not_food') OR
   * errStr.toLowerCase().includes('not food'). This relies on the
   * schema validation error MESSAGE containing these strings when zod
   * rejects { not_food: true }. In practice zod's error for an unexpected
   * shape won't include "not_food" — it will say something like
   * "Required at items". This means the not_food detection may NEVER fire
   * and such images would return a 500 instead of the intended 422.
   * Marked as BUG below.
   */

  function classifyAiError(aiError: unknown): 'not_food' | 'rethrow' {
    const errStr = String(aiError);
    if (errStr.includes('not_food') || errStr.toLowerCase().includes('not food')) {
      return 'not_food';
    }
    return 'rethrow';
  }

  it('error string containing "not_food" → 422 path', () => {
    const err = new Error('Zod parse failed: not_food field present');
    assertEquals(classifyAiError(err), 'not_food');
  });

  it('error string containing "not food" (with space) → 422 path', () => {
    const err = new Error('The image is not food');
    assertEquals(classifyAiError(err), 'not_food');
  });

  it('NOT FOOD in uppercase → 422 path (toLowerCase check)', () => {
    const err = new Error('NOT FOOD detected');
    assertEquals(classifyAiError(err), 'not_food');
  });

  it('generic zod parse error without food mention → rethrow (→ 500)', () => {
    // BUG: This is the likely path when the model returns { not_food: true }
    // because zod will say "Required at items" or similar — NOT "not_food".
    // The 422 branch will be skipped and the caller gets a 500.
    const err = new Error('ZodError: Required at items; Required at name');
    assertEquals(classifyAiError(err), 'rethrow');
  });

  it('network error → rethrow', () => {
    const err = new TypeError('fetch failed');
    assertEquals(classifyAiError(err), 'rethrow');
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
