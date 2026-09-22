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
 * What granted access must do (mp-454, paywall ticket 01):
 *   - every `pro` event, a promotional NON_RENEWING_PURCHASE included, asks
 *     RevenueCat (a fake REST client) for the current `pro` expiry and writes
 *     that as active_until;
 *   - a trial started during a live grant keeps the grant's end; a lapsed
 *     trial leaves a live grant open;
 *   - RevenueCat reporting no `pro` closes the row at the event time.
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
  takesProPath,
} from './entitlements.ts';
import type { RevenueCatClient } from '../_shared/revenuecat/client.ts';

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
// Fake RevenueCat REST client. It models what RevenueCat itself knows about a
// customer: the store subscription's end and a promotional grant's end, each
// moved by the events RevenueCat sends (never by what the webhook wrote), and
// answers `currentProExpiry` the way RevenueCat does: the later of the two
// still-live ends. A test can also pin the answer outright.
// ---------------------------------------------------------------------------

class FakeRevenueCat implements RevenueCatClient {
  subscriptionEnds = new Map<string, number | null>();
  grantEnds = new Map<string, number>();
  private lastEventAt = new Map<string, number>();
  expiryCalls: string[] = [];
  /** When set, the answer for every customer (null = no `pro`). */
  pinned: { expiry: string | null } | null = null;
  failNext: Error | null = null;

  constructor(private now: () => number) {}

  /** RevenueCat's own state moves with each event it sends. */
  observe(event: RcEvent | null | undefined) {
    if (!event) return;
    const user = String(event.app_user_id ?? '');
    const type = String(event.type ?? '');
    if (!user || type === 'TEST' || type === 'TRANSFER') return;
    const ids = event.entitlement_ids;
    const pro = (Array.isArray(ids) && ids.includes('pro')) || String(event.product_id ?? '').includes('_pro_');
    if (!pro) return;
    const at = Number(event.event_timestamp_ms ?? 0);
    if (at < (this.lastEventAt.get(user) ?? -Infinity)) return;
    this.lastEventAt.set(user, at);
    // After an EXPIRATION RevenueCat no longer counts that grant or subscription.
    if (event.store === 'PROMOTIONAL') {
      if (type === 'EXPIRATION') this.grantEnds.delete(user);
      else this.grantEnds.set(user, Number(event.expiration_at_ms));
      return;
    }
    const expiry = event.expiration_at_ms == null ? null : Number(event.expiration_at_ms);
    this.subscriptionEnds.set(user, type === 'EXPIRATION' ? null : expiry);
  }

  // deno-lint-ignore require-await
  async currentProExpiry(appUserId: string): Promise<string | null> {
    this.expiryCalls.push(appUserId);
    if (this.failNext) {
      const e = this.failNext;
      this.failNext = null;
      throw e;
    }
    if (this.pinned) return this.pinned.expiry;
    const live = [this.subscriptionEnds.get(appUserId), this.grantEnds.get(appUserId)]
      .filter((v): v is number => typeof v === 'number' && v > this.now());
    return live.length === 0 ? null : new Date(Math.max(...live)).toISOString();
  }

  // deno-lint-ignore require-await
  async grantPro(): Promise<void> {
    throw new Error('the webhook never grants');
  }

  // deno-lint-ignore require-await
  async setAttributes(): Promise<void> {
    throw new Error('the webhook never sets attributes');
  }

  // deno-lint-ignore require-await
  async getAttributes(): Promise<Record<string, string> | null> {
    throw new Error('the webhook never reads attributes');
  }

  // deno-lint-ignore require-await
  async promotionalProEnd(): Promise<string | null> {
    throw new Error('the webhook never reads grants');
  }

  // deno-lint-ignore require-await
  async createCustomer(): Promise<void> {
    throw new Error('the webhook never creates customers');
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

/**
 * A hand grant of `pro` in the RevenueCat dashboard, as RevenueCat delivers
 * it: a NON_RENEWING_PURCHASE on the PROMOTIONAL store, period PROMOTIONAL,
 * environment PRODUCTION even for a sandbox user (mp-454).
 */
function promotionalGrant(overrides: Record<string, unknown> = {}): RcEvent {
  return {
    aliases: [USER_ID],
    app_id: 'app2a6d45e56e',
    app_user_id: USER_ID,
    commission_percentage: null,
    country_code: null,
    currency: null,
    entitlement_id: 'pro',
    entitlement_ids: ['pro'],
    environment: 'PRODUCTION',
    event_timestamp_ms: T0,
    expiration_at_ms: T0 + 30 * DAY,
    id: 'A1B2C3D4-0000-4000-8000-0000000000C1',
    is_family_share: false,
    offer_code: null,
    original_app_user_id: USER_ID,
    original_transaction_id: 'rc_promo_pro_custom_' + T0,
    period_type: 'PROMOTIONAL',
    presented_offering_id: null,
    price: 0,
    price_in_purchased_currency: 0,
    product_id: 'rc_promo_pro_custom',
    purchased_at_ms: T0,
    store: 'PROMOTIONAL',
    subscriber_attributes: {},
    takehome_percentage: null,
    tax_percentage: null,
    transaction_id: 'rc_promo_pro_custom_' + T0,
    type: 'NON_RENEWING_PURCHASE',
    ...overrides,
  };
}

function body(event: RcEvent) {
  return { api_version: '1.0', event };
}

function iso(ms: number) {
  return new Date(ms).toISOString();
}

/** For paths that must never reach RevenueCat's REST API. */
const noRevenueCat = (): RevenueCatClient => {
  throw new Error('this path never asks RevenueCat');
};

/**
 * The handler under test, with RevenueCat's view moved by each delivered
 * event before the handler sees it (RevenueCat updates itself, then sends).
 */
function withRevenueCat(
  env: (key: string) => string | undefined,
  db: FakeDb,
  now: number,
  rc = new FakeRevenueCat(() => now),
) {
  const inner = makeWebhookHandler({
    env,
    db: () => db as unknown as WebhookDb,
    revenueCat: () => rc,
    now: () => now,
  });
  const handle = async (req: Request) => {
    if (req.method === 'POST') rc.observe((await req.clone().json().catch(() => null))?.event);
    return await inner(req);
  };
  return { rc, handle };
}

function setup(now = T0 + 60_000) {
  const db = new FakeDb();
  const { rc, handle } = withRevenueCat(envWith(), db, now);
  return { db, rc, handle };
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
      revenueCat: noRevenueCat,
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

  it('RevenueCat reporting no `pro` closes the row at the event time (never open-ended access)', async () => {
    await handle(rcRequest(body(trialStart({ expiration_at_ms: null }))));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0));
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
  it('NON_RENEWING_PURCHASE of the $4.99 pack adds a quarter of a month ($1.00) through grant_credits and touches no entitlement row', async () => {
    const { db, handle } = setup();
    const res = await handle(rcRequest(body(creditPack())));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls, [{
      fn: 'grant_credits',
      args: { p_user_id: USER_ID, p_amount: 1_000_000, p_reason: 'grant_purchase', p_ref: 'evt-credits-001' },
    }]);
    assertEquals(db.writes.length, 0);
  });

  it('the $19.99 pack adds a month and a quarter ($5.00); the prod ids and the test pack map too (mp-430 clause 7)', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(creditPack({ id: 'evt-250', product_id: 'mealvana_credits_250' }))));
    await handle(rcRequest(body(creditPack({ id: 'evt-250p', product_id: 'mealvana_credits_250_prod' }))));
    await handle(rcRequest(body(creditPack({ id: 'evt-50p', product_id: 'mealvana_credits_50_prod' }))));
    await handle(rcRequest(body(creditPack({ id: 'evt-t1', product_id: 'mealvana_credits_test_1' }))));
    assertEquals(db.rpcCalls.map((c) => c.args.p_amount), [5_000_000, 5_000_000, 1_000_000, 20_000]);
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

  it('RC_PRODUCT_BUDGET overrides the map (micro-dollars); bad JSON falls back to defaults', async () => {
    const db = new FakeDb();
    const withMap = makeWebhookHandler({
      env: envWith({ RC_PRODUCT_BUDGET: '{"mealvana_credits_50": 75}' }),
      db: () => db as unknown as WebhookDb,
      revenueCat: noRevenueCat,
    });
    await withMap(rcRequest(body(creditPack())));
    assertEquals(db.rpcCalls[0].args.p_amount, 75);
    const bad = makeWebhookHandler({
      env: envWith({ RC_PRODUCT_BUDGET: '{nope' }),
      db: () => db as unknown as WebhookDb,
      revenueCat: noRevenueCat,
    });
    await bad(rcRequest(body(creditPack())));
    assertEquals(db.rpcCalls[1].args.p_amount, 1_000_000);
  });
});

// ---------------------------------------------------------------------------
// G. The monthly budget (mp-281 ticket 20; mp-430 ai-cost ticket 09): $4.00 a
//    month in micro-dollars, the trial week a quarter of it
// ---------------------------------------------------------------------------

describe('G. allowance grants', () => {
  let db: FakeDb;
  let handle: (req: Request) => Promise<Response>;
  beforeEach(() => {
    ({ db, handle } = setup());
    db.rpcResult = { data: { granted: true, forfeited: 0, balance: 1_000_000, allowance: 1_000_000 } };
  });

  it('the trial’s INITIAL_PURCHASE grants the trial week’s quarter ($1.00), expiring with the trial, keyed on the event id', async () => {
    const res = await handle(rcRequest(body(trialStart())));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls, [{
      fn: 'grant_allowance',
      args: { p_user_id: USER_ID, p_amount: 1_000_000, p_active_until: iso(T0 + 7 * DAY), p_ref: 'A1B2C3D4-0000-4000-8000-0000000000A1' },
    }]);
    // The entitlement row is written first, in the same delivery.
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 7 * DAY));
    const out = await res.json();
    assertEquals(out.allowance, { granted: true, forfeited: 0, balance: 1_000_000, allowance: 1_000_000 });
  });

  it('RENEWAL grants the month ($4.00), keyed on its own event id, with the new period end', async () => {
    await handle(rcRequest(body(trialStart())));
    await handle(rcRequest(body(paidRenewal())));
    assertEquals(db.rpcCalls.length, 2);
    assertEquals(db.rpcCalls[1], {
      fn: 'grant_allowance',
      args: { p_user_id: USER_ID, p_amount: 4_000_000, p_active_until: iso(T0 + 37 * DAY), p_ref: 'A1B2C3D4-0000-4000-8000-0000000000A2' },
    });
  });

  it('a paid INITIAL_PURCHASE with no trial grants the month; annual and founding plans get the same month (mp-430 clause 2)', async () => {
    await handle(rcRequest(body(trialStart({ period_type: 'NORMAL', product_id: 'me_pro_annual_founding', expiration_at_ms: T0 + 365 * DAY }))));
    assertEquals(db.rpcCalls[0].args.p_amount, 4_000_000);
  });

  it('a TRANSFER leaves the allowance where it was granted: no wallet RPC at all (mp-430 clause 11)', async () => {
    await handle(rcRequest(body(trialStart())));
    const before = db.rpcCalls.length;
    await handle(rcRequest(body({
      app_user_id: OTHER_USER, environment: 'SANDBOX', event_timestamp_ms: T0 + 3 * DAY, id: 'evt-transfer-1', store: 'APP_STORE',
      transferred_from: [USER_ID], transferred_to: [OTHER_USER], type: 'TRANSFER',
    })));
    assertEquals(db.rpcCalls.length, before, 'the wallet is not touched by a transfer');
    assertEquals(db.rows.get(OTHER_USER)!.period_type, 'TRIAL', 'the entitlement moved');
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
    db.rpcResult = { data: { forfeited: 280_000, balance: 50_000, allowance: 0 } };
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
    assertEquals((await res.json()).allowance, { forfeited: 280_000, balance: 50_000, allowance: 0 });
  });

  it('a stale event grants nothing', async () => {
    await handle(rcRequest(body(paidRenewal())));
    await handle(rcRequest(body(trialStart({ event_timestamp_ms: T0 - DAY }))));
    assertEquals(db.rpcCalls.length, 1);
  });

  it('an event RevenueCat reports no `pro` for writes the row but cannot open an allowance window', async () => {
    const res = await handle(rcRequest(body(trialStart({ expiration_at_ms: null }))));
    assertEquals(res.status, 200);
    assertEquals(db.rpcCalls.length, 0);
    assertEquals((await res.json()).allowance, { skipped: 'not_active' });
  });

  it('AI_MONTHLY_BUDGET and AI_TRIAL_BUDGET override the numbers per project', async () => {
    const own = new FakeDb();
    own.rpcResult = { data: { granted: true } };
    const { handle: withEnv } = withRevenueCat(envWith({ AI_MONTHLY_BUDGET: '120', AI_TRIAL_BUDGET: '30' }), own, T0 + 60_000);
    await withEnv(rcRequest(body(trialStart())));
    assertEquals(own.rpcCalls[0].args.p_amount, 30);
    await withEnv(rcRequest(body(paidRenewal())));
    assertEquals(own.rpcCalls[1].args.p_amount, 120);
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
    db.rpcResult = { data: 5_000_000 };
    await handle(rcRequest(body(creditPack())));
    assertEquals(db.rpcCalls.map((c) => c.fn), ['grant_credits']);
  });
});

// ---------------------------------------------------------------------------
// H. Granted access (mp-454, paywall ticket 01)
// ---------------------------------------------------------------------------

describe('H. granted access reaches the row', () => {
  it('a promotional grant (NON_RENEWING_PURCHASE, PROMOTIONAL) opens the row to the grant’s end', async () => {
    const { db, rc, handle } = setup();
    const res = await handle(rcRequest(body(promotionalGrant())));
    assertEquals(res.status, 200);
    assertEquals(db.rows.get(USER_ID), {
      user_id: USER_ID,
      active_until: iso(T0 + 30 * DAY),
      period_type: 'PROMOTIONAL',
      event_at: iso(T0),
    });
    assertEquals(rc.expiryCalls, [USER_ID], 'the expiry comes from RevenueCat, asked once');
    assertEquals(db.rpcCalls.filter((c) => c.fn === 'grant_credits').length, 0, 'a grant is not a credit pack');
  });

  it('the row takes RevenueCat’s answer, not the payload’s expiry', async () => {
    const { db, rc, handle } = setup();
    rc.pinned = { expiry: iso(T0 + 45 * DAY) };
    await handle(rcRequest(body(promotionalGrant())));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 45 * DAY));
  });

  it('a trial started during a live grant leaves the row at the grant’s later end', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(promotionalGrant())));
    await handle(rcRequest(body(trialStart({ event_timestamp_ms: T0 + 2 * DAY, expiration_at_ms: T0 + 9 * DAY }))));
    const row = db.rows.get(USER_ID)!;
    assertEquals(row.active_until, iso(T0 + 30 * DAY));
    assertEquals(row.period_type, 'PROMOTIONAL');
    assertEquals(row.event_at, iso(T0 + 2 * DAY));
  });

  it('a trial that outlasts the grant moves the row to the trial’s end', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(promotionalGrant({ expiration_at_ms: T0 + 3 * DAY }))));
    await handle(rcRequest(body(trialStart({ event_timestamp_ms: T0 + DAY, expiration_at_ms: T0 + 8 * DAY }))));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 8 * DAY));
    assertEquals(db.rows.get(USER_ID)!.period_type, 'TRIAL');
  });

  it('a lapsed trial leaves a live grant open, and its allowance in place', async () => {
    const { db, handle } = setup(T0 + 9 * DAY + 60_000);
    db.rpcResult = { data: { granted: true } };
    await handle(rcRequest(body(promotionalGrant())));
    await handle(rcRequest(body(trialStart({ event_timestamp_ms: T0 + 2 * DAY, expiration_at_ms: T0 + 9 * DAY }))));
    const res = await handle(rcRequest(body(trialStart({
      id: 'A1B2C3D4-0000-4000-8000-0000000000C4',
      type: 'EXPIRATION',
      expiration_reason: 'UNSUBSCRIBE',
      event_timestamp_ms: T0 + 9 * DAY,
      expiration_at_ms: T0 + 9 * DAY,
    }))));
    assertEquals(res.status, 200);
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 30 * DAY));
    assertEquals(db.rows.get(USER_ID)!.event_at, iso(T0 + 9 * DAY));
    assertEquals(db.rpcCalls.filter((c) => c.fn === 'forfeit_allowance').length, 0, 'access is still live');
  });

  it('the grant’s own EXPIRATION, with nothing else live, closes the row at the event time', async () => {
    const { db, handle } = setup(T0 + 31 * DAY);
    await handle(rcRequest(body(promotionalGrant())));
    await handle(rcRequest(body(promotionalGrant({
      id: 'A1B2C3D4-0000-4000-8000-0000000000C5',
      type: 'EXPIRATION',
      event_timestamp_ms: T0 + 30 * DAY,
      expiration_at_ms: T0 + 30 * DAY,
    }))));
    assertEquals(db.rows.get(USER_ID)!.active_until, iso(T0 + 30 * DAY));
  });

  it('a RevenueCat REST failure is a 500 so RevenueCat retries, and nothing is written', async () => {
    const { db, rc, handle } = setup();
    rc.failNext = new Error('RevenueCat 503');
    const res = await handle(rcRequest(body(promotionalGrant())));
    assertEquals(res.status, 500);
    assertEquals(db.writes.length, 0);
  });

  it('no RevenueCat secret key → 500 on a `pro` event; a credit pack still grants', async () => {
    const db = new FakeDb();
    const handle = makeWebhookHandler({
      env: envWith(),
      db: () => db as unknown as WebhookDb,
      revenueCat: () => {
        throw new Error('RevenueCat secret key not set');
      },
    });
    assertEquals((await handle(rcRequest(body(promotionalGrant())))).status, 500);
    assertEquals(db.writes.length, 0);
    assertEquals((await handle(rcRequest(body(creditPack())))).status, 200);
    assertEquals(db.rpcCalls.map((c) => c.fn), ['grant_credits']);
  });

  it('a stale event does not ask RevenueCat', async () => {
    const { rc, handle } = setup();
    await handle(rcRequest(body(paidRenewal())));
    await handle(rcRequest(body(trialStart({ type: 'CANCELLATION', event_timestamp_ms: T0 + DAY }))));
    assertEquals(rc.expiryCalls.length, 1);
  });

  it('the environment is never filtered: a PRODUCTION grant and a SANDBOX trial both write', async () => {
    const { db, handle } = setup();
    await handle(rcRequest(body(promotionalGrant({ environment: 'PRODUCTION' }))));
    assert(db.rows.has(USER_ID));
    await handle(rcRequest(body(trialStart({ app_user_id: OTHER_USER, environment: 'SANDBOX' }))));
    assert(db.rows.has(OTHER_USER));
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

  it('the eight new `me_pro_*` ids are in the fallback list', () => {
    for (const base of ['me_pro_monthly', 'me_pro_annual', 'me_pro_monthly_founding', 'me_pro_annual_founding']) {
      assert(PRO_PRODUCT_IDS.has(base), base);
      assert(PRO_PRODUCT_IDS.has(`${base}_prod`), `${base}_prod`);
      assert(isProEvent({ product_id: base, entitlement_ids: null }), base);
    }
  });

  it('takesProPath: every `pro` event but TEST and TRANSFER, whatever its type; packs never', () => {
    for (const t of ['INITIAL_PURCHASE', 'RENEWAL', 'CANCELLATION', 'UNCANCELLATION', 'EXPIRATION', 'BILLING_ISSUE', 'PRODUCT_CHANGE', 'SUBSCRIPTION_PAUSED', 'SUBSCRIPTION_EXTENDED', 'NON_RENEWING_PURCHASE', 'TEMPORARY_ENTITLEMENT_GRANT']) {
      assert(takesProPath(trialStart({ type: t })), t);
    }
    assert(takesProPath(promotionalGrant()));
    assert(!takesProPath(trialStart({ type: 'TEST' })));
    assert(!takesProPath(trialStart({ type: 'TRANSFER' })));
    assert(!takesProPath(creditPack()));
  });

  it('entitlementRowFor yields exactly the two fields plus the event time', () => {
    const row = entitlementRowFor(trialStart(), T0, iso(T0 + 7 * DAY));
    assertEquals(row, { active_until: iso(T0 + 7 * DAY), period_type: 'TRIAL', event_at: iso(T0) });
  });

  it('entitlementRowFor without event_timestamp_ms stamps the current time', () => {
    const row = entitlementRowFor(trialStart({ event_timestamp_ms: undefined }), T0 + 5, null);
    assertEquals(row.event_at, iso(T0 + 5));
    assertEquals(row.active_until, iso(T0 + 5), 'no `pro` closes at the event time');
  });

  it('entitlementRowFor: the payload period type holds only when RevenueCat’s end is the payload’s own', () => {
    // A trial during a grant: RevenueCat's end is the grant's, so the stored PROMOTIONAL stays.
    const during = entitlementRowFor(trialStart(), T0, iso(T0 + 30 * DAY), { period_type: 'PROMOTIONAL' });
    assertEquals(during, { active_until: iso(T0 + 30 * DAY), period_type: 'PROMOTIONAL', event_at: iso(T0) });
    // RevenueCat rounds to the second; within a minute is the same end.
    const same = entitlementRowFor(trialStart(), T0, iso(T0 + 7 * DAY + 900), { period_type: 'PROMOTIONAL' });
    assertEquals(same.period_type, 'TRIAL');
  });
});

Deno.test('wiring fidelity — index.ts serves the injected handler with the real env and client', async () => {
  const src = await Deno.readTextFile(new URL('./index.ts', import.meta.url));
  assert(src.includes('makeWebhookHandler('), 'index.ts must build the handler from handler.ts');
  assert(src.includes("Deno.env.get('REVENUECAT_WEBHOOK_SECRET')") || src.includes('Deno.env.get(key)') || src.includes('(key) => Deno.env.get(key)'), 'env must come from Deno.env');
  assert(src.includes('createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)'), 'the writer is the service-role client');
  assert(src.includes("Deno.env.get('REVENUECAT_SECRET_KEY')"), 'the REST client holds the RevenueCat secret key');
  assert(src.includes('makeRevenueCatClient('), 'the REST client is the shared one');
});
