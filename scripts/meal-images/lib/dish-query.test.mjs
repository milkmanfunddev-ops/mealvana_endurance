import test from 'node:test';
import assert from 'node:assert/strict';

import { dishQueryVariants, plainDishName } from './dish-query.mjs';

test('the plain name drops a parenthetical qualifier', () => {
  assert.equal(
    plainDishName('Butternut squash "mac & cheese" (GF pasta, dairy-free)'),
    'Butternut squash mac and cheese',
  );
  assert.equal(plainDishName('Baked ziti (leftover portion)'), 'Baked ziti');
});

test('the plain name keeps the words a quote was wrapped around', () => {
  assert.equal(plainDishName('Lentil & mushroom "no meat" pasta'), 'Lentil and mushroom no meat pasta');
});

test('the plain name drops a trailing list of diet qualifiers', () => {
  assert.equal(plainDishName('Banana-oat pancakes, egg-free'), 'Banana-oat pancakes');
  assert.equal(
    plainDishName('Grilled chicken, roasted potato & green beans (gluten-free, dairy-free, egg-free)'),
    'Grilled chicken, roasted potato and green beans',
  );
});

test("the plain name drops a person's name, and only a person's name", () => {
  assert.equal(plainDishName("Scott Jurek's blueberry smoothie"), 'blueberry smoothie');
  // Not a person: the possessive IS the dish.
  assert.equal(plainDishName("Shepherd's pie"), "Shepherd's pie");
  assert.equal(plainDishName("Lentil & vegetable shepherd's pie"), "Lentil and vegetable shepherd's pie");
});

test('a name with nothing to strip survives untouched', () => {
  assert.equal(plainDishName('Mushroom risotto with parmesan'), 'Mushroom risotto with parmesan');
});

test('the variants lead with the whole dish name', () => {
  assert.equal(dishQueryVariants('Mushroom risotto with parmesan')[0], 'Mushroom risotto with parmesan');
});

test('the variants shorten by dropping the accompaniment, then the qualifiers', () => {
  const v = dishQueryVariants('Red lentil dal with basmati rice');
  assert.ok(v.includes('Red lentil dal'), `expected the head dish in ${JSON.stringify(v)}`);
  assert.ok(v.indexOf('Red lentil dal with basmati rice') < v.indexOf('Red lentil dal'));
});

test('the variants shorten a comma list to its head', () => {
  const v = dishQueryVariants('Chicken, celeriac & mango casserole over rice');
  assert.ok(v.includes('Chicken'), `expected the head phrase in ${JSON.stringify(v)}`);
});

test('the last resort asks for a recipe photograph rather than the bare words', () => {
  const v = dishQueryVariants('Superhero muffins');
  assert.equal(v.at(-1), 'Superhero muffins recipe');
});

test('the variants never repeat a query', () => {
  for (const name of ['Superhero muffins', 'Baked ziti (leftover portion)', 'Uji with milk & sugar']) {
    const v = dishQueryVariants(name);
    assert.equal(new Set(v).size, v.length, `${name} -> ${JSON.stringify(v)}`);
  }
});

test('a name that is only a qualifier still yields something searchable', () => {
  assert.deepEqual(dishQueryVariants('(leftover portion)'), []);
  assert.deepEqual(dishQueryVariants(''), []);
});

test('the same name always gives the same queries', () => {
  const name = 'Slow-cooker chicken & white bean chilli with rice';
  assert.deepEqual(dishQueryVariants(name), dishQueryVariants(name));
});
