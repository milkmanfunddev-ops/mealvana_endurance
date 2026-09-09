import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  cartLines,
  KrogerError,
  productFromApi,
  rankProducts,
} from "./catalog.ts";
import { type Config, KrogerClient } from "./client.ts";
import { KrogerService } from "./service.ts";
import type { Db } from "../vana/env.ts";

const cfg: Config = {
  base: "https://api-ce.kroger.com/v1",
  clientId: "test-client",
  secret: "test-secret",
  redirect: "com.milkman.mealvanaendurance://callback",
  environment: "certification",
};
const user = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  plan = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const product = {
  upc: "0001111040101",
  name: "Milk",
  brand: "Kroger",
  size: "1 l",
  price: 3,
  available: true,
  image: null,
};
const payload = () => ({
  id: crypto.randomUUID(),
  planId: plan,
  store: "01400943",
  modality: "PICKUP",
  items: [{ upc: product.upc, quantity: 2, price: 3, size: "1 l" }],
});

Deno.test("cart validation preserves UPC zeros and aggregates repeated products", () => {
  assertEquals(
    cartLines([{ upc: product.upc, quantity: 2 }, {
      upc: product.upc,
      quantity: 3,
    }], "PICKUP"),
    [{ upc: product.upc, quantity: 5, modality: "PICKUP" }],
  );
  for (
    const bad of [
      [],
      [{ upc: 1111040101, quantity: 1 }],
      [{ upc: product.upc, quantity: 1.5 }],
      [{ upc: product.upc, quantity: 0 }],
      [{ upc: product.upc, quantity: 100 }],
      [{ upc: product.upc, quantity: 60 }, { upc: product.upc, quantity: 50 }],
    ]
  ) {
    assertThrows(() => cartLines(bad, "PICKUP"), KrogerError);
  }
});
const fixture = (name: string) =>
  JSON.parse(
    Deno.readTextFileSync(new URL(`./fixtures/${name}.json`, import.meta.url)),
  );
const spoke = fixture("spoke_product").data[0],
  storeItem = fixture("store_product").data[0];

Deno.test("catalog safely flattens items and reads the promotional price", () => {
  const raw = {
    upc: product.upc,
    description: "Milk",
    items: [[{ size: "1 l", price: { regular: 4, promo: 3 } }]],
  };
  assertEquals(productFromApi(raw)?.price, 3);
  assertEquals(productFromApi(null), null);
  raw.items[0][0].price.promo = 0;
  assertEquals(productFromApi(raw)?.price, 4);
});
Deno.test("a Spoke's fulfillment booleans never decide availability", () => {
  // The Spoke says curbside: true for an item the curbside filter will not
  // return. Availability is the filter's answer: this product came back, so
  // it is available for the modality that was asked for.
  assertEquals(spoke.items[0].fulfillment.curbside, true);
  assertEquals(productFromApi(spoke)?.available, true);
  const outOfStock = structuredClone(spoke);
  outOfStock.items[0].inventory.stockLevel = "TEMPORARILY_OUT_OF_STOCK";
  assertEquals(productFromApi(outOfStock)?.available, false);
});
Deno.test("a Spoke product has no price, and never a zero one", () => {
  assertEquals("price" in spoke.items[0], false);
  assertEquals(productFromApi(spoke)?.price, null);
  assertEquals(productFromApi(spoke)?.size, "1 ct");
  // The same item id at a Store: price is a fact about the Location.
  assertEquals(productFromApi(storeItem)?.upc, productFromApi(spoke)?.upc);
  assertEquals(productFromApi(storeItem)?.price, 2.19);
  assertEquals(productFromApi(storeItem)?.size, "1 lb");
});
Deno.test("modality picks Kroger's fulfillment filter for search and lookup", async () => {
  const asked: string[] = [];
  const client = (body: unknown) =>
    new KrogerClient(cfg, (input) => {
      asked.push(String(input));
      return Promise.resolve(
        new Response(JSON.stringify(body), {
          headers: { "Content-Type": "application/json" },
        }),
      );
    });
  const db = new MemoryDb();
  const spokeBody = fixture("spoke_product");
  await new KrogerService(db as unknown as Db, user, client(spokeBody)).run(
    "search",
    { query: "broccoli", store: "70100108", modality: "DELIVERY" },
  );
  await new KrogerService(db as unknown as Db, user, client(spokeBody)).run(
    "search",
    { query: "broccoli", store: "01400943", modality: "PICKUP" },
  );
  await client({ data: spokeBody.data[0] }).product(
    spoke.upc,
    "70100108",
    "DELIVERY",
    "test-token",
  );
  assertEquals(asked[0].includes("filter.fulfillment=dth"), true);
  assertEquals(asked[1].includes("filter.fulfillment=csp"), true);
  assertEquals(asked[2].includes("filter.fulfillment=dth"), true);
});
Deno.test("a search finds nothing when the filter excludes everything", async () => {
  // What a Spoke actually does under the curbside filter: an empty list, not
  // an error and not a silent success with products in it.
  const service = new KrogerService(
    new MemoryDb() as unknown as Db,
    user,
    new KrogerClient(cfg, () =>
      Promise.resolve(
        new Response(JSON.stringify({ data: [] }), {
          headers: { "Content-Type": "application/json" },
        }),
      )),
  );
  const result = await service.run("search", {
    query: "broccoli",
    store: "70100108",
    modality: "PICKUP",
  });
  assertEquals((result.products as unknown[]).length, 0);
});
Deno.test("ranking favors matching form and available products", () => {
  const fresh = { ...product, name: "Blueberries" };
  assertEquals(
    rankProducts("blueberries", [{ ...fresh, name: "Dried Blueberries" }, {
      ...fresh,
      available: false,
    }, fresh])[0],
    fresh,
  );
});
Deno.test("token secret stays in Basic header; failures do not leak upstream content", async () => {
  const client = new KrogerClient(cfg, async (input, init) => {
    assertEquals(String(input).includes(cfg.secret), false);
    assertEquals(
      new Headers((init as RequestInit)?.headers).get("Authorization"),
      `Basic ${btoa("test-client:test-secret")}`,
    );
    return new Response("sensitive upstream detail", { status: 401 });
  });
  const error = await assertRejects(
    () => client.token({ grant_type: "authorization_code", code: "test-code" }),
    KrogerError,
  );
  assertEquals(error.message, "reconnect_required");
});
Deno.test("cart timeout is never automatically retried", async () => {
  let attempts = 0;
  const client = new KrogerClient(cfg, () => {
    attempts++;
    return Promise.reject(new Error("timeout"));
  });
  await assertRejects(() => client.add([], "test-token"));
  assertEquals(attempts, 1);
});

// In-memory PostgREST test double. Atomic insert models the UNIQUE constraint;
// the SQL integration test separately executes the actual migration and RLS.
class MemoryDb {
  tables: Record<string, any[]> = {
    meal_plans: [{ id: plan, user_id: user, is_deleted: false }],
    kroger_exports: [],
    kroger_oauth_sessions: [],
    kroger_connections: [{
      user_id: user,
      environment: "certification",
      access_token: "test-token",
      expires_at: new Date(Date.now() + 3600000).toISOString(),
    }],
  };
  failInsert = false;
  failUpdate = false;
  from(table: string) {
    const db = this;
    let operation = "select", input: any, single = false;
    const filters: ((r: any) => boolean)[] = [];
    const query = {
      select(_columns?: string) {
        return query;
      },
      eq(k: string, v: any) {
        filters.push((r) => r[k] === v);
        return query;
      },
      gt(k: string, v: any) {
        filters.push((r) => r[k] > v);
        return query;
      },
      lt(k: string, v: any) {
        filters.push((r) => r[k] < v);
        return query;
      },
      maybeSingle() {
        single = true;
        return query;
      },
      insert(v: any) {
        operation = "insert";
        input = v;
        return query;
      },
      upsert(v: any, _options?: any) {
        operation = "insert";
        input = v;
        return query;
      },
      update(v: any) {
        operation = "update";
        input = v;
        return query;
      },
      delete() {
        operation = "delete";
        return query;
      },
      then(resolve: (v: any) => any, reject?: (e: any) => any) {
        try {
          const rows = db.tables[table] ??= [];
          const selected = rows.filter((r) => filters.every((f) => f(r)));
          if (operation === "insert") {
            if (db.failInsert) {
              return Promise.resolve({ error: { code: "storage" } }).then(
                resolve,
                reject,
              );
            }
            if (
              table === "kroger_exports" &&
              rows.some((r) =>
                r.id === input.id ||
                r.user_id === input.user_id && r.plan_id === input.plan_id &&
                  r.environment === input.environment
              )
            ) {
              return Promise.resolve({ error: { code: "23505" } }).then(
                resolve,
                reject,
              );
            }
            rows.push({ ...input });
          }
          if (operation === "update") {
            if (db.failUpdate) {
              return Promise.resolve({ error: { code: "storage" } }).then(
                resolve,
                reject,
              );
            }
            selected.forEach((r) => Object.assign(r, input));
          }
          if (operation === "delete") {
            db.tables[table] = rows.filter((r) => !selected.includes(r));
          }
          return Promise.resolve({
            data: single
              ? selected[0] ?? null
              : selected.map((r) => ({ ...r })),
            error: null,
          }).then(resolve, reject);
        } catch (e) {
          return Promise.reject(e).then(resolve, reject);
        }
      },
    };
    return query;
  }
}
class TestClient extends KrogerClient {
  adds = 0;
  exchanges = 0;
  changed = false;
  timeout = false;
  missing = false;
  constructor() {
    super(cfg);
  }
  override product() {
    return this.missing
      ? Promise.reject(new KrogerError("product_unavailable"))
      : Promise.resolve({ ...product, price: this.changed ? 4 : 3 });
  }
  override token() {
    this.exchanges++;
    return Promise.resolve({ access_token: "test-token", expires_in: 3600 });
  }
  override add() {
    this.adds++;
    return this.timeout
      ? Promise.reject(new Error("timeout"))
      : Promise.resolve();
  }
}
function setup() {
  const db = new MemoryDb(), client = new TestClient();
  return {
    db,
    client,
    service: new KrogerService(db as unknown as Db, user, client),
  };
}
Deno.test("preflight price changes require review and do not touch cart", async () => {
  const { db, client, service } = setup();
  client.changed = true;
  const result = await service.run("export", payload());
  assertEquals((result.changed as any[]).length, 1);
  assertEquals(client.adds, 0);
  assertEquals(db.tables.kroger_exports.length, 0);
});
Deno.test("a line the fulfillment filter drops is reviewed, not an error", async () => {
  const { db, client, service } = setup();
  client.missing = true;
  const result = await service.run("export", payload());
  assertEquals((result.changed as any[])[0].available, false);
  assertEquals(client.adds, 0);
  assertEquals(db.tables.kroger_exports.length, 0);
});
Deno.test("replay and concurrent exports add at most once", async () => {
  const { client, service } = setup();
  await Promise.all([
    service.run("export", payload()),
    service.run("export", payload()),
  ]);
  await service.run("export", payload());
  assertEquals(client.adds, 1);
});
Deno.test("ambiguous add is durably unknown and never replayed", async () => {
  const { db, client, service } = setup();
  client.timeout = true;
  await service.run("export", payload());
  assertEquals(db.tables.kroger_exports[0].status, "unknown");
  await service.run("export", payload());
  assertEquals(client.adds, 1);
});
Deno.test("failed receipt reservation prevents write; failed outcome persistence blocks retry", async () => {
  const { db, client, service } = setup();
  db.failInsert = true;
  await assertRejects(() => service.run("export", payload()), KrogerError);
  assertEquals(client.adds, 0);
  db.failInsert = false;
  db.failUpdate = true;
  await assertRejects(() => service.run("export", payload()), KrogerError);
  assertEquals(db.tables.kroger_exports[0].status, "sending");
  await service.run("export", payload());
  assertEquals(client.adds, 1);
});
Deno.test("cannot export another user plan", async () => {
  const { db, client, service } = setup();
  db.tables.meal_plans[0].user_id = "someone-else";
  await assertRejects(
    () => service.run("export", payload()),
    KrogerError,
    "plan_not_found",
  );
  assertEquals(client.adds, 0);
});
Deno.test("OAuth state is owner-bound, expiring and single-use", async () => {
  const { db, client, service } = setup();
  const state = crypto.randomUUID();
  db.tables.kroger_oauth_sessions = [{
    state,
    user_id: "someone-else",
    environment: "certification",
    expires_at: new Date(Date.now() + 60000).toISOString(),
  }];
  await assertRejects(
    () => service.run("exchange", { state, code: "test-code" }),
    KrogerError,
    "invalid_oauth_state",
  );
  db.tables.kroger_oauth_sessions[0].user_id = user;
  db.tables.kroger_oauth_sessions[0].expires_at = new Date(0).toISOString();
  await assertRejects(
    () => service.run("exchange", { state, code: "test-code" }),
    KrogerError,
  );
  db.tables.kroger_oauth_sessions[0].expires_at = new Date(Date.now() + 60000)
    .toISOString();
  await service.run("exchange", { state, code: "test-code" });
  await assertRejects(
    () => service.run("exchange", { state, code: "test-code" }),
    KrogerError,
  );
  assertEquals(client.exchanges, 1);
});
Deno.test("concurrent refreshes claim only one lease and persist the new expiry", async () => {
  const { db, client, service } = setup();
  Object.assign(db.tables.kroger_connections[0], {
    expires_at: new Date(0).toISOString(),
    refresh_token: "test-refresh",
    refresh_locked_until: new Date(0).toISOString(),
  });
  const results = await Promise.allSettled([
    service.customerToken(),
    service.customerToken(),
  ]);
  assertEquals(results.filter((r) => r.status === "fulfilled").length, 1);
  assertEquals(client.exchanges, 1);
  assertEquals(
    Date.parse(db.tables.kroger_connections[0].expires_at) > Date.now(),
    true,
  );
});
