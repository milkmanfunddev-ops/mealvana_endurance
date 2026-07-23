/**
 * Unit tests for revenuecat-webhook edge function.
 *
 * Strategy (same as create-user/ai-coach tests): the handler is registered via
 * `serve()` and reads Deno.env at module top, so it cannot be imported as a
 * plain function. We mirror the handler logic here 1:1 with an injected env
 * lookup and an injected Supabase client, and assert on the captured
 * `grant_credits` RPC writes — not just status codes.
 *
 * Covered:
 *   - method / shared-secret enforcement (405, unconfigured 500, bad/missing
 *     Authorization 401 — and that NO grant is attempted)
 *   - malformed JSON body → 400
 *   - non-granting event types (CANCELLATION, EXPIRATION, TEST) acked 200,
 *     no grant
 *   - happy path for INITIAL_PURCHASE / RENEWAL / NON_RENEWING_PURCHASE:
 *     grant_credits called with p_user_id / p_amount / p_reason / p_ref
 *   - unmapped product acked 200, no grant
 *   - missing app_user_id / event id → 400
 *   - idempotency: rpc unique-violation (23505) → 200 { idempotent: true }
 *   - rpc error / thrown exception → 500
 *   - RC_PRODUCT_CREDITS env override (valid JSON used, bad JSON → defaults)
 *
 * Run with:
 *   deno test --allow-read --allow-write --allow-env --node-modules-dir=none \
 *     supabase/functions/revenuecat-webhook/index.test.ts
 */

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it, beforeEach } from 'https://deno.land/std@0.224.0/testing/bdd.ts';

// ---------------------------------------------------------------------------
// Handler mirror (kept 1:1 with revenuecat-webhook/index.ts)
// ---------------------------------------------------------------------------

type EnvLookup = (key: string) => string | undefined;

interface RpcCall {
  fn: string;
  args: Record<string, unknown>;
}

interface FakeRpcResult {
  data?: unknown;
  error?: { code?: string; message: string } | null;
  throws?: unknown;
}

/** Captures every rpc() call and returns a configured result. */
class FakeSupabaseClient {
  calls: RpcCall[] = [];
  result: FakeRpcResult;

  constructor(result: FakeRpcResult = { data: 100, error: null }) {
    this.result = result;
  }

  // deno-lint-ignore require-await
  async rpc(fn: string, args: Record<string, unknown>) {
    this.calls.push({ fn, args });
    if (this.result.throws !== undefined) throw this.result.throws;
    return { data: this.result.data ?? null, error: this.result.error ?? null };
  }
}

const DEFAULT_PRODUCT_CREDITS: Record<string, number> = {
  mealvana_credits_100: 100,
  mealvana_credits_500: 500,
  mealvana_credits_1200: 1200,
};

const GRANTING_EVENT_TYPES = new Set(['NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE', 'RENEWAL']);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function productCredits(env: EnvLookup): Record<string, number> {
  const raw = env('RC_PRODUCT_CREDITS');
  if (!raw) return DEFAULT_PRODUCT_CREDITS;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object') return parsed as Record<string, number>;
  } catch (_e) {
    // bad JSON → fall through to defaults (real handler logs this)
  }
  return DEFAULT_PRODUCT_CREDITS;
}

/** Mirrors the serve() callback in index.ts, with env + client injected. */
async function handleWebhook(
  req: Request,
  env: EnvLookup,
  client: FakeSupabaseClient,
): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const webhookSecret = env('REVENUECAT_WEBHOOK_SECRET') ?? '';
  if (!webhookSecret) return json({ error: 'Webhook not configured' }, 500);

  const auth = req.headers.get('Authorization') ?? '';
  if (auth !== webhookSecret) return json({ error: 'Unauthorized' }, 401);

  let payload: { event?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
  const event = payload.event ?? {};
  const type = String(event.type ?? '');
  const eventId = String(event.id ?? '');
  const appUserId = String(event.app_user_id ?? '');
  const productId = String(event.product_id ?? '');

  if (!GRANTING_EVENT_TYPES.has(type)) {
    return json({ ok: true, ignored: type });
  }

  const credits = productCredits(env)[productId];
  if (!credits || credits <= 0) {
    return json({ ok: true, ignored: 'unmapped_product', product_id: productId });
  }

  if (!appUserId || !eventId) {
    return json({ error: 'Missing app_user_id or event id' }, 400);
  }

  try {
    const { data, error } = await client.rpc('grant_credits', {
      p_user_id: appUserId,
      p_amount: credits,
      p_reason: 'grant_purchase',
      p_ref: eventId,
    });
    if (error) {
      if (error.code === '23505') {
        return json({ ok: true, idempotent: true });
      }
      return json({ error: 'grant failed' }, 500);
    }
    return json({ ok: true, granted: credits, balance: data });
  } catch (_e) {
    return json({ error: 'internal error' }, 500);
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const SECRET = 'rc-test-secret';
const USER_ID = 'c18d3737-0000-4000-8000-000000000001';

function envWith(overrides: Record<string, string | undefined> = {}): EnvLookup {
  const base: Record<string, string | undefined> = {
    REVENUECAT_WEBHOOK_SECRET: SECRET,
    ...overrides,
  };
  return (key) => base[key];
}

function rcRequest(
  body: unknown,
  { auth = SECRET, method = 'POST' }: { auth?: string | null; method?: string } = {},
): Request {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (auth !== null) headers['Authorization'] = auth;
  return new Request('http://localhost/revenuecat-webhook', {
    method,
    headers,
    body: method === 'POST' ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
  });
}

function rcEvent(overrides: Record<string, unknown> = {}): { event: Record<string, unknown> } {
  return {
    event: {
      id: 'evt-001',
      type: 'INITIAL_PURCHASE',
      app_user_id: USER_ID,
      product_id: 'mealvana_credits_100',
      ...overrides,
    },
  };
}

// ---------------------------------------------------------------------------
// A. Method + shared-secret enforcement
// ---------------------------------------------------------------------------

describe('A. auth / shared secret', () => {
  let client: FakeSupabaseClient;
  beforeEach(() => {
    client = new FakeSupabaseClient();
  });

  it('non-POST is rejected with 405 and no grant attempted', async () => {
    const res = await handleWebhook(rcRequest(null, { method: 'GET' }), envWith(), client);
    assertEquals(res.status, 405);
    assertEquals(client.calls.length, 0);
  });

  it('missing REVENUECAT_WEBHOOK_SECRET → 500 (unconfigured, never grants)', async () => {
    const res = await handleWebhook(
      rcRequest(rcEvent()),
      envWith({ REVENUECAT_WEBHOOK_SECRET: undefined }),
      client,
    );
    assertEquals(res.status, 500);
    assertEquals((await res.json()).error, 'Webhook not configured');
    assertEquals(client.calls.length, 0);
  });

  it('missing Authorization header → 401, no grant', async () => {
    const res = await handleWebhook(rcRequest(rcEvent(), { auth: null }), envWith(), client);
    assertEquals(res.status, 401);
    assertEquals((await res.json()).error, 'Unauthorized');
    assertEquals(client.calls.length, 0);
  });

  it('wrong Authorization value → 401, no grant', async () => {
    const res = await handleWebhook(
      rcRequest(rcEvent(), { auth: 'wrong-secret' }),
      envWith(),
      client,
    );
    assertEquals(res.status, 401);
    assertEquals(client.calls.length, 0);
  });

  it('secret must match exactly (Bearer-prefixed value is rejected)', async () => {
    const res = await handleWebhook(
      rcRequest(rcEvent(), { auth: `Bearer ${SECRET}` }),
      envWith(),
      client,
    );
    assertEquals(res.status, 401);
    assertEquals(client.calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// B. Body parsing
// ---------------------------------------------------------------------------

describe('B. malformed body', () => {
  it('invalid JSON → 400, no grant', async () => {
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(rcRequest('{not json'), envWith(), client);
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, 'Invalid JSON');
    assertEquals(client.calls.length, 0);
  });

  it('empty object (no event key) is treated as non-granting and acked 200', async () => {
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(rcRequest({}), envWith(), client);
    assertEquals(res.status, 200);
    assertEquals((await res.json()).ok, true);
    assertEquals(client.calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// C. Event-type branching
// ---------------------------------------------------------------------------

describe('C. event types', () => {
  for (const type of ['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE', 'TEST']) {
    it(`${type} is acked 200 with ignored=${type} and no grant`, async () => {
      const client = new FakeSupabaseClient();
      const res = await handleWebhook(rcRequest(rcEvent({ type })), envWith(), client);
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(body.ok, true);
      assertEquals(body.ignored, type);
      assertEquals(client.calls.length, 0);
    });
  }

  for (const type of ['INITIAL_PURCHASE', 'RENEWAL', 'NON_RENEWING_PURCHASE']) {
    it(`${type} with mapped product grants credits via grant_credits RPC`, async () => {
      const client = new FakeSupabaseClient({ data: 250, error: null });
      const res = await handleWebhook(
        rcRequest(rcEvent({ type, id: `evt-${type}` })),
        envWith(),
        client,
      );
      assertEquals(res.status, 200);
      const body = await res.json();
      assertEquals(body.ok, true);
      assertEquals(body.granted, 100); // mealvana_credits_100 default mapping
      assertEquals(body.balance, 250); // RPC return surfaced as new balance

      // The DB write itself: exactly one grant_credits call, right args.
      assertEquals(client.calls.length, 1);
      assertEquals(client.calls[0].fn, 'grant_credits');
      assertEquals(client.calls[0].args, {
        p_user_id: USER_ID,
        p_amount: 100,
        p_reason: 'grant_purchase',
        p_ref: `evt-${type}`,
      });
    });
  }

  it('default product map: 500 and 1200 packs grant their amounts', async () => {
    for (const [productId, expected] of [
      ['mealvana_credits_500', 500],
      ['mealvana_credits_1200', 1200],
    ] as const) {
      const client = new FakeSupabaseClient();
      const res = await handleWebhook(
        rcRequest(rcEvent({ product_id: productId })),
        envWith(),
        client,
      );
      assertEquals(res.status, 200);
      assertEquals(client.calls[0].args.p_amount, expected);
    }
  });

  it('unmapped product is acked 200 (so RC stops retrying) with no grant', async () => {
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(
      rcRequest(rcEvent({ product_id: 'monthly_subscription' })),
      envWith(),
      client,
    );
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.ignored, 'unmapped_product');
    assertEquals(body.product_id, 'monthly_subscription');
    assertEquals(client.calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// D. Required identifiers
// ---------------------------------------------------------------------------

describe('D. missing identifiers', () => {
  it('missing app_user_id → 400, no grant', async () => {
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(
      rcRequest(rcEvent({ app_user_id: undefined })),
      envWith(),
      client,
    );
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, 'Missing app_user_id or event id');
    assertEquals(client.calls.length, 0);
  });

  it('missing event id → 400, no grant', async () => {
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(rcRequest(rcEvent({ id: undefined })), envWith(), client);
    assertEquals(res.status, 400);
    assertEquals(client.calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// E. Grant outcomes (idempotency + errors)
// ---------------------------------------------------------------------------

describe('E. grant outcomes', () => {
  it('duplicate delivery (unique violation 23505) → 200 idempotent, RPC was attempted once', async () => {
    const client = new FakeSupabaseClient({
      error: { code: '23505', message: 'duplicate key value violates unique constraint' },
    });
    const res = await handleWebhook(rcRequest(rcEvent()), envWith(), client);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.ok, true);
    assertEquals(body.idempotent, true);
    // idempotency lives in the DB (token_ledger unique index on ref) — the
    // handler still issues the RPC, and the 23505 is swallowed as success.
    assertEquals(client.calls.length, 1);
    assertEquals(client.calls[0].args.p_ref, 'evt-001');
  });

  it('non-unique-violation RPC error → 500 grant failed (RC will retry)', async () => {
    const client = new FakeSupabaseClient({
      error: { code: 'P0001', message: 'wallet missing' },
    });
    const res = await handleWebhook(rcRequest(rcEvent()), envWith(), client);
    assertEquals(res.status, 500);
    assertEquals((await res.json()).error, 'grant failed');
  });

  it('RPC throwing → 500 internal error', async () => {
    const client = new FakeSupabaseClient({ throws: new Error('network down') });
    const res = await handleWebhook(rcRequest(rcEvent()), envWith(), client);
    assertEquals(res.status, 500);
    assertEquals((await res.json()).error, 'internal error');
  });
});

// ---------------------------------------------------------------------------
// F. RC_PRODUCT_CREDITS override
// ---------------------------------------------------------------------------

describe('F. RC_PRODUCT_CREDITS env override', () => {
  it('valid JSON map replaces the defaults entirely', async () => {
    const env = envWith({ RC_PRODUCT_CREDITS: '{"custom_pack":42}' });
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(
      rcRequest(rcEvent({ product_id: 'custom_pack' })),
      env,
      client,
    );
    assertEquals(res.status, 200);
    assertEquals(client.calls[0].args.p_amount, 42);

    // A default-mapped product is no longer mapped once overridden.
    const client2 = new FakeSupabaseClient();
    const res2 = await handleWebhook(rcRequest(rcEvent()), env, client2);
    assertEquals((await res2.json()).ignored, 'unmapped_product');
    assertEquals(client2.calls.length, 0);
  });

  it('malformed JSON override falls back to the default map', async () => {
    const env = envWith({ RC_PRODUCT_CREDITS: '{not json' });
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(rcRequest(rcEvent()), env, client);
    assertEquals(res.status, 200);
    assertEquals(client.calls[0].args.p_amount, 100);
  });

  it('zero-credit mapping is treated as unmapped (never grants 0)', async () => {
    const env = envWith({ RC_PRODUCT_CREDITS: '{"mealvana_credits_100":0}' });
    const client = new FakeSupabaseClient();
    const res = await handleWebhook(rcRequest(rcEvent()), env, client);
    assertEquals((await res.json()).ignored, 'unmapped_product');
    assertEquals(client.calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// Mirror-fidelity note: assert the mirrored constants match index.ts so this
// file rots loudly if the real handler's tables change.
// ---------------------------------------------------------------------------

Deno.test('mirror fidelity — constants match revenuecat-webhook/index.ts', async () => {
  const src = await Deno.readTextFile(new URL('./index.ts', import.meta.url));
  for (const type of GRANTING_EVENT_TYPES) {
    assert(src.includes(`'${type}'`), `index.ts no longer handles event type ${type}`);
  }
  for (const [product, amount] of Object.entries(DEFAULT_PRODUCT_CREDITS)) {
    assert(
      src.includes(`${product}: ${amount}`),
      `index.ts default credit map drifted for ${product}`,
    );
  }
  assert(src.includes("'23505'"), 'index.ts no longer special-cases unique violations');
  assert(src.includes("p_reason: 'grant_purchase'"), 'grant reason drifted');
});
