/**
 * Creates Vana's prompts in Langfuse from the copy bundled in code (langfuse ticket 02).
 *
 * For each prompt in `PROMPT_TEMPLATES`: when Langfuse has none by that name, version 1 is created from the bundled
 * text with the `production` label (Langfuse puts `latest` on it too). A prompt that already exists is left alone,
 * whatever its text, so running this again changes nothing and never overwrites an edit made in Langfuse.
 *
 * Run from the repo root:
 *   deno run --allow-read --allow-env --allow-net --allow-sys --node-modules-dir=none scripts/langfuse/seed_prompts.ts
 * Keys are read from `secrets/langfuse.env`. Hobby allows 30 API requests a minute, so the script waits between calls.
 */
import { PROMPT_TEMPLATES } from '../../supabase/functions/_shared/vana/persona.ts';

const env = Object.fromEntries((await Deno.readTextFile('secrets/langfuse.env')).split('\n')
  .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/)).filter((m): m is RegExpMatchArray => !!m).map((m) => [m[1], m[2]]));
const base = env.LANGFUSE_BASE_URL ?? 'https://us.cloud.langfuse.com';
const headers = { Authorization: `Basic ${btoa(`${env.LANGFUSE_PUBLIC_KEY}:${env.LANGFUSE_SECRET_KEY}`)}`, 'Content-Type': 'application/json' };
const pause = () => new Promise((r) => setTimeout(r, 2_200));

let created = 0;
for (const [name, prompt] of Object.entries(PROMPT_TEMPLATES)) {
  const existing = await fetch(`${base}/api/public/v2/prompts/${encodeURIComponent(name)}?label=latest`, { headers });
  await existing.body?.cancel();
  await pause();
  if (existing.ok) { console.log(`exists   ${name}`); continue; }
  if (existing.status !== 404) throw new Error(`${name}: reading it answered HTTP ${existing.status}`);
  const made = await fetch(`${base}/api/public/v2/prompts`, { method: 'POST', headers, body: JSON.stringify({ type: 'text', name, prompt, labels: ['production'], commitMessage: 'The text the code held on the day the prompt moved to Langfuse.' }) });
  if (!made.ok) throw new Error(`${name}: creating it answered HTTP ${made.status}: ${await made.text()}`);
  await made.body?.cancel();
  created++;
  console.log(`created  ${name}`);
  await pause();
}
console.log(`${created} created, ${Object.keys(PROMPT_TEMPLATES).length - created} already there.`);
