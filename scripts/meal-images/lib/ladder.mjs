// The ladder: what a Meal shows, decided once, in one place.
//
//   dish   - a real photograph of the meal exists (image_url); tiles unused
//   mosaic - 2-4 ingredient tiles, and the meal is separable
//   tile   - exactly one ingredient tile, and the meal genuinely is one thing
//   none   - nothing honest to show; image_blocked is raised
//
// Three rules decide the rungs, and all three exist because the first version
// of this pass broke them (verified by pass 8, which judges the composed image
// against the meal rather than each tile against its ingredient):
//
//   1. Only SEPARABLE meals may wear tiles. A mosaic promises "these are the
//      things that will be in front of you"; for a smoothie or cherry ice cream
//      that promise is false however good the individual photographs are.
//      Separability comes from pass 7 and cuts across recipe/assembly.
//
//   2. Seasonings, oils and liquids are never tiles. They were previously
//      ranked last but still used when nothing else was left, which is how 15
//      meals — "Sprouted multigrain porridge" among them — ended up represented
//      by a photograph of water over pebbles.
//
//   3. One tile only when the meal really is one thing. "Energy bar, whole" is
//      honest as a single photograph. "Bircher-style oats with peach, cherries
//      & coconut" shown as a photograph of cherries is not: it looks like a
//      picture of the meal and is a picture of one fifth of it.
//
// Pure: no network, no database, no model, no mutation of its arguments. The
// rules are therefore testable on their own (`ladder.test.mjs`), which is the
// point of them living here rather than inline in pass 3.
import { normalizeName, toSlug, isLowValue, roleRank } from './normalize.mjs';

// MIM-3: the grid has room for four cells and no more, so the ladder never
// offers a fifth. One rule, declared where the grid is described.
export { MAX_TILES } from './mosaic-geometry.mjs';
import { MAX_TILES } from './mosaic-geometry.mjs';

/**
 * Why a meal was blocked, and the label pass 3 reports it under, in print order.
 *
 * `no_bank_tile` currently covers two different situations: no tile exists for
 * any ingredient, and every ingredient was dropped by rule 2. A maintainer
 * reading the report cannot tell them apart, and the second kind cannot be
 * helped by sourcing more tiles. Telling them apart is worth doing and is not
 * this change — the rules were moved here without altering a single verdict.
 */
export const BLOCKED_REASONS = {
  transformed: 'transformed (a mosaic would misrepresent it)',
  no_bank_tile: 'no tile in the bank for any ingredient',
  multi_part_single_tile: 'one tile for a meal of several parts',
};

/**
 * Resolve one meal onto the ladder.
 *
 * @param {{image_url?: string|null, separability?: string|null, ingredients_json?: Array<{name: string, role?: string}>|null}} meal
 * @param {Map<string, {slug: string, display_name: string, image_url: string, license: string, creator: string, source_url: string, provider: string}>} bank
 *   Verified ingredient tiles, keyed by slug.
 * @returns {{mode: 'dish'|'mosaic'|'tile'|'none', tiles: Array<object>|null, blocked: boolean, reason: string}}
 */
export function resolveMealImage(meal, bank) {
  if (meal.image_url) {                      // a real dish photo always wins
    return { mode: 'dish', tiles: null, blocked: false, reason: 'dish_photo' };
  }

  // Rule 1: a transformed meal cannot be told by its parts.
  if (meal.separability === 'transformed') {
    return { mode: 'none', tiles: null, blocked: true, reason: 'transformed' };
  }

  const substantive = substantiveIngredients(meal);
  const cands = substantive.filter((c) => bank.has(c.slug));
  // Principal ingredients first: the role that best represents the meal, then
  // original recipe order.
  cands.sort((a, b) => a.rank - b.rank || a.order - b.order);
  const tiles = cands.slice(0, MAX_TILES).map((c) => toTile(bank.get(c.slug)));

  if (tiles.length >= 2) {
    return { mode: 'mosaic', tiles, blocked: false, reason: 'mosaic' };
  }
  // Rule 3: the one tile IS the meal, not one part of it.
  if (tiles.length === 1 && substantive.length === 1) {
    return { mode: 'tile', tiles, blocked: false, reason: 'single_ingredient_meal' };
  }
  return {
    mode: 'none',
    tiles: null,
    blocked: true,
    reason: tiles.length ? 'multi_part_single_tile' : 'no_bank_tile',
  };
}

/**
 * The ingredients that could stand for the meal in a picture, deduplicated and
 * carrying the two things that order them.
 *
 * Rule 2 lives here: seasonings, oils and liquids are dropped outright rather
 * than deprioritised, so they cannot be reached by a meal that has nothing else.
 */
function substantiveIngredients(meal) {
  const seen = new Set();
  const out = [];
  (meal.ingredients_json ?? []).forEach((ing, i) => {
    const norm = normalizeName(ing.name);
    if (!norm || isLowValue(norm)) return;
    const slug = toSlug(norm);
    if (seen.has(slug)) return;
    seen.add(slug);
    out.push({ slug, order: i, rank: roleRank(ing.role) });
  });
  return out;
}

/** A bank row as the app's mosaic widget wants it, attribution included. */
function toTile(row) {
  return {
    slug: row.slug, name: row.display_name, url: row.image_url,
    license: row.license, creator: row.creator,
    sourceUrl: row.source_url, provider: row.provider,
  };
}
