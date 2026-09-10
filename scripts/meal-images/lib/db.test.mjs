// Paging, tested with no network.
//
// A `Range:`-paged read with no unique ordering is the kind of bug that leaves
// no trace: Postgres makes no promise about row order between two queries, so
// page 2 can repeat rows from page 1 and silently omit others. Pass 3 pages
// 1,922 meals; the meals it missed keep a stale `image_mode` and nothing says
// so. `rows_using.desc` is not a fix — hundreds of ingredients share a count.
//
// Run with:  node --test scripts/meal-images/lib/db.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { withStableOrder } from './db.mjs';

test('an unordered query is given one, so paging cannot repeat or drop rows', () => {
  assert.equal(
    withStableOrder('select=id,name&is_active=eq.true', 'id'),
    'select=id,name&is_active=eq.true&order=id',
  );
});

test('a non-unique order keeps its meaning and gains a tiebreaker', () => {
  assert.equal(
    withStableOrder('select=slug&order=rows_using.desc', 'slug'),
    'select=slug&order=rows_using.desc,slug',
  );
});

test('an order that is already unique is left exactly as it is', () => {
  const q = 'select=id&order=id';
  assert.equal(withStableOrder(q, 'id'), q);
  assert.equal(withStableOrder('select=id&order=name,id', 'id'), 'select=id&order=name,id');
});

test('a descending key still counts as the tiebreaker', () => {
  assert.equal(withStableOrder('select=id&order=id.desc', 'id'), 'select=id&order=id.desc');
});
