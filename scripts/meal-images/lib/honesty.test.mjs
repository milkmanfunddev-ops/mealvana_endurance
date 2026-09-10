// The honesty measure, tested with no network, no model and no database.
//
// The number this file defends is the one ticket 03 exists to produce: how many
// Meals are showing something a judge rated honest, versus how many the library
// merely has a picture for. Every assertion is a definition someone argued for,
// so a change to what counts as honest should break exactly one of these.
//
// Run with:  node --test scripts/meal-images/lib/honesty.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  estimateSpend,
  rankByReach,
  renderReport,
  spliceRegion,
  summarise,
} from './honesty.mjs';

/** A meal_library row as passes 3 and 8 leave it. */
const row = (over = {}) => ({
  id: 'm1',
  name: 'A meal',
  image_mode: 'mosaic',
  image_verdict: 'ok',
  image_verdict_reason: 'shows the meal',
  image_blocked: false,
  image_blocked_reason: null,
  frequency: 'common',
  contexts: [],
  allergens: [],
  ...over,
});

// ── what the measure counts ──────────────────────────────────────────────────

test('honesty counts an ok image and an honestly blocked meal, and nothing else', () => {
  const s = summarise([
    row({ id: 'a', image_verdict: 'ok' }),
    row({ id: 'b', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: 'transformed' }),
    row({ id: 'c', image_verdict: 'weak' }),
    row({ id: 'd', image_verdict: 'wrong' }),
  ]);

  assert.equal(s.total, 4);
  assert.equal(s.honest, 2);
  assert.equal(s.honestPct, 50);
});

test('coverage and honesty are different numbers, and both are reported', () => {
  // Four meals all showing a picture; only one of the pictures is honest.
  const s = summarise([
    row({ id: 'a', image_verdict: 'ok' }),
    row({ id: 'b', image_verdict: 'wrong' }),
    row({ id: 'c', image_verdict: 'wrong' }),
    row({ id: 'd', image_verdict: 'weak' }),
  ]);

  assert.equal(s.coverage, 4, 'every meal has a picture');
  assert.equal(s.honest, 1, 'one of them is honest');
});

test('an unjudged meal is not honest — it is unmeasured, and is counted apart', () => {
  const s = summarise([
    row({ id: 'a', image_verdict: null }),
    row({ id: 'b', image_verdict: 'ok' }),
  ]);

  assert.equal(s.unjudged, 1);
  assert.equal(s.honest, 1);
  assert.equal(s.complete, false, 'the measure is not final while a meal is unjudged');
});

test('the measure is complete only when every meal showing a picture has a verdict', () => {
  const s = summarise([
    row({ id: 'a', image_verdict: 'ok' }),
    row({ id: 'b', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: 'transformed' }),
  ]);

  assert.equal(s.unjudged, 0, 'a meal showing nothing needs no verdict');
  assert.equal(s.complete, true);
});

test('a meal showing nothing without the blocked flag is neither honest nor ignored', () => {
  // Pass 3 raises the flag on every `none`, so this row means the two passes
  // disagree. It must not quietly inflate the honesty figure.
  const s = summarise([row({ id: 'a', image_mode: 'none', image_verdict: null, image_blocked: false })]);

  assert.equal(s.honest, 0);
  assert.equal(s.unaccounted, 1);
});

// ── the breakdown ────────────────────────────────────────────────────────────

test('verdicts break down by image mode, dish included', () => {
  const s = summarise([
    row({ id: 'a', image_mode: 'dish', image_verdict: 'ok' }),
    row({ id: 'b', image_mode: 'dish', image_verdict: 'wrong' }),
    row({ id: 'c', image_mode: 'mosaic', image_verdict: 'weak' }),
    row({ id: 'd', image_mode: 'tile', image_verdict: 'ok' }),
    row({ id: 'e', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: 'no_bank_tile' }),
  ]);

  assert.deepEqual(s.byMode.dish, { total: 2, ok: 1, weak: 0, wrong: 1, unjudged: 0 });
  assert.deepEqual(s.byMode.mosaic, { total: 1, ok: 0, weak: 1, wrong: 0, unjudged: 0 });
  assert.deepEqual(s.byMode.tile, { total: 1, ok: 1, weak: 0, wrong: 0, unjudged: 0 });
  assert.equal(s.byMode.none.total, 1);
});

test('the blocked population breaks down by reason', () => {
  const s = summarise([
    row({ id: 'a', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: 'transformed' }),
    row({ id: 'b', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: 'transformed' }),
    row({ id: 'c', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: 'no_bank_tile' }),
    row({ id: 'd', image_mode: 'none', image_verdict: null, image_blocked: true, image_blocked_reason: null }),
  ]);

  assert.equal(s.blocked, 4);
  assert.equal(s.blockedByReason.transformed, 2);
  assert.equal(s.blockedByReason.no_bank_tile, 1);
  assert.equal(s.blockedByReason.unrecorded, 1, 'a blocked meal with no reason is still countable');
});

// ── the work queue ───────────────────────────────────────────────────────────

test('the wrong meals are listed most-surfaced first', () => {
  // search_meals orders a browse rail by score, and the only thing that moves a
  // library meal up that rail is its frequency. So a staple outranks a common
  // one, which outranks an occasional one.
  const ranked = rankByReach([
    row({ id: 'occasional', frequency: 'occasional', image_verdict: 'wrong' }),
    row({ id: 'staple', frequency: 'staple', image_verdict: 'wrong' }),
    row({ id: 'common', frequency: 'common', image_verdict: 'wrong' }),
  ]);

  assert.deepEqual(ranked.map((r) => r.id), ['staple', 'common', 'occasional']);
});

test('among equally frequent meals, the one visible in more rails comes first', () => {
  const ranked = rankByReach([
    row({ id: 'one-rail', contexts: ['weeknight'] }),
    row({ id: 'three-rails', contexts: ['weeknight', 'batch', 'travel'] }),
  ]);

  assert.deepEqual(ranked.map((r) => r.id), ['three-rails', 'one-rail']);
});

test('an allergen hides a meal from athletes, so it surfaces less often', () => {
  const ranked = rankByReach([
    row({ id: 'nuts-and-dairy', allergens: ['tree_nuts', 'dairy'] }),
    row({ id: 'clean', allergens: [] }),
  ]);

  assert.deepEqual(ranked.map((r) => r.id), ['clean', 'nuts-and-dairy']);
});

test('ranking is total and deterministic — id breaks every remaining tie', () => {
  const rows = [row({ id: 'b' }), row({ id: 'a' }), row({ id: 'c' })];

  assert.deepEqual(rankByReach(rows).map((r) => r.id), ['a', 'b', 'c']);
  assert.deepEqual(rankByReach([...rows].reverse()).map((r) => r.id), ['a', 'b', 'c']);
});

test('ranking does not mutate what it is given', () => {
  const rows = [row({ id: 'b' }), row({ id: 'a' })];
  rankByReach(rows);
  assert.deepEqual(rows.map((r) => r.id), ['b', 'a']);
});

// ── what a run cost ──────────────────────────────────────────────────────────

test('spend is priced from the tokens the run actually used', () => {
  // Sonnet 5: $2.00 per million in, $10.00 per million out.
  const usd = estimateSpend({
    model: 'anthropic/claude-sonnet-5',
    inputTokens: 1_000_000,
    outputTokens: 1_000_000,
  });

  assert.equal(usd, 12);
});

test('an unpriced model reports no spend rather than a wrong one', () => {
  assert.equal(
    estimateSpend({ model: 'someone-elses/model', inputTokens: 1_000_000, outputTokens: 0 }),
    null,
  );
});

// ── the record ───────────────────────────────────────────────────────────────

test('the report states both numbers and does not lead with coverage', () => {
  const md = renderReport({
    summary: summarise([
      row({ id: 'a', image_verdict: 'ok' }),
      row({ id: 'b', image_verdict: 'wrong' }),
    ]),
    wrong: [row({ id: 'b', name: 'Cherry ice cream', image_verdict: 'wrong', image_verdict_reason: 'a cherry beside a tub' })],
    geometryVersion: 1,
    at: '2026-09-10T12:00:00.000Z',
  });

  assert.match(md, /50\.0%/, 'the honesty figure');
  assert.match(md, /Cherry ice cream/, 'the work queue');
  assert.match(md, /geometry v1/, 'which grid the verdicts describe');
});

test('a generated region is replaced, and everything around it is left alone', () => {
  const doc = [
    'keep me',
    '<!-- honesty:begin -->',
    'stale',
    '<!-- honesty:end -->',
    'keep me too',
  ].join('\n');

  const out = spliceRegion(doc, 'honesty', 'fresh');

  assert.equal(out, [
    'keep me',
    '<!-- honesty:begin -->',
    'fresh',
    '<!-- honesty:end -->',
    'keep me too',
  ].join('\n'));
});

test('splicing a document with no such region says so rather than losing the text', () => {
  assert.throws(() => spliceRegion('nothing here', 'honesty', 'fresh'), /honesty:begin/);
});
