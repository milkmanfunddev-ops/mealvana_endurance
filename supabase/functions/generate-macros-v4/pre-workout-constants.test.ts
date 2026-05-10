/**
 * Unit Tests for normalizeToken
 *
 * Validates that the token normalizer correctly maps user-facing display strings
 * (as stored in food_preferences.food_name) to canonical snake_case tokens used
 * in pre_workout_templates.component_food_names.
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/pre-workout-constants.test.ts
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { normalizeToken } from './pre-workout-constants.ts';

// ============================================================================
// Parenthetical qualifier stripping (the #24 bug surface)
// ============================================================================

Deno.test('normalizeToken strips parenthetical qualifiers — display strings from template_foods', () => {
  // These are real user-facing display strings observed in production
  // food_preferences.food_name values, paired with the snake_case token
  // they should match in pre_workout_templates.component_food_names.
  assertEquals(normalizeToken('Oatmeal (½ cup dry)'), 'oatmeal');
  assertEquals(normalizeToken('Bagel (large)'), 'bagel');
  assertEquals(normalizeToken('Cereal (low-fiber type)'), 'cereal');
  assertEquals(normalizeToken('Yogurt (plain)'), 'yogurt');
});

Deno.test('normalizeToken strips parens with leading whitespace before them', () => {
  assertEquals(normalizeToken('Oatmeal  (½ cup dry)'), 'oatmeal');
  assertEquals(normalizeToken('  Bagel   (large)  '), 'bagel');
});

// ============================================================================
// Trailing brand-variant comma suffix stripping
// ============================================================================

Deno.test('normalizeToken strips trailing brand variants after a comma', () => {
  // Real production examples from food_preferences (disliked rows for one user)
  assertEquals(
    normalizeToken('Gatorade Gatorade Thirst Quencher, Orange'),
    'gatorade_gatorade_thirst_quencher',
  );
});

// ============================================================================
// No-regression cases — pre-existing matching must still work
// ============================================================================

Deno.test('normalizeToken preserves already-canonical snake_case tokens', () => {
  assertEquals(normalizeToken('oatmeal'), 'oatmeal');
  assertEquals(normalizeToken('banana'), 'banana');
  assertEquals(normalizeToken('peanut_butter'), 'peanut_butter');
  assertEquals(normalizeToken('sports_drink'), 'sports_drink');
});

Deno.test('normalizeToken still handles existing separator behaviors', () => {
  // "+" → space → underscore
  assertEquals(normalizeToken('peanut + butter'), 'peanut_butter');
  // "-" and "/" → space → underscore
  assertEquals(normalizeToken('Bread / Toast'), 'bread_toast');
  assertEquals(normalizeToken('low-fiber'), 'low_fiber');
});

Deno.test('normalizeToken lowercases as before', () => {
  assertEquals(normalizeToken('Oatmeal'), 'oatmeal');
  assertEquals(normalizeToken('BANANA'), 'banana');
});

// ============================================================================
// Edge cases
// ============================================================================

Deno.test('normalizeToken handles empty and degenerate inputs without crashing', () => {
  assertEquals(normalizeToken(''), '');
  assertEquals(normalizeToken('   '), '');
  // Only parens — nothing left after strip
  assertEquals(normalizeToken('(only parens)'), '');
  // Only a comma suffix
  assertEquals(normalizeToken(', whatever'), '');
});

Deno.test('normalizeToken handles multiple parenthetical groups', () => {
  // Both groups stripped
  assertEquals(normalizeToken('Oatmeal (½ cup) (dry)'), 'oatmeal');
});

// ============================================================================
// Out-of-scope documentation — codifying #24's known limitations
// ============================================================================

Deno.test('normalizeToken does NOT alias divergent canonical tokens (out of #24 scope)', () => {
  // 127 production rows store "oatmeal_cooked" (legacy v3 catalog token).
  // pre_workout_templates uses "oatmeal" — these will still not match after
  // this fix. Resolving requires a synonym map or a backfill migration,
  // which is intentionally out of scope for #24.
  // This test exists to flag when that limitation is later addressed.
  assertEquals(normalizeToken('oatmeal_cooked'), 'oatmeal_cooked');
});
