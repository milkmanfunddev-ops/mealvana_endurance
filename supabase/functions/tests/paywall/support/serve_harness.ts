/**
 * Drive a function's real `index.ts` in-process: the handler it hands to std's `serve()`, with no
 * socket and no network.
 *
 * The functions register their handler with `serve()` from std@0.224.0 at import time, so the
 * handler cannot be imported as a value. std's `serve` calls `Deno.listen` synchronously, then
 * `listener.accept()` → `Deno.serveHttp(conn)` → `httpConn.nextRequest()` → `respondWith(response)`.
 * This harness replaces `Deno.listen` and `Deno.serveHttp` with in-memory fakes for the length of
 * one import, so every request [call] sends goes through the module's own handler (auth, body
 * parsing, the Pro gate, the credit check) exactly as deployed.
 *
 * Outbound traffic goes through `globalThis.fetch`, which the caller stubs (see [withWorld]).
 */

type RequestEvent = { request: Request; respondWith(r: Response | Promise<Response>): Promise<void> };

interface FakeListener {
  push(event: RequestEvent): void;
}

function fakeListener(): FakeListener & Record<string, unknown> {
  const waiting: ((conn: unknown) => void)[] = [];
  const queued: unknown[] = [];
  const addr = { transport: 'tcp', hostname: '127.0.0.1', port: 0 };
  return {
    addr,
    // deno-lint-ignore require-await
    async accept() {
      const next = queued.shift();
      if (next) return next;
      return new Promise((resolve) => waiting.push(resolve));
    },
    close() {},
    [Symbol.asyncIterator]() { return { next: () => new Promise(() => {}) }; },
    push(event: RequestEvent) {
      const conn = { localAddr: addr, remoteAddr: addr, event };
      const w = waiting.shift();
      if (w) w(conn);
      else queued.push(conn);
    },
  };
}

/** One connection, one request, then closed. */
function fakeHttpConn(conn: { event: RequestEvent }) {
  let served = false;
  return {
    // deno-lint-ignore require-await
    async nextRequest() {
      if (served) return null;
      served = true;
      return conn.event;
    },
    close() {},
  };
}

export type Call = (req: Request) => Promise<Response>;

/** Import [modulePath] (a function's index.ts) and return a caller for its registered handler. */
export async function loadFunction(modulePath: string): Promise<Call> {
  // deno-lint-ignore no-explicit-any
  const d = Deno as any;
  const realListen = d.listen;
  const realServeHttp = d.serveHttp;
  let listener: ReturnType<typeof fakeListener> | null = null;
  d.listen = () => (listener = fakeListener());
  // Left in place after the import: std calls it lazily, per accepted connection.
  d.serveHttp = (conn: { event?: RequestEvent }) =>
    conn && conn.event ? fakeHttpConn(conn as { event: RequestEvent }) : realServeHttp(conn);
  try {
    await import(modulePath);
  } finally {
    d.listen = realListen;
  }
  if (!listener) throw new Error(`${modulePath} did not call serve()`);
  const l = listener as ReturnType<typeof fakeListener>;
  return (request: Request) =>
    new Promise<Response>((resolve) => {
      l.push({
        request,
        respondWith: async (r) => { resolve(await r); },
      });
    });
}

// ---------------------------------------------------------------------------
// A fake Supabase + AI Gateway behind globalThis.fetch
// ---------------------------------------------------------------------------

export const STUB_SUPABASE_URL = 'https://stub.supabase.test';

/** The env every function reads at load. Set before the first [loadFunction]. */
export function setStubEnv(): void {
  Deno.env.set('SUPABASE_URL', STUB_SUPABASE_URL);
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', 'service-role-not-real');
  Deno.env.set('SUPABASE_ANON_KEY', 'anon-not-real');
  Deno.env.set('AI_GATEWAY_API_KEY', 'gateway-not-real');
  // Credits enforced, so "holding bought budget" means the wallet check would say yes.
  Deno.env.set('AI_CREDITS_ENFORCED', 'true');
}

export interface World {
  userId: string;
  /** `public.user_entitlements` rows, as the RevenueCat webhook writes them. */
  entitlements: { user_id: string; active_until: string | null; period_type: string | null }[];
  /** What `ai_budget_reserve` sees: the caller's budget in micro-dollars (ai-cost ticket 09). */
  balance: number;
  /** When true the wallet RPCs answer 500: the database error that must refuse the call (ticket 09). */
  budgetDown?: boolean;
  /** `public.users` rows (meal-photo reads `is_internal`; the gate reads `is_admin`, 122-004). */
  users: { id: string; is_internal: boolean; is_admin?: boolean | null }[];
}

/** Every outbound request, as `METHOD path` (host dropped for Supabase, kept for anything else). */
export type Hits = string[];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

/** Answer PostgREST's GET on [table] with [rows] filtered by the `eq.` params. */
function tableAnswer(url: URL, accept: string, rows: Record<string, unknown>[]): Response {
  const filtered = rows.filter((row) =>
    [...url.searchParams.entries()].every(([k, v]) =>
      k === 'select' || !v.startsWith('eq.') || String(row[k]) === v.slice(3)
    )
  );
  if (accept.includes('vnd.pgrst.object')) {
    if (filtered.length === 1) return json(filtered[0]);
    return json({ code: 'PGRST116', message: 'JSON object requested, multiple (or no) rows returned', details: `${filtered.length} rows`, hint: null }, 406);
  }
  return json(filtered);
}

/** Run [body] with fetch answering from [world]. Unknown Supabase routes answer 404; anything else (the AI Gateway) 402. */
export async function withWorld<T>(world: World, body: (hits: Hits) => Promise<T>): Promise<T> {
  const realFetch = globalThis.fetch;
  const hits: Hits = [];
  globalThis.fetch = (async (input: Request | URL | string, init?: RequestInit) => {
    const req = input instanceof Request ? input : new Request(input, init);
    const url = new URL(req.url);
    const accept = req.headers.get('accept') ?? '';
    if (url.origin !== STUB_SUPABASE_URL) {
      hits.push(`${req.method} ${url.origin}${url.pathname}`);
      return json({ error: { message: 'stub gateway: no budget', type: 'insufficient_funds' } }, 402);
    }
    hits.push(`${req.method} ${url.pathname}`);
    switch (url.pathname) {
      case '/auth/v1/user':
        return json({ id: world.userId, aud: 'authenticated', role: 'authenticated', email: 'athlete@example.test' });
      case '/rest/v1/user_entitlements':
        return tableAnswer(url, accept, world.entitlements);
      case '/rest/v1/users':
        return tableAnswer(url, accept, world.users);
      case '/rest/v1/rpc/ai_budget_reserve': {
        if (world.budgetDown) return json({ code: '57P01', message: 'terminating connection' }, 500);
        // The budget's one statement (ticket 09): allowed when the balance covers the estimate the function asked for.
        const args = await req.clone().json().catch(() => ({})) as { p_estimate?: number };
        const allowed = world.balance >= (args.p_estimate ?? 0);
        return json({ allowed, reservation_id: allowed ? 'res-stub' : undefined, balance: world.balance, allowance: 0, allowance_monthly: 0, allowance_expires_at: null });
      }
      case '/rest/v1/rpc/ai_budget_settle':
        return json({ settled: true });
      default:
        if (url.pathname.startsWith('/rest/v1/') && req.method === 'GET') return tableAnswer(url, accept, []);
        return json({ message: `stub: no route for ${req.method} ${url.pathname}` }, 404);
    }
  }) as typeof fetch;
  try {
    return await body(hits);
  } finally {
    globalThis.fetch = realFetch;
  }
}
