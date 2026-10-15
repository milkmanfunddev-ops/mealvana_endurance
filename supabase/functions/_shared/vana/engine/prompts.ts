/**
 * PromptSource implementations. Files for now: ops/experiments/setup-chat/v7/prompts/<stem>.md, found through the
 * container-root workspace.env registry (OPS_ROOT) so no path is hardcoded. Langfuse plugs in as another PromptSource.
 */
import type { PromptSource } from './adapters.ts';

export const V7_PROMPTS = 'experiments/setup-chat/v7/prompts';

/** An in-memory source: tests and the harness's "edit one prompt" lane. */
export const memoryPrompts = (map: Record<string, string>): PromptSource => ({
  get: (stem) => (stem in map ? Promise.resolve(map[stem]) : Promise.reject(new Error(`no prompt "${stem}"`))),
});

/** Reads `<dir>/<stem>.md`, cached per stem for the life of the source. */
export function filePromptSource(dir: string): PromptSource {
  const cache = new Map<string, string>();
  return {
    async get(stem) {
      const hit = cache.get(stem);
      if (hit !== undefined) return hit;
      const text = await Deno.readTextFile(`${dir}/${stem}.md`);
      cache.set(stem, text);
      return text;
    },
  };
}

/** Walk up from `from` to the directory holding workspace.env (the container root), or null. */
export function findWorkspaceRoot(from: string = new URL('.', import.meta.url).pathname): string | null {
  let dir = from.replace(/\/+$/, '');
  for (let i = 0; i < 12 && dir; i++) {
    try { Deno.statSync(`${dir}/workspace.env`); return dir; } catch { /* keep walking */ }
    const up = dir.slice(0, dir.lastIndexOf('/'));
    if (up === dir) break;
    dir = up;
  }
  return null;
}

/** OPS_ROOT from workspace.env (`OPS_ROOT="$MV_ROOT/ops"`), resolved against the root it was found in. */
export function opsRootFromWorkspace(root: string): string | null {
  try {
    const env = Deno.readTextFileSync(`${root}/workspace.env`);
    const m = env.match(/^OPS_ROOT="?([^"\n]+)"?/m);
    return m ? m[1].replace('$MV_ROOT', root).replace('${MV_ROOT}', root) : null;
  } catch { return null; }
}

/** The v7 prompts folder, or null when this checkout has no ops sibling (CI on the app repo alone). */
export function v7PromptsDir(): string | null {
  const fromEnv = Deno.env.get('VANA_PROMPTS_DIR');
  if (fromEnv) return fromEnv;
  const root = findWorkspaceRoot();
  const ops = root ? opsRootFromWorkspace(root) : null;
  return ops ? `${ops}/${V7_PROMPTS}` : null;
}
