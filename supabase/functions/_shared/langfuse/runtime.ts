/** The runtime's background-work hook: what keeps a flush or a prompt refresh alive after the response. Detached where
 *  there is none (a local run, a test that installs no hook). */
export function background(p: Promise<unknown>): void {
  // deno-lint-ignore no-explicit-any
  const rt = (globalThis as any).EdgeRuntime;
  if (rt?.waitUntil) rt.waitUntil(p); else void p.catch(() => {});
}
