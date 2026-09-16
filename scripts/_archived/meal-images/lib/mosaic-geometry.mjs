// The mosaic grid, described once for both sides of it.
//
// Two programs draw this grid. `MealImageMosaic` draws it for the athlete, in
// Flutter, at whatever size the card or hero gives it. Pass 8 draws it again,
// in Python, to show a judge the picture and record a verdict. Nothing used to
// hold those two together, and drift between them means every stored verdict
// describes a picture no one has ever seen — the sweep bills real money to
// grade an artefact that does not exist.
//
// So neither side computes the layout any more. This module is the layout, the
// numbers it produces are pinned in `mosaic-geometry.json`, and both sides are
// asserted against that file (`mosaic-geometry.test.mjs` here,
// `test/shared/widgets/kyle_design/meal_image_mosaic_geometry_test.dart` there).
//
// The rules, from `docs/ssot/spec/design/components/meal-image-mosaic.md` v1:
//
//   MIM-3  1 tile fills the box. 2 → two equal columns. 3 → one full-height
//          column on the left, two stacked on the right. 4 → 2x2. Never more.
//   MIM-4  every cell is cover-cropped and centred — scaled to fill, then
//          trimmed equally on the overflowing axis. Never letterboxed, never
//          stretched.
//   MIM-7  a GAP-wide surface-coloured hairline is the only separator.
//
// Cells come back in tile order, so cell i shows tile i.
import { readFileSync } from 'node:fs';

const PINNED = JSON.parse(
  readFileSync(new URL('./mosaic-geometry.json', import.meta.url), 'utf8'),
);

/** MIM-7. One logical pixel in Flutter, one image pixel in the compositor. */
export const GAP = PINNED.separator.widthPx;

/** MIM-3. The ladder never offers a fifth tile, and the grid has nowhere to put one. */
export const MAX_TILES = PINNED.maxTiles;

/** MIM-4. The only fit either side may use. */
export const FIT = PINNED.fit;

/** MIM-7. The hairline, by theme — the widget's divider colour, pinned. */
export const HAIRLINE = PINNED.separator;

/**
 * The cell rectangles for `n` tiles in a `width` x `height` box.
 *
 * Fractional on purpose: Flutter's Expanded splits the space left by the
 * hairline in exact halves, so a 768px box with a 1px gap gives 383.5 either
 * side. A raster compositor rounds those edges — see {@link pixelCells} — and
 * that rounding is the only difference the two sides are allowed to have.
 *
 * @param {number} n tile count, 1..4
 * @param {number} width
 * @param {number} height
 * @param {number} [gap]
 * @returns {Array<{x: number, y: number, w: number, h: number}>}
 */
export function cells(n, width, height, gap = GAP) {
  if (!Number.isInteger(n) || n < 1 || n > MAX_TILES) {
    throw new Error(`tile count must be 1..${MAX_TILES}, got ${n}`);
  }
  // The split is symmetric: the two columns are equal, and so are the rows.
  const cw = (width - gap) / 2;
  const ch = (height - gap) / 2;
  const rx = cw + gap;
  const by = ch + gap;

  switch (n) {
    case 1:
      return [{ x: 0, y: 0, w: width, h: height }];
    case 2:
      return [
        { x: 0, y: 0, w: cw, h: height },
        { x: rx, y: 0, w: width - rx, h: height },
      ];
    case 3:
      return [
        { x: 0, y: 0, w: cw, h: height },
        { x: rx, y: 0, w: width - rx, h: ch },
        { x: rx, y: by, w: width - rx, h: height - by },
      ];
    default:
      return [
        { x: 0, y: 0, w: cw, h: ch },
        { x: rx, y: 0, w: width - rx, h: ch },
        { x: 0, y: by, w: cw, h: height - by },
        { x: rx, y: by, w: width - rx, h: height - by },
      ];
  }
}

/**
 * The same cells snapped to whole pixels, for a compositor that can only paste
 * integer boxes. Edges are rounded, never widths, so adjacent cells stay
 * exactly `gap` apart and the grid still reaches both edges of the canvas.
 */
export function pixelCells(n, width, height, gap = GAP) {
  return cells(n, width, height, gap).map((c) => {
    const x = Math.round(c.x);
    const y = Math.round(c.y);
    return {
      x,
      y,
      w: Math.round(c.x + c.w) - x,
      h: Math.round(c.y + c.h) - y,
    };
  });
}

/** The pinned numbers both sides are checked against. */
export function pinnedGeometry() {
  return PINNED;
}
