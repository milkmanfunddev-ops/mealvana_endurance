#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-run --allow-env --allow-sys
/**
 * Pass 8 — does the image a Meal is showing actually represent that Meal?
 *
 * This is the question nothing has ever asked. Pass 5 checks a Tile against its
 * ingredient — "is this a cherry?" — and a good photograph of a cherry passes.
 * It cannot catch a Mosaic of a cherry and a tub of ice cream standing in for
 * cherry ice cream, because both tiles are correct and the composition is still
 * a lie.
 *
 * So the judge has to see what the user sees. Mosaics are composed client-side
 * in Flutter and no composite file exists anywhere, so this pass renders its
 * own, from the same description of the grid the widget is asserted against
 * (`lib/mosaic-geometry.json`), and judges that.
 *
 * Verdicts:
 *   ok     someone seeing this beside the meal's name would recognise the meal
 *   weak   not misleading, but thin — one component standing for many, or too
 *          generic to say much
 *   wrong  actively misleading — a different food, or parts that are not what
 *          the finished meal looks like
 *
 * BILLS REAL SPEND: one vision call per meal, ~1,800 meals, roughly $7 on
 * Sonnet 5. Run it when the library changes, not casually.
 *
 *   set -a; source secrets/ai_gateway.env; set +a
 *   deno run --allow-net --allow-read --allow-write --allow-run --allow-env --allow-sys \
 *     scripts/meal-images/08-verify-meal-image.ts
 *
 * Idempotent: only meals with no verdict yet are judged. LIMIT=n to sample,
 * REVERIFY=1 to redo, MODE=mosaic to judge one rung only, DRY=1 to print
 * without writing, KEEP=1 to leave the composites on disk for eyeballing.
 */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import { selectAll, updateMany } from './lib/db.mjs';
import { pinnedGeometry } from './lib/mosaic-geometry.mjs';
import { CANVAS, composeMosaic } from './lib/compose-mosaic.mjs';

const MODEL = Deno.env.get('MEAL_IMAGE_JUDGE_MODEL') ?? 'anthropic/claude-sonnet-5';
const CONCURRENCY = Number(Deno.env.get('CONCURRENCY') ?? 4);
const LIMIT = Number(Deno.env.get('LIMIT') ?? 0);
const REVERIFY = Deno.env.get('REVERIFY') === '1';
const DRY = Deno.env.get('DRY') === '1';
const KEEP = Deno.env.get('KEEP') === '1';
const MODE = Deno.env.get('MODE') ?? '';
const GEOMETRY = pinnedGeometry();

if (!Deno.env.get('AI_GATEWAY_API_KEY')) {
  console.error('AI_GATEWAY_API_KEY missing — set -a; source secrets/ai_gateway.env; set +a');
  Deno.exit(1);
}

const Verdict = z.object({
  verdict: z.enum(['ok', 'weak', 'wrong']),
  reason: z.string().describe('one short sentence saying what the picture actually shows'),
});

type Tile = { url: string; name?: string };
type Row = {
  id: string;
  name: string;
  ingredients: string | null;
  image_mode: string;
  image_url: string | null;
  image_tiles: Tile[] | null;
  separability: string | null;
};

let rows: Row[] = await selectAll(
  'meal_library',
  'select=id,name,ingredients,image_mode,image_url,image_tiles,separability' +
    `&is_active=eq.true&image_mode=neq.none${REVERIFY ? '' : '&image_verdict=is.null'}` +
    `${MODE ? `&image_mode=eq.${MODE}` : ''}&order=id`,
);
if (LIMIT) rows = rows.slice(0, LIMIT);

console.log(`model: ${MODEL}`);
// Stamped on every run: a verdict is only meaningful for the grid it was
// judged on, and this is the version of that grid.
console.log(`mosaic geometry: v${GEOMETRY.version}`);
console.log(`meals to judge: ${rows.length}\n`);
if (!rows.length) Deno.exit(0);

const dir = await Deno.makeTempDir({ prefix: 'mvjudge-' });

function urlsFor(row: Row): string[] {
  if (row.image_mode === 'dish') return row.image_url ? [row.image_url] : [];
  return (row.image_tiles ?? []).map((t) => t.url).filter(Boolean).slice(0, 4);
}

/**
 * Lay the tiles out as the app lays them out, so the judge sees the artefact
 * rather than a tidier version of it.
 *
 * No layout happens here. `composeMosaic` draws the grid from the cells in
 * `lib/mosaic-geometry.json`, which is the same description `MealImageMosaic`
 * is asserted against, so the composite judged here and the picture the athlete
 * sees cannot drift apart without a test failing. A change to that description
 * invalidates every stored verdict — see docs/meal-images/README.md.
 */
async function render(row: Row): Promise<Uint8Array | null> {
  const urls = urlsFor(row);
  if (!urls.length) return null;

  const files: string[] = [];
  for (const [i, url] of urls.entries()) {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'MealvanaBot/1.0 (https://mealvana.com)' },
      signal: AbortSignal.timeout(25_000),
    });
    if (!res.ok) throw new Error(`tile ${i} -> ${res.status}`);
    const f = `${dir}/${row.id}_${i}.img`;
    await Deno.writeFile(f, new Uint8Array(await res.arrayBuffer()));
    files.push(f);
  }

  const out = `${dir}/${row.id}.jpg`;
  await composeMosaic({ files, out, width: CANVAS, height: CANVAS });

  const bytes = await Deno.readFile(out);
  if (!KEEP) {
    for (const f of [...files, out]) await Deno.remove(f).catch(() => {});
  }
  return bytes;
}

async function judge(row: Row, bytes: Uint8Array) {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);

  const what = row.image_mode === 'dish'
    ? 'a single photograph chosen to show the finished meal'
    : row.image_mode === 'tile'
    ? 'a single ingredient photograph standing in for the whole meal'
    : 'a grid of ingredient photographs, one cell per ingredient, standing in for the meal';

  const { object } = await generateObject({
    model: MODEL,
    schema: Verdict,
    messages: [{
      role: 'user',
      content: [
        { type: 'image', image: btoa(bin), mediaType: 'image/jpeg' },
        {
          type: 'text',
          text:
            `In a meal-planning app this picture is shown beside the meal:\n\n` +
            `  "${row.name}"\n` +
            `  ingredients: ${(row.ingredients ?? '(not listed)').slice(0, 240)}\n\n` +
            `The picture is ${what}.\n\n` +
            `Judge whether it represents that meal honestly.\n\n` +
            `"ok" — someone seeing this beside the name would recognise the meal. For an ` +
            `ingredient grid, that means the ingredients shown really are the things you would ` +
            `see in the finished meal.\n` +
            `"weak" — not misleading, but thin: one component standing for a meal of many parts, ` +
            `or so generic it says almost nothing.\n` +
            `"wrong" — actively misleading: a different food, packaging or branding as the ` +
            `subject, people as the subject, or ingredients that are NOT visible in the finished ` +
            `meal because they were blended, baked or churned into it. A grid of a cherry and a ` +
            `tub of ice cream for "cherry ice cream" is wrong: the real thing is pink ice cream ` +
            `and neither cell shows it.\n\n` +
            `Judge only what the picture shows against what the meal is. Ignore styling, ` +
            `lighting and photographic quality.`,
        },
      ],
    }],
  });
  return object;
}

const tally: Record<string, number> = { ok: 0, weak: 0, wrong: 0 };
const results: { id: string; verdict: string; reason: string }[] = [];
const worst: { name: string; mode: string; reason: string }[] = [];
let done = 0, skipped = 0;

const queue = [...rows];
await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
  while (queue.length) {
    const row = queue.shift()!;
    let v: z.infer<typeof Verdict> | null = null;
    for (let attempt = 1; attempt <= 3 && !v; attempt++) {
      try {
        const bytes = await render(row);
        if (!bytes) break;
        v = await judge(row, bytes);
      } catch (e) {
        if (attempt === 3) {
          skipped++;
          console.log(`  SKIP ${row.id}: ${(e as Error).message.slice(0, 70)}`);
        } else await new Promise((r) => setTimeout(r, 1500 * attempt));
      }
    }
    done++;
    if (!v) continue;

    tally[v.verdict]++;
    results.push({ id: row.id, verdict: v.verdict, reason: v.reason });
    if (v.verdict === 'wrong' && worst.length < 25) {
      worst.push({ name: row.name, mode: row.image_mode, reason: v.reason });
    }
    if (v.verdict === 'wrong') {
      console.log(`[${done}/${rows.length}] WRONG ${row.image_mode.padEnd(6)} ${row.name.slice(0, 46)} — ${v.reason.slice(0, 56)}`);
    } else if (done % 50 === 0) {
      console.log(`[${done}/${rows.length}] ok ${tally.ok} / weak ${tally.weak} / wrong ${tally.wrong}`);
    }
  }
}));

if (!KEEP) await Deno.remove(dir, { recursive: true }).catch(() => {});
else console.log(`\ncomposites kept in ${dir}`);

console.log(`\njudged ${results.length}${skipped ? `, skipped ${skipped}` : ''}`);
for (const k of ['ok', 'weak', 'wrong']) {
  const pct = results.length ? (100 * tally[k] / results.length).toFixed(1) : '0.0';
  console.log(`  ${k.padEnd(6)} ${String(tally[k]).padStart(5)}  ${pct}%`);
}
if (worst.length) {
  console.log('\nwrong, a sample:');
  for (const w of worst.slice(0, 15)) {
    console.log(`  ${w.mode.padEnd(6)} ${w.name.slice(0, 44).padEnd(46)} ${w.reason.slice(0, 56)}`);
  }
}

if (DRY) { console.log('\nDRY=1 — nothing written'); Deno.exit(0); }

const at = new Date().toISOString();
const written = await updateMany('meal_library', results.map((r) => ({
  id: r.id,
  image_verdict: r.verdict,
  image_verdict_reason: r.reason,
  image_verdict_at: at,
})));
console.log(`\nrows written: ${written}`);
