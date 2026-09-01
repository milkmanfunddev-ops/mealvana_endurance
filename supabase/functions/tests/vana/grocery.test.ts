/** Port of the prototype's grocery.test.ts — the pure shopping-list aggregation. */
import { assertEquals, assert } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildItems, parseQty, aggregate, classifyAisle, canonicalName } from '../../_shared/vana/grocery.ts';

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
