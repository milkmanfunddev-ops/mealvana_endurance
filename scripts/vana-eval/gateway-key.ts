/**
 * The gateway key an eval script spends when it calls the AI Gateway itself (mp-467, ticket ai-cost 02).
 *
 * Evals and build agents have their own key with its own monthly budget, so a runaway eval stops at that
 * cap and never eats the dev or production key's. Order:
 *   1. `AI_GATEWAY_API_KEY_EVALS` in the environment
 *   2. `AI_GATEWAY_API_KEY_EVALS` in `secrets/ai_gateway.env` at the repo root
 *   3. an explicitly exported `AI_GATEWAY_API_KEY`, with a warning that it is not the evals key
 * The file's plain `AI_GATEWAY_API_KEY` is never read: that is not a key with an evals budget.
 *
 * The chat evals (`run.ts`, `lifecycle.ts`, `personalization.ts`) hold no key: they call the DEV edge functions,
 * whose spend lands on the dev key. This is for the scripts that call the gateway directly (the model tests).
 */
export const EVALS_KEY = 'AI_GATEWAY_API_KEY_EVALS';

export interface KeySources {
  env: (name: string) => string | undefined;
  file: Record<string, string>;
  warn?: (msg: string) => void;
}

export function evalsGatewayKey({ env, file, warn = console.warn }: KeySources): string | null {
  const own = env(EVALS_KEY) || file[EVALS_KEY];
  if (own) return own;
  const exported = env('AI_GATEWAY_API_KEY');
  if (exported) {
    warn(`vana-eval: ${EVALS_KEY} not found; spending the exported AI_GATEWAY_API_KEY instead (not the evals budget)`);
    return exported;
  }
  return null;
}

/** Reads `KEY=value` lines; a missing file is an empty map. */
export function readEnvFile(path: string): Record<string, string> {
  try {
    const o: Record<string, string> = {};
    for (const line of Deno.readTextFileSync(path).split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m) o[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
    return o;
  } catch {
    return {};
  }
}

/** The evals key from this process's environment and the repo's secrets file. */
export function evalsGatewayKeyFromRepo(): string | null {
  const root = new URL('../../', import.meta.url).pathname;
  return evalsGatewayKey({ env: (k) => Deno.env.get(k), file: readEnvFile(root + 'secrets/ai_gateway.env') });
}
