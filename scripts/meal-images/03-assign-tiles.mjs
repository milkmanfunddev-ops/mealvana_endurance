// Pass 3: resolve every meal onto the fallback ladder and write image_tiles.
//
// The rules themselves live in `lib/ladder.mjs` — a pure function with tests
// beside it — so that changing what a meal shows is an edit with an assertion
// next to it rather than surgery on a script that talks to the database. This
// pass is the part that cannot be pure: read the bank, read the meals, apply
// the rules, write the answers, report.
//
// Idempotent: recomputed from scratch on every run. DRY=1 to report without
// writing.
import { selectAll, updateMany } from './lib/db.mjs';
import { resolveMealImage, BLOCKED_REASONS } from './lib/ladder.mjs';

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
const blocked = Object.fromEntries(Object.keys(BLOCKED_REASONS).map((r) => [r, 0]));
let unclassified = 0;

for (const m of meals) {
  if (!m.image_url && m.separability === null) unclassified++;

  const { mode, tiles, blocked: isBlocked, reason } = resolveMealImage(m, bank);
  tally[mode]++;
  if (isBlocked) blocked[reason]++;

  updates.push({ id: m.id, image_tiles: tiles, image_mode: mode, image_blocked: isBlocked });
}

const withImage = tally.dish + tally.mosaic + tally.tile;
console.log(`\nmeals: ${meals.length}`);
for (const k of ['dish', 'mosaic', 'tile', 'none']) {
  console.log(`  ${k.padEnd(7)} ${String(tally[k]).padStart(5)}  ${(100 * tally[k] / meals.length).toFixed(1)}%`);
}
console.log(`\nblocked, by reason:`);
for (const [reason, label] of Object.entries(BLOCKED_REASONS)) {
  console.log(`  ${label.padEnd(45)} ${String(blocked[reason]).padStart(5)}`);
}
if (unclassified) {
  console.log(`\n${unclassified} meals have no separability verdict yet — treated as separable.`);
  console.log('Run pass 7 first for the honest answer.');
}
console.log(`\nCOVERAGE: ${withImage}/${meals.length} = ${(100 * withImage / meals.length).toFixed(1)}%`);

if (DRY) { console.log('\nDRY=1 — nothing written'); process.exit(0); }
const written = await updateMany('meal_library', updates);
console.log(`rows written: ${written}`);
