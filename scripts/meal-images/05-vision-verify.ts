#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env --allow-sys
/**
 * Pass 5 — vision verification of the ingredient tile bank.
 *
 * Relevance scoring in `lib/score.mjs` reads TITLES, and Wikimedia titles are
 * terse: the file behind "Chorizo" is a vacuum-sealed supermarket packet, the
 * one behind "Fusilli" is a pair of hands on an empty table, and "Mursik" is
 * two people. No regex over the title can catch that, so this pass looks at
 * the actual pixels and demotes any tile that does not show the ingredient as
 * recognisable food.
 *
 * Verification only — nothing here generates an image (Lee, 2026-09-08).
 *
 * Runs on Haiku through the Vercel AI Gateway, matching how the edge functions
 * call models (`supabase/functions/_shared/ai/model.ts`). BILLS REAL SPEND:
 * roughly one small vision call per bank tile.
 *
 *   set -a; source secrets/ai_gateway.env; set +a
 *   deno run --allow-net --allow-read --allow-env --allow-sys scripts/meal-images/05-vision-verify.ts
 *
 * Idempotent: only tiles with status='ok' and no verdict yet are examined.
 * LIMIT=n to sample, RECHECK=1 to re-examine tiles already verified.
 */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import { selectAll, rest } from './lib/db.mjs';

const MODEL = Deno.env.get('MEAL_IMAGE_VISION_MODEL') ?? 'anthropic/claude-haiku-4-5';
const CONCURRENCY = Number(Deno.env.get('CONCURRENCY') ?? 6);
const LIMIT = Number(Deno.env.get('LIMIT') ?? 0);
const RECHECK = Deno.env.get('RECHECK') === '1';
/**
 * STRICT=1 demands the ingredient itself as the subject and fails a composed
 * dish that merely contains it. The looser default was written for a bank
 * feeding single tiles; it is wrong for mosaics, where a cell showing a
 * finished dish makes the grid read as four unrelated meals (pass 8 catches
 * this downstream: "the grid shows crepes with sauce" for an oatmeal).
 */
const STRICT = Deno.env.get('STRICT') === '1';

if (!Deno.env.get('AI_GATEWAY_API_KEY')) {
  console.error('AI_GATEWAY_API_KEY missing — set -a; source secrets/ai_gateway.env; set +a');
  Deno.exit(1);
}

const Verdict = z.object({
  showsIngredient: z.boolean()
    .describe('true only if the named ingredient is clearly visible as food in the photo'),
  problem: z.enum(['none', 'packaging', 'people', 'empty_scene', 'wrong_food', 'unclear'])
    .describe('the main reason it fails, or "none" when it passes'),
  note: z.string().describe('a short reason, at most one sentence'),
});

type Row = { slug: string; display_name: string; image_url: string };

let rows: Row[] = await selectAll(
  'ingredient_images',
  `select=slug,display_name,image_url&status=eq.ok${RECHECK ? '' : '&vision_ok=is.null'}&order=rows_using.desc`,
);
if (LIMIT) rows = rows.slice(0, LIMIT);
console.log(`model: ${MODEL}`);
console.log(`tiles to verify: ${rows.length}\n`);

async function verify(row: Row) {
  const res = await fetch(row.image_url, { signal: AbortSignal.timeout(20_000) });
  if (!res.ok) throw new Error(`download ${res.status}`);
  const bytes = new Uint8Array(await res.arrayBuffer());
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);

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
            `This picture is meant to represent the single ingredient "${row.display_name}" ` +
            `as a small tile in a meal-planning app.\n\n` +
            `Pass it only if that ingredient is clearly visible as food someone could eat or cook with.\n\n` +
            `Fail it if the picture mainly shows:\n` +
            `- commercial packaging, a branded packet, jar, carton or supermarket shelf ("packaging")\n` +
            `- people, faces or hands as the subject ("people")\n` +
            `- an empty scene, a room, equipment or utensils with little visible food ("empty_scene")\n` +
            `- a different food, or a composed dish where the ingredient is not identifiable ("wrong_food")\n` +
            `- anything too dark, blurry or abstract to recognise ("unclear")\n\n` +
            (STRICT
              ? `A plain photo of the raw or cooked ingredient passes, alone or as the clear ` +
                `subject. A COMPOSED DISH FAILS as "wrong_food" even when the ingredient is in ` +
                `it — a bowl of porridge is not a photo of oats, avocado toast is not a photo of ` +
                `bread, a stir-fry is not a photo of broccoli. These tiles sit side by side in a ` +
                `grid standing in for one meal, so a cell showing a finished dish makes the grid ` +
                `read as several different meals.`
              : `A plain photo of the raw or cooked ingredient passes. A tasteful dish in which the ` +
                `ingredient is plainly the subject also passes.`),
        },
      ],
    }],
  });
  return object;
}

let done = 0, kept = 0, rejected = 0;
const reasons: Record<string, number> = {};
const queue = [...rows];

await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
  while (queue.length) {
    const row = queue.shift()!;
    let v: z.infer<typeof Verdict> | null = null;
    for (let attempt = 1; attempt <= 3 && !v; attempt++) {
      try { v = await verify(row); }
      catch (e) {
        if (attempt === 3) {
          done++;
          console.log(`[${done}] SKIP ${row.slug}: ${(e as Error).message.slice(0, 60)}`);
        } else await new Promise((r) => setTimeout(r, 1500 * attempt));
      }
    }
    if (!v) continue;

    const ok = v.showsIngredient && v.problem === 'none';
    reasons[v.problem] = (reasons[v.problem] ?? 0) + 1;
    try {
    // A failed tile is demoted, not deleted: image_url is kept for audit and
    // pass 3 only ever reads status='ok'.
      await rest(`ingredient_images?slug=eq.${encodeURIComponent(row.slug)}`, {
        method: 'PATCH',
        headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({
          vision_ok: ok,
          vision_reason: ok ? null : `${v.problem}: ${v.note}`,
          vision_at: new Date().toISOString(),
          status: ok ? 'ok' : 'rejected',
      }),
      });
    } catch (e) {
      // One unwritable verdict must not end the batch; the tile simply stays
      // unverified and a re-run picks it up.
      console.log(`[${done}] WRITE-FAIL ${row.slug}: ${(e as Error).message.slice(0, 60)}`);
      continue;
    }

    done++;
    ok ? kept++ : rejected++;
    if (!ok) console.log(`[${done}/${rows.length}] REJECT ${row.slug} — ${v.problem}: ${v.note}`);
    else if (done % 50 === 0) console.log(`[${done}/${rows.length}] ${kept} kept / ${rejected} rejected`);
  }
}));

console.log(`\nverified ${done}: ${kept} kept, ${rejected} rejected`);
console.log('reasons:', JSON.stringify(reasons));
