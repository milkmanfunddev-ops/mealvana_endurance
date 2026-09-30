/**
 * The prompt source — the one module that resolves a prompt by name (langfuse spec, "Prompts").
 *
 * Wording lives in Langfuse. The dev project asks for the `latest` label, so a saved edit is live at once; the prod
 * project asks for `production`, so moving that label is publishing and moving it back is the undo. There is no
 * `staging` label and no gate.
 *
 * A copy of every prompt is bundled in code. It is what runs when the fetch fails or times out, and the result says so
 * (`fallback`), which the Trace records. An outage at Langfuse never stops a Turn.
 *
 * Fetched prompts are kept in the function instance for a short time. A kept prompt past its time is still served
 * while it is fetched again in the background, so only a cold instance ever waits on Langfuse. A failed fetch is
 * remembered for a shorter time, so an outage costs one timeout and not one per Turn.
 *
 * Prompts are templates: `{{name}}` is filled by the caller (`compilePrompt`). What fills them stays in code.
 */
export type PromptLabel = 'latest' | 'production';

export interface FetchedPrompt { text: string; version: number; config?: Record<string, unknown> }
/** Langfuse's prompt API, as the source uses it. A test passes its own. */
export type FetchPrompt = (name: string, label: PromptLabel) => Promise<FetchedPrompt>;

export interface ResolvedPrompt {
  name: string;
  text: string;
  /** The Langfuse version, or null for the bundled copy. */
  version: number | null;
  config: Record<string, unknown>;
  /** True when the bundled copy stood in for a fetch that failed or timed out. */
  fallback: boolean;
}

export interface PromptSource {
  /** Every named prompt, each from Langfuse or, failing that, from the bundled copy. Never rejects. */
  resolve<N extends string>(names: readonly N[]): Promise<Record<N, ResolvedPrompt>>;
}

export interface PromptSourceConfig {
  label: PromptLabel;
  /** Absent: there is no Langfuse to ask, and every prompt is the bundled copy. */
  fetchPrompt?: FetchPrompt;
  /** The copy of every prompt that ships in code, by name. */
  bundled: Record<string, string>;
  /** How long a fetched prompt is served before it is fetched again. */
  ttlMs?: number;
  /** How long a failed fetch is remembered. */
  retryMs?: number;
  /** How long a Turn waits for a prompt it does not hold. */
  timeoutMs?: number;
  /** How long a background refresh may take. Longer, since no Turn is waiting: a slow Langfuse still gets through. */
  refreshTimeoutMs?: number;
  now?: () => number;
  /** Where the background refresh runs. EdgeRuntime.waitUntil in production. */
  background?: (p: Promise<unknown>) => void;
}

const warn = (what: string, e: unknown) => console.error(`[langfuse] ${what}:`, (e as Error)?.message ?? e);

/** Fills a template's `{{name}}` variables. A variable with no value is left as written, the way Langfuse leaves it. */
export function compilePrompt(template: string, variables: Record<string, string | number>): string {
  return template.replace(/\{\{\s*(\w+)\s*\}\}/g, (whole, name: string) => (Object.hasOwn(variables, name) ? String(variables[name]) : whole));
}

export function createPromptSource(config: PromptSourceConfig): PromptSource {
  const { label, fetchPrompt, bundled } = config;
  const ttlMs = config.ttlMs ?? 60_000; const retryMs = config.retryMs ?? 15_000; const timeoutMs = config.timeoutMs ?? 1_500; const refreshTimeoutMs = config.refreshTimeoutMs ?? 10_000;
  const now = config.now ?? Date.now;
  const background = config.background ?? ((p) => void p.catch(() => {}));
  const kept = new Map<string, { prompt: ResolvedPrompt; until: number }>();
  const inFlight = new Map<string, Promise<ResolvedPrompt>>();

  const bundledCopy = (name: string, fallback: boolean): ResolvedPrompt => {
    if (!(name in bundled)) throw new Error(`no bundled copy of prompt "${name}"`);
    return { name, text: bundled[name], version: null, config: {}, fallback };
  };
  /** One fetch per name at a time. It always settles: on any failure the bundled copy (or the prompt already held). */
  const load = (name: string, fetch: FetchPrompt, waitMs: number): Promise<ResolvedPrompt> => {
    const running = inFlight.get(name);
    if (running) return running;
    let timer: number | undefined;
    const timeout = new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error(`timed out after ${waitMs}ms`)), waitMs); });
    const p = Promise.race([Promise.resolve().then(() => fetch(name, label)), timeout])
      .then((f): ResolvedPrompt => {
        if (typeof f?.text !== 'string' || !f.text) throw new Error('empty prompt');
        const prompt = { name, text: f.text, version: f.version, config: f.config ?? {}, fallback: false };
        kept.set(name, { prompt, until: now() + ttlMs });
        return prompt;
      })
      .catch((e): ResolvedPrompt => {
        warn(`prompt "${name}" (${label}) not fetched, using ${kept.has(name) ? 'the one held' : 'the bundled copy'}`, e);
        const prompt = kept.get(name)?.prompt ?? bundledCopy(name, true);
        kept.set(name, { prompt, until: now() + retryMs });
        return prompt;
      })
      .finally(() => { clearTimeout(timer); inFlight.delete(name); });
    inFlight.set(name, p);
    return p;
  };
  const one = (name: string): Promise<ResolvedPrompt> => {
    if (!fetchPrompt) return Promise.resolve(bundledCopy(name, false));
    const held = kept.get(name);
    if (!held) return load(name, fetchPrompt, timeoutMs);
    if (held.until <= now()) background(load(name, fetchPrompt, refreshTimeoutMs));
    return Promise.resolve(held.prompt);
  };

  return {
    async resolve<N extends string>(names: readonly N[]) {
      const prompts = await Promise.all(names.map(one));
      return Object.fromEntries(prompts.map((p) => [p.name, p])) as Record<N, ResolvedPrompt>;
    },
  };
}

/** Langfuse's prompt API over HTTP: one prompt by name and label. */
export function langfuseFetchPrompt(keys: { publicKey: string; secretKey: string; baseUrl: string }): FetchPrompt {
  const authorization = `Basic ${btoa(`${keys.publicKey}:${keys.secretKey}`)}`;
  return async (name, label) => {
    const r = await fetch(`${keys.baseUrl}/api/public/v2/prompts/${encodeURIComponent(name)}?label=${label}`, { headers: { Authorization: authorization } });
    if (!r.ok) { await r.body?.cancel(); throw new Error(`HTTP ${r.status}`); }
    const body = await r.json() as { prompt?: unknown; version?: unknown; config?: unknown };
    if (typeof body.prompt !== 'string') throw new Error('not a text prompt');
    return { text: body.prompt, version: Number(body.version), config: body.config && typeof body.config === 'object' ? body.config as Record<string, unknown> : {} };
  };
}

/** The label a project asks for: `latest` on dev, `production` everywhere else. A project whose environment is unset
 *  or misspelt gets `production`, so an unpublished edit can only ever reach a project that says it is dev. */
export const promptLabelFor = (environment: string | undefined): PromptLabel => (environment === 'dev' ? 'latest' : 'production');

/** The function instance's prompt source, from the function secrets. With no keys set every prompt is the bundled copy. */
export function promptSourceFromEnv(bundled: Record<string, string>, background: (p: Promise<unknown>) => void): PromptSource {
  const publicKey = Deno.env.get('LANGFUSE_PUBLIC_KEY'); const secretKey = Deno.env.get('LANGFUSE_SECRET_KEY');
  return createPromptSource({
    label: promptLabelFor(Deno.env.get('LANGFUSE_TRACING_ENVIRONMENT')),
    fetchPrompt: publicKey && secretKey ? langfuseFetchPrompt({ publicKey, secretKey, baseUrl: Deno.env.get('LANGFUSE_BASE_URL') ?? 'https://us.cloud.langfuse.com' }) : undefined,
    bundled, background,
  });
}
