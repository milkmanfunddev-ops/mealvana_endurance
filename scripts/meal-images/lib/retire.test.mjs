// Taking a picture away, tested with no network, no model and no database.
//
// Pass 10 retires a meal's picture when the judge rated it `wrong` and nothing
// better was found. What the meal shows next is the ladder's to decide; what
// these tests hold is that the retired picture can never come back — not from
// the next rung down, not from a later run of pass 3.
//
// Run with:  node --test scripts/meal-images/lib/retire.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { resolveMealImage } from './ladder.mjs';
import { rememberRejected, retire, showsWrongPicture } from './retire.mjs';

/** A bank row as pass 1/2 leaves it, keyed by slug. */
const tile = (slug) => ({
  slug,
  display_name: slug,
  image_url: `https://img.example/${slug}.jpg`,
  license: 'cc-by',
  creator: 'A Photographer',
  source_url: `https://archive.example/${slug}`,
  provider: 'wikimedia',
});
const bankOf = (...slugs) => new Map(slugs.map((s) => [s, tile(s)]));

/** A meal row as pass 10 reads it, showing whatever the ladder gives it. */
function row({ ingredients, bank, verdict = null, ...rest }) {
  const base = {
    id: 'm1',
    name: 'A meal',
    separability: 'separable',
    ingredients_json: ingredients.map((name) => ({ name })),
    image_url: null,
    image_rejected_urls: [],
    image_rejected_mosaics: [],
    ...rest,
  };
  const rung = resolveMealImage(base, bank);
  return {
    ...base,
    image_mode: rung.mode,
    image_tiles: rung.tiles,
    image_blocked: rung.blocked,
    image_verdict: verdict,
    image_verdict_reason: verdict ? 'what the judge saw' : null,
    image_verdict_at: verdict ? '2026-09-10T12:00:00Z' : null,
    ...(rest.image_url
      ? {
        image_source_url: 'https://blog.example/post',
        image_license: 'unknown',
        image_creator: 'A Blogger',
        image_provider: 'wikimedia',
        image_credit: 'A Blogger / Wikimedia',
        image_unlicensed: true,
      }
      : {}),
  };
}

const PHOTO = 'https://img.example/a-carton-of-eggs.jpg';

test('a wrong dish photo is retired to the mosaic the meal is entitled to, unjudged', () => {
  const bank = bankOf('egg', 'turkey-bacon', 'bread');
  const meal = row({ ingredients: ['eggs', 'turkey bacon', 'toast'], bank, image_url: PHOTO, verdict: 'wrong' });

  const next = retire(meal, bank);

  assert.equal(next.image_url, null);
  assert.equal(next.image_mode, 'mosaic');
  assert.deepEqual(next.image_tiles.map((t) => t.slug), ['egg', 'turkey-bacon', 'bread']);
  assert.equal(next.image_blocked, false);
  // The verdict described the photograph, which this meal no longer shows.
  assert.equal(next.image_verdict, null);
  assert.equal(next.image_verdict_reason, null);
  assert.equal(next.image_verdict_at, null);
});

test("a retired photograph takes its attribution with it", () => {
  const bank = bankOf('egg', 'bread');
  const meal = row({ ingredients: ['eggs', 'toast'], bank, image_url: PHOTO, verdict: 'wrong' });

  const next = retire(meal, bank);

  for (const col of ['image_source_url', 'image_license', 'image_creator', 'image_provider', 'image_credit']) {
    assert.equal(next[col], null, col);
  }
  assert.equal(next.image_unlicensed, false);
});

test('a retired photograph is remembered, so no later search offers it to the judge again', () => {
  const bank = bankOf('egg', 'bread');
  const meal = row({ ingredients: ['eggs', 'toast'], bank, image_url: PHOTO, verdict: 'wrong' });

  assert.deepEqual(retire(meal, bank).image_rejected_urls, [PHOTO]);
});

test('a wrong mosaic is retired to nothing, blocked, and says the judge refused it', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'wrong' });

  const next = retire(meal, bank);

  assert.equal(next.image_mode, 'none');
  assert.equal(next.image_tiles, null);
  assert.equal(next.image_blocked, true);
  assert.equal(next.image_blocked_reason, 'grid_refused');
  assert.equal(next.image_verdict, null);
});

test('a wrong single tile is retired to nothing as well', () => {
  const bank = bankOf('energy-bar');
  const meal = row({ ingredients: ['energy bar'], bank, verdict: 'wrong' });
  assert.equal(meal.image_mode, 'tile');

  const next = retire(meal, bank);

  assert.equal(next.image_mode, 'none');
  assert.equal(next.image_blocked_reason, 'grid_refused');
});

// The one that matters most: pass 3 recomputes every meal from scratch, and
// without a memory of the refusal it would hand the grid straight back.
test('a retired mosaic does not come back when pass 3 re-runs the ladder', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'wrong' });

  const next = retire(meal, bank);

  assert.equal(resolveMealImage({ ...meal, ...next }, bank).mode, 'none');
});

// The row's stored tiles are what the athlete was shown, and a stock CDN may
// have served them with resize parameters the bank's copy does not carry.
test('a wrong grid stored with CDN parameters is still recognised when the ladder rebuilds it', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = {
    ...row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'wrong' }),
    image_tiles: [
      { slug: 'cherries', url: 'https://img.example/cherries.jpg?w=600&fit=crop' },
      { slug: 'ice-cream', url: 'https://img.example/ice-cream.jpg?w=600' },
    ],
  };

  const next = retire(meal, bank);

  assert.deepEqual(next.image_rejected_mosaics,
    ['https://img.example/cherries.jpg + https://img.example/ice-cream.jpg']);
  assert.equal(next.image_blocked_reason, 'grid_refused');
});

test('a wrong dish photo whose fallback mosaic was already refused is retired to nothing', () => {
  const bank = bankOf('egg', 'bread');
  const meal = row({
    ingredients: ['eggs', 'toast'],
    bank,
    image_url: PHOTO,
    verdict: 'wrong',
    image_rejected_mosaics: ['https://img.example/egg.jpg + https://img.example/bread.jpg'],
  });

  const next = retire(meal, bank);

  assert.equal(next.image_mode, 'none');
  assert.equal(next.image_blocked_reason, 'grid_refused');
});

test('a wrong dish photo on a transformed meal is retired to its icon', () => {
  const bank = bankOf('banana', 'spinach');
  const meal = row({
    ingredients: ['banana', 'spinach'],
    bank,
    separability: 'transformed',
    image_url: PHOTO,
    verdict: 'wrong',
  });

  const next = retire(meal, bank);

  assert.equal(next.image_mode, 'none');
  assert.equal(next.image_blocked_reason, 'transformed');
});

// Pass 10 replaces a wrong mosaic with a photograph. If that photograph is
// retired one day, the meal must not fall back to the grid it was rescued from.
test('a mosaic replaced by a photograph stays refused after the photograph goes', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'wrong' });

  const served = { ...meal, ...rememberRejected(meal), image_url: 'https://img.example/pink.jpg',
    image_mode: 'dish', image_tiles: null, image_verdict: 'wrong' };

  assert.equal(retire(served, bank).image_mode, 'none');
});

test('a picture the judge did not rate wrong is not remembered as refused', () => {
  const bank = bankOf('cherries', 'ice-cream');
  for (const verdict of ['ok', 'weak', null]) {
    const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict });
    assert.deepEqual(rememberRejected(meal), { image_rejected_urls: [], image_rejected_mosaics: [] }, String(verdict));
  }
});

// Decided 2026-09-10 (Lee): a meal whose photograph was of the wrong food does
// not get to keep a thin grid in its place. The grid it falls back to must be
// `ok`; a `weak` one is refused like a wrong one, and the meal shows its icon.
test('a grid the caller refuses is remembered and retired, whatever its verdict', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'weak' });

  const next = retire(meal, bank, { refuse: true });

  assert.equal(next.image_mode, 'none');
  assert.equal(next.image_blocked_reason, 'grid_refused');
  assert.deepEqual(next.image_rejected_mosaics,
    ['https://img.example/cherries.jpg + https://img.example/ice-cream.jpg']);
  assert.equal(resolveMealImage({ ...meal, ...next }, bank).mode, 'none');
});

test('left to itself, retiring does not refuse a picture the judge did not rate wrong', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'weak' });

  assert.deepEqual(retire(meal, bank).image_rejected_mosaics, []);
});

test('retiring twice records each refusal once', () => {
  const bank = bankOf('cherries', 'ice-cream');
  const meal = row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'wrong' });

  const once = retire(meal, bank);
  const twice = retire({ ...meal, ...once, image_mode: meal.image_mode, image_tiles: meal.image_tiles,
    image_verdict: 'wrong' }, bank);

  assert.equal(twice.image_rejected_mosaics.length, 1);
});

test('retiring mutates neither the meal nor the bank', () => {
  const bank = bankOf('egg', 'bread');
  const meal = row({ ingredients: ['eggs', 'toast'], bank, image_url: PHOTO, verdict: 'wrong' });
  const before = JSON.stringify(meal);
  const bankBefore = JSON.stringify([...bank]);

  retire(meal, bank);

  assert.equal(JSON.stringify(meal), before);
  assert.equal(JSON.stringify([...bank]), bankBefore);
});

test('only a meal actually showing a picture rated wrong is showing a wrong picture', () => {
  const bank = bankOf('cherries', 'ice-cream');
  assert.equal(showsWrongPicture(row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'wrong' })), true);
  assert.equal(showsWrongPicture(row({ ingredients: ['cherries', 'ice cream'], bank, verdict: 'weak' })), false);
  assert.equal(showsWrongPicture({ image_mode: 'none', image_verdict: 'wrong' }), false);
});
