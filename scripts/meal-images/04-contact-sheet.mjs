// Pass 4 (review): render pictures onto contact sheets so a person can look at
// them, rather than reading rows about them. Read-only.
//
// Two subjects, because there are two questions a person asks:
//
//   SUBJECT=bank    every resolved ingredient tile — "is this bank any good?"
//   SUBJECT=meals   the dish photographs meals are showing — "do these belong
//                   beside these names, and does the rail repeat itself?"
//
// The second exists because the judge rates a picture ALONE, against one meal.
// It cannot see that four green smoothies were handed the same photograph, or
// that a page of them reads as one stock library's idea of food. Only a person
// looking at them together can, and this is what they look at.
//
//   SUBJECT=meals SINCE=2026-09-10T19:00 node scripts/meal-images/04-contact-sheet.mjs
//   OUT=/tmp keeps a local copy as well as uploading.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { selectAll, uploadImage } from './lib/db.mjs';

const run = promisify(execFile);
const SUBJECT = process.env.SUBJECT ?? 'bank';
const SINCE = process.env.SINCE ?? '';
const OUT = process.env.OUT ?? '';
// A dish photo is judged as a whole picture, so it needs more room than a tile
// whose only job is to be recognisable as one ingredient.
const COLS = SUBJECT === 'meals' ? 6 : 8;
const CELL = SUBJECT === 'meals' ? 200 : 150;
const PER_SHEET = SUBJECT === 'meals' ? 60 : 96;

const rows = SUBJECT === 'meals'
  ? (await selectAll('meal_library',
      'select=id,name,image_url,image_provider,image_verdict&is_active=eq.true' +
      `&image_mode=eq.dish&image_url=not.is.null${SINCE ? `&image_at=gte.${SINCE}` : ''}&order=id`))
    .map((r) => ({ label: r.name, image_url: r.image_url, provider: r.image_provider }))
  : (await selectAll('ingredient_images',
      'select=slug,image_url,provider,rows_using&status=eq.ok&order=rows_using.desc', { key: 'slug' }))
    .map((r) => ({ label: r.slug, image_url: r.image_url, provider: r.provider }));
console.log(`${SUBJECT}: ${rows.length} pictures`);
if (!rows.length) process.exit(0);

const dir = mkdtempSync(join(tmpdir(), 'mvsheet-'));
const urls = [];
try {
  for (let s = 0; s * PER_SHEET < rows.length; s++) {
    const batch = rows.slice(s * PER_SHEET, (s + 1) * PER_SHEET);
    const files = [];
    await Promise.all(batch.map(async (r, i) => {
      try {
        const res = await fetch(r.image_url);
        if (!res.ok) return;
        const f = join(dir, `${s}_${String(i).padStart(3, '0')}.jpg`);
        writeFileSync(f, Buffer.from(await res.arrayBuffer()));
        files[i] = { f, r };
      } catch { /* a dead tile simply leaves a gap in the sheet */ }
    }));

    const present = files.filter(Boolean);
    if (!present.length) continue;
    const py = join(dir, `sheet${s}.py`);
    writeFileSync(py, `
from PIL import Image, ImageDraw
import json, sys
items = json.load(open(${JSON.stringify(join(dir, `items${s}.json`))}))
cols, cell = ${COLS}, ${CELL}
rows_n = (len(items) + cols - 1) // cols
c = Image.new('RGB', (cols*(cell+8), rows_n*(cell+26)), '#111')
d = ImageDraw.Draw(c)
for i, it in enumerate(items):
    try: im = Image.open(it['f']).convert('RGB').resize((cell, cell))
    except Exception: continue
    x, y = (i%cols)*(cell+8)+4, (i//cols)*(cell+26)+4
    c.paste(im, (x, y))
    d.text((x, y+cell+2), it['label'][:${SUBJECT === 'meals' ? 34 : 22}], fill='#eee')
    d.text((x, y+cell+13), it['provider'] or '', fill='#7cf')
c.save(${JSON.stringify(join(dir, `sheet${s}.png`))})
`);
    writeFileSync(join(dir, `items${s}.json`),
      JSON.stringify(present.map(({ f, r }) => ({ f, label: r.label, provider: r.provider }))));
    await run('python3', [py]);
    const bytes = readFileSync(join(dir, `sheet${s}.png`));
    const name = `${SUBJECT}-${String(s + 1).padStart(2, '0')}.png`;
    if (OUT) writeFileSync(join(OUT, name), bytes);
    const url = await uploadImage('meal-images', `_review/${name}`, bytes, 'image/png');
    urls.push(url);
    console.log(`sheet ${s + 1}: ${present.length} pictures -> ${url}`);
  }
} finally { rmSync(dir, { recursive: true, force: true }); }

console.log(`\n${urls.length} sheet(s):`);
for (const u of urls) console.log(`  ${u}`);
