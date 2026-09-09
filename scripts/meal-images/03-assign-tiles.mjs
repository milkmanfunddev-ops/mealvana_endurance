// Pass 3: resolve every meal onto the fallback ladder and write image_tiles.
//
//   dish   - a real photograph of the meal exists (image_url); tiles unused
//   mosaic - 2-4 ingredient tiles
//   tile   - exactly one ingredient tile
//   none   - nothing usable; the app shows no image at all
//
// Idempotent: recomputed from scratch on every run.
import { selectAll, updateMany } from './lib/db.mjs';
import { normalizeName, toSlug, isLowValue, roleRank } from './lib/normalize.mjs';

const MAX_TILES = 4;

const bank = new Map(
  (await selectAll('ingredient_images',
    'select=slug,display_name,image_url,license,creator,source_url,provider&status=eq.ok'))
    .map((r) => [r.slug, r]));
console.log(`bank: ${bank.size} ingredient tiles`);

const meals = await selectAll('meal_library',
  'select=id,name,ingredients_json,image_url&is_active=eq.true');

const updates = [];
const tally = { dish: 0, mosaic: 0, tile: 0, none: 0 };

for (const m of meals) {
  if (m.image_url) {                       // a real dish photo always wins
    updates.push({ id: m.id, image_tiles: null, image_mode: 'dish' });
    tally.dish++;
    continue;
  }

  const seen = new Set();
  const cands = [];
  (m.ingredients_json ?? []).forEach((ing, i) => {
    const norm = normalizeName(ing.name);
    if (!norm) return;
    const slug = toSlug(norm);
    if (seen.has(slug) || !bank.has(slug)) return;
    seen.add(slug);
    cands.push({ slug, order: i, low: isLowValue(norm) ? 1 : 0, rank: roleRank(ing.role) });
  });

  // Principal ingredients first: real foods before seasonings, then by the
  // role that best represents the meal, then original recipe order.
  cands.sort((a, b) => a.low - b.low || a.rank - b.rank || a.order - b.order);

  const tiles = cands.slice(0, MAX_TILES).map((c) => {
    const b = bank.get(c.slug);
    return {
      slug: b.slug, name: b.display_name, url: b.image_url,
      license: b.license, creator: b.creator,
      sourceUrl: b.source_url, provider: b.provider,
    };
  });

  const mode = tiles.length >= 2 ? 'mosaic' : tiles.length === 1 ? 'tile' : 'none';
  tally[mode]++;
  updates.push({ id: m.id, image_tiles: tiles.length ? tiles : null, image_mode: mode });
}

const written = await updateMany('meal_library', updates);
console.log(`rows written: ${written}`);

const withImage = tally.dish + tally.mosaic + tally.tile;
console.log(`\nmeals: ${meals.length}`);
for (const k of ['dish', 'mosaic', 'tile', 'none']) {
  console.log(`  ${k.padEnd(7)} ${String(tally[k]).padStart(5)}  ${(100 * tally[k] / meals.length).toFixed(1)}%`);
}
console.log(`\nCOVERAGE: ${withImage}/${meals.length} = ${(100 * withImage / meals.length).toFixed(1)}%`);
