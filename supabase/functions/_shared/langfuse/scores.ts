/**
 * Scores — what an athlete did, written to Langfuse against the Conversation's Session (langfuse spec, "Athlete
 * signals"): a plan confirmed or its Draft abandoned, and an opinion volunteered to Vana.
 *
 * The server writes them; the Flutter app never talks to Langfuse. Each Score is sent under the score config of its
 * name, which Langfuse validates it against. The configs are read once and kept for the function instance, so a
 * config deleted and remade in Langfuse is picked up by the next instance with no deploy.
 *
 * A Score never changes what the athlete sees: `recordScore` does not wait, hands the write to the runtime's
 * background-work hook, and logs a failure. With no keys it does nothing.
 */
import { background } from './runtime.ts';
import type { TracingEnvironment } from './tracing.ts';

export interface Score {
  name: 'plan_confirmed' | 'athlete_feedback';
  /** BOOLEAN: 1 is yes, 0 is no. NUMERIC: within the config's range. */
  value: number;
  dataType: 'BOOLEAN' | 'NUMERIC';
  /** The Conversation. */
  sessionId: string;
  comment?: string;
  /** In place of the project's own environment. */
  environment?: TracingEnvironment;
}
export type SendScore = (score: Score) => Promise<void>;

const warn = (what: string, e: unknown) => console.error(`[langfuse] ${what}:`, (e as Error)?.message ?? e);

/** Langfuse's scores API over HTTP. */
export function langfuseScoreSender(keys: { publicKey: string; secretKey: string; baseUrl: string; environment?: string }): SendScore {
  const headers = { Authorization: `Basic ${btoa(`${keys.publicKey}:${keys.secretKey}`)}`, 'Content-Type': 'application/json' };
  let configs: Promise<Map<string, string>> | null = null;
  /** The live score configs' ids by name. A failed read is not kept, so the next Score asks again. */
  const configIds = () => (configs ??= (async () => {
    const r = await fetch(`${keys.baseUrl}/api/public/score-configs?limit=100`, { headers });
    if (!r.ok) { await r.body?.cancel(); throw new Error(`reading score configs: HTTP ${r.status}`); }
    const body = await r.json() as { data?: { id: string; name: string; isArchived?: boolean }[] };
    return new Map((body.data ?? []).filter((c) => !c.isArchived).map((c) => [c.name, c.id]));
  })().catch((e) => { configs = null; throw e; }));
  return async (score) => {
    const configId = (await configIds()).get(score.name);
    if (!configId) throw new Error(`no score config named "${score.name}"`);
    const { environment, comment, ...rest } = score;
    const r = await fetch(`${keys.baseUrl}/api/public/scores`, { method: 'POST', headers, body: JSON.stringify({ ...rest, configId, ...(comment ? { comment } : {}), environment: environment ?? keys.environment }) });
    const answer = await r.text();
    if (!r.ok) throw new Error(`HTTP ${r.status}: ${answer.slice(0, 200)}`);
  };
}

let fromEnv: SendScore | null | undefined;
let inPlace: SendScore | null = null;
/** In place of the instance's sender, for a test. Null puts it back. */
export function setScoreSender(send: SendScore | null): void { inPlace = send; }
/** The function instance's sender, from the function secrets. Null with no keys set. */
function defaultSender(): SendScore | null {
  if (inPlace) return inPlace;
  if (fromEnv !== undefined) return fromEnv;
  const publicKey = Deno.env.get('LANGFUSE_PUBLIC_KEY'); const secretKey = Deno.env.get('LANGFUSE_SECRET_KEY');
  fromEnv = publicKey && secretKey
    ? langfuseScoreSender({ publicKey, secretKey, baseUrl: Deno.env.get('LANGFUSE_BASE_URL') ?? 'https://us.cloud.langfuse.com', environment: Deno.env.get('LANGFUSE_TRACING_ENVIRONMENT') ?? undefined })
    : null;
  return fromEnv;
}

/** Writes a Score in the background. Never throws and is never waited for. */
export function recordScore(score: Score): void {
  try {
    const send = defaultSender();
    if (!send) return;
    background(send(score).catch((e) => warn(`score "${score.name}" not written`, e)));
  } catch (e) { warn(`score "${score.name}" not written`, e); }
}
