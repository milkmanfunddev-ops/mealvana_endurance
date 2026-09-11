/** Port of the prototype's grocery.test.ts — the pure shopping-list aggregation. */
import { assertEquals, assert } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildItems, parseQty, aggregate, classifyAisle, canonicalName, defaultQty } from '../../_shared/vana/grocery.ts';

Deno.test('grocery: parses portions incl. unicode fractions', () => {
  assertEquals(parseQty('200g'), { n: 200, unit: 'g' });
  assertEquals(parseQty('½'), { n: 0.5, unit: '' });
  assertEquals(parseQty('1/2 cup'), { n: 0.5, unit: 'cup' });
  assertEquals(parseQty('2 tbsp'), { n: 2, unit: 'tbsp' });
  assertEquals(parseQty('splash').n, null);
});

Deno.test('grocery: aggregates across meals with serving multipliers and unit promotion', () => {
  assertEquals(aggregate([{ qty: '200g', mult: 5 }, { qty: '100g', mult: 4 }]), '1.4 kg');
  assertEquals(aggregate([{ qty: '1', mult: 4 }, { qty: '½', mult: 2 }]), '5');
});

Deno.test('grocery: classifies aisles and canonicalises names', () => {
  assertEquals(classifyAisle('chicken breast'), 'Protein');
  assertEquals(classifyAisle('jasmine rice'), 'Bakery & Grains');
  assertEquals(classifyAisle('crushed tomatoes'), 'Pantry');
  assertEquals(classifyAisle('broccoli'), 'Produce');
  assertEquals(canonicalName('Roasted broccoli (florets)'), 'broccoli');
  assertEquals(canonicalName('yellow onion'), 'onion');
});

Deno.test("grocery: builds a deduped, aisle-ordered list, honours pantry 'have', and skips salt/oil", () => {
  const items = buildItems([
    { id: 'a', servings: 5, baseServings: 1, ingredients: [{ name: 'chicken breast', qty: '200g' }, { name: 'jasmine rice', qty: '100g dry' }, { name: 'broccoli', qty: '200g' }, { name: 'salt', qty: 'pinch' }] },
    { id: 'b', servings: 4, baseServings: 1, ingredients: [{ name: 'salmon', qty: '180g' }, { name: 'jasmine rice', qty: '100g dry' }, { name: 'olive oil', qty: '1 tsp' }] },
  ], new Set(['rice']));
  const names = items.map((i) => i.name);
  assert(names.includes('Chicken breast')); assert(!names.includes('Salt')); assert(!names.includes('Olive oil'));
  const rice = items.find((i) => i.name === 'Jasmine rice')!;
  assertEquals(rice.qty, '900 g'); assertEquals(rice.have, true); assertEquals(rice.fromMealIds, ['a', 'b']);
  assertEquals(items[0].aisle, 'Produce'); // broccoli first
});

Deno.test('grocery: blank catalog quantities get a per-serving default that scales (Lee 2026-09-07)', () => {
  assertEquals(defaultQty('cucumber'), '½');
  assertEquals(defaultQty('bell pepper'), '1');
  assertEquals(defaultQty('broccoli'), '1 cup');
  assertEquals(defaultQty('garlic'), '1 clove');
  assertEquals(defaultQty('smoked paprika'), '½ tsp'); // by aisle
  const items = buildItems([
    { id: 'a', servings: 4, baseServings: 1, ingredients: [{ name: 'cucumber', qty: '' }, { name: 'garlic', qty: '' }] },
    { id: 'b', servings: 2, baseServings: 1, ingredients: [{ name: 'garlic cloves', qty: '' }] },
  ], new Set());
  assertEquals(items.find((i) => i.name === 'Cucumber')!.qty, '2');
  const garlic = items.find((i) => i.name === 'Garlic')!;
  assertEquals(garlic.qty, '6 cloves'); assertEquals(garlic.fromMealIds, ['a', 'b']);
  assert(items.every((i) => i.qty !== ''));
});

Deno.test('grocery: always-have matches whole phrases only, never bell pepper', () => {
  const items = buildItems([
    { id: 'a', servings: 1, baseServings: 1, ingredients: [{ name: 'bell pepper', qty: '1' }, { name: 'black pepper', qty: 'pinch' }, { name: 'sea salt', qty: '' }, { name: 'olive oil', qty: '1 tbsp' }] },
  ], new Set());
  assertEquals(items.map((i) => i.name), ['Bell pepper']);
});
