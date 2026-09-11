// The ladder decision, tested with no network, no model and no database.
//
// Every assertion here is a rule someone argued for in the spec, so a rule
// change should break exactly one of these and read as a deliberate edit.
//
// Run with:  node --test scripts/meal-images/lib/ladder.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { resolveMealImage, pictureIdentity, MAX_TILES } from './ladder.mjs';

/** A bank row as pass 1/2 leaves it, keyed by slug. */
const tile = (slug, extra = {}) => ({
  slug,
  display_name: slug.replace(/-/g, ' '),
  image_url: `https://img.example/${slug}.jpg`,
  license: 'unsplash',
  creator: 'A Photographer',
  source_url: `https://unsplash.example/${slug}`,
  provider: 'unsplash',
  ...extra,
});

const bankOf = (...slugs) => new Map(slugs.map((s) => [s, tile(s)]));

const meal = ({ ingredients, ...rest }) => ({
  id: 'm1',
  name: 'A meal',
  image_url: null,
  separability: 'separable',
  ingredients_json: ingredients.map((i) => (typeof i === 'string' ? { name: i } : i)),
  ...rest,
});

test('a dish photo wins over any number of available tiles', () => {
  const r = resolveMealImage(
    meal({
      image_url: 'https://img.example/the-actual-dish.jpg',
      ingredients: ['rolled oats', 'blueberries', 'walnuts', 'banana', 'yogurt'],
    }),
    bankOf('rolled-oats', 'blueberry', 'walnut', 'banana', 'yogurt'),
  );

  assert.equal(r.mode, 'dish');
  assert.equal(r.tiles, null);
  assert.equal(r.blocked, false);
});

test('a transformed meal with tiles available resolves to none, blocked, with a reason', () => {
  const r = resolveMealImage(
    meal({
      name: 'Cherry ice cream',
      separability: 'transformed',
      ingredients: ['cherries', 'cream', 'sugar'],
    }),
    bankOf('cherry', 'cream'),
  );

  assert.equal(r.mode, 'none');
  assert.equal(r.tiles, null);
  assert.equal(r.blocked, true);
  assert.equal(r.reason, 'transformed');
});

// The reason reads `no_bank_tile` even though the bank holds all three tiles:
// rule 2 dropped them, so from the ladder's side there was nothing to pick. The
// report cannot currently tell this apart from a genuinely empty bank — see the
// note on BLOCKED_REASONS.
test('a meal whose only candidate is a seasoning, oil or liquid resolves to none, not to that tile', () => {
  const r = resolveMealImage(
    meal({ name: 'Sprouted multigrain porridge', ingredients: ['water', 'salt', 'olive oil'] }),
    bankOf('water', 'salt', 'olive-oil'),
  );

  assert.equal(r.mode, 'none');
  assert.equal(r.blocked, true);
  assert.equal(r.reason, 'no_bank_tile');
});

test('a one-ingredient meal with one tile resolves to tile', () => {
  const r = resolveMealImage(
    meal({ name: 'Energy bar, whole', ingredients: ['energy bar'] }),
    bankOf('energy-bar'),
  );

  assert.equal(r.mode, 'tile');
  assert.equal(r.blocked, false);
  assert.deepEqual(r.tiles.map((t) => t.slug), ['energy-bar']);
});

test('seasonings do not stop a meal from being one ingredient', () => {
  const r = resolveMealImage(
    meal({ name: 'Scrambled eggs', ingredients: ['eggs', 'salt', 'black pepper', 'olive oil'] }),
    bankOf('egg'),
  );

  assert.equal(r.mode, 'tile');
  assert.deepEqual(r.tiles.map((t) => t.slug), ['egg']);
});

test('a meal of several ingredients with one tile resolves to none, blocked, and says why', () => {
  const r = resolveMealImage(
    meal({
      name: 'Bircher-style oats with peach, cherries & coconut',
      ingredients: ['rolled oats', 'peach', 'cherries', 'coconut', 'yogurt'],
    }),
    bankOf('peach'),
  );

  assert.equal(r.mode, 'none');
  assert.equal(r.tiles, null);
  assert.equal(r.blocked, true);
  assert.equal(r.reason, 'multi_part_single_tile');
});

test('a separable meal with two to four tiles resolves to mosaic, in principal-ingredient order', () => {
  const r = resolveMealImage(
    meal({
      ingredients: [
        { name: 'blueberries', role: 'fruit' },
        { name: 'rolled oats', role: 'starch' },
        { name: 'chicken breast', role: 'protein' },
      ],
    }),
    bankOf('blueberry', 'rolled-oats', 'chicken-breast'),
  );

  assert.equal(r.mode, 'mosaic');
  assert.equal(r.blocked, false);
  assert.deepEqual(r.tiles.map((t) => t.slug), ['chicken-breast', 'rolled-oats', 'blueberry']);
});

test('ingredients of equal role keep their recipe order', () => {
  const r = resolveMealImage(
    meal({
      ingredients: [
        { name: 'spinach', role: 'veg' },
        { name: 'carrots', role: 'veg' },
      ],
    }),
    bankOf('spinach', 'carrot'),
  );

  assert.deepEqual(r.tiles.map((t) => t.slug), ['spinach', 'carrot']);
});

test('a mosaic is capped at four, and it is the four most principal that survive', () => {
  const r = resolveMealImage(
    meal({
      ingredients: [
        { name: 'walnuts', role: 'fat' },
        { name: 'yogurt', role: 'dairy' },
        { name: 'blueberries', role: 'fruit' },
        { name: 'rolled oats', role: 'starch' },
        { name: 'chicken breast', role: 'protein' },
      ],
    }),
    bankOf('walnut', 'yogurt', 'blueberry', 'rolled-oats', 'chicken-breast'),
  );

  assert.equal(r.mode, 'mosaic');
  assert.equal(r.tiles.length, MAX_TILES);
  // Sorted first, then cut: the fat is what gets dropped, not the protein.
  assert.deepEqual(r.tiles.map((t) => t.slug),
    ['chicken-breast', 'rolled-oats', 'blueberry', 'yogurt']);
});

test('a tile carries the attribution the card needs to credit the photographer', () => {
  const r = resolveMealImage(
    meal({ name: 'Banana', ingredients: ['banana'] }),
    bankOf('banana'),
  );

  assert.deepEqual(r.tiles[0], {
    slug: 'banana',
    name: 'banana',
    url: 'https://img.example/banana.jpg',
    license: 'unsplash',
    creator: 'A Photographer',
    sourceUrl: 'https://unsplash.example/banana',
    provider: 'unsplash',
  });
});

test('the same ingredient named twice contributes one tile', () => {
  const r = resolveMealImage(
    meal({ ingredients: ['banana', 'bananas, sliced'] }),
    bankOf('banana'),
  );

  assert.equal(r.mode, 'tile');
  assert.deepEqual(r.tiles.map((t) => t.slug), ['banana']);
});

test('a meal with no ingredients at all resolves to none', () => {
  const r = resolveMealImage(meal({ ingredients: [] }), bankOf('banana'));

  assert.equal(r.mode, 'none');
  assert.equal(r.reason, 'no_bank_tile');
});

test('a meal never yet classified is treated as separable', () => {
  const r = resolveMealImage(
    meal({ separability: null, ingredients: ['rolled oats', 'blueberries'] }),
    bankOf('rolled-oats', 'blueberry'),
  );

  assert.equal(r.mode, 'mosaic');
});

// Rule 4. A mosaic is the ladder's own choice, so without a memory of the
// judge's answer every re-run of pass 3 would hand a meal back the very grid it
// was retired from.
test('a mosaic the judge rated wrong is not offered to the same meal again', () => {
  const bank = bankOf('cherries', 'cream');
  const m = meal({ name: 'Cherries & cream', ingredients: ['cherries', 'cream'] });
  const shown = resolveMealImage(m, bank);

  const r = resolveMealImage({ ...m, image_rejected_mosaics: [pictureIdentity(shown.tiles)] }, bank);

  assert.equal(r.mode, 'none');
  assert.equal(r.tiles, null);
  assert.equal(r.blocked, true);
  assert.equal(r.reason, 'judged_wrong');
});

test('a single tile the judge rated wrong is not offered again either', () => {
  const bank = bankOf('energy-bar');
  const m = meal({ name: 'Energy bar, whole', ingredients: ['energy bar'] });

  const r = resolveMealImage(
    { ...m, image_rejected_mosaics: [pictureIdentity(resolveMealImage(m, bank).tiles)] },
    bank,
  );

  assert.equal(r.mode, 'none');
  assert.equal(r.reason, 'judged_wrong');
});

// The verdict was about a picture. Once pass 2 replaces a tile's photograph the
// grid is a different picture, and nobody has judged it.
test('a rejected mosaic does not block a different picture of the same ingredients', () => {
  const m = meal({ ingredients: ['cherries', 'cream'] });
  const before = resolveMealImage(m, bankOf('cherries', 'cream'));
  const regrown = new Map([
    ['cherries', tile('cherries', { image_url: 'https://img.example/cherries-v2.jpg' })],
    ['cream', tile('cream')],
  ]);

  const r = resolveMealImage({ ...m, image_rejected_mosaics: [pictureIdentity(before.tiles)] }, regrown);

  assert.equal(r.mode, 'mosaic');
  assert.deepEqual(r.tiles.map((t) => t.url),
    ['https://img.example/cherries-v2.jpg', 'https://img.example/cream.jpg']);
});

test("a stock CDN's resize parameters are not part of a picture's identity", () => {
  const a = [{ url: 'https://images.pexels.com/1.jpeg?w=600' }, { url: 'https://x.example/2.jpg' }];
  const b = [{ url: 'https://images.pexels.com/1.jpeg?w=1200' }, { url: 'https://x.example/2.jpg' }];

  assert.equal(pictureIdentity(a), pictureIdentity(b));
});

// What pass 10 stores, spelled out rather than rebuilt with the function under
// test: rows already in the database are compared against this format, and a
// change to it would silently stop every stored refusal from matching.
test('a stored refusal is the grid\'s photographs in drawing order, joined by " + "', () => {
  const bank = bankOf('cherries', 'cream');
  const m = meal({ ingredients: ['cherries', 'cream'] });

  const r = resolveMealImage({
    ...m,
    image_rejected_mosaics: ['https://img.example/cherries.jpg + https://img.example/cream.jpg'],
  }, bank);

  assert.equal(r.reason, 'judged_wrong');
});

test('a dish photo still wins over a rejected mosaic', () => {
  const bank = bankOf('cherries', 'cream');
  const m = meal({ ingredients: ['cherries', 'cream'] });
  const rejected = [pictureIdentity(resolveMealImage(m, bank).tiles)];

  const r = resolveMealImage(
    { ...m, image_url: 'https://img.example/dish.jpg', image_rejected_mosaics: rejected },
    bank,
  );

  assert.equal(r.mode, 'dish');
  assert.equal(r.blocked, false);
});

test('the same inputs produce the same output on a re-run', () => {
  const m = meal({
    ingredients: [
      { name: 'blueberries', role: 'fruit' },
      { name: 'rolled oats', role: 'starch' },
      { name: 'walnuts', role: 'fat' },
    ],
  });
  const bank = bankOf('blueberry', 'rolled-oats', 'walnut');

  assert.deepEqual(resolveMealImage(m, bank), resolveMealImage(m, bank));
});

test('resolving a meal mutates neither the meal nor the bank', () => {
  const m = meal({ ingredients: ['rolled oats', 'blueberries'] });
  const bank = bankOf('rolled-oats', 'blueberry');
  const mBefore = JSON.stringify(m);
  const bankBefore = JSON.stringify([...bank]);

  resolveMealImage(m, bank);

  assert.equal(JSON.stringify(m), mBefore);
  assert.equal(JSON.stringify([...bank]), bankBefore);
});
