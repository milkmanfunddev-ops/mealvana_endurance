/**
 * Seam tests for the revenuecat-webhook edge function.
 *
 * The handler is built by `makeWebhookHandler()` (handler.ts) with the env
 * lookup and the database injected, so these tests run the code the deployed
 * function runs — no mirror. Events are shaped like RevenueCat's webhook
 * payloads (v1 `event` object: sandbox INITIAL_PURCHASE with a TRIAL period,
 * RENEWAL, CANCELLATION, EXPIRATION, TRANSFER with user lists), never like the
 * writer's own output (docs/test/README.md, "Seam tests").
 *
 * What the entitlement path must do (mp-285, mp-279, ticket 18):
 *   - a subscriber's first event lands active_until + period_type on their row;
 *   - the webhook writes those two fields (and the event time) and nothing else;
 *   - an event older than the row's event time is ignored;
 *   - a TRANSFER moves the row to the new owner and closes it on the old one;
 *   - nothing else in the payload reaches the table.
 * What the allowance path must do (mp-281, ticket 20):
 *   - INITIAL_PURCHASE and RENEWAL grant the monthly Allowance into the wallet;
 *   - EXPIRATION forfeits what is left; CANCELLATION leaves the wallet alone.
 * The credit-grant path (consumable packs) is unchanged and still covered.
 *
 * Run with:
 *   deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none \
 *     supabase/functions/revenuecat-webhook/index.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { beforeEach, describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { makeWebhookHandler, type WebhookDb } from './handler.ts';
import {
  entitlementRowFor,
  isProEvent,
  isStaleEvent,
  PRO_PRODUCT_IDS,
  type RcEvent,
  SUBSCRIPTION_EVENT_TYPES,
} from './entitlements.ts';

// ---------------------------------------------------------------------------
// Fake database: one table (user_entitlements) keyed by user_id, plus rpc().
// Supports the query shapes the handler uses and records every write.
// ---------------------------------------------------------------------------

type Row = Record<string, unknown> & { user_id: string };
type DbError = { code?: string; message: string } | null;

interface RpcCall {
  fn: string;
  args: Record<string, unknown>;
}

class FakeDb {
  rows = new Map<string, Row>();
  writes: { op: string; payload: unknown }[] = [];
  rpcCalls: RpcCall[] = [];
  rpcResult: { data?: unknown; error?: DbError; throws?: unknown } = { data: 100, error: null };
  /** Error returned by the next matching operation (then cleared). */
  failNext: { op: 'select' | 'upsert' | 'update'; error: DbError } | null = null;
  tables: string[] = [];

  from(table: string) {
    this.tables.push(table);
    return new FakeQuery(this);
  }

  // deno-lint-ignore require-await
  async rpc(fn: string, args: Record<string, unknown>) {
    this.rpcCalls.push({ fn, args });
    if (this.rpcResult.throws !== undefined) throw this.rpcResult.throws;
    return { data: this.rpcResult.data ?? null, error: this.rpcResult.error ?? null };
  }

  /** Seed a row as the table would hold it after an earlier event. */
  seed(row: Row) {
    this.rows.set(row.user_id, { ...row });
  }
}

class FakeQuery {
  private filters: ((r: Row) => boolean)[] = [];
  private op: 'select' | 'upsert' | 'update' = 'select';
  private payload: unknown = null;
  private onConflict: string | undefined;

  constructor(private db: FakeDb) {}

  select(_cols?: string) {
    this.op = 'select';
    return this;
  }
  eq(col: string, value: unknown) {
    this.filters.push((r) => r[col] === value);
    return this;
  }
  in(col: string, values: unknown[]) {
    this.filters.push((r) => values.includes(r[col]));
    return this;
  }
  upsert(rows: Row | Row[], opts?: { onConflict?: string }) {
    this.op = 'upsert';
    this.payload = Array.isArray(rows) ? rows : [rows];
    this.onConflict = opts?.onConflict;
    return this;
  }
  update(values: Record<string, unknown>) {
    this.op = 'update';
    this.payload = values;
    return this;
  }
  maybeSingle() {
    return this.exec().then(({ data, error }) => ({
      data: Array.isArray(data) ? (data[0] ?? null) : null,
      error,
    }));
  }
  // Supabase builders are thenables.
  then<T>(
    onFulfilled: (v: { data: Row[] | null; error: DbError }) => T,
    onRejected?: (e: unknown) => T,
  ) {
    return this.exec().then(onFulfilled, onRejected);
  }

  private matching(): Row[] {
    return [...this.db.rows.values()].filter((r) => this.filters.every((f) => f(r)));
  }

  // deno-lint-ignore require-await
  private async exec(): Promise<{ data: Row[] | null; error: DbError }> {
    const fail = this.db.failNext;
    if (fail && fail.op === this.op) {
      this.db.failNext = null;
      return { data: null, error: fail.error };
    }
    if (this.op === 'select') return { data: this.matching(), error: null };
    if (this.op === 'upsert') {
      assertEquals(this.onConflict, 'user_id', 'upserts conflict on the user_id primary key');
      const rows = this.payload as Row[];
      this.db.writes.push({ op: 'upsert', payload: rows });
      for (const row of rows) this.db.rows.set(row.user_id, { ...this.db.rows.get(row.user_id), ...row });
      return { data: null, error: null };
    }
    const values = this.payload as Record<string, unknown>;
    const hit = this.matching();
    this.db.writes.push({ op: 'update', payload: { values, users: hit.map((r) => r.user_id) } });
    for (const row of hit) this.db.rows.set(row.user_id, { ...row, ...values });
    return { data: null, error: null };
  }
}

// ---------------------------------------------------------------------------
// Fixtures: RevenueCat-shaped events (webhook v1, `event` object)
// ---------------------------------------------------------------------------

const SECRET = 'rc-test-secret';
const USER_ID = 'c18d3737-0000-4000-8000-000000000001';
const OTHER_USER = 'c18d3737-0000-4000-8000-000000000002';

const T0 = Date.parse('2026-09-15T12:00:00Z');
const DAY = 24 * 60 * 60 * 1000;

function envWith(overrides: Record<string, string | undefined> = {}) {
  const base: Record<string, string | undefined> = { REVENUECAT_WEBHOOK_SECRET: SECRET, ...overrides };
  return (key: string) => base[key];
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

/** A sandbox trial start on the iOS dev app, as RevenueCat delivers it. */
function trialStart(overrides: Record<string, unknown> = {}): RcEvent {
  return {
    aliases: ['$RCAnonymousID:8f0c1e2a4b6d4e5f9a1b2c3d4e5f6a7b', USER_ID],
    app_id: 'app2a6d45e56e',
    app_user_id: USER_ID,
    commission_percentage: 0.3,
    country_code: 'US',
    currency: 'USD',
    entitlement_id: 'pro',
    entitlement_ids: ['pro'],
    environment: 'SANDBOX',
    event_timestamp_ms: T0,
    expiration_at_ms: T0 + 7 * DAY,
    id: 'A1B2C3D4-0000-4000-8000-0000000000A1',
    is_family_share: false,
    is_trial_conversion: false,
    offer_code: null,
    original_app_user_id: USER_ID,
    original_transaction_id: '2000000123456789',
    period_type: 'TRIAL',
    presented_offering_id: 'default',
    price: 0,
    price_in_purchased_currency: 0,
    product_id: 'mealvana_pro_monthly',
    purchased_at_ms: T0,
    store: 'APP_STORE',
    subscriber_attributes: {},
    takehome_percentage: 0.7,
    tax_percentage: 0,
    transaction_id: '2000000123456789',
    type: 'INITIAL_PURCHASE',
    ...overrides,
  };
}

/** Day-eight renewal: the trial converted to a paid month. */
function paidRenewal(overrides: Record<string, unknown> = {}): RcEvent {
  return trialStart({
    id: 'A1B2C3D4-0000-4000-8000-0000000000A2',
    type: 'RENEWAL',
    period_type: 'NORMAL',
    is_trial_conversion: true,
    event_timestamp_ms: T0 + 7 * DAY,
    purchased_at_ms: T0 + 7 * DAY,
    expiration_at_ms: T0 + 37 * DAY,
    price: 9.99,
    price_in_purchased_currency: 9.99,
    transaction_id: '2000000123456790',
    ...overrides,
  });
}

function creditPack(overrides: Record<string, unknown> = {}): RcEvent {
  return {
    id: 'evt-credits-001',
    type: 'NON_RENEWING_PURCHASE',
    app_user_id: USER_ID,
    product_id: 'mealvana_credits_50',
    entitlement_ids: null,
    environment: 'SANDBOX',
    event_timestamp_ms: T0,
    store: 'APP_STORE',
    ...overrides,
  };
}

function body(event: RcEvent) {
  return { api_version: '1.0', event };
}

function iso(ms: number) {
  return new Date(ms).toISOString();
}

function setup(now = T0 + 60_000) {
  const db = new FakeDb();
  const handle = makeWebhookHandler({
    env: envWith(),
    db: () => db as unknown as WebhookDb,
    now: () => now,
  });
  return { db, handle };
}

// ---------------------------------------------------------------------------
// A. Method + shared-secret enforcement
// ---------------------------------------------------------------------------

describe('A. auth / shared secret', () => {
  it('non-POST is rejected with 405 and nothing is written', async () => {
    const { db, handle } = setup();
    const res = await handle(rcRequest(null, { method: 'GET' }));
    assertEquals(res.status, 405);
    assertEquals(db.writes.length + db.rpcCalls.length, 0);
  });

  it('missing REVENUECAT_WEBHOOK_SECRET → 500, never grants', async () => {
    const db = new FakeDb();
    const handle = makeWebhookHandler({
      env: envWith({ REVENUECAT_WEBHOOK_SECRET: undefined }),
      db: () => db as unknown as WebhookDb,
    });
    const res = await handle(rcRequest(body(trialStart())));
    assertEquals(res.status, 500);
    assertEquals(db.writes.length, 0);
  });

  it('wrong or absent Authorization → 401, nothing written', async () => {
    const { db, handle } = setup();
    assertEquals((await handle(rcRequest(body(trialStart()), { auth: 'nope' }))).status, 401);
    assertEquals((await handle(rcRequest(body(trialStart()), { auth: null }))).status, 401);
    assertEquals(db.writes.length, 0);
  });

  it('malformed JSON → 400', async () => {
    const { handle } = setup();
    const res = await handle(rcRequest('{not json'));
    assertEquals(res.status, 400);
  });
});

// ---------------------------------------------------------------------------
// B. A sandbox subscriber's first event lands the two fields
// ---------------------------------------------------------------------------

describe('B. first event → two-field row', () => {
  let db: FakeDb;
  let handle: (req: Request) => Promise<Response>;
  beforeEach(() => {
    ({ db, handle } = setup());
  });

  it('INITIAL_PURCHASE (TRIAL) writes active_until, period_type and the event time — nothing else', async () => {
    const res = await handle(rcRequest(body(trialStart())));
    assertEquals(res.status, 200);
    const out = await res.json();
    assertEquals(out.ok, true);
    assertEquals(out.active_until, iso(T0 + 7 * DAY));

    assertEquals(db.tables, ['user_entitlements', 'user_entitlements']);
    const row = db.rows.get(USER_ID)!;
    assertEquals(row, {
      user_id: USER_ID,
      active_until: iso(T0 + 7 * DAY),
      period_type: 'TRIAL',
      event_at: iso(T0),
    });
    assertEquals(db.rpcCalls.filter((c) => c.fn === 'grant_credits').length, 0, 'a Pro subscription never reaches grant_credits');
  });

  it('the payload’s other fields (store, product, price, environment) never reach the row', async () => {
    await handle(rcRequest(body(trialStart())));
    const written = (db.writes[0].payload as Row[])[0];
    assertEquals(Object.keys(written).sort(), ['active_until', 'event_at', 'period_type', 'user_id']);
  });

  it('RENEWAL on day eight moves active_until out and period_type to NORMAL', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(paidRenewal())));
    const row = db.rows.get(USER_ID)!;
    assertEquals(row.active_until, iso(T0 + 37 * DAY));
    assertEquals(row.period_type, 'NORMAL');
    assertEquals(row.event_at, iso(T0 + 7 * DAY));
  });

  it('CANCELLATION keeps active_until (access runs to the end of the period)', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(trialStart({
      id: 'A1B2C3D4-0000-4000-8000-0000000000A3',
      type: 'CANCELLATION',
      cancel_reason: 'UNSUBSCRIBE',
      event_timestamp_ms: T0 + 2 * DAY,
    }))));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 7 * DAY));
    assertEquals(db.rows.get(USER_ID)!.event_at, iso(T0 + 2 * DAY));
  });

  it('EXPIRATION closes the row at the expiry, even when the payload’s expiry is later than the event', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(trialStart({
      id: 'A1B2C3D4-0000-4000-8000-0000000000A4',
      type: 'EXPIRATION',
      expiration_reason: 'UNSUBSCRIBE',
      event_timestamp_ms: T0 + 7 * DAY,
      expiration_at_ms: T0 + 7 * DAY + 60_000, // clock skew
    }))));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 7 * DAY));
  });

  it('an event without expiration_at_ms leaves active_until null (never open-ended access)', async () => {
    await handle(rcRequest(body(trialStart({ expiration_at_ms: null }))));
    assertEquals(db.rows.get(USER_ID)!.active_until, null);
  });

  it('a payload without period_type keeps the stored one', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(paidRenewal({ period_type: undefined }))));
    assertEquals(db.rows.get(USER_ID)!.period_type, 'TRIAL');
  });

  it('a Play event carrying the bare subscription id is still a Pro event', async () => {
    await handle(rcRequest(body(trialStart({
      store: 'PLAY_STORE',
      product_id: 'mealvana_pro_annual',
      entitlement_ids: undefined,
      entitlement_id: undefined,
    }))));
    assert(db.rows.has(USER_ID));
  });

  it('missing app_user_id or event id → 400, nothing written', async () => {
    assertEquals((await handle(rcRequest(body(trialStart({ app_user_id: '' }))))).status, 400);
    assertEquals((await handle(rcRequest(body(trialStart({ id: undefined }))))).status, 400);
    assertEquals(db.writes.length, 0);
  });

  it('a user unknown to this project (23503) is acked, not retried', async () => {
    db.failNext = { op: 'upsert', error: { code: '23503', message: 'fk' } };
    const res = await handle(rcRequest(body(trialStart())));
    assertEquals(res.status, 200);
    assertEquals((await res.json()).ignored, 'user_not_in_project');
  });

  it('a read or write failure → 500 so RevenueCat retries', async () => {
    db.failNext = { op: 'select', error: { message: 'boom' } };
    assertEquals((await handle(rcRequest(body(trialStart())))).status, 500);
    db.failNext = { op: 'upsert', error: { message: 'boom' } };
    assertEquals((await handle(rcRequest(body(trialStart())))).status, 500);
  });
});

// ---------------------------------------------------------------------------
// C. Ordering: an event older than the row's event time is ignored
// ---------------------------------------------------------------------------

describe('C. stale events', () => {
  it('a delayed CANCELLATION delivered after the RENEWAL does not roll the row back', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(paidRenewal())));
    const res = await handle(rcRequest(body(trialStart({
      id: 'A1B2C3D4-0000-4000-8000-0000000000A5',
      type: 'CANCELLATION',
      event_timestamp_ms: T0 + 2 * DAY,
    }))));
    assertEquals((await res.json()).ignored, 'stale_event');
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 37 * DAY));
    assertEquals(db.writes.length, 1);
  });

  it('a re-delivered identical event is applied again without harm (same event time is not stale)', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(trialStart())));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 7 * DAY));
  });

  it('isStaleEvent compares the event time with the stored event_at', () => {
    const stored = iso(T0);
    assert(isStaleEvent(trialStart({ event_timestamp_ms: T0 - 1 }), stored));
    assert(!isStaleEvent(trialStart({ event_timestamp_ms: T0 }), stored));
    assert(!isStaleEvent(trialStart({ event_timestamp_ms: T0 + 1 }), stored));
    assert(!isStaleEvent(trialStart(), null), 'no row → nothing to be older than');
    assert(!isStaleEvent(trialStart({ event_timestamp_ms: undefined }), stored));
  });
});

// ---------------------------------------------------------------------------
// D. TRANSFER moves the row
// ---------------------------------------------------------------------------

describe('D. TRANSFER', () => {
  function transfer(overrides: Record<string, unknown> = {}): RcEvent {
    return {
      app_id: 'app2a6d45e56e',
      app_user_id: OTHER_USER,
      environment: 'SANDBOX',
      event_timestamp_ms: T0 + 3 * DAY,
      id: 'A1B2C3D4-0000-4000-8000-0000000000B1',
      store: 'APP_STORE',
      transferred_from: [USER_ID],
      transferred_to: [OTHER_USER],
      type: 'TRANSFER',
      ...overrides,
    };
  }

  it('the new owner gets the two fields; the old owner’s row closes at the transfer time', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(trialStart())));
    const res = await handle(rcRequest(body(transfer())));
    assertEquals(res.status, 200);
    assertEquals(db.rows.get(OTHER_USER), {
      user_id: OTHER_USER,
      active_until: iso(T0 + 7 * DAY),
      period_type: 'TRIAL',
      event_at: iso(T0 + 3 * DAY),
    });
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 3 * DAY));
    assertEquals(db.rows.get(USER_ID)!.event_at, iso(T0 + 3 * DAY));
  });

  it('after the transfer, a late event for the old owner is stale', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(transfer())));
    const res = await handle(rcRequest(body(paidRenewal({ event_timestamp_ms: T0 + 2 * DAY }))));
    assertEquals((await res.json()).ignored, 'stale_event');
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 3 * DAY));
  });

  it('nothing to move (no source row) is acked; the recipient is left for the next event', async () => {
    const { db, handle } = setup();
    const res = await handle(rcRequest(body(transfer())));
    assertEquals(res.status, 200);
    assertEquals((await res.json()).transferred, false);
    assert(!db.rows.has(OTHER_USER));
  });

  it('a transfer without parties is acked as a no-op', async () => {
    const { db, handle } = setup();
    const res = await handle(rcRequest(body(transfer({ transferred_from: [], transferred_to: [] }))));
    assertEquals((await res.json()).ignored, 'transfer_no_parties');
    assertEquals(db.writes.length, 0);
  });
});

// ---------------------------------------------------------------------------
// E. Credit packs: the grant path is unchanged
// ---------------------------------------------------------------------------

describe('E. credit-pack grant path', () => {
  it('NON_RENEWING_PURCHASE of a pack calls grant_credits and touches no entitlement row', async () => {
    const { db, handle } = setup();
    const res = await handle(rcRequest(body(creditPack())));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls, [{
      fn: 'grant_credits',
      args: { p_user_id: USER_ID, p_amount: 50, p_reason: 'grant_purchase', p_ref: 'evt-credits-001' },
    }]);
    assertEquals(db.writes.length, 0);
  });

  it('unmapped product and non-granting types are acked without a grant', async () => {
    const { db, handle } = setup();
    assertEquals((await (await handle(rcRequest(body(creditPack({ product_id: 'mystery' }))))).json()).ignored, 'unmapped_product');
    assertEquals((await (await handle(rcRequest(body({ id: 'x', type: 'TEST', app_user_id: USER_ID })))).json()).ignored, 'TEST');
    assertEquals(db.rpcCalls.length, 0);
    assertEquals(db.writes.length, 0, 'a TEST ping never writes the cache');
  });

  it('23505 → idempotent ack; 23503 → cross-project ack; other errors → 500', async () => {
    const { db, handle } = setup();
    db.rpcResult = { error: { code: '23505', message: 'dup' } };
    assertEquals((await (await handle(rcRequest(body(creditPack())))).json()).idempotent, true);
    db.rpcResult = { error: { code: '23503', message: 'fk' } };
    assertEquals((await (await handle(rcRequest(body(creditPack())))).json()).ignored, 'user_not_in_project');
    db.rpcResult = { error: { message: 'boom' } };
    assertEquals((await handle(rcRequest(body(creditPack())))).status, 500);
  });

  it('RC_PRODUCT_CREDITS overrides the map; bad JSON falls back to defaults', async () => {
    const db = new FakeDb();
    const withMap = makeWebhookHandler({
      env: envWith({ RC_PRODUCT_CREDITS: '{"mealvana_credits_50": 75}' }),
      db: () => db as unknown as WebhookDb,
    });
    await withMap(rcRequest(body(creditPack())));
    assertEquals(db.rpcCalls[0].args.p_amount, 75);
    const bad = makeWebhookHandler({
      env: envWith({ RC_PRODUCT_CREDITS: '{nope' }),
      db: () => db as unknown as WebhookDb,
    });
    await bad(rcRequest(body(creditPack())));
    assertEquals(db.rpcCalls[1].args.p_amount, 50);
  });
});

// ---------------------------------------------------------------------------
// G. The monthly Allowance (mp-281, ticket 20)
// ---------------------------------------------------------------------------

describe('G. allowance grants', () => {
  let db: FakeDb;
  let handle: (req: Request) => Promise<Response>;
  beforeEach(() => {
    ({ db, handle } = setup());
    db.rpcResult = { data: { granted: true, forfeited: 0, balance: 300, allowance: 300 } };
  });

  it('the trial’s INITIAL_PURCHASE grants the full Allowance, expiring with the trial, keyed on the event id', async () => {
    const res = await handle(rcRequest(body(trialStart())));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls, [{
      fn: 'grant_allowance',
      args: { p_user_id: USER_ID, p_amount: 300, p_active_until: iso(T0 + 7 * DAY), p_ref: 'A1B2C3D4-0000-4000-8000-0000000000A1' },
    }]);
    // The entitlement row is written first, in the same delivery.
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 7 * DAY));
    const out = await res.json();
    assertEquals(out.allowance, { granted: true, forfeited: 0, balance: 300, allowance: 300 });
  });

  it('RENEWAL grants again, keyed on its own event id, with the new period end', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(paidRenewal())));
    assertEquals(db.rpcCalls.length, 2);
    assertEquals(db.rpcCalls[1], {
      fn: 'grant_allowance',
      args: { p_user_id: USER_ID, p_amount: 300, p_active_until: iso(T0 + 37 * DAY), p_ref: 'A1B2C3D4-0000-4000-8000-0000000000A2' },
    });
  });

  it('CANCELLATION touches the wallet not at all (access and the allowance run to the period end)', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(trialStart({
      id: 'A1B2C3D4-0000-4000-8000-0000000000A3',
      type: 'CANCELLATION',
      cancel_reason: 'UNSUBSCRIBE',
      event_timestamp_ms: T0 + 2 * DAY,
    }))));
    assertEquals(db.rpcCalls.length, 1, 'only the initial grant');
  });

  it('EXPIRATION forfeits what is left of the allowance and grants nothing', async () => {
    await handle(rcRequest(body(trialStart())));
    db.rpcResult = { data: { forfeited: 280, balance: 50, allowance: 0 } };
    const res = await handle(rcRequest(body(trialStart({
      id: 'A1B2C3D4-0000-4000-8000-0000000000A4',
      type: 'EXPIRATION',
      expiration_reason: 'UNSUBSCRIBE',
      event_timestamp_ms: T0 + 7 * DAY,
    }))));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls[1], {
      fn: 'forfeit_allowance',
      args: { p_user_id: USER_ID, p_ref: 'A1B2C3D4-0000-4000-8000-0000000000A4' },
    });
    assertEquals(db.rpcCalls.length, 2);
    assertEquals((await res.json()).allowance, { forfeited: 280, balance: 50, allowance: 0 });
  });

  it('a stale event grants nothing', async () => {
    await handle(rcRequest(body(paidRenewal())));
    await handle(rcRequest(body(trialStart({ event_timestamp_ms: T0 - DAY }))));
    assertEquals(db.rpcCalls.length, 1);
  });

  it('an event without an expiry writes the row but cannot open an allowance window', async () => {
    const res = await handle(rcRequest(body(trialStart({ expiration_at_ms: null }))));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls.length, 0);
    assertEquals((await res.json()).allowance, { skipped: 'no_active_until' });
  });

  it('AI_MONTHLY_ALLOWANCE overrides the number per project', async () => {
    const own = new FakeDb();
    own.rpcResult = { data: { granted: true } };
    const withEnv = makeWebhookHandler({
      env: envWith({ AI_MONTHLY_ALLOWANCE: '120' }),
      db: () => own as unknown as WebhookDb,
    });
    await withEnv(rcRequest(body(trialStart())));
    assertEquals(own.rpcCalls[0].args.p_amount, 120);
  });

  it('a redelivered grant (23505) is acked; any other grant failure is a 500 so RevenueCat retries', async () => {
    db.rpcResult = { error: { code: '23505', message: 'dup' } };
    const dup = await handle(rcRequest(body(trialStart())));
    assertEquals(dup.status, 200);
    assertEquals((await dup.json()).allowance, { idempotent: true });
    db.rpcResult = { error: { message: 'boom' } };
    assertEquals((await handle(rcRequest(body(paidRenewal())))).status, 500);
  });

  it('a credit-pack purchase still goes to grant_credits only', async () => {
    db.rpcResult = { data: 350 };
    await handle(rcRequest(body(creditPack())));
    assertEquals(db.rpcCalls.map((c) => c.fn), ['grant_credits']);
  });
});

// ---------------------------------------------------------------------------
// F. Pure mapping
// ---------------------------------------------------------------------------

describe('F. entitlements.ts', () => {
  it('isProEvent: entitlement_ids wins; every Pro SKU matches; packs do not', () => {
    assert(isProEvent({ entitlement_ids: ['pro'], product_id: 'anything' }));
    assert(!isProEvent({ entitlement_ids: ['other'], product_id: 'mealvana_credits_50' }));
    for (const sku of PRO_PRODUCT_IDS) assert(isProEvent({ product_id: sku }), sku);
    assert(!isProEvent({ product_id: 'mealvana_credits_50' }));
    assert(!isProEvent({}));
  });

  it('SUBSCRIPTION_EVENT_TYPES is the lifecycle, not TEST and not consumables', () => {
    for (const t of ['INITIAL_PURCHASE', 'RENEWAL', 'CANCELLATION', 'UNCANCELLATION', 'EXPIRATION', 'BILLING_ISSUE', 'PRODUCT_CHANGE', 'SUBSCRIPTION_PAUSED', 'SUBSCRIPTION_EXTENDED']) {
      assert(SUBSCRIPTION_EVENT_TYPES.has(t), t);
    }
    assert(!SUBSCRIPTION_EVENT_TYPES.has('TEST'));
    assert(!SUBSCRIPTION_EVENT_TYPES.has('NON_RENEWING_PURCHASE'));
  });

  it('entitlementRowFor yields exactly the two fields plus the event time', () => {
    const row = entitlementRowFor(trialStart(), T0);
    assertEquals(row, { active_until: iso(T0 + 7 * DAY), period_type: 'TRIAL', event_at: iso(T0) });
  });

  it('entitlementRowFor without event_timestamp_ms stamps the current time', () => {
    const row = entitlementRowFor(trialStart({ event_timestamp_ms: undefined }), T0 + 5);
    assertEquals(row.event_at, iso(T0 + 5));
  });
});

Deno.test('wiring fidelity — index.ts serves the injected handler with the real env and client', async () => {
  const src = await Deno.readTextFile(new URL('./index.ts', import.meta.url));
  assert(src.includes('makeWebhookHandler('), 'index.ts must build the handler from handler.ts');
  assert(src.includes("Deno.env.get('REVENUECAT_WEBHOOK_SECRET')") || src.includes('Deno.env.get(key)') || src.includes('(key) => Deno.env.get(key)'), 'env must come from Deno.env');
  assert(src.includes('createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)'), 'the writer is the service-role client');
});
