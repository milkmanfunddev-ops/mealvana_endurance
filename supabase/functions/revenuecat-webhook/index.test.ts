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
import {
  entitlementRowFor,
  isProEvent,
  isStaleEvent,
  PRO_PRODUCT_IDS,
  type RcEvent,
  SUBSCRIPTION_EVENT_TYPES,
  transferParties,
} from './entitlements.ts';

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
  mealvana_credits_50: 50,
  mealvana_credits_250: 250,
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
      if (error.code === '23503') {
        return json({ ok: true, ignored: 'user_not_in_project' });
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
      product_id: 'mealvana_credits_50',
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
      assertEquals(body.granted, 50); // mealvana_credits_50 default mapping
      assertEquals(body.balance, 250); // RPC return surfaced as new balance

      // The DB write itself: exactly one grant_credits call, right args.
      assertEquals(client.calls.length, 1);
      assertEquals(client.calls[0].fn, 'grant_credits');
      assertEquals(client.calls[0].args, {
        p_user_id: USER_ID,
        p_amount: 50,
        p_reason: 'grant_purchase',
        p_ref: `evt-${type}`,
      });
    });
  }

  it('default product map: the 250 pack grants its amount', async () => {
    for (const [productId, expected] of [
      ['mealvana_credits_250', 250],
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

  it('FK violation 23503 (user not in this project) → 200 acked, no retry storm', async () => {
    // Dev + prod share one RC project and TestFlight is always sandbox, so each
    // Supabase project receives events for users that only exist in the other.
    const client = new FakeSupabaseClient({
      error: {
        code: '23503',
        message: 'insert or update on table "token_wallets" violates foreign key constraint',
      },
    });
    const res = await handleWebhook(rcRequest(rcEvent()), envWith(), client);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.ok, true);
    assertEquals(body.ignored, 'user_not_in_project');
    assertEquals(client.calls.length, 1);
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
    assertEquals(client.calls[0].args.p_amount, 50);
  });

  it('zero-credit mapping is treated as unmapped (never grants 0)', async () => {
    const env = envWith({ RC_PRODUCT_CREDITS: '{"mealvana_credits_50":0}' });
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
  assert(src.includes("'23503'"), 'index.ts no longer acks cross-project user misses');
  assert(src.includes("p_reason: 'grant_purchase'"), 'grant reason drifted');
});

// ---------------------------------------------------------------------------
// G. Pro subscription → user_entitlements
//
// The mapping lives in ./entitlements.ts and is imported here directly (no
// mirror), so these tests run the code the handler runs. The handler wiring
// (branch order, upsert target, 23503 ack) is asserted against index.ts source.
// ---------------------------------------------------------------------------

const NOW_MS = Date.parse('2026-09-01T12:00:00Z');
const IN_30_DAYS_MS = NOW_MS + 30 * 24 * 60 * 60 * 1000;
const YESTERDAY_MS = NOW_MS - 24 * 60 * 60 * 1000;

function proEvent(overrides: Record<string, unknown> = {}): RcEvent {
  return {
    id: 'evt-pro-001',
    type: 'INITIAL_PURCHASE',
    app_user_id: USER_ID,
    product_id: 'mealvana_pro_monthly',
    entitlement_ids: ['pro'],
    store: 'APP_STORE',
    period_type: 'NORMAL',
    event_timestamp_ms: NOW_MS,
    expiration_at_ms: IN_30_DAYS_MS,
    ...overrides,
  };
}

describe('G. Pro subscription mapping (entitlements.ts)', () => {
  it('isProEvent: entitlement_ids containing pro wins regardless of product', () => {
    assert(isProEvent({ entitlement_ids: ['pro'], product_id: 'anything' }));
    assert(!isProEvent({ entitlement_ids: ['other'], product_id: 'mealvana_credits_50' }));
  });

  it('isProEvent: every one of the Pro store SKUs matches without entitlement_ids', () => {
    for (const sku of PRO_PRODUCT_IDS) {
      assert(isProEvent({ product_id: sku }), `${sku} should be a Pro SKU`);
    }
    // Play may send the bare subscription id without the base-plan suffix.
    assert(isProEvent({ product_id: 'mealvana_pro_annual' }));
  });

  it('isProEvent: a credit pack is NOT a Pro event (falls through to grant path)', () => {
    assert(!isProEvent({ product_id: 'mealvana_credits_50' }));
    assert(!isProEvent({ product_id: 'mealvana_credits_test_1_prod' }));
    assert(!isProEvent({}));
  });

  it('SUBSCRIPTION_EVENT_TYPES covers the lifecycle the spec lists', () => {
    for (
      const t of [
        'INITIAL_PURCHASE',
        'RENEWAL',
        'CANCELLATION',
        'UNCANCELLATION',
        'EXPIRATION',
        'BILLING_ISSUE',
        'PRODUCT_CHANGE',
        'SUBSCRIPTION_PAUSED',
        'SUBSCRIPTION_EXTENDED',
        'TEST',
      ]
    ) {
      assert(SUBSCRIPTION_EVENT_TYPES.has(t), `${t} missing`);
    }
    assert(!SUBSCRIPTION_EVENT_TYPES.has('NON_RENEWING_PURCHASE'), 'consumables are not subscriptions');
  });

  it('INITIAL_PURCHASE with a future expiry → active row with the event fields', () => {
    const row = entitlementRowFor(proEvent(), NOW_MS);
    assertEquals(row.entitlement, 'pro');
    assertEquals(row.active, true);
    assertEquals(row.product_id, 'mealvana_pro_monthly');
    assertEquals(row.store, 'APP_STORE');
    assertEquals(row.period_type, 'NORMAL');
    assertEquals(row.expires_at, new Date(IN_30_DAYS_MS).toISOString());
    assertEquals(row.updated_at, new Date(NOW_MS).toISOString());
    assertEquals(row.unsubscribe_detected_at, null);
    assertEquals(row.billing_issue_detected_at, null);
    assertEquals(row.source, 'revenuecat');
  });

  it('a past expiration_at_ms → inactive even on RENEWAL', () => {
    const row = entitlementRowFor(
      proEvent({ type: 'RENEWAL', expiration_at_ms: YESTERDAY_MS }),
      NOW_MS,
    );
    assertEquals(row.active, false);
  });

  it('EXPIRATION → inactive even if expiration_at_ms is (clock-skew) in the future', () => {
    const row = entitlementRowFor(
      proEvent({ type: 'EXPIRATION', expiration_at_ms: NOW_MS + 60_000 }),
      NOW_MS,
    );
    assertEquals(row.active, false);
  });

  it('missing expiration_at_ms → inactive (never grant open-ended access by accident)', () => {
    const row = entitlementRowFor(proEvent({ expiration_at_ms: undefined }), NOW_MS);
    assertEquals(row.active, false);
    assertEquals(row.expires_at, null);
  });

  it('CANCELLATION keeps access until expiry and stamps unsubscribe_detected_at', () => {
    const row = entitlementRowFor(proEvent({ type: 'CANCELLATION' }), NOW_MS);
    assertEquals(row.active, true);
    assertEquals(row.unsubscribe_detected_at, new Date(NOW_MS).toISOString());
  });

  it('UNCANCELLATION clears unsubscribe_detected_at carried from the stored row', () => {
    const previous = entitlementRowFor(proEvent({ type: 'CANCELLATION' }), NOW_MS);
    const row = entitlementRowFor(
      proEvent({ type: 'UNCANCELLATION', event_timestamp_ms: NOW_MS + 1000 }),
      NOW_MS,
      previous,
    );
    assertEquals(row.unsubscribe_detected_at, null);
    assertEquals(row.active, true);
  });

  it('BILLING_ISSUE stamps billing_issue_detected_at; the next RENEWAL clears it', () => {
    const issue = entitlementRowFor(proEvent({ type: 'BILLING_ISSUE' }), NOW_MS);
    assertEquals(issue.billing_issue_detected_at, new Date(NOW_MS).toISOString());
    assertEquals(issue.active, true, 'grace period keeps access while RC extends expiry');

    const renewal = entitlementRowFor(
      proEvent({ type: 'RENEWAL', event_timestamp_ms: NOW_MS + 1000 }),
      NOW_MS,
      issue,
    );
    assertEquals(renewal.billing_issue_detected_at, null);
  });

  it('PRODUCT_CHANGE keeps a stored cancellation timestamp (event is silent on it)', () => {
    const cancelled = entitlementRowFor(proEvent({ type: 'CANCELLATION' }), NOW_MS);
    const changed = entitlementRowFor(
      proEvent({
        type: 'PRODUCT_CHANGE',
        product_id: 'mealvana_pro_annual',
        event_timestamp_ms: NOW_MS + 1000,
      }),
      NOW_MS,
      cancelled,
    );
    assertEquals(changed.unsubscribe_detected_at, cancelled.unsubscribe_detected_at);
    assertEquals(changed.product_id, 'mealvana_pro_annual');
  });

  it('event fields missing from the payload fall back to the stored row', () => {
    const previous = entitlementRowFor(proEvent(), NOW_MS);
    const row = entitlementRowFor(
      proEvent({ product_id: undefined, store: undefined, period_type: undefined }),
      NOW_MS,
      previous,
    );
    assertEquals(row.product_id, 'mealvana_pro_monthly');
    assertEquals(row.store, 'APP_STORE');
    assertEquals(row.period_type, 'NORMAL');
  });

  it('isStaleEvent: an event older than the stored updated_at is stale; same/newer is not', () => {
    const stored = new Date(NOW_MS).toISOString();
    assert(isStaleEvent(proEvent({ event_timestamp_ms: NOW_MS - 1 }), stored));
    assert(!isStaleEvent(proEvent({ event_timestamp_ms: NOW_MS }), stored));
    assert(!isStaleEvent(proEvent({ event_timestamp_ms: NOW_MS + 1 }), stored));
    assert(!isStaleEvent(proEvent(), null), 'no stored row → never stale');
    assert(!isStaleEvent(proEvent({ event_timestamp_ms: undefined }), stored));
  });

  it('transferParties reads both user lists and ignores empties', () => {
    const { from, to } = transferParties({
      type: 'TRANSFER',
      transferred_from: ['a', ''],
      transferred_to: ['b'],
    });
    assertEquals(from, ['a']);
    assertEquals(to, ['b']);
    assertEquals(transferParties({}), { from: [], to: [] });
  });
});

Deno.test('wiring fidelity — index.ts routes Pro events to user_entitlements before the grant path', async () => {
  const src = await Deno.readTextFile(new URL('./index.ts', import.meta.url));
  const proBranch = src.indexOf('SUBSCRIPTION_EVENT_TYPES.has(type) && isProEvent(event)');
  const grantGate = src.indexOf('if (!GRANTING_EVENT_TYPES.has(type))');
  assert(proBranch > 0, 'index.ts no longer routes Pro subscription events');
  assert(proBranch < grantGate, 'Pro branch must run before the consumable grant path');
  assert(src.includes("from('user_entitlements')"), 'index.ts no longer writes user_entitlements');
  assert(
    src.includes("onConflict: 'user_id,entitlement'"),
    'upsert must conflict on the (user_id, entitlement) primary key',
  );
  assert(src.includes('TRANSFER_EVENT_TYPE'), 'index.ts no longer handles TRANSFER');
  // The 23503 ack must exist in the Pro branch too (dev/prod share one RC project).
  assert(
    src.split("'23503'").length - 1 >= 2,
    'both the grant path and the entitlement path must ack cross-project user misses',
  );
});
