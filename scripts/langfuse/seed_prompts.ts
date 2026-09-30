/**
 * Creates Vana's prompts in Langfuse from the copy bundled in code (langfuse tickets 02, 11 and 12).
 *
 * For each prompt: when Langfuse has none by that name, version 1 is created from the bundled text with the
 * `production` label (Langfuse puts `latest` on it too). A prompt that is one model call's instructions is created
 * with that call's model in its config: the model the code runs today with no override set. A prompt that already
 * exists is left alone, whatever its text or config, so running this again changes nothing and never overwrites an
 * edit made in Langfuse.
 *
 * Run from the repo root, with none of the model environment variables set:
 *   deno run --allow-read --allow-env --allow-net --allow-sys --node-modules-dir=none scripts/langfuse/seed_prompts.ts
 * Keys are read from `secrets/langfuse.env`. Hobby allows 30 API requests a minute, so the script waits between calls.
 */
import { PROMPT_TEMPLATES } from '../../supabase/functions/_shared/vana/persona.ts';
import { MEAL_PROMPT_TEMPLATES, DESCRIBE_MEAL_PROMPT, MEAL_PHOTO_PROMPT } from '../../supabase/functions/_shared/meal_analysis/prompt.ts';
import { ANALYZE_MEAL_PHOTO_MODEL, DESCRIBE_MEAL_MODEL } from '../../supabase/functions/_shared/ai/model.ts';
import { EXTRACT_PROMPT_TEMPLATES, EXTRACTION_PROMPT, SUMMARY_PROMPT } from '../../supabase/functions/_shared/vana/extract.ts';
import { DAY_NOTES_PROMPT_TEMPLATES, DAY_NOTES_PROMPT } from '../../supabase/functions/_shared/vana/daynotes.ts';
import { PANTRY_PROMPT_TEMPLATES, PANTRY_PHOTO_PROMPT } from '../../supabase/functions/_shared/vana/pantry.ts';
import { INGREDIENTS_PROMPT_TEMPLATES, INGREDIENTS_PROMPT } from '../../supabase/functions/_shared/vana/saved-ingredients.ts';
import { backgroundModel, TOOL_MODEL } from '../../supabase/functions/_shared/vana/env.ts';

/** The model each call runs on today, by its prompt's name. */
const MODELS: Record<string, string> = {
  [DESCRIBE_MEAL_PROMPT]: DESCRIBE_MEAL_MODEL,
  [MEAL_PHOTO_PROMPT]: ANALYZE_MEAL_PHOTO_MODEL,
  [EXTRACTION_PROMPT]: backgroundModel(),
  [SUMMARY_PROMPT]: backgroundModel(),
  [DAY_NOTES_PROMPT]: TOOL_MODEL,
  [PANTRY_PHOTO_PROMPT]: TOOL_MODEL,
  [INGREDIENTS_PROMPT]: backgroundModel(),
};
const PROMPTS: Record<string, string> = { ...PROMPT_TEMPLATES, ...MEAL_PROMPT_TEMPLATES, ...EXTRACT_PROMPT_TEMPLATES, ...DAY_NOTES_PROMPT_TEMPLATES, ...PANTRY_PROMPT_TEMPLATES, ...INGREDIENTS_PROMPT_TEMPLATES };

const env = Object.fromEntries((await Deno.readTextFile('secrets/langfuse.env')).split('\n')
  .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/)).filter((m): m is RegExpMatchArray => !!m).map((m) => [m[1], m[2]]));
const base = env.LANGFUSE_BASE_URL ?? 'https://us.cloud.langfuse.com';
const headers = { Authorization: `Basic ${btoa(`${env.LANGFUSE_PUBLIC_KEY}:${env.LANGFUSE_SECRET_KEY}`)}`, 'Content-Type': 'application/json' };
const pause = () => new Promise((r) => setTimeout(r, 2_200));

let created = 0;
for (const [name, prompt] of Object.entries(PROMPTS)) {
  const existing = await fetch(`${base}/api/public/v2/prompts/${encodeURIComponent(name)}?label=latest`, { headers });
  await existing.body?.cancel();
  await pause();
  if (existing.ok) { console.log(`exists   ${name}`); continue; }
  if (existing.status !== 404) throw new Error(`${name}: reading it answered HTTP ${existing.status}`);
  const made = await fetch(`${base}/api/public/v2/prompts`, { method: 'POST', headers, body: JSON.stringify({ type: 'text', name, prompt, labels: ['production'], ...(MODELS[name] ? { config: { model: MODELS[name] } } : {}), commitMessage: 'The text the code held on the day the prompt moved to Langfuse.' }) });
  if (!made.ok) throw new Error(`${name}: creating it answered HTTP ${made.status}: ${await made.text()}`);
  await made.body?.cancel();
  created++;
  console.log(`created  ${name}${MODELS[name] ? `  (model ${MODELS[name]})` : ''}`);
  await pause();
}
console.log(`${created} created, ${Object.keys(PROMPTS).length - created} already there.`);
