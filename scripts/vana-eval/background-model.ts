/**
 * The model test behind mp-465 clause 3 / ai-cost ticket 14: does a cheaper gateway model give the
 * same structured answer as Haiku 4.5 on the three background jobs?
 *
 * The three jobs write nothing the athlete reads — the memory extraction at idle, the rolling
 * conversation summary, and the ingredient list for a saved meal — so the only questions are "does
 * it satisfy the schema" and "is the answer the same". This script asks each candidate the REAL
 * system prompt and the REAL prompt builder from `_shared/vana/extract.ts` and
 * `_shared/vana/saved-ingredients.ts`, against the REAL Zod schemas, so a pass here is a pass for
 * the shipped code path and not for a paraphrase of it.
 *
 * It spends the EVALS gateway key (`AI_GATEWAY_API_KEY_EVALS`, ticket 02) — never the dev or
 * production key.
 *
 * The cases file holds athlete conversations read from DEV. It is NOT committed and its path is
 * given on the command line; keep it outside the repo.
 *
 *   deno run --allow-env --allow-net --allow-read --allow-sys --allow-write \
 *     scripts/vana-eval/background-model.ts <cases.json> <out.json> [model ...]
 *
 * (--allow-sys because the gateway provider reads the hostname; --allow-write for <out.json>.)
 *
 * Cases file shape:
 *   { "extract":     [{ id, lines: [{role,text}], existing: string[] }],
 *     "summary":     [{ id, lines: [{role,text}], from, to, previous: null }],
 *     "ingredients": [{ id, meal: { name, items, notes, calories, carbsG, proteinG, fatG } }] }
 */
import { generateObject } from 'npm:ai@6.0.277';
import { EXTRACTOR_SYSTEM, ExtractionZ, extractionPrompt, SUMMARY_SYSTEM, SummaryZ, summaryPrompt } from '../../supabase/functions/_shared/vana/extract.ts';
import type { TranscriptLine } from '../../supabase/functions/_shared/vana/extract.ts';
import { INGREDIENTS_SYSTEM, IngredientsZ, ingredientsPrompt } from '../../supabase/functions/_shared/vana/saved-ingredients.ts';
import { evalsGatewayKeyFromRepo } from './gateway-key.ts';

const BASELINE = 'anthropic/claude-haiku-4.5';

interface ExtractCase { id: string; lines: TranscriptLine[]; existing: string[] }
interface SummaryCase { id: string; lines: TranscriptLine[]; from: number; to: number }
// deno-lint-ignore no-explicit-any
interface IngredientCase { id: string; meal: any }
interface Cases { extract: ExtractCase[]; summary: SummaryCase[]; ingredients: IngredientCase[] }

/** The three jobs as (system, prompt, schema, maxOutputTokens) — exactly what the edge function sends. */
// deno-lint-ignore no-explicit-any
function jobs(cases: Cases): { job: string; id: string; system: string; prompt: string; schema: any; max: number }[] {
  return [
    ...cases.extract.map((c) => ({ job: 'extract', id: c.id, system: EXTRACTOR_SYSTEM, prompt: extractionPrompt(c.lines, c.existing), schema: ExtractionZ, max: 400 })),
    ...cases.summary.map((c) => ({ job: 'summary', id: c.id, system: SUMMARY_SYSTEM, prompt: summaryPrompt(null, c.lines, c.from, c.to), schema: SummaryZ, max: 400 })),
    ...cases.ingredients.map((c) => ({ job: 'ingredients', id: c.id, system: INGREDIENTS_SYSTEM, prompt: ingredientsPrompt(c.meal), schema: IngredientsZ, max: 500 })),
  ];
}

async function main() {
  const [casesPath, outPath, ...candidates] = Deno.args;
  if (!casesPath || !outPath) { console.error('usage: background-model.ts <cases.json> <out.json> [model ...]'); Deno.exit(2); }

  const key = evalsGatewayKeyFromRepo();
  if (!key) { console.error('no evals gateway key; export AI_GATEWAY_API_KEY_EVALS'); Deno.exit(2); }
  Deno.env.set('AI_GATEWAY_API_KEY', key);   // what the AI SDK reads; the evals key, not dev's

  const cases: Cases = JSON.parse(await Deno.readTextFile(casesPath));
  const work = jobs(cases);
  // SKIP_BASELINE=1 leaves Haiku out when its answers are already on disk — Haiku is the dearest
  // model here, so re-running it to re-test a candidate is the one avoidable cost.
  const models = Deno.env.get('SKIP_BASELINE') === '1' ? candidates : [BASELINE, ...candidates];
  // A model that thinks past this is disqualified anyway: these three jobs run in the background of a
  // request and the shipped call has no retry. Without it, one stalled call hangs the whole comparison.
  const perCallMs = Number(Deno.env.get('CALL_TIMEOUT_MS') ?? 90_000);
  // deno-lint-ignore no-explicit-any
  const out: Record<string, Record<string, any>> = {};

  for (const model of models) {
    out[model] = {};
    let ok = 0, bad = 0, inTok = 0, outTok = 0;
    for (const w of work) {
      const k = `${w.job}:${w.id}`;
      try {
        const { object, usage } = await generateObject({ model, schema: w.schema, maxOutputTokens: w.max, system: w.system, prompt: w.prompt, abortSignal: AbortSignal.timeout(perCallMs) });
        out[model][k] = { ok: true, object };
        inTok += usage?.inputTokens ?? 0; outTok += usage?.outputTokens ?? 0; ok++;
      } catch (e) {
        out[model][k] = { ok: false, error: String((e as Error).message ?? e).slice(0, 300) };
        bad++;
      }
    }
    out[model].__totals = { ok, bad, inputTokens: inTok, outputTokens: outTok };
    console.error(`${model}: ${ok} ok, ${bad} failed, ${inTok} in / ${outTok} out tokens`);
    await Deno.writeTextFile(outPath, JSON.stringify(out, null, 1));   // after each model, so a stall loses nothing
  }

  await Deno.writeTextFile(outPath, JSON.stringify(out, null, 1));
  console.error(`wrote ${outPath}`);
}

if (import.meta.main) await main();
