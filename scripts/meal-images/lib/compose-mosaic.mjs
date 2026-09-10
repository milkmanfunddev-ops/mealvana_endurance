// The compositor: the mosaic, drawn as a file.
//
// The athlete's copy of this picture is drawn by Flutter and never exists as a
// file. This is the second drawing of it — the one pass 8 shows a judge, and
// the one the parity test compares against what the widget paints. Cells, gap
// and hairline all come from `mosaic-geometry.mjs`; the reasoning for that
// lives there.
//
// Needs python3 with Pillow. Usage as a CLI, for eyeballing what the judge is
// shown for a set of tiles without spending anything:
//
//   node scripts/meal-images/lib/compose-mosaic.mjs --out grid.png a.png b.png
//
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

import { HAIRLINE, pixelCells, MAX_TILES } from './mosaic-geometry.mjs';

const run = promisify(execFile);

/** The square the judge is shown. Big enough to read, small enough to send. */
export const CANVAS = 768;

// MIM-4 — cover: scale to fill the cell, then trim the overflowing axis
// equally at both ends. Pillow's LANCZOS is the closest match to the filtering
// Flutter uses when it scales a texture down into a cell.
const COMPOSE = `
import sys, json
from PIL import Image

job = json.load(open(sys.argv[1]))
W, H = job['canvas']

def fit(path, w, h):
    im = Image.open(path).convert('RGB')
    sw, sh = im.size
    scale = max(w / sw, h / sh)
    im = im.resize((max(1, round(sw * scale)), max(1, round(sh * scale))), Image.LANCZOS)
    nw, nh = im.size
    left, top = (nw - w) // 2, (nh - h) // 2
    return im.crop((left, top, left + w, top + h))

c = Image.new('RGB', (W, H), job['hairline'])
for path, cell in zip(job['files'], job['cells']):
    c.paste(fit(path, cell['w'], cell['h']), (cell['x'], cell['y']))
c.save(job['out'], job['format'], quality=82)
`;

/**
 * Draw `files` as the mosaic the app would draw for the same tiles.
 *
 * Async because pass 8 renders four meals at once; a synchronous python call
 * would quietly serialise its workers.
 *
 * @param {{files: string[], out: string, width?: number, height?: number,
 *          theme?: 'light'|'dark'}} job
 * @returns {Promise<string>} the path written
 */
export async function composeMosaic(
  { files, out, width = CANVAS, height = width, theme = 'light' },
) {
  if (!files.length || files.length > MAX_TILES) {
    throw new Error(`a mosaic is 1..${MAX_TILES} tiles, got ${files.length}`);
  }
  const dir = mkdtempSync(join(tmpdir(), 'mvcompose-'));
  try {
    const script = join(dir, 'compose.py');
    const manifest = join(dir, 'job.json');
    writeFileSync(script, COMPOSE);
    writeFileSync(
      manifest,
      JSON.stringify({
        files,
        out,
        hairline: HAIRLINE[theme],
        canvas: [width, height],
        format: out.toLowerCase().endsWith('.png') ? 'PNG' : 'JPEG',
        cells: pixelCells(files.length, width, height),
      }),
    );
    await run('python3', [script, manifest]);
    return out;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

if (import.meta.main || process.argv[1]?.endsWith('compose-mosaic.mjs')) {
  const argv = process.argv.slice(2);
  const flag = argv.indexOf('--out');
  const out = flag === -1 ? null : argv.splice(flag, 2)[1];
  if (!out || !argv.length) {
    console.error('usage: compose-mosaic.mjs --out <file> <tile>...');
    process.exit(2);
  }
  console.log(await composeMosaic({ files: argv, out }));
}
