/**
 * Testing-wave 89-003: a meal saved from a log carries the dish as its one item, so its "ingredients" were its own
 * name and the card repeated it under the name. getMeal gives such a meal no ingredients; a real list is kept.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { getMeal } from '../../_shared/vana/meals.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row } from './support/fake_db.ts';

const U = TEST_USER_ID;
const saved = (id: string, name: string, items: Row['items']): Row => ({
  id, user_id: U, name, is_deleted: false, library_meal_id: null, meal_types: ['breakfast'], batch: false, icon: null,
  calories: 280, carbs_g: '8.0', protein_g: '22.0', fat_g: '18.0', items,
});

Deno.test('getMeal: a saved meal whose only item is its own name has no ingredients', async () => {
  const id = 'fd993bbb-a13a-43e7-a662-ea71ed2ae64a';
  const v = testCtx({ saved_meals: [saved(id, 'Egg & Veggie Scramble', [{ name: 'egg & veggie scramble', portion: '1 serving' }])] });
  const meal = await getMeal(v, 'saved', id);
  assertEquals(meal?.name, 'Egg & Veggie Scramble');
  assertEquals(meal?.ingredients, '');
});

Deno.test('getMeal: a saved meal with real items lists them', async () => {
  const id = '5dc40ba5-3fc5-4a29-8e50-0f3a7c5db6d8';
  const v = testCtx({ saved_meals: [saved(id, 'Salmon, brown rice & zucchini', [{ name: 'salmon fillet' }, { food_name: 'brown rice' }])] });
  const meal = await getMeal(v, 'saved', id);
  assertEquals(meal?.ingredients, 'salmon fillet, brown rice');
});
