// Pass 6 — send vision-rejected tiles back for another photograph.
//
// Pass 2 walks its ranked candidates only until one *downloads*; whether the
// picture shows the right food is not known until pass 5 looks at it, and a
// rejection there was terminal. So the bank ended up with 192 slugs stuck on a
// wrong photo — and they are not obscure ones. Between them they cover 1,942
// meal references: bread (117 meals) showing a composed avocado toast, quinoa
// (92) showing chickpeas, hummus (62) showing pink donuts, chicken (39) showing
// a live bird. Pass 3 reads only status='ok', so all of that contributes
// nothing to any mosaic.
//
// This pass does not fetch. It resets a rejected slug to 'pending' while
// remembering the URL that failed, so a re-run of pass 2 has to choose
// something else. The loop is:
//
//   node scripts/meal-images/06-retry-rejected.mjs     # arm the retries
//   node scripts/meal-images/02-fetch-images.mjs       # fetch, skipping rejects
//   deno run ... scripts/meal-images/05-vision-verify.ts   # judge the new tiles
//   node scripts/meal-images/03-assign-tiles.mjs       # re-resolve the ladder
//
// Repeat while it keeps recovering slugs. MAX_ATTEMPTS stops a slug that has no
// good photograph anywhere from being retried forever.
//
// Idempotent: a slug already at MAX_ATTEMPTS, or with no URL to blame, is left
// alone. MIN_ROWS=n to retry only ingredients used by at least n meals;
// LIMIT=n to sample; DRY=1 to see the plan without writing.
import { selectAll, updateMany } from './lib/db.mjs';

const MAX_ATTEMPTS = Number(process.env.MAX_ATTEMPTS ?? 4);
const MIN_ROWS = Number(process.env.MIN_ROWS ?? 1);
const LIMIT = Number(process.env.LIMIT ?? 0);
const DRY = process.env.DRY === '1';

let rows = await selectAll(
  'ingredient_images',
  'select=slug,display_name,rows_using,image_url,origin_url,provider,vision_reason,rejected_urls,attempts' +
  '&status=eq.rejected&order=rows_using.desc',
  { key: 'slug' },
);

const skippedExhausted = rows.filter((r) => (r.attempts ?? 0) >= MAX_ATTEMPTS);
rows = rows.filter((r) => (r.attempts ?? 0) < MAX_ATTEMPTS && r.rows_using >= MIN_ROWS);
if (LIMIT) rows = rows.slice(0, LIMIT);

const references = rows.reduce((n, r) => n + (r.rows_using ?? 0), 0);
console.log(`rejected slugs eligible: ${rows.length} (${references} meal references)`);
if (skippedExhausted.length) {
  console.log(`already at ${MAX_ATTEMPTS} attempts, left alone: ${skippedExhausted.length}`);
}
if (!rows.length) { console.log('nothing to retry'); process.exit(0); }

console.log('\ntop of the queue:');
for (const r of rows.slice(0, 15)) {
  console.log(`  ${String(r.rows_using).padStart(4)} meals  ${r.slug.padEnd(22)} ${(r.vision_reason ?? '').slice(0, 58)}`);
}

const updates = rows.map((r) => {
  // origin_url is the provider's own page/file; image_url may be our mirrored
  // copy, which is not what the ranking matches on. Blame both, deduped, so
  // neither route back to the same picture.
  const blame = [...new Set([...(r.rejected_urls ?? []), r.origin_url, r.image_url].filter(Boolean))];
  return {
    slug: r.slug,
    status: 'pending',
    rejected_urls: blame,
    // Clear the failed tile so a half-finished retry can never leave a rejected
    // photograph looking like a live one.
    image_url: null,
    origin_url: null,
    source_url: null,
    license: null,
    creator: null,
    provider: null,
    vision_ok: null,
    vision_reason: null,
    vision_at: null,
    updated_at: new Date().toISOString(),
  };
});

if (DRY) {
  console.log(`\nDRY=1 — would arm ${updates.length} slugs for retry`);
  process.exit(0);
}

const written = await updateMany('ingredient_images', updates, { key: 'slug' });
console.log(`\narmed ${written} slugs for retry (${references} meal references in play)`);
console.log('next: node scripts/meal-images/02-fetch-images.mjs');
