// Pass 4 (review): render every resolved ingredient tile onto contact sheets
// and upload them, so the whole bank can be eyeballed in a few images rather
// than a thousand database rows. Read-only against the bank.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { selectAll, uploadImage } from './lib/db.mjs';

const run = promisify(execFile);
const COLS = 8, CELL = 150, PER_SHEET = 96;

const rows = await selectAll('ingredient_images',
  'select=slug,image_url,provider,rows_using&status=eq.ok&order=rows_using.desc', { key: 'slug' });
console.log(`tiles: ${rows.length}`);

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
    d.text((x, y+cell+2), it['slug'][:22], fill='#eee')
    d.text((x, y+cell+13), it['provider'] or '', fill='#7cf')
c.save(${JSON.stringify(join(dir, `sheet${s}.png`))})
`);
    writeFileSync(join(dir, `items${s}.json`),
      JSON.stringify(present.map(({ f, r }) => ({ f, slug: r.slug, provider: r.provider }))));
    await run('python3', [py]);
    const url = await uploadImage('meal-images', `_review/bank-${String(s + 1).padStart(2, '0')}.png`,
      readFileSync(join(dir, `sheet${s}.png`)), 'image/png');
    urls.push(url);
    console.log(`sheet ${s + 1}: ${present.length} tiles -> ${url}`);
  }
} finally { rmSync(dir, { recursive: true, force: true }); }

console.log(`\n${urls.length} sheet(s):`);
for (const u of urls) console.log(`  ${u}`);
