/**
 * Wrapper and helper contract for edge-function error reporting (ticket 12,
 * .scratch/sentry/spec.md §"Edge functions" and Testing Decisions item 3).
 *
 *   - every request runs under its own isolation scope, tagged with the
 *     function name, the method and component:edge_function;
 *   - an exception that escapes the handler is captured exactly once and
 *     answered with a 500; the flush runs before the response leaves;
 *   - serverError() captures the error it is given; errorResponse() captures
 *     with a cause or a 5xx and only breadcrumbs a 4xx without one;
 *   - the probe header throws only when SENTRY_PROBE_TOKEN is set and matches;
 *   - raw-retention-alert sends in_progress then ok/error check-ins.
 *
 * Local test: no network (fetch is stubbed where a handler would call out).
 */
import {
  assert,
  assertEquals,
  assertNotEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { FakeSentry, stubServers } from "./sentry_fake_client.ts";
import {
  captureEdgeError,
  PROBE_HEADER,
  setSentryClientForTesting,
  withSentry,
  wrappedHandlers,
} from "./sentry.ts";
import { errorResponse, serverError } from "./responses.ts";

const fake = new FakeSentry();
setSentryClientForTesting(fake);
Deno.env.delete("SENTRY_DSN");
Deno.env.delete("SENTRY_PROBE_TOKEN");
Deno.env.delete("SENTRY_CRON_MONITORS");

const post = (headers: Record<string, string> = {}, body?: unknown) =>
  new Request("https://example.supabase.co/functions/v1/unit-test", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

Deno.test("wrapper: tags the scope and flushes on a clean request", async () => {
  fake.reset();
  const handler = withSentry("unit-ok", () => new Response("ok"));
  const res = await handler(post());
  assertEquals(res.status, 200);
  assertEquals(fake.captures.length, 0);
  assertEquals(fake.flushes, 1);
  assert(wrappedHandlers().has("unit-ok"));
});

Deno.test("wrapper: an escaped exception is captured once under its own scope and answered 500", async () => {
  fake.reset();
  const handler = withSentry("unit-throw", () => {
    throw new Error("boom");
  });
  const res = await handler(post());
  assertEquals(res.status, 500);
  const body = await res.json();
  assertEquals(body.success, false);
  assertStringIncludes(body.error, "boom");
  assertEquals(fake.captures.length, 1);
  const c = fake.captures[0];
  assert(c.scope, "capture happened under an isolation scope");
  assertEquals(c.scope!.tags.edge_function, "unit-throw");
  assertEquals(c.scope!.tags.method, "POST");
  assertEquals(c.scope!.tags.component, "edge_function");
  assertEquals(c.scope!.extras.path, "/functions/v1/unit-test");
  assertEquals(c.context?.tags?.edge_function, "unit-throw");
  assertEquals(fake.flushes, 1);
});

Deno.test("wrapper: consecutive requests get distinct scopes", async () => {
  fake.reset();
  const handler = withSentry("unit-scopes", () => {
    throw new Error("again");
  });
  await handler(post());
  await handler(new Request("https://x.test/f", { method: "GET" }));
  assertEquals(fake.captures.length, 2);
  assertNotEquals(fake.captures[0].scope!.id, fake.captures[1].scope!.id);
  assertEquals(fake.captures[1].scope!.tags.method, "GET");
});

Deno.test("wrapper: a capture inside the handler lands on the request scope", async () => {
  fake.reset();
  const handler = withSentry("unit-inner", () => {
    captureEdgeError(new Error("inner"), { message: "inner failure" });
    return new Response("degraded");
  });
  const res = await handler(post());
  assertEquals(res.status, 200);
  assertEquals(fake.captures.length, 1);
  assertEquals(fake.captures[0].scope!.tags.edge_function, "unit-inner");
});

Deno.test("wrapper: probe header is inert without SENTRY_PROBE_TOKEN", async () => {
  fake.reset();
  Deno.env.delete("SENTRY_PROBE_TOKEN");
  const handler = withSentry("unit-probe-off", () => new Response("ok"));
  const res = await handler(post({ [PROBE_HEADER]: "anything" }));
  assertEquals(res.status, 200);
  assertEquals(fake.captures.length, 0);
});

Deno.test("wrapper: probe header with the matching token throws before the handler", async () => {
  fake.reset();
  Deno.env.set("SENTRY_PROBE_TOKEN", "secret-token");
  let ran = false;
  const handler = withSentry("unit-probe-on", () => {
    ran = true;
    return new Response("ok");
  });
  const wrong = await handler(post({ [PROBE_HEADER]: "nope" }));
  assertEquals(wrong.status, 200);
  const res = await handler(post({ [PROBE_HEADER]: "secret-token" }));
  Deno.env.delete("SENTRY_PROBE_TOKEN");
  assertEquals(res.status, 500);
  assertEquals(ran, true, "the wrong token ran the handler; the right one did not run it twice");
  assertEquals(fake.captures.length, 1);
  assertEquals((fake.captures[0].error as Error).name, "SentryProbeError");
});

Deno.test("serverError() captures the error it is given and keeps the public message", async () => {
  fake.reset();
  const err = new Error("db exploded");
  const res = serverError(err, false, "Could not provision wallet");
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, "Could not provision wallet");
  assertEquals(fake.captures.length, 1);
  assertEquals(fake.captures[0].error, err);
});

Deno.test("errorResponse(): 4xx without a cause is only a breadcrumb", () => {
  fake.reset();
  const res = errorResponse("Missing authorization header", 401);
  assertEquals(res.status, 401);
  assertEquals(fake.captures.length, 0);
  assertEquals(fake.breadcrumbs.length, 1);
  assertEquals(fake.breadcrumbs[0].data?.status, 401);
});

Deno.test("errorResponse(): a cause is captured even on a 4xx", () => {
  fake.reset();
  const cause = new Error("parse failed");
  errorResponse("Bad payload", 400, undefined, undefined, cause);
  assertEquals(fake.captures.length, 1);
  assertEquals(fake.captures[0].error, cause);
});

Deno.test("errorResponse(): a 5xx without a cause is captured as a message", () => {
  fake.reset();
  errorResponse("Upstream unavailable", 503);
  assertEquals(fake.captures.length, 1);
  assertEquals(fake.captures[0].kind, "message");
  assertEquals(fake.captures[0].message, "Upstream unavailable");
});

Deno.test("captureEdgeError(): a non-Error value becomes an Error with the raw value kept", () => {
  fake.reset();
  captureEdgeError({ code: "23505" }, { message: "rpc failed", level: "warning" });
  assertEquals(fake.captures.length, 1);
  assert(fake.captures[0].error instanceof Error);
  assertEquals(fake.captures[0].context?.level, "warning");
  assertEquals((fake.captures[0].context?.extra as Record<string, unknown>).raw_error, { code: "23505" });
});

// ---------------------------------------------------------------------------
// raw-retention-alert: cron check-ins
// ---------------------------------------------------------------------------

async function retentionHandler() {
  stubServers();
  Deno.env.set("RAW_RETENTION_ALERT_TOKEN", "sweep-token");
  Deno.env.set("RAW_RETENTION_ALERT_TO", "ops@example.test");
  Deno.env.set("RESEND_API_KEY", "resend-test");
  await import("../raw-retention-alert/index.ts");
  const handler = wrappedHandlers().get("raw-retention-alert");
  assert(handler, "raw-retention-alert registers through withSentry");
  return handler!;
}

const sweepPost = (body: unknown) =>
  post({ "x-alert-token": "sweep-token" }, body);

Deno.test("raw-retention-alert: quiet night → in_progress then ok, no email", async () => {
  const handler = await retentionHandler();
  fake.reset();
  Deno.env.set("SENTRY_CRON_MONITORS", "1");
  const res = await handler(sweepPost({ audit: { id: 1, oversize_alert: false, underarrival_alerts: [] }, sweep_status: "ok", alerted: false }));
  Deno.env.delete("SENTRY_CRON_MONITORS");
  assertEquals(res.status, 200);
  assertEquals(fake.checkIns.map((c) => c.status), ["in_progress", "ok"]);
  assertEquals(fake.checkIns[0].monitorSlug, "raw-retention-sweep");
  assertEquals(fake.checkIns[0].monitorConfig?.schedule.value, "17 3 * * *");
  assertEquals(fake.checkIns[0].monitorConfig?.checkinMargin, 30);
  assert(fake.checkIns[0].checkInId === undefined, "in_progress opens a new check-in");
  assert(fake.checkIns[1].checkInId?.startsWith("checkin-"), "ok closes the id in_progress returned");
  assertEquals(fake.captures.length, 0);
});

Deno.test("raw-retention-alert: sweep failure → in_progress then error, and the failure is captured", async () => {
  const handler = await retentionHandler();
  fake.reset();
  Deno.env.set("SENTRY_CRON_MONITORS", "1");
  const res = await handler(sweepPost({ audit: null, sweep_status: "error", sweep_error: "XX000: disk full", alerted: false }));
  Deno.env.delete("SENTRY_CRON_MONITORS");
  assertEquals(res.status, 200);
  assertEquals(fake.checkIns.map((c) => c.status), ["in_progress", "error"]);
  assertEquals(fake.captures.length, 1);
  assertStringIncludes(fake.captures[0].message ?? "", "disk full");
});

Deno.test("raw-retention-alert: alert night sends the email; a rejected email is an error check-in", async () => {
  const handler = await retentionHandler();
  const realFetch = globalThis.fetch;
  const calls: string[] = [];
  globalThis.fetch = ((input: string | URL | Request, _init?: RequestInit) => {
    calls.push(String(input));
    return Promise.resolve(new Response("rate limited", { status: 429 }));
  }) as typeof fetch;
  fake.reset();
  Deno.env.set("SENTRY_CRON_MONITORS", "1");
  try {
    const res = await handler(sweepPost({ audit: { id: 2, oversize_alert: true, underarrival_alerts: [], row_counts: {}, purged: {} }, sweep_status: "ok", alerted: true }));
    assertEquals(res.status, 502);
  } finally {
    globalThis.fetch = realFetch;
    Deno.env.delete("SENTRY_CRON_MONITORS");
  }
  assertEquals(calls, ["https://api.resend.com/emails"]);
  assertEquals(fake.checkIns.map((c) => c.status), ["in_progress", "error"]);
  assertEquals(fake.captures.length, 1);
});

Deno.test("raw-retention-alert: legacy bare audit body still means 'alert fired'", async () => {
  const handler = await retentionHandler();
  const realFetch = globalThis.fetch;
  globalThis.fetch = (() => Promise.resolve(new Response("{}", { status: 200 }))) as typeof fetch;
  fake.reset();
  try {
    const res = await handler(sweepPost({ id: 3, oversize_alert: true, underarrival_alerts: [], row_counts: {}, purged: {} }));
    assertEquals(res.status, 200);
  } finally {
    globalThis.fetch = realFetch;
  }
  assertEquals(fake.checkIns.length, 0, "SENTRY_CRON_MONITORS unset → no check-ins");
  assertEquals(fake.captures.length, 0);
});

Deno.test("raw-retention-alert: bad token is a breadcrumb, not an event", async () => {
  const handler = await retentionHandler();
  fake.reset();
  const res = await handler(post({ "x-alert-token": "wrong" }, {}));
  assertEquals(res.status, 401);
  assertEquals(fake.captures.length, 0);
  assertEquals(fake.breadcrumbs.length, 1);
});
