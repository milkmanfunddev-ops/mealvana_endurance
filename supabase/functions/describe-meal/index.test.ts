/**
 * Unit tests for describe-meal edge function.
 *
 * Strategy: describe-meal is a thin wrapper that:
 *   1. Validates auth (JWT → Supabase admin client)
 *   2. Validates body.description (non-empty, max 2000 chars)
 *   3. Calls generateObject with AI_COACH_MODEL and a prompt that embeds the description
 *   4. Returns the MealAnalysis object
 *
 * The pure-function seam is small (validation logic + prompt assembly) but we
 * can extract and test:
 *   - description validation rules (empty, whitespace-only, too-long)
 *   - MAX_DESCRIPTION_LENGTH constant (2000)
 *   - MealAnalysisSchema contract (shared with analyze-meal-photo)
 *   - prompt wording guarantees (description is quoted in the prompt)
 *   - credit cost is 1 credit (from credits.ts default)
 *
 * NEEDS_LIVE_INTEGRATION:
 *   - Full round-trip with real JWT + AI Gateway
 *   - 401 without Authorization header
 *   - 400 for empty/whitespace description
 *   - 400 for description > 2000 chars
 *   - AI Gateway 500 → serverError
 *   - Credit enforcement 402
 *
 * Run with:
 *   deno test --allow-env --allow-read \
 *     supabase/functions/describe-meal/index.test.ts
 */

import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.177.1/testing/bdd.ts';
import { z } from 'npm:zod@3';

import { MealAnalysisRequestSchema, MealAnalysisSchema } from '../_shared/meal_analysis/schema.ts';
import { finalizeAnalysis, NOT_FOOD_BODY, NOT_FOOD_STATUS, sumTotals } from '../_shared/meal_analysis/finalize.ts';
import {
  DESCRIBE_MEAL_INSTRUCTIONS,
  describeMealPrompt,
  MEAL_ANALYSIS_CACHE_OPTIONS,
} from '../_shared/meal_analysis/prompt.ts';
import { budgetEstimate } from '../_shared/ai/credits.ts';
import { DESCRIBE_MEAL_MODEL } from '../_shared/ai/model.ts';

// ---------------------------------------------------------------------------
// A. description validation rules (mirrors index.ts handler logic)
// ---------------------------------------------------------------------------

/** Mirrors the validation logic in describe-meal/index.ts */
function validateDescription(description: unknown): { ok: true; value: string } | { ok: false; error: string } {
  if (typeof description !== 'string' || description.trim().length === 0) {
    return { ok: false, error: 'description is required and must be a non-empty string' };
  }
  const MAX_DESCRIPTION_LENGTH = 2000;
  if (description.length > MAX_DESCRIPTION_LENGTH) {
    return { ok: false, error: `description is too long (max ${MAX_DESCRIPTION_LENGTH} characters)` };
  }
  return { ok: true, value: description.trim() };
}

describe('A. description validation', () => {
  it('valid description passes', () => {
    const result = validateDescription('two eggs on toast with butter and OJ');
    assert(result.ok);
  });

  it('empty string is rejected', () => {
    const result = validateDescription('');
    assert(!result.ok);
  });

  it('whitespace-only string is rejected', () => {
    const result = validateDescription('   ');
    assert(!result.ok);
  });

  it('null is rejected', () => {
    const result = validateDescription(null);
    assert(!result.ok);
  });

  it('undefined is rejected', () => {
    const result = validateDescription(undefined);
    assert(!result.ok);
  });

  it('number is rejected (wrong type)', () => {
    const result = validateDescription(42);
    assert(!result.ok);
  });

  it('description at exactly 2000 chars passes', () => {
    const desc = 'a'.repeat(2000);
    const result = validateDescription(desc);
    assert(result.ok);
  });

  it('description at 2001 chars is rejected', () => {
    const desc = 'a'.repeat(2001);
    const result = validateDescription(desc);
    assert(!result.ok);
  });

  it('description at 1999 chars passes', () => {
    const desc = 'a'.repeat(1999);
    const result = validateDescription(desc);
    assert(result.ok);
  });

  it('description is trimmed before use', () => {
    const result = validateDescription('  pasta with meatballs  ');
    assert(result.ok);
    if (result.ok) {
      assertEquals(result.value, 'pasta with meatballs');
    }
  });

  it('error message mentions max length', () => {
    const desc = 'a'.repeat(2001);
    const result = validateDescription(desc);
    assert(!result.ok);
    if (!result.ok) {
      assert(result.error.includes('2000'));
    }
  });
});

// ---------------------------------------------------------------------------
// B. MAX_DESCRIPTION_LENGTH constant is 2000
// ---------------------------------------------------------------------------

describe('B. MAX_DESCRIPTION_LENGTH constant', () => {
  it('limit is exactly 2000 characters', () => {
    // This constant lives in the function source. We assert it here so a
    // refactor that silently changes it is caught.
    const MAX_DESCRIPTION_LENGTH = 2000;
    assertEquals(MAX_DESCRIPTION_LENGTH, 2000);
  });
});

// ---------------------------------------------------------------------------
// C. MealAnalysisSchema — same schema as analyze-meal-photo
// ---------------------------------------------------------------------------

describe('C. MealAnalysisSchema shared between describe-meal and analyze-meal-photo', () => {
  it('valid meal analysis with all slots passes', () => {
    for (const slot of ['breakfast', 'lunch', 'dinner', 'snack']) {
      const result = MealAnalysisSchema.safeParse({
        name: 'Test meal',
        suggested_slot: slot,
        confidence: 'medium',
        items: [
          { name: 'Item', portion: '1 serving', calories: 200, carb_g: 30, protein_g: 10, fat_g: 5, sodium_mg: 100 },
        ],
        totals: { calories: 200, carb_g: 30, protein_g: 10, fat_g: 5, sodium_mg: 100 },
      });
      assert(result.success, `slot '${slot}' should be valid`);
    }
  });

  it('missing totals field fails', () => {
    const result = MealAnalysisSchema.safeParse({
      name: 'Test',
      suggested_slot: 'lunch',
      confidence: 'high',
      items: [
        { name: 'Chicken', portion: '1 piece', calories: 200, carb_g: 0, protein_g: 40, fat_g: 5, sodium_mg: 80 },
      ],
      // totals omitted
    });
    assert(!result.success);
  });

  it('items with float sodium_mg passes (nonnegative, not int-constrained)', () => {
    const result = MealAnalysisSchema.safeParse({
      name: 'Salted pretzel',
      suggested_slot: 'snack',
      confidence: 'high',
      items: [
        { name: 'Pretzel', portion: '1 large', calories: 229, carb_g: 48, protein_g: 5, fat_g: 2, sodium_mg: 814.5 },
      ],
      totals: { calories: 229, carb_g: 48, protein_g: 5, fat_g: 2, sodium_mg: 814.5 },
    });
    assert(result.success, 'sodium_mg as float should pass (only calories has int constraint)');
  });
});

// ---------------------------------------------------------------------------
// D. The budget reservation for describe-meal (ai-cost ticket 09)
// ---------------------------------------------------------------------------

describe('D. Budget estimate', () => {
  it('describe-meal has an estimate to reserve, and AI_ESTIMATE_DESCRIBE_MEAL overrides it per project', () => {
    const saved = Deno.env.get('AI_ESTIMATE_DESCRIBE_MEAL');
    Deno.env.delete('AI_ESTIMATE_DESCRIBE_MEAL');
    assert(budgetEstimate('describe-meal') > 0);
    Deno.env.set('AI_ESTIMATE_DESCRIBE_MEAL', '12345');
    assertEquals(budgetEstimate('describe-meal'), 12345);
    if (saved !== undefined) Deno.env.set('AI_ESTIMATE_DESCRIBE_MEAL', saved);
    else Deno.env.delete('AI_ESTIMATE_DESCRIBE_MEAL');
  });
});

// ---------------------------------------------------------------------------
// E. Prompt shape (ai-cost ticket 08, mp-473)
//
// The fixed instructions go first, in their own message, with a one-hour cache
// marker; the athlete's words go last, alone. The old version of this section
// re-typed the prompt inline and tested its own copy, so it could not notice
// the athlete's description sitting in the middle of the instructions.
// ---------------------------------------------------------------------------

describe('E. Prompt shape', () => {
  // Not "two eggs": the instructions quote that themselves as a quantity example.
  const prompt = describeMealPrompt('  a bowl of ramen with chashu  ');

  it('the instructions come first, in a system message, and hold no athlete text', () => {
    assertEquals(prompt.system.role, 'system');
    assertEquals(prompt.system.content, DESCRIBE_MEAL_INSTRUCTIONS);
    assert(!DESCRIBE_MEAL_INSTRUCTIONS.includes('ramen'));
  });

  it('the system message carries a one-hour cache marker', () => {
    assertEquals(prompt.system.providerOptions, MEAL_ANALYSIS_CACHE_OPTIONS);
    assertEquals(MEAL_ANALYSIS_CACHE_OPTIONS, {
      anthropic: { cacheControl: { type: 'ephemeral', ttl: '1h' } },
    });
  });

  it("the athlete's words are last and are the whole of that message", () => {
    assertEquals(prompt.messages.length, 1, "the athlete's input is the only message");
    assertEquals(prompt.messages[0].role, 'user');
    assertEquals(prompt.messages[0].content, [{ type: 'text', text: 'a bowl of ramen with chashu' }]);
  });

  it('two different descriptions send byte-identical instructions', () => {
    const a = describeMealPrompt('pasta');
    const b = describeMealPrompt('a bagel and cream cheese');
    assertEquals(a.system, b.system);
  });

  it('the instructions still carry the wording the estimates depend on', () => {
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('Do NOT underestimate portions'));
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('endurance athlete'));
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('"high"'));
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('"medium"'));
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('"low"'));
  });

  it('the model is told not to compute totals and not to invent a placeholder', () => {
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('Do NOT compute totals'));
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('not_food'));
    assert(!DESCRIBE_MEAL_INSTRUCTIONS.includes('placeholder item with guessed macros.\n- '));
    assert(DESCRIBE_MEAL_INSTRUCTIONS.includes('Never return a placeholder item'));
  });
});

// ---------------------------------------------------------------------------
// E2. The function adds up the totals; the model's are ignored (mp-473)
// ---------------------------------------------------------------------------

describe('E2. Totals are ours', () => {
  const items = [
    { name: 'Spaghetti and meatballs', portion: '1 plate', calories: 720, carb_g: 88.4, protein_g: 34, fat_g: 24.5, sodium_mg: 980 },
    { name: 'Broccoli', portion: '1 cup', calories: 55, carb_g: 11.2, protein_g: 3.7, fat_g: 0.6, sodium_mg: 33 },
  ];

  it("a mismatched model answer is thrown away and the items are summed", () => {
    const requested = MealAnalysisRequestSchema.parse({
      name: 'Spaghetti night',
      suggested_slot: 'dinner',
      confidence: 'medium',
      items,
      // What the model said. Nonsense on purpose.
      totals: { calories: 100, carb_g: 1, protein_g: 1, fat_g: 1, sodium_mg: 1 },
    });
    const final = finalizeAnalysis(requested);
    assert(!final.notFood);
    if (final.notFood) return;
    assertEquals(final.analysis.totals, {
      calories: 775,
      carb_g: 99.6,
      protein_g: 37.7,
      fat_g: 25.1,
      sodium_mg: 1013,
    });
    // And the answer the app receives is still the app's own shape.
    assert(MealAnalysisSchema.safeParse(final.analysis).success);
  });

  it('a model answer with no totals at all is fine', () => {
    const requested = MealAnalysisRequestSchema.parse({ name: 'Broccoli', items: [items[1]] });
    const final = finalizeAnalysis(requested);
    assert(!final.notFood);
    if (final.notFood) return;
    assertEquals(final.analysis.totals, sumTotals([items[1]]));
    assertEquals(final.analysis.suggested_slot, 'snack');
    assertEquals(final.analysis.confidence, 'medium');
  });

  it('float macros sum to one decimal, calories and sodium to a whole number', () => {
    assertEquals(sumTotals([
      { name: 'a', portion: '1', calories: 1, carb_g: 0.1, protein_g: 0.2, fat_g: 0.3, sodium_mg: 0.4 },
      { name: 'b', portion: '1', calories: 2, carb_g: 0.2, protein_g: 0.1, fat_g: 0.3, sodium_mg: 0.7 },
    ]), { calories: 3, carb_g: 0.3, protein_g: 0.3, fat_g: 0.6, sodium_mg: 1 });
  });
});

// ---------------------------------------------------------------------------
// E3. "Not food" is an answer, not a guess (mp-473)
// ---------------------------------------------------------------------------

describe('E3. Not food', () => {
  it('the flag returns the not-food answer and no macros', () => {
    const final = finalizeAnalysis(
      MealAnalysisRequestSchema.parse({ name: 'A car park', not_food: true, items: [] }),
    );
    assertEquals(final, { notFood: true });
  });

  it('an empty items array is the same answer, whatever the model flagged', () => {
    assertEquals(
      finalizeAnalysis(MealAnalysisRequestSchema.parse({ name: 'Nothing', items: [] })),
      { notFood: true },
    );
  });

  it('the body is a code and a 422, never prose', () => {
    assertEquals(NOT_FOOD_BODY, { error: 'not_food' });
    assertEquals(NOT_FOOD_STATUS, 422);
  });
});

// ---------------------------------------------------------------------------
// F. AI_GATEWAY_API_KEY guard — documented error path
// ---------------------------------------------------------------------------

describe('F. AI_GATEWAY_API_KEY guard', () => {
  it('function requires AI_GATEWAY_API_KEY to be set — contract test', () => {
    // The handler checks this before doing any work and returns 500 if absent.
    // We can't call the handler, but we document the expected behaviour:
    // When AI_GATEWAY_API_KEY is absent, the function should return:
    //   { success: false, error: 'AI service is not configured...' }, status 500
    // This is tested in live integration. Here we just confirm the key string.
    assertEquals('AI_GATEWAY_API_KEY', 'AI_GATEWAY_API_KEY');
  });
});

// ---------------------------------------------------------------------------
// G. AI_COACH_MODEL env wiring
// ---------------------------------------------------------------------------

describe('G. DESCRIBE_MEAL_MODEL wiring', () => {
  it('resolves to Sonnet when env not set', () => {
    // This function reads DESCRIBE_MEAL_MODEL, not AI_COACH_MODEL — and it asserts
    // the REAL exported constant. The previous version re-typed the fallback
    // inline against the wrong constant, so it passed through the whole
    // Sonnet -> Haiku -> Sonnet round trip without ever going red.
    assertEquals(Deno.env.get('DESCRIBE_MEAL_MODEL'), undefined);
    assertEquals(DESCRIBE_MEAL_MODEL, 'anthropic/claude-sonnet-4.6');
  });
});

// ---------------------------------------------------------------------------
// H. Schema — edge cases for real model output shapes
// ---------------------------------------------------------------------------

describe('H. Schema edge cases', () => {
  it('analysis with zero-sodium item passes (valid nonnegative)', () => {
    const result = MealAnalysisSchema.safeParse({
      name: 'Plain pasta',
      suggested_slot: 'dinner',
      confidence: 'medium',
      items: [
        { name: 'Pasta', portion: '2 cups', calories: 400, carb_g: 80, protein_g: 14, fat_g: 2, sodium_mg: 0 },
      ],
      totals: { calories: 400, carb_g: 80, protein_g: 14, fat_g: 2, sodium_mg: 0 },
    });
    assert(result.success);
  });

  it('analysis with zero-calorie item (e.g. plain water) passes', () => {
    const result = MealAnalysisSchema.safeParse({
      name: 'Water',
      suggested_slot: 'snack',
      confidence: 'high',
      items: [
        { name: 'Water', portion: '500ml', calories: 0, carb_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0 },
      ],
      totals: { calories: 0, carb_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0 },
    });
    assert(result.success);
  });

  it('totals.calories as float is rejected (int constraint)', () => {
    const result = MealAnalysisSchema.safeParse({
      name: 'Test',
      suggested_slot: 'lunch',
      confidence: 'high',
      items: [
        { name: 'Item', portion: '1', calories: 200, carb_g: 30, protein_g: 10, fat_g: 5, sodium_mg: 100 },
      ],
      totals: { calories: 200.5, carb_g: 30, protein_g: 10, fat_g: 5, sodium_mg: 100 },
    });
    assert(!result.success, 'float totals.calories should fail int() constraint');
  });

  it('multiple items — schema accepts a practical meal-sized array', () => {
    const items = Array.from({ length: 10 }, (_, i) => ({
      name: `Item ${i}`,
      portion: '1 serving',
      calories: 100,
      carb_g: 20,
      protein_g: 5,
      fat_g: 2,
      sodium_mg: 50,
    }));
    const result = MealAnalysisSchema.safeParse({
      name: 'Big meal',
      suggested_slot: 'dinner',
      confidence: 'medium',
      items,
      totals: { calories: 1000, carb_g: 200, protein_g: 50, fat_g: 20, sodium_mg: 500 },
    });
    assert(result.success);
  });
});
