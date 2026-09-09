#!/usr/bin/env -S deno run --allow-net --allow-read --allow-env --allow-sys
/**
 * Pass 7 — is this Meal separable or transformed?
 *
 * A Mosaic makes a promise: *these are the things that will be in front of
 * you*. For oatmeal with blueberries the promise holds — you can see oats and
 * you can see blueberries in the bowl. For cherry ice cream it is a lie: the
 * cherries are churned in, the finished thing is pink ice cream, and a photo of
 * a cherry beside a photo of ice cream describes the shopping list rather than
 * the food.
 *
 * So: **separable** = the named components stay individually recognisable in
 * the finished Meal, and a Mosaic may be used. **transformed** = they do not,
 * and the Meal needs a Dish photo or nothing.
 *
 * This cuts ACROSS Recipe/Assembly, which is why it cannot be derived from
 * `kind`, `prep` or `method_steps`: a raspberry-nectarine smoothie has no
 * method steps and is transformed; a grain bowl may have a dozen steps and
 * stays separable.
 *
 * Language only — no image is fetched and none is needed. "Cherry ice cream"
 * tells you the cherries are gone; "steel-cut oats with peanut butter &
 * blueberries" tells you they are not.
 *
 * BILLS REAL SPEND, but very little: meals are judged in batches of
 * BATCH_SIZE, so the whole library is roughly 100 small text calls.
 *
 *   set -a; source secrets/ai_gateway.env; set +a
 *   deno run --allow-net --allow-read --allow-env --allow-sys \
 *     scripts/meal-images/07-classify-separability.ts
 *
 * Idempotent: only meals with no verdict yet are classified. LIMIT=n to
 * sample, RECLASSIFY=1 to redo the whole library, DRY=1 to print without
 * writing.
 */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import { selectAll, updateMany } from './lib/db.mjs';

const MODEL = Deno.env.get('MEAL_SEPARABILITY_MODEL') ?? 'anthropic/claude-sonnet-5';
const BATCH_SIZE = Number(Deno.env.get('BATCH_SIZE') ?? 20);
const CONCURRENCY = Number(Deno.env.get('CONCURRENCY') ?? 4);
const LIMIT = Number(Deno.env.get('LIMIT') ?? 0);
const RECLASSIFY = Deno.env.get('RECLASSIFY') === '1';
const DRY = Deno.env.get('DRY') === '1';
/** Spot-check a slice of the library by name, e.g. MATCH=smoothie. */
const MATCH = Deno.env.get('MATCH') ?? '';

if (!Deno.env.get('AI_GATEWAY_API_KEY')) {
  console.error('AI_GATEWAY_API_KEY missing — set -a; source secrets/ai_gateway.env; set +a');
  Deno.exit(1);
}

const Batch = z.object({
  meals: z.array(z.object({
    id: z.string().describe('the meal id exactly as given'),
    separability: z.enum(['separable', 'transformed']),
    reason: z.string().describe('at most one short sentence, naming what gives it away'),
  })),
});

type Row = { id: string; name: string; kind: string; ingredients: string | null };

let rows: Row[] = await selectAll(
  'meal_library',
  `select=id,name,kind,ingredients&is_active=eq.true${RECLASSIFY ? '' : '&separability=is.null'}` +
    `${MATCH ? `&name=ilike.*${encodeURIComponent(MATCH)}*` : ''}&order=id`,
);
if (LIMIT) rows = rows.slice(0, LIMIT);

console.log(`model: ${MODEL}`);
console.log(`meals to classify: ${rows.length} (batches of ${BATCH_SIZE})\n`);
if (!rows.length) Deno.exit(0);

const GUIDANCE = `
You are deciding whether a small grid of ingredient photographs would honestly
represent a meal, or would misrepresent it.

Answer "separable" when the named components stay individually recognisable in
the finished meal — someone looking at the real plate or bowl could point at
each one. Answer "transformed" when cooking, blending, baking, churning or
emulsifying has made the components stop looking like themselves.

separable:
- Oatmeal with banana and maple syrup — oats and banana slices both visible.
- Greek yoghurt with berries and honey — layers you can see.
- Grain bowl with chicken, rice and roasted vegetables — every part identifiable.
- Toast with almond butter and sliced strawberries.
- A cheese and fruit plate.

transformed:
- Cherry ice cream — the cherries are churned in; the thing is pink ice cream.
- Raspberry-nectarine smoothie — everything is now one pink liquid.
- Banana bread — the banana is invisible inside a baked loaf.
- Lentil soup or a stew — simmered into one body.
- Scrambled eggs with cheese — the cheese is melted through.
- A protein shake.

Borderline rule: judge the DOMINANT impression. A bowl of chilli with a visible
dollop of yoghurt and sliced avocado on top is separable — the toppings sit
there in plain sight. A chilli with the same ingredients cooked through and
nothing on top is transformed. If the finished dish is mostly one homogeneous
mass, it is transformed even when a garnish survives.

A meal having cooking steps does NOT make it transformed, and a meal having
none does NOT make it separable. Roast vegetables are still recognisably
vegetables; an unheated smoothie is still a homogeneous liquid.
`.trim();

async function classify(batch: Row[]) {
  const list = batch.map((m) =>
    `id: ${m.id}\nname: ${m.name}\ningredients: ${(m.ingredients ?? '').slice(0, 300) || '(not listed)'}`
  ).join('\n\n');

  const { object } = await generateObject({
    model: MODEL,
    schema: Batch,
    messages: [{
      role: 'user',
      content: `${GUIDANCE}\n\nClassify every meal below. Return one entry per meal, using the id exactly as given.\n\n${list}`,
    }],
  });
  return object.meals;
}

const batches: Row[][] = [];
for (let i = 0; i < rows.length; i += BATCH_SIZE) batches.push(rows.slice(i, i + BATCH_SIZE));

const byId = new Map(rows.map((r) => [r.id, r]));
const verdicts: { id: string; separability: string; reason: string }[] = [];
const tally: Record<string, number> = { separable: 0, transformed: 0 };
let doneBatches = 0;

const queue = [...batches];
await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
  while (queue.length) {
    const batch = queue.shift()!;
    let got: Awaited<ReturnType<typeof classify>> | null = null;
    for (let attempt = 1; attempt <= 3 && !got; attempt++) {
      try { got = await classify(batch); }
      catch (e) {
        if (attempt === 3) console.log(`  batch failed, left unclassified: ${(e as Error).message.slice(0, 70)}`);
        else await new Promise((r) => setTimeout(r, 1500 * attempt));
      }
    }
    doneBatches++;
    if (!got) continue;

    for (const v of got) {
      // A hallucinated or duplicated id must never be written back onto a meal
      // it does not belong to.
      if (!byId.has(v.id)) continue;
      verdicts.push(v);
      tally[v.separability] = (tally[v.separability] ?? 0) + 1;
    }
    console.log(`[${doneBatches}/${batches.length}] ${verdicts.length} classified`);
  }
}));

console.log(`\nseparable   ${tally.separable ?? 0}`);
console.log(`transformed ${tally.transformed ?? 0}`);

const sample = verdicts.filter((v) => v.separability === 'transformed').slice(0, 12);
if (sample.length) {
  console.log('\ntransformed, a sample:');
  for (const v of sample) console.log(`  ${byId.get(v.id)!.name.slice(0, 52).padEnd(54)} ${v.reason.slice(0, 60)}`);
}

if (DRY) { console.log(`\nDRY=1 — nothing written`); Deno.exit(0); }

const at = new Date().toISOString();
const written = await updateMany('meal_library', verdicts.map((v) => ({
  id: v.id,
  separability: v.separability,
  separability_reason: v.reason,
  separability_at: at,
})));
console.log(`\nrows written: ${written}`);
