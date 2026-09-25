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

Deno.test('grocery: whole grains and mixed vegetables take their aisles, not Other (16-007)', () => {
  for (const g of ['farro', 'spelt', 'freekeh', 'bulgur', 'bulgur wheat', 'millet', 'buckwheat', 'wheat berries', 'amaranth', 'sorghum', 'teff', 'pearl barley', 'pearl couscous', 'spelt flour']) assertEquals(classifyAisle(g), 'Bakery & Grains', g);
  for (const veg of ['mixed vegetables', 'mixed veg', 'stir-fry vegetables', 'root vegetables', 'vegetable']) assertEquals(classifyAisle(veg), 'Produce', veg);
  // the broader "vegetable" match never pulls a pantry or freezer line into Produce
  assertEquals(classifyAisle('frozen mixed vegetables'), 'Frozen');
  assertEquals(classifyAisle('vegetable broth'), 'Pantry');
  assertEquals(classifyAisle('vegetable stock'), 'Pantry');
  assertEquals(classifyAisle('vegetable oil'), 'Pantry');
  assertEquals(classifyAisle('canned mixed vegetables'), 'Pantry');
  const aisles = buildItems([{ id: 'a', servings: 2, baseServings: 1, ingredients: [{ name: 'Farro', qty: '200g' }, { name: 'Spelt', qty: '100g' }, { name: 'Mixed vegetables', qty: '100g' }] }], new Set()).map((i) => [i.name, i.aisle]);
  assertEquals(aisles, [['Mixed vegetables', 'Produce'], ['Farro', 'Bakery & Grains'], ['Spelt', 'Bakery & Grains']]);
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

Deno.test('grocery: a cooked-weight grain is bought dry, never at three times the rice (18-006)', () => {
  // Sweet rice cake with jam, added twice from Browse: 8 servings of "Cooked short-grain rice 200g".
  const items = buildItems([
    { id: 'a', servings: 8, baseServings: 1, ingredients: [{ name: 'Cooked short-grain rice', qty: '200g' }, { name: 'Egg', qty: '1' }] },
  ], new Set());
  const rice = items.find((i) => i.name.toLowerCase().includes('rice'))!;
  assert(rice.qty !== '1.6 kg', `bought at cooked weight: ${rice.name} ${rice.qty}`);
  // 1.6 kg cooked × 0.35 (rice's dry/cooked yield) = 560 g dry.
  assertEquals(rice.name, 'Short-grain rice'); assertEquals(rice.qty, '560 g');
  assertEquals(items.find((i) => i.name === 'Egg')!.qty, '8');
});

Deno.test('grocery: cooked weight given in the name or the amount converts per grain, and joins the dry row', () => {
  const items = buildItems([
    { id: 'a', servings: 4, baseServings: 1, ingredients: [{ name: 'white rice, cooked', qty: '200 g' }, { name: 'pasta, cooked', qty: '250 g' }, { name: 'quinoa, cooked', qty: '1/2 cup' }] },
    { id: 'b', servings: 2, baseServings: 1, ingredients: [{ name: 'white rice', qty: '100g dry' }, { name: 'basmati rice', qty: '180g cooked' }, { name: 'rolled oats, cooked in water', qty: '1 cup' }] },
  ], new Set());
  const qty = (n: string) => items.find((i) => i.name === n)?.qty;
  assertEquals(qty('White rice'), '480 g');        // 800 g cooked × 0.35 + 200 g dry
  assertEquals(qty('Basmati rice'), '126 g');      // 360 g cooked × 0.35
  assertEquals(qty('Pasta'), '430 g');             // 1 kg cooked × 0.43
  assertEquals(qty('Quinoa'), '¾ cup');         // 2 cups cooked ÷ 3 = ⅔, shown to the quarter
  assertEquals(qty('Rolled oats'), '1 cup');       // 2 cups cooked × ½
});

Deno.test('grocery: a cooked grain whose amount cannot convert keeps "cooked" in its name', () => {
  const items = buildItems([
    { id: 'a', servings: 5, baseServings: 1, ingredients: [{ name: 'short-grain white rice, cooked with cream cheese', qty: '1 square (~70 g)' }] },
  ], new Set());
  assertEquals(items.map((i) => i.name), ['Cooked short-grain white rice']);
});

Deno.test('grocery: cooked food that is not a grain, and uncooked grain, pass through', () => {
  const items = buildItems([
    { id: 'a', servings: 2, baseServings: 1, ingredients: [{ name: 'chicken breast, grilled', qty: '180 g' }, { name: 'boiled egg', qty: '1' }, { name: 'jasmine rice', qty: '100g dry' }, { name: 'rice vinegar', qty: '1 tbsp' }] },
  ], new Set());
  const qty = (n: string) => items.find((i) => i.name === n)?.qty;
  assertEquals(qty('Chicken breast'), '360 g'); assertEquals(qty('Jasmine rice'), '200 g'); assertEquals(qty('Rice vinegar'), '2 tbsp');
});
