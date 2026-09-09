// Pass 3: resolve every meal onto the fallback ladder and write image_tiles.
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
// Idempotent: recomputed from scratch on every run. DRY=1 to report without
// writing.
import { selectAll, updateMany } from './lib/db.mjs';
import { normalizeName, toSlug, isLowValue, roleRank } from './lib/normalize.mjs';

const MAX_TILES = 4;
const DRY = process.env.DRY === '1';

const bank = new Map(
  (await selectAll('ingredient_images',
    'select=slug,display_name,image_url,license,creator,source_url,provider&status=eq.ok'))
    .map((r) => [r.slug, r]));
console.log(`bank: ${bank.size} ingredient tiles`);

const meals = await selectAll('meal_library',
  'select=id,name,ingredients_json,image_url,separability&is_active=eq.true');

const updates = [];
const tally = { dish: 0, mosaic: 0, tile: 0, none: 0 };
const blocked = { transformed: 0, no_bank_tile: 0, multi_part_single_tile: 0 };
let unclassified = 0;

for (const m of meals) {
  if (m.image_url) {                       // a real dish photo always wins
    updates.push({ id: m.id, image_tiles: null, image_mode: 'dish', image_blocked: false });
    tally.dish++;
    continue;
  }

  if (m.separability === null) unclassified++;

  // Rule 1: a transformed meal cannot be told by its parts.
  if (m.separability === 'transformed') {
    updates.push({ id: m.id, image_tiles: null, image_mode: 'none', image_blocked: true });
    tally.none++; blocked.transformed++;
    continue;
  }

  // Rule 2: seasonings, oils and liquids are dropped outright, not deprioritised.
  const seen = new Set();
  const substantive = [];
  (m.ingredients_json ?? []).forEach((ing, i) => {
    const norm = normalizeName(ing.name);
    if (!norm || isLowValue(norm)) return;
    const slug = toSlug(norm);
    if (seen.has(slug)) return;
    seen.add(slug);
    substantive.push({ slug, order: i, rank: roleRank(ing.role) });
  });

  // Principal ingredients first: the role that best represents the meal, then
  // original recipe order.
  const cands = substantive.filter((c) => bank.has(c.slug));
  cands.sort((a, b) => a.rank - b.rank || a.order - b.order);

  const tiles = cands.slice(0, MAX_TILES).map((c) => {
    const b = bank.get(c.slug);
    return {
      slug: b.slug, name: b.display_name, url: b.image_url,
      license: b.license, creator: b.creator,
      sourceUrl: b.source_url, provider: b.provider,
    };
  });

  let mode;
  if (tiles.length >= 2) {
    mode = 'mosaic';
  } else if (tiles.length === 1 && substantive.length === 1) {
    // Rule 3: the one tile IS the meal, not one part of it.
    mode = 'tile';
  } else {
    mode = 'none';
    if (!tiles.length) blocked.no_bank_tile++;
    else blocked.multi_part_single_tile++;
  }

  tally[mode]++;
  updates.push({
    id: m.id,
    image_tiles: mode === 'none' ? null : tiles,
    image_mode: mode,
    image_blocked: mode === 'none',
  });
}

const withImage = tally.dish + tally.mosaic + tally.tile;
console.log(`\nmeals: ${meals.length}`);
for (const k of ['dish', 'mosaic', 'tile', 'none']) {
  console.log(`  ${k.padEnd(7)} ${String(tally[k]).padStart(5)}  ${(100 * tally[k] / meals.length).toFixed(1)}%`);
}
console.log(`\nblocked, by reason:`);
console.log(`  transformed (a mosaic would misrepresent it)  ${String(blocked.transformed).padStart(5)}`);
console.log(`  no tile in the bank for any ingredient        ${String(blocked.no_bank_tile).padStart(5)}`);
console.log(`  one tile for a meal of several parts          ${String(blocked.multi_part_single_tile).padStart(5)}`);
if (unclassified) {
  console.log(`\n${unclassified} meals have no separability verdict yet — treated as separable.`);
  console.log('Run pass 7 first for the honest answer.');
}
console.log(`\nCOVERAGE: ${withImage}/${meals.length} = ${(100 * withImage / meals.length).toFixed(1)}%`);

if (DRY) { console.log('\nDRY=1 — nothing written'); process.exit(0); }
const written = await updateMany('meal_library', updates);
console.log(`rows written: ${written}`);
