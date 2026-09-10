// The grid geometry, tested against the numbers both sides are pinned to.
//
// The Flutter side has the mirror of this file at
// `test/shared/widgets/kyle_design/meal_image_mosaic_geometry_test.dart`. Both
// read `mosaic-geometry.json`, so changing the grid on one side alone breaks
// the other side's test rather than silently invalidating stored verdicts.
//
// Run with:  node --test scripts/meal-images/lib/mosaic-geometry.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { cells, pixelCells, pinnedGeometry, MAX_TILES } from './mosaic-geometry.mjs';

const spec = pinnedGeometry();
const label = (c) => `${c.tiles} tiles at ${c.width}x${c.height}`;

test('the pinned cases are the ones the app and the judge actually draw', () => {
  // A missing case is a case nobody is checking, so the shape of the pinned
  // description is itself asserted: every legal tile count, at a square canvas
  // and a wide one. (The constants are read from this file rather than
  // restated, so asserting them against it would prove nothing.)
  const counts = new Set(spec.cases.map((c) => c.tiles));
  assert.deepEqual([...counts].sort(), [1, 2, 3, 4]);
  assert.ok(spec.cases.some((c) => c.width === c.height), 'a square canvas');
  assert.ok(spec.cases.some((c) => c.width !== c.height), 'a non-square canvas');
  // The hairline has a colour on both sides of it, or the composite is drawn on
  // a background the athlete never sees.
  for (const theme of ['light', 'dark']) {
    assert.match(spec.separator[theme], /^#[0-9A-Fa-f]{6}$/, `${theme} hairline`);
  }
});

for (const c of spec.cases) {
  test(`${label(c)} matches the pinned cells`, () => {
    assert.deepEqual(cells(c.tiles, c.width, c.height, c.gap), c.cells);
  });

  test(`${label(c)} tiles the canvas with nothing but the hairline between`, () => {
    // Stated as properties rather than numbers, so a fixture edited to match a
    // broken formula still fails here.
    const cs = cells(c.tiles, c.width, c.height, c.gap);
    assert.equal(cs.length, c.tiles);
    for (const cell of cs) {
      assert.ok(cell.w > 0 && cell.h > 0, 'no empty cell');
      assert.ok(cell.x >= 0 && cell.y >= 0, 'inside the canvas');
      assert.ok(cell.x + cell.w <= c.width, 'inside the canvas');
      assert.ok(cell.y + cell.h <= c.height, 'inside the canvas');
    }
    // Every pair either overlaps on neither axis, or is separated by exactly
    // the gap on the axis it is split along.
    for (let i = 0; i < cs.length; i++) {
      for (let j = i + 1; j < cs.length; j++) {
        const a = cs[i], b = cs[j];
        const gapX = Math.max(a.x, b.x) - Math.min(a.x + a.w, b.x + b.w);
        const gapY = Math.max(a.y, b.y) - Math.min(a.y + a.h, b.y + b.h);
        assert.ok(
          gapX === c.gap || gapY === c.gap,
          `cells ${i} and ${j} are not one hairline apart`,
        );
      }
    }
    const painted = cs.reduce((sum, cell) => sum + cell.w * cell.h, 0);
    const hairlines = c.width * c.height - painted;
    assert.ok(hairlines >= 0 && hairlines <= c.gap * (c.width + c.height),
      'the only unpainted pixels are the hairline');
  });

  test(`${label(c)} rounds to whole pixels without moving a cell`, () => {
    // The compositor can only paste integer boxes. That rounding is the one
    // difference the two sides are allowed: half a pixel, never more.
    const exact = cells(c.tiles, c.width, c.height, c.gap);
    const px = pixelCells(c.tiles, c.width, c.height, c.gap);
    for (const [i, p] of px.entries()) {
      assert.ok(Number.isInteger(p.x + p.y + p.w + p.h), 'whole pixels');
      assert.ok(Math.abs(p.x - exact[i].x) <= 0.5, `cell ${i} x drifted`);
      assert.ok(Math.abs(p.y - exact[i].y) <= 0.5, `cell ${i} y drifted`);
      assert.ok(Math.abs(p.x + p.w - exact[i].x - exact[i].w) <= 0.5, `cell ${i} right drifted`);
      assert.ok(Math.abs(p.y + p.h - exact[i].y - exact[i].h) <= 0.5, `cell ${i} bottom drifted`);
    }
    // Rounded or not, the grid still reaches both far edges.
    assert.equal(Math.max(...px.map((p) => p.x + p.w)), c.width);
    assert.equal(Math.max(...px.map((p) => p.y + p.h)), c.height);
  });
}

test('the tile count is bounded — the ladder never offers a fifth', () => {
  assert.throws(() => cells(0, 768, 768), /1\.\.4/);
  assert.throws(() => cells(5, 768, 768), /1\.\.4/);
});

test('the judge lays out with this module rather than its own arithmetic', () => {
  // The point of one description is that nobody re-derives it. Pass 8 goes
  // through the shared compositor, and the compositor is handed its cells.
  const pass8 = readFileSync(new URL('../08-verify-meal-image.ts', import.meta.url), 'utf8');
  assert.match(pass8, /compose-mosaic\.mjs/, 'pass 8 must use the shared compositor');
  assert.doesNotMatch(pass8, /PIL|Image\.new/, 'pass 8 must not draw the grid itself');

  const compositor = readFileSync(new URL('./compose-mosaic.mjs', import.meta.url), 'utf8');
  assert.match(compositor, /pixelCells/, 'the compositor must take its cells from here');
  // Delimited by the template literal itself, not by any comment near it.
  const open = compositor.indexOf('`', compositor.indexOf('const COMPOSE'));
  const python = compositor.slice(open + 1, compositor.indexOf('`', open + 1));
  assert.ok(python.includes('PIL'), 'found the compositor source');
  assert.match(python, /job\['cells'\]/, 'the compositor must be handed its cells');
  assert.doesNotMatch(python, /\blen\(|\belif\b/, 'the compositor must not branch on tile count');
});
