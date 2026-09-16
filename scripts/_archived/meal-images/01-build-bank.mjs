// Pass 1: read every meal_library ingredient, normalize it, and seed
// ingredient_images with one row per distinct ingredient ranked by how many
// meals use it. Idempotent — re-running only refreshes rows_using.
import { selectAll, upsert } from './lib/db.mjs';
import { normalizeName, toSlug, isLowValue } from './lib/normalize.mjs';

const meals = await selectAll('meal_library', 'select=id,ingredients_json&is_active=eq.true');
console.log(`meals: ${meals.length}`);

const bank = new Map(); // slug -> {display, aliases:Set, rows:Set}
for (const m of meals) {
  for (const ing of m.ingredients_json ?? []) {
    const norm = normalizeName(ing.name);
    if (!norm) continue;
    const slug = toSlug(norm);
    if (!bank.has(slug)) bank.set(slug, { display: norm, aliases: new Set(), rows: new Set() });
    const e = bank.get(slug);
    e.aliases.add(String(ing.name).toLowerCase());
    e.rows.add(m.id);
  }
}

const rows = [...bank.entries()]
  .map(([slug, e]) => ({
    slug, display_name: e.display,
    aliases: [...e.aliases].slice(0, 25),
    rows_using: e.rows.size,
    // Seasonings sort last so the fetch budget goes to ingredients that
    // actually photograph as food.
    _low: isLowValue(e.display),
  }))
  .sort((a, b) => (a._low - b._low) || (b.rows_using - a.rows_using));

const payload = rows.map(({ _low, ...r }) => r);
await upsert('ingredient_images', payload, 'slug');

console.log(`distinct ingredients: ${payload.length}`);
console.log(`  high-value: ${rows.filter(r => !r._low).length}   low-value: ${rows.filter(r => r._low).length}`);
console.log('\ntop 25:');
for (const r of rows.filter(r => !r._low).slice(0, 25)) console.log(`  ${String(r.rows_using).padStart(4)}  ${r.slug}`);
