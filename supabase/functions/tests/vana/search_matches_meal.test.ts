/**
 * A typed meal search matches the meal, not its research note (testing-wave 18-004, fix ticket 60).
 *
 * "salmon" on a vegetarian account returned eight meals with no salmon: search_meals ranked every row by trigram
 * similarity against `search_text`, which carries the library's `why` (the research note), and filtered nothing.
 * The migration 20260925150000 makes a typed search (no embedding) keep only rows whose name or ingredients hold
 * every word of the query; `searchMeals` applies the same predicate to what the RPC returns.
 *
 * The RPC is faked with rows shaped as the pre-fix function returned them (research-note matches included), so this
 * proves the edge function's filter and the RPC arguments. The SQL itself is proven by a real read after the
 * migration is applied (the lead's close routine).
 *
 * Run: deno test --allow-all supabase/functions/tests/vana/search_matches_meal.test.ts
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { searchMeals, matchesMealText } from '../../_shared/vana/meals.ts';
import { testCtx } from './support/vana_ctx.ts';
import type { Row } from './support/fake_db.ts';

const row = (id: string, name: string, ingredients: string, why: string, over: Record<string, unknown> = {}): Row => ({ source: 'library', id, name, meal_type: 'dinner', contexts: ['everyday'], batch: false, prep_minutes: 20, kcal: 600, carbs_g: 70, protein_g: 35, fat_g: 15, allergens: [], diets_ok: [], swaps: null, why, attribution: 'the library', ingredients, library_meal_id: id, score: 0.5, kind: 'recipe', ...over });

/** What the pre-fix search_meals answered for "salmon": research-note matches ranked alongside a real salmon meal. */
const PRE_FIX_SALMON: Row[] = [
  row('LD-041', 'Tofu, quinoa, asparagus & spinach salad', 'tofu, quinoa, asparagus, spinach, olive oil', 'Dinner: salmon, tofu or steak with some quinoa and asparagus and a spinach salad.', { score: 0.62 }),
  row('LD-007', 'Rice, miso soup, natto & egg', 'rice, miso, natto, egg, nori', "Zach Bitter's recovery-day \"salmon, eggs and red meat\"", { score: 0.58 }),
  row('LD-112', 'Baked salmon, sweet potato & greens', 'salmon fillet, sweet potato, kale, lemon', 'A staple recovery dinner.', { score: 0.55 }),
  row('LD-230', 'Rice bowl', 'rice, smoked Salmon, avocado, cucumber', 'Sushi-bowl pattern.', { score: 0.41 }),
  row('3b0c1d4e-0000-4000-8000-000000000001', 'Salmon pasta (mine)', '', 'one of your saved meals', { source: 'saved', score: 0.7, library_meal_id: null }),
  row('LD-300', 'Lentils, brown rice & kale', 'lentils, brown rice, kale', 'his dinner base is salmon or lentils', { score: 0.39 }),
];

Deno.test('"salmon" returns only meals whose name or ingredients contain salmon', async () => {
  const asked: Record<string, unknown>[] = [];
  const v = testCtx({}, { rpc: { search_meals: (args) => { asked.push(args); return PRE_FIX_SALMON; } } });

  const found = await searchMeals(v, { query: 'salmon', embed: false, limit: 12 });

  assertEquals(found.map((m) => m.id), ['LD-112', 'LD-230', '3b0c1d4e-0000-4000-8000-000000000001']);
  for (const m of found) assertEquals(`${m.name} ${m.ingredients}`.toLowerCase().includes('salmon'), true);
  // A typed search sends the query and no embedding, so search_meals runs its name-and-ingredients path.
  assertEquals(asked[0].p_query, 'salmon');
  assertEquals(asked[0].p_embedding, null);
});

Deno.test('every word of the query has to be in the name or ingredients; case and spacing do not matter', () => {
  assertEquals(matchesMealText('  Salmon   RICE ', 'Rice bowl', 'rice, smoked salmon, avocado'), true);
  assertEquals(matchesMealText('salmon rice', 'Baked salmon, sweet potato & greens', 'salmon fillet, sweet potato'), false);
  assertEquals(matchesMealText('salmon', 'Tofu salad', 'tofu, quinoa'), false);
  assertEquals(matchesMealText('', 'Tofu salad', 'tofu, quinoa'), true);
});

Deno.test('a search with no query is not filtered', async () => {
  const v = testCtx({}, { rpc: { search_meals: () => PRE_FIX_SALMON } });
  const found = await searchMeals(v, { mealType: 'dinner', embed: false, limit: 12 });
  assertEquals(found.length, PRE_FIX_SALMON.length);
});
