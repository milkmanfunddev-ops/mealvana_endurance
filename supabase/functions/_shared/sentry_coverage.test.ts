/**
 * Every edge function reports (ticket 12, spec §Enforcement).
 *
 *   (a) Scan: every supabase/functions/<fn>/index.ts enters through
 *       `serve(withSentry("<fn>", ...))` — the name must match the folder, so
 *       the Sentry `function` tag can never lie. FROZEN folders are skipped:
 *       they are never redeployed and never edited without a ruling.
 *   (b) Drive: each function's registered handler is run through the wrapper
 *       with a fake Sentry client and an error-forcing request (the probe
 *       header, honoured only when SENTRY_PROBE_TOKEN is set), asserting
 *       exactly one capture under that request's own scope, tagged with the
 *       function name, and a flush before the response left.
 *
 * The probe forces the error at the wrapper boundary, so (b) proves that the
 * handler Supabase serves IS the wrapped one and that the wrapper reports
 * once per request; the catch paths inside handlers are covered by the helper
 * tests in sentry.test.ts and the console.error audit in the ticket.
 *
 * Local test: no port is bound (servers are stubbed) and no network call is
 * made (the probe throws before the handler runs).
 */
import { assert, assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { FakeSentry, stubServers } from "./sentry_fake_client.ts";
import { PROBE_HEADER, setSentryClientForTesting, wrappedHandlers } from "./sentry.ts";

const FUNCTIONS_DIR = new URL("../", import.meta.url);

function functionFolders(): string[] {
  const out: string[] = [];
  for (const entry of Deno.readDirSync(FUNCTIONS_DIR)) {
    if (!entry.isDirectory || entry.name.startsWith("_") || entry.name === "tests") continue;
    const dir = new URL(`${entry.name}/`, FUNCTIONS_DIR);
    let hasIndex = false;
    let frozen = false;
    for (const f of Deno.readDirSync(dir)) {
      if (f.name === "index.ts") hasIndex = true;
      if (f.name === "FROZEN") frozen = true;
    }
    if (hasIndex && !frozen) out.push(entry.name);
  }
  return out.sort();
}

const folders = functionFolders();

Deno.test("scan: the tree has edge functions to check", () => {
  assert(folders.length >= 30, `expected the full function set, found ${folders.length}`);
});

Deno.test("scan: every function enters through serve(withSentry('<folder>', ...))", () => {
  const failures: string[] = [];
  for (const fn of folders) {
    const src = Deno.readTextFileSync(new URL(`${fn}/index.ts`, FUNCTIONS_DIR));
    const entry = new RegExp(`(^|[^\\w.])(Deno\\.)?serve\\(\\s*withSentry\\(\\s*["'${"`"}]${fn}["'${"`"}]\\s*,`, "m");
    if (!entry.test(src)) failures.push(`${fn}: no serve(withSentry("${fn}", ...)) entry`);
    if (/(^|[^\w.])(Deno\.)?serve\(\s*(async\s*)?\(/m.test(src)) failures.push(`${fn}: a bare serve(handler) remains`);
    if (!/from ["']\.\.\/_shared\/sentry\.ts["']/.test(src)) failures.push(`${fn}: does not import ../_shared/sentry.ts`);
  }
  assertEquals(failures, []);
});

// Import-time environment: functions read their config into module constants
// and some construct clients eagerly. Nothing here is a real credential.
function seedEnv() {
  const dummies: Record<string, string> = {
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_ANON_KEY: "test-anon",
    SUPABASE_SERVICE_ROLE_KEY: "test-service",
    OPENAI_API_KEY: "test-openai",
    ANTHROPIC_API_KEY: "test-anthropic",
    AI_GATEWAY_API_KEY: "test-gateway",
    RESEND_API_KEY: "test-resend",
    MIXPANEL_PROJECT_TOKEN: "test-mixpanel",
    ONESIGNAL_APP_ID: "test-onesignal",
    ONESIGNAL_REST_API_KEY: "test-onesignal-key",
    GARMIN_CONSUMER_KEY: "test-garmin",
    GARMIN_CONSUMER_SECRET: "test-garmin-secret",
    REVENUECAT_WEBHOOK_SECRET: "test-rc",
    RAW_RETENTION_ALERT_TOKEN: "test-sweep",
    RAW_RETENTION_ALERT_TO: "ops@example.test",
    USDA_API_KEY: "test-usda",
    KROGER_CLIENT_ID: "test-kroger",
    KROGER_CLIENT_SECRET: "test-kroger-secret",
    OPENWEATHER_API_KEY: "test-weather",
    CORPUS_EXPORT_TOKEN: "test-corpus",
    SENTRY_PROBE_TOKEN: "probe-token",
  };
  for (const [k, v] of Object.entries(dummies)) {
    if (!Deno.env.get(k)) Deno.env.set(k, v);
  }
  Deno.env.delete("SENTRY_DSN");
}

Deno.test("drive: every handler captures exactly once, under its own scope, through the wrapper", async () => {
  stubServers();
  seedEnv();
  const fake = new FakeSentry();
  setSentryClientForTesting(fake);
  const failures: string[] = [];
  const seenScopes = new Set<number>();

  for (const fn of folders) {
    try {
      await import(`../${fn}/index.ts`);
    } catch (e) {
      failures.push(`${fn}: import failed: ${(e as Error).message}`);
      continue;
    }
    const handler = wrappedHandlers().get(fn);
    if (!handler) {
      failures.push(`${fn}: no handler registered under its own name`);
      continue;
    }
    fake.reset();
    const req = new Request(`https://example.supabase.co/functions/v1/${fn}`, {
      method: "POST",
      headers: { "content-type": "application/json", [PROBE_HEADER]: "probe-token" },
      body: "{}",
    });
    let res: Response;
    try {
      res = await handler(req);
    } catch (e) {
      failures.push(`${fn}: the wrapper let an error escape: ${(e as Error).message}`);
      continue;
    }
    if (res.status !== 500) failures.push(`${fn}: expected 500 from the probe, got ${res.status}`);
    if (fake.captures.length !== 1) failures.push(`${fn}: expected 1 capture, got ${fake.captures.length}`);
    const scope = fake.captures[0]?.scope;
    if (!scope) {
      failures.push(`${fn}: capture happened outside an isolation scope`);
    } else {
      if (scope.tags.edge_function !== fn) failures.push(`${fn}: scope tag function=${scope.tags.edge_function}`);
      if (scope.tags.component !== "edge_function") failures.push(`${fn}: scope tag component=${scope.tags.component}`);
      if (scope.tags.method !== "POST") failures.push(`${fn}: scope tag method=${scope.tags.method}`);
      if (seenScopes.has(scope.id)) failures.push(`${fn}: reused another request's scope`);
      seenScopes.add(scope.id);
    }
    if (fake.flushes < 1) failures.push(`${fn}: no flush before the response`);
  }
  setSentryClientForTesting(null);
  assertEquals(failures, []);
});
