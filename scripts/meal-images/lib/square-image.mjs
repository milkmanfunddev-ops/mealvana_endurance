// Turning a downloaded photograph into the square we store.
//
// Two passes mirror pictures into our own bucket — pass 2 an ingredient tile,
// pass 10 a dish photograph — and both need the same thing: scale the SHORT
// side to the target so the centre crop is never padded, then cut the square
// out of the middle. That is the same `cover` fit the mosaic compositor and the
// Flutter widget apply, so a mirrored picture is cropped once here and not
// again at render.
//
// macOS `sips`, because it is already on the machine these passes run on and
// pulling in an image library for a centre crop is not worth the dependency.
import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';

const run = promisify(execFile);

/** Below this the crop is an upscale, which looks worse than no picture. */
export const MIN_SOURCE_PX = 300;

/**
 * Centre-crop `bytes` to a `size`x`size` JPEG.
 *
 * @param {Uint8Array|Buffer} bytes the downloaded file, whatever format it is in
 * @param {number} size the square's edge, in pixels
 * @param {{minSourcePx?: number, quality?: number}} [opts]
 * @returns {Promise<Buffer>} the JPEG
 * @throws when the file will not decode, or is too small to crop without upscaling
 */
export async function squareImage(bytes, size, { minSourcePx = MIN_SOURCE_PX, quality = 82 } = {}) {
  if (!bytes || bytes.length < 2000) throw new Error('file too small');

  const dir = mkdtempSync(join(tmpdir(), 'mvsquare-'));
  const src = join(dir, 'src'), out = join(dir, 'out.jpg');
  try {
    writeFileSync(src, bytes);
    const { stdout } = await run('sips', ['-g', 'pixelWidth', '-g', 'pixelHeight', src]);
    const w = +(stdout.match(/pixelWidth:\s*(\d+)/)?.[1] ?? 0);
    const h = +(stdout.match(/pixelHeight:\s*(\d+)/)?.[1] ?? 0);
    if (!w || !h) throw new Error('undecodable');
    if (Math.min(w, h) < minSourcePx) throw new Error(`too small ${w}x${h}`);

    const arg = w < h ? ['--resampleWidth', String(size)] : ['--resampleHeight', String(size)];
    await run('sips', [...arg, src, '--out', out]);
    await run('sips', ['-c', String(size), String(size), out]);
    await run('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', String(quality), out]);
    return readFileSync(out);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
