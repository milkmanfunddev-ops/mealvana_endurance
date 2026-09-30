/**
 * Sets up the flag evaluators that score each new dev chat Turn in Langfuse (langfuse ticket 16).
 *
 * Four evaluators, one evaluation rule:
 *   - `user_disagreement`, `user_distress` and `all_caps` are Langfuse's ready-made user-signal evaluators, copied from
 *     its managed templates as they stood on 2026-09-30 (`managed_flag_templates.json`, unedited).
 *   - `conversation_signal` is ours: true when the athlete corrects Vana, repeats a request or shows frustration.
 * The three that call a model run on Haiku 4.5 through the Gateway connection that holds the evals key.
 *
 * The rule matches the root observation of a `vana-turn` Trace in the `dev` environment, for Turns the athlete wrote (tag
 * `message`; an opener's input is a hidden prompt, not an athlete's words). Matching on the environment is also what
 * leaves out experiments (`experiment`) and the evaluators' own calls (Langfuse files those under its own
 * environments). Each evaluator reads the root's input as the athlete's message and the root's `history` metadata as
 * the turns before it.
 *
 * An evaluator or rule that already exists by name is left alone, so running this again changes nothing and never
 * overwrites an edit made in Langfuse. To change one, edit it in Langfuse, or delete it there and run this again.
 *
 * Run from the repo root:
 *   deno run --allow-read --allow-net scripts/langfuse/setup_flag_evaluators.ts
 * Keys are read from `secrets/langfuse.env`. Hobby allows 30 API requests a minute, so the script waits between calls.
 */
const MODEL = { provider: 'vercel-ai-gateway', model: 'anthropic/claude-haiku-4.5' };
const RULE = 'Flag dev chat Turns';

const CONVERSATION_SIGNAL = `You read one message an athlete sent to Vana, a nutrition assistant for endurance athletes, along with the turns that came before it. Decide whether the message shows that the conversation is going badly for the athlete.

Answer true when the message does at least one of these:
- Correction: the athlete tells Vana that it got something wrong or missed what they asked for. "No, I said dinner, not lunch." "That's not my race date." "I already told you I don't eat fish."
- Repeat: the athlete asks again for something they already asked for in the earlier turns, because the reply did not give it to them. The wording may differ. What counts is that the same request comes back.
- Frustration: the athlete is annoyed with Vana or with the app. "This is useless." "Why is this so hard?" "Forget it."

Answer false for everything else, including:
- a change of mind ("actually, make it four dinners"): the athlete changed what they want, and Vana did not get it wrong;
- a follow-up question, a request for more detail, or a swap of one meal for another;
- a short reply to a question Vana asked, including "no" to an offer;
- being tired, sore or worried about training or a race, which is about their day and not about Vana;
- an earlier turn that shows one of the signals when this message does not. Judge this message only. The earlier turns are there so you can tell a repeat from a first ask, and a correction from a new request.

With no earlier turns, only frustration can apply.

Earlier turns, oldest first (empty when this is the first message):
{{history}}

The athlete's message:
{{message}}`;

interface Template { key: string; evaluator: { type: string; source?: string; language?: string; promptMessages?: { role: string; content: string }[]; outputDefinition?: { dataType: string; score?: { description?: string }; reasoning?: { description?: string } } } }
const templates = JSON.parse(await Deno.readTextFile(new URL('./managed_flag_templates.json', import.meta.url))) as Template[];
const template = (key: string) => { const t = templates.find((x) => x.key === key); if (!t) throw new Error(`no managed template "${key}"`); return t.evaluator; };
const judge = (name: string, key: string) => {
  const t = template(key);
  return { name, type: 'llm_as_judge', prompt: t.promptMessages, modelConfig: MODEL,
    outputDefinition: { dataType: t.outputDefinition!.dataType, scoreValueInstructions: t.outputDefinition!.score?.description, scoreReasoningInstructions: t.outputDefinition!.reasoning?.description } };
};
const HISTORY = { source: 'metadata', jsonPath: '$.history' };
const MESSAGE = { source: 'input' };

/** Each evaluator with the mapping the rule gives it. A code evaluator takes none. */
const EVALUATORS: { body: Record<string, unknown>; mapping?: Record<string, unknown>[] }[] = [
  { body: judge('user_disagreement', 'user-disagreement'), mapping: [{ variable: 'conversation_history', ...HISTORY }, { variable: 'last_user_message', ...MESSAGE }] },
  { body: judge('user_distress', 'user-distress'), mapping: [{ variable: 'conversation_history', ...HISTORY }, { variable: 'last_user_message', ...MESSAGE }] },
  { body: { name: 'all_caps', type: 'code', sourceCode: template('all-caps').source, sourceCodeLanguage: template('all-caps').language } },
  { body: { name: 'conversation_signal', type: 'llm_as_judge', prompt: CONVERSATION_SIGNAL, modelConfig: MODEL,
      outputDefinition: { dataType: 'BOOLEAN', scoreValueInstructions: 'True when this message is a correction, a repeat or frustration. False otherwise.', scoreReasoningInstructions: 'One sentence. Name the signal (correction, repeat or frustration) and quote the words that show it, or say why none applies.' } },
    mapping: [{ variable: 'history', ...HISTORY }, { variable: 'message', ...MESSAGE }] },
];
const FILTER = [
  { type: 'stringOptions', column: 'traceName', operator: 'any of', value: ['vana-turn'] },
  { type: 'boolean', column: 'isRootObservation', operator: '=', value: true },
  { type: 'stringOptions', column: 'environment', operator: 'any of', value: ['dev'] },
  { type: 'arrayOptions', column: 'tags', operator: 'any of', value: ['message'] },
];

const env = Object.fromEntries((await Deno.readTextFile('secrets/langfuse.env')).split('\n')
  .map((l) => l.match(/^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$/)).filter((m): m is RegExpMatchArray => !!m).map((m) => [m[1], m[2]]));
const base = env.LANGFUSE_BASE_URL ?? 'https://us.cloud.langfuse.com';
const headers = { Authorization: `Basic ${btoa(`${env.LANGFUSE_PUBLIC_KEY}:${env.LANGFUSE_SECRET_KEY}`)}`, 'Content-Type': 'application/json' };
const pause = () => new Promise((r) => setTimeout(r, 2_200));
async function api(method: string, path: string, body?: unknown) {
  const r = await fetch(`${base}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  await pause();
  if (!r.ok) throw new Error(`${method} ${path} answered HTTP ${r.status}: ${text.slice(0, 600)}`);
  return JSON.parse(text);
}

const held = (await api('GET', '/api/public/v2/evaluators?limit=100')).data as { id: string; name: string }[];
const assignments: Record<string, unknown>[] = [];
let created = 0;
for (const e of EVALUATORS) {
  const name = e.body.name as string;
  let id = held.find((h) => h.name === name)?.id;
  if (id) console.log(`exists   evaluator ${name}`);
  else { id = (await api('POST', '/api/public/v2/evaluators', e.body)).id as string; created++; console.log(`created  evaluator ${name}`); }
  assignments.push({ evaluatorId: id, ...(e.mapping ? { variableMapping: e.mapping } : {}) });
}
const rules = (await api('GET', '/api/public/v2/evaluation-rules?limit=100')).data as { id: string; name: string }[];
const rule = rules.find((r) => r.name === RULE);
// An evaluator made on this run is not on a rule made on an earlier one, so the rule is given the full list again.
if (rule && created) { await api('PATCH', `/api/public/v2/evaluation-rules/${rule.id}`, { evaluatorAssignments: assignments }); console.log(`updated  rule "${RULE}" with ${created} new evaluator(s)`); }
else if (rule) console.log(`exists   rule "${RULE}"`);
else { await api('POST', '/api/public/v2/evaluation-rules', { name: RULE, enabled: true, sampling: 1, filter: FILTER, evaluatorAssignments: assignments }); console.log(`created  rule "${RULE}"`); }
