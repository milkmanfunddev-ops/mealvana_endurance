/**
 * The one question this pipeline exists to ask: does this picture represent
 * this meal?
 *
 * It lives here because two passes ask it and they must ask it identically.
 * Pass 8 asks it of what a meal is already showing, and that answer becomes
 * `image_verdict` — the measure. Pass 10 asks it of a candidate photograph
 * before storing it, and only an `ok` is kept. If those were two prompts, pass
 * 10 would be buying acceptances that pass 8 would then rate `wrong`, and the
 * honesty figure would go down as a direct result of work done to raise it.
 *
 * So: one prompt, one schema, one model default. A change here re-prices and
 * re-values every verdict in the table — see
 * docs/meal-images/README.md#compositor-parity.
 *
 * Deno only: this reaches the network through the Vercel AI Gateway. The pure
 * parts of the pipeline (the ladder, the geometry, the scoring) stay in .mjs so
 * node can test them.
 */
import { generateObject } from 'npm:ai@6';
import { z } from 'npm:zod@3';

export const DEFAULT_JUDGE_MODEL = Deno.env.get('MEAL_IMAGE_JUDGE_MODEL') ??
  'anthropic/claude-sonnet-5';

export const VerdictSchema = z.object({
  verdict: z.enum(['ok', 'weak', 'wrong']),
  reason: z.string().describe('one short sentence saying what the picture actually shows'),
});

export type Verdict = z.infer<typeof VerdictSchema>;

export type JudgedMeal = { name: string; ingredients?: string | null };

/** The rungs of the ladder that actually show a picture. */
export type ImageMode = 'dish' | 'tile' | 'mosaic';

/** What the picture is, so the judge grades the artefact rather than the idea. */
function describe(mode: ImageMode): string {
  if (mode === 'dish') return 'a single photograph chosen to show the finished meal';
  if (mode === 'tile') return 'a single ingredient photograph standing in for the whole meal';
  return 'a grid of ingredient photographs, one cell per ingredient, standing in for the meal';
}

export function judgePrompt(meal: JudgedMeal, mode: ImageMode): string {
  return `In a meal-planning app this picture is shown beside the meal:\n\n` +
    `  "${meal.name}"\n` +
    `  ingredients: ${(meal.ingredients ?? '(not listed)').slice(0, 240)}\n\n` +
    `The picture is ${describe(mode)}.\n\n` +
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
    `lighting and photographic quality.`;
}

/**
 * Show the judge one composed picture and take its verdict.
 *
 * BILLS REAL SPEND: one frontier-model vision call per invocation. `usage` comes
 * back so the caller can report what a run cost rather than estimate it.
 */
export async function judgeMealImage(
  { meal, mode, bytes, model = DEFAULT_JUDGE_MODEL }: {
    meal: JudgedMeal;
    mode: ImageMode;
    bytes: Uint8Array;
    model?: string;
  },
): Promise<{ verdict: Verdict; usage: { inputTokens: number; outputTokens: number } }> {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);

  const { object, usage } = await generateObject({
    model,
    schema: VerdictSchema,
    messages: [{
      role: 'user',
      content: [
        { type: 'image', image: btoa(bin), mediaType: 'image/jpeg' },
        { type: 'text', text: judgePrompt(meal, mode) },
      ],
    }],
  });

  return {
    verdict: object,
    usage: { inputTokens: usage?.inputTokens ?? 0, outputTokens: usage?.outputTokens ?? 0 },
  };
}
