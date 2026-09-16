/**
 * Playtest 2026-09-16 §5, option A: a saved meal made from a log carries the dish as its one item, so the shopping
 * list read "Egg & veggie scramble — 4 serving". The detector tells that row from a "Save to mine" copy; the hook
 * extracts ingredients once (model faked) when such a meal joins a plan; the grocery builder prefers them.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { isDishLevel, hasQuantityUnit, ensureSavedMealIngredients, extractIngredients, toStoredIngredients, ingredientsPrompt, ingredientDeps } from '../../_shared/vana/saved-ingredients.ts';
import type { IngredientDeps, IngredientsOut } from '../../_shared/vana/saved-ingredients.ts';
import { savedMealIngredients, buildShoppingList } from '../../_shared/vana/grocery.ts';
import { addMealById, getPlanById } from '../../_shared/vana/plan.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const SCRAMBLE_ID = 'fd993bbb-a13a-43e7-a662-ea71ed2ae64a';

/** The real dev row (saved_meals fd993bbb…, read 2026-09-16): one dish-level item, macros, "1 serving", notes. */
const scramble = (over: Partial<Row> = {}): Row => ({
  id: SCRAMBLE_ID, user_id: U, name: 'Egg & Veggie Scramble', is_deleted: false, library_meal_id: null, meal_types: ['breakfast'], batch: false, icon: null,
  calories: 280, carbs_g: '8.0', protein_g: '22.0', fat_g: '18.0',
  notes: 'Low heat, butter, splash of cream. Two eggs per serving.',
  items: [{ calories: 280, carb_g: 8, fat_g: 18, name: 'Egg & Veggie Scramble', portion: '1 serving', protein_g: 22 }],
  ingredients_json: null, ...over,
});
/** A "Save to mine" copy (dev row 5dc40ba5…, AD-008): real ingredient rows with amounts and roles, no macros on the rows. */
const salmonCopy = (over: Partial<Row> = {}): Row => ({
  id: '5dc40ba5-3fc5-4a29-8e50-0f3a7c5db6d8', user_id: U, name: 'Salmon, brown rice & zucchini', is_deleted: false, library_meal_id: 'AD-008', meal_types: ['dinner'], batch: true, icon: null,
  calories: 620, carbs_g: '55.0', protein_g: '42.0', fat_g: '22.0', notes: null,
  items: [{ name: 'salmon fillet', portion: '180 g', role: 'protein' }, { name: 'brown rice', portion: '1 cup', role: 'carb' }, { name: 'zucchini', portion: '1', role: 'veg' }],
  ingredients_json: null, ...over,
});

const SCRAMBLE_OUT: IngredientsOut = { ingredients: [
  { name: 'eggs', qty: 2, unit: null }, { name: 'bell pepper', qty: 0.5, unit: null }, { name: 'spinach', qty: 1, unit: 'cup' },
  { name: 'butter', qty: 1, unit: 'tbsp' }, { name: 'cream', qty: 1, unit: 'tbsp' }, { name: 'Eggs', qty: 1, unit: 'servings' },
] };

/** A model stand-in that answers with a fixed list and counts how often it was asked. */
function fixedModel(object: IngredientsOut = SCRAMBLE_OUT) {
  const calls: { system: string; prompt: string }[] = [];
  const deps: IngredientDeps = { generate: (input) => { calls.push(input); return Promise.resolve({ object, inputTokens: 300, outputTokens: 80 }); } };
  return { deps, calls };
}

// ---------------------------------------------------------------- detector
Deno.test('isDishLevel: the log-made scramble row is dish-level; the "Save to mine" copy is not', () => {
  assertEquals(isDishLevel(scramble().items, 'Egg & Veggie Scramble'), true);
  assertEquals(isDishLevel(salmonCopy().items, 'Salmon, brown rice & zucchini'), false);
});

Deno.test('isDishLevel: no items or one item is dish-level; several items all named as the meal is dish-level', () => {
  assertEquals(isDishLevel([], 'Anything'), true);
  assertEquals(isDishLevel(null, 'Anything'), true);
  assertEquals(isDishLevel([{ name: 'banana', portion: '1' }], 'Banana'), true);
  assertEquals(isDishLevel([{ name: 'Overnight oats', portion: '1 bowl' }, { name: 'overnight oats (large)', portion: '1 bowl' }], 'Overnight oats'), true);
});

Deno.test('isDishLevel: logged foods with macros and no quantity units are dish-level; ingredient rows with units are not', () => {
  // A Describe log with two foods, each a portion of a dish rather than an ingredient amount.
  assertEquals(isDishLevel([{ food_name: 'chicken curry', portion: '1 plate', calories: 520 }, { food_name: 'naan', portion: '1 piece', calories: 260 }], 'Curry night'), false); // "piece" is a unit
  assertEquals(isDishLevel([{ food_name: 'chicken curry', portion: '1 plate', calories: 520 }, { food_name: 'rice', portion: '1 serving', calories: 200 }], 'Curry night'), true);
  assertEquals(isDishLevel([{ name: 'chicken breast', portion: '200 g', calories: 330 }, { name: 'rice', portion: '1 cup', calories: 200 }], 'Chicken and rice'), false);
  assertEquals(hasQuantityUnit('1 serving'), false);
  assertEquals(hasQuantityUnit('180 g'), true);
  assertEquals(hasQuantityUnit('2 cloves'), true);
});

// ---------------------------------------------------------------- output shaping and prompt
Deno.test('toStoredIngredients: numbers and units become qty strings, duplicates and "serving" units are dropped', () => {
  assertEquals(toStoredIngredients(SCRAMBLE_OUT), [
    { name: 'eggs', qty: '2' }, { name: 'bell pepper', qty: '0.5' }, { name: 'spinach', qty: '1 cup' }, { name: 'butter', qty: '1 tbsp' }, { name: 'cream', qty: '1 tbsp' },
  ]);
  assertEquals(toStoredIngredients({ ingredients: [{ name: 'garlic', qty: null, unit: 'clove' }] }), [{ name: 'garlic', qty: 'clove' }]);
});

Deno.test('the prompt carries the name, the logged items, the notes and the per-serving macros', () => {
  const p = ingredientsPrompt({ name: 'Egg & Veggie Scramble', items: scramble().items, notes: scramble().notes, calories: 280, carbsG: 8, proteinG: 22, fatG: 18 });
  assert(p.includes('DISH: Egg & Veggie Scramble'));
  assert(p.includes('- Egg & Veggie Scramble (1 serving)'));
  assert(p.includes('Two eggs per serving'));
  assert(p.includes('kcal 280, carbs g 8, protein g 22, fat g 18'));
});

// ---------------------------------------------------------------- the hook
Deno.test('ensureSavedMealIngredients: one model call writes ingredients_json; a second call finds it present and asks nothing', async () => {
  const v = testCtx({ saved_meals: [scramble()], vana_calls: [] });
  const { deps, calls } = fixedModel();

  assertEquals(await ensureSavedMealIngredients(v, SCRAMBLE_ID, deps), 'extracted');
  assertEquals(calls.length, 1);
  assertEquals(v.fake.rows('saved_meals')[0].ingredients_json, toStoredIngredients(SCRAMBLE_OUT));
  assertEquals(v.fake.writesTo('vana_calls', 'insert').length, 1);
  assertEquals(v.fake.writesTo('vana_calls', 'insert')[0].values.function_name, 'vana.ingredients');

  assertEquals(await ensureSavedMealIngredients(v, SCRAMBLE_ID, deps), 'present');
  assertEquals(calls.length, 1);
});

Deno.test('ensureSavedMealIngredients: a "Save to mine" copy is left alone, and a model failure leaves the column null', async () => {
  const v = testCtx({ saved_meals: [salmonCopy(), scramble()], vana_calls: [] });
  const { deps, calls } = fixedModel();
  assertEquals(await ensureSavedMealIngredients(v, salmonCopy().id, deps), 'not-dish-level');
  assertEquals(calls.length, 0);

  const failing: IngredientDeps = { generate: () => Promise.reject(new Error('gateway down')) };
  assertEquals(await ensureSavedMealIngredients(v, SCRAMBLE_ID, failing), 'failed');
  assertEquals(v.fake.rows('saved_meals').find((r) => r.id === SCRAMBLE_ID)!.ingredients_json, null);
  assertEquals(await ensureSavedMealIngredients(v, 'no-such-id', deps), 'not-found');
});

Deno.test('extractIngredients: the write is conditioned on the column still being null (two adds racing pay once)', async () => {
  const v = testCtx({ saved_meals: [scramble({ ingredients_json: [{ name: 'eggs', qty: '2' }] })], vana_calls: [] });
  const { deps } = fixedModel();
  assertEquals(await extractIngredients(v, scramble(), deps), null);
  assertEquals(v.fake.rows('saved_meals')[0].ingredients_json, [{ name: 'eggs', qty: '2' }]);
});

// ---------------------------------------------------------------- grocery prefers the extracted rows
Deno.test('savedMealIngredients: ingredients_json wins when present, else items (either name key), so the fallback still reads', () => {
  assertEquals(savedMealIngredients(scramble({ ingredients_json: toStoredIngredients(SCRAMBLE_OUT) })).map((i) => i.name), ['eggs', 'bell pepper', 'spinach', 'butter', 'cream']);
  assertEquals(savedMealIngredients(scramble()), [{ name: 'Egg & Veggie Scramble', qty: '1 serving' }]);
  assertEquals(savedMealIngredients(scramble({ ingredients_json: [] })), [{ name: 'Egg & Veggie Scramble', qty: '1 serving' }]);
  assertEquals(savedMealIngredients({ items: [{ food_name: 'oats', quantity: 50 }] }), [{ name: 'oats', qty: '50' }]);
  assertEquals(savedMealIngredients(null), []);
});

const planRow = (): Row => ({ id: 'p1', user_id: U, week_start: '2026-09-13', status: 'draft', batch_cooking: true, conversation_id: null, is_deleted: false, shopping: [], days: {}, rules: [], updated_at: '2026-09-16T00:00:00Z', created_at: '2026-09-16T00:00:00Z' });
const planMeal = (savedMealId: string, name: string): Row => ({ id: `pm-${savedMealId}`, plan_id: 'p1', user_id: U, source: 'saved', library_meal_id: null, saved_meal_id: savedMealId, name, meal_type: 'breakfast', session: null, servings: 4, servings_left: 4, kcal: 280, carbs_g: 8, protein_g: 22, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null });
const world = (over: Partial<Tables> = {}): Tables => ({ meal_plans: [planRow()], plan_meals: [], saved_meals: [scramble()], user_memories: [], meal_logs: [], vana_calls: [], ...over });

Deno.test('buildShoppingList: an extracted saved meal lists its ingredients per aisle; an unextracted one reads "4 servings"', async () => {
  const extracted = testCtx(world({ saved_meals: [scramble({ ingredients_json: toStoredIngredients(SCRAMBLE_OUT) })], plan_meals: [planMeal(SCRAMBLE_ID, 'Egg & Veggie Scramble')] }));
  const plan = (await getPlanById(extracted, 'p1'))!;
  const items = await buildShoppingList(extracted, plan);
  const eggs = items.find((i) => i.name === 'Eggs')!;
  assertEquals(eggs.aisle, 'Protein'); assertEquals(eggs.qty, '8');
  assertEquals(items.find((i) => i.name === 'Spinach')!.qty, '4 cups');
  assert(!items.some((i) => /scramble/i.test(i.name)));

  const raw = testCtx(world({ plan_meals: [planMeal(SCRAMBLE_ID, 'Egg & Veggie Scramble')] }));
  const fallback = await buildShoppingList(raw, (await getPlanById(raw, 'p1'))!);
  assertEquals(fallback.map((i) => [i.name, i.qty]), [['Egg & veggie scramble', '4 servings']]);
});

Deno.test('addMealById on a dish-level saved meal extracts first (model faked), so the list it returns is ingredient lines', async () => {
  const v = testCtx(world());
  const { deps, calls } = fixedModel();
  const real = ingredientDeps.generate; ingredientDeps.generate = deps.generate;
  try {
    const plan = await addMealById(v, 'saved', SCRAMBLE_ID, 4, null, { planId: 'p1' });
    assertEquals(calls.length, 1);
    assertEquals(v.fake.rows('saved_meals')[0].ingredients_json, toStoredIngredients(SCRAMBLE_OUT));
    assertEquals(plan.shopping.find((i) => i.name === 'Eggs')?.qty, '8');
    assert(!plan.shopping.some((i) => /serving/.test(i.qty)));
    // Adding it again (more servings) asks the model nothing.
    await addMealById(v, 'saved', SCRAMBLE_ID, 2, null, { planId: 'p1' });
    assertEquals(calls.length, 1);
  } finally { ingredientDeps.generate = real; }
});

Deno.test('addMealById on a "Save to mine" copy never calls the model and lists its own items', async () => {
  const v = testCtx(world({ saved_meals: [salmonCopy()] }));
  const { deps, calls } = fixedModel();
  const real = ingredientDeps.generate; ingredientDeps.generate = deps.generate;
  try {
    const plan = await addMealById(v, 'saved', salmonCopy().id, 4, null, { planId: 'p1' });
    assertEquals(calls.length, 0);
    assertEquals(v.fake.rows('saved_meals')[0].ingredients_json, null);
    assertEquals(plan.shopping.find((i) => i.name === 'Salmon fillet')?.qty, '720 g');
  } finally { ingredientDeps.generate = real; }
});

Deno.test('refreshShopping backfills a dish-level saved meal already in the plan (one call), and a plain read does not', async () => {
  const { refreshShopping } = await import('../../_shared/vana/plan.ts');
  const v = testCtx(world({ plan_meals: [planMeal(SCRAMBLE_ID, 'Egg & Veggie Scramble'), planMeal(salmonCopy().id, 'Salmon'), { ...planMeal('lib-only', 'Lib'), source: 'library', library_meal_id: 'D-1', saved_meal_id: null }], saved_meals: [scramble(), salmonCopy()], meal_library: [{ id: 'D-1', ingredients_json: [{ name: 'oats', qty: '50 g' }] }] }));
  const { deps, calls } = fixedModel();
  const real = ingredientDeps.generate; ingredientDeps.generate = deps.generate;
  try {
    await getPlanById(v, 'p1');                      // a read: nothing extracted
    assertEquals(calls.length, 0);
    const plan = await refreshShopping(v, 'p1');     // a rebuild: the scramble only, once
    assertEquals(calls.length, 1);
    assertEquals(v.fake.rows('saved_meals').find((r) => r.id === SCRAMBLE_ID)!.ingredients_json, toStoredIngredients(SCRAMBLE_OUT));
    assertEquals(v.fake.rows('saved_meals').find((r) => r.id === salmonCopy().id)!.ingredients_json, null);
    assertEquals(plan.shopping.find((i) => i.name === 'Eggs')?.qty, '8');
    await refreshShopping(v, 'p1');
    assertEquals(calls.length, 1);
  } finally { ingredientDeps.generate = real; }
});
