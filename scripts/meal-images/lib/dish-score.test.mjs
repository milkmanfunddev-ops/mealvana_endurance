import test from 'node:test';
import assert from 'node:assert/strict';

import { dishHeadNoun, rankDishCandidates, scoreDishCandidate } from './dish-score.mjs';

const cand = (title, extra = {}) => ({
  title, provider: 'pexels', url: `https://x/${title}`, width: 900, height: 900, ...extra,
});

test('the head noun is the dish, not what comes with it', () => {
  assert.equal(dishHeadNoun('Mushroom risotto with parmesan'), 'risotto');
  assert.equal(dishHeadNoun('Red lentil dal with basmati rice'), 'dal');
  assert.equal(dishHeadNoun('Chicken tortilla soup'), 'soup');
  // Folded to its singular, because that is what a title is matched against.
  assert.equal(dishHeadNoun('Superhero muffins'), 'muffin');
});

test('a candidate that does not show the dish itself is refused outright', () => {
  // Every other word matches; the thing being photographed does not.
  assert.equal(scoreDishCandidate(cand('mushroom and parmesan pasta'), 'Mushroom risotto with parmesan'), null);
});

test('the head noun matches across singular and plural', () => {
  assert.ok(scoreDishCandidate(cand('blueberry muffin on a plate'), 'Superhero muffins') > 0);
  assert.ok(scoreDishCandidate(cand('a tray of muffins'), 'Superhero muffin') > 0);
});

test('more of the dish named in the title scores higher', () => {
  const name = 'Mushroom risotto with parmesan';
  const specific = scoreDishCandidate(cand('creamy mushroom risotto with parmesan'), name);
  const generic = scoreDishCandidate(cand('risotto'), name);
  assert.ok(specific > generic, `${specific} !> ${generic}`);
});

test('a finished plated dish is what we want here, unlike a tile', () => {
  const name = 'Chicken tortilla soup';
  const plated = scoreDishCandidate(cand('bowl of chicken tortilla soup served with lime'), name);
  const raw = scoreDishCandidate(cand('chicken tortilla soup ingredients isolated on white'), name);
  assert.ok(plated > raw, `${plated} !> ${raw}`);
});

test('packaging, branding and people are pushed down', () => {
  const name = 'Chicken tortilla soup';
  const plain = scoreDishCandidate(cand('chicken tortilla soup'), name);
  for (const bad of [
    'canned chicken tortilla soup product packaging',
    'woman eating chicken tortilla soup portrait',
    'chicken tortilla soup nutrition facts label',
  ]) {
    assert.ok(scoreDishCandidate(cand(bad), name) < plain, bad);
  }
});

test('a picture too small to show at size is pushed down', () => {
  const name = 'Chicken tortilla soup';
  const big = scoreDishCandidate(cand('chicken tortilla soup', { width: 1600, height: 1200 }), name);
  const small = scoreDishCandidate(cand('chicken tortilla soup', { width: 240, height: 200 }), name);
  assert.ok(small < big, `${small} !< ${big}`);
});

test('ranking returns every acceptable candidate, best first', () => {
  const ranked = rankDishCandidates(
    [cand('risotto'), cand('a bicycle'), cand('creamy mushroom risotto with parmesan, served')],
    'Mushroom risotto with parmesan',
  );
  assert.equal(ranked.length, 2);
  assert.equal(ranked[0].title, 'creamy mushroom risotto with parmesan, served');
  assert.ok(ranked[0].score >= ranked[1].score);
});

test('ranking is stable: the same candidates always rank the same way', () => {
  const cands = [cand('risotto'), cand('mushroom risotto'), cand('risotto with parmesan')];
  const a = rankDishCandidates(cands, 'Mushroom risotto with parmesan').map((c) => c.title);
  const b = rankDishCandidates([...cands].reverse(), 'Mushroom risotto with parmesan').map((c) => c.title);
  assert.deepEqual(a, b);
});

test('ranking does not mutate the candidates it was given', () => {
  const cands = [cand('mushroom risotto')];
  rankDishCandidates(cands, 'Mushroom risotto with parmesan');
  assert.deepEqual(Object.keys(cands[0]).includes('score'), false);
});

test('a dish with no name to match refuses everything', () => {
  assert.equal(scoreDishCandidate(cand('anything at all'), ''), null);
  assert.deepEqual(rankDishCandidates([cand('anything at all')], ''), []);
});
