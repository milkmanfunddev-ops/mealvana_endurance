/**
 * Tests for the shared Garmin token helpers (testing-wave ticket 138,
 * Findings 112-010, 121-010, 118-016).
 *
 * Run with: deno test --allow-all supabase/functions/_shared/garmin/token.test.ts
 */

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  deregisterGarminForUser,
  ensureFreshGarminToken,
  GARMIN_DEREGISTRATION_URL,
  GARMIN_TOKEN_URL,
  isGarminTokenInactive,
  markGarminRequiresReauth,
} from "./token.ts";

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

interface UpdateCapture {
  table: string;
  values: Record<string, unknown>;
  filters: [string, unknown][];
}

/** A supabase double covering `.from().select().eq().eq().maybeSingle()` and `.from().update().eq().eq()`. */
function fakeSupabase(opts: {
  integrationRow?: Record<string, unknown> | null;
  readError?: { code?: string; message: string; details?: string; hint?: string } | null;
  updateError?: { code?: string; message: string; details?: string; hint?: string } | null;
} = {}) {
  const updates: UpdateCapture[] = [];
  const supabase = {
    from(table: string) {
      return {
        select() {
          const filters: [string, unknown][] = [];
          const q = {
            eq(col: string, v: unknown) {
              filters.push([col, v]);
              return q;
            },
            maybeSingle() {
              return Promise.resolve({
                data: opts.readError ? null : (opts.integrationRow ?? null),
                error: opts.readError ?? null,
              });
            },
          };
          return q;
        },
        update(values: Record<string, unknown>) {
          const filters: [string, unknown][] = [];
          const q = {
            eq(col: string, v: unknown) {
              filters.push([col, v]);
              return q;
            },
            then(resolve: (r: { error: unknown }) => void) {
              updates.push({ table, values, filters });
              resolve({ error: opts.updateError ?? null });
            },
          };
          return q;
        },
      };
    },
  };
  return { supabase, updates };
}

interface FetchCall {
  url: string;
  method: string;
  auth: string | null;
}

/** A fetch double that answers by URL and records every call. */
function fakeFetch(
  answer: (url: string, init?: RequestInit) => Response | Promise<Response>,
) {
  const calls: FetchCall[] = [];
  const fn = ((input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    const headers = new Headers(init?.headers);
    calls.push({
      url,
      method: init?.method ?? "GET",
      auth: headers.get("Authorization"),
    });
    return Promise.resolve(answer(url, init));
  }) as typeof fetch;
  return { fn, calls };
}

const creds = { clientId: "cid", clientSecret: "secret" };
const hourAhead = () => new Date(Date.now() + 60 * 60 * 1000).toISOString();
const hourAgo = () => new Date(Date.now() - 60 * 60 * 1000).toISOString();

function captureConsole(run: () => Promise<void>): Promise<string[]> {
  const lines: string[] = [];
  const err = console.error;
  const warn = console.warn;
  const log = console.log;
  const push = (...args: unknown[]) =>
    lines.push(args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" "));
  console.error = push;
  console.warn = push;
  console.log = push;
  return run().then(() => lines).finally(() => {
    console.error = err;
    console.warn = warn;
    console.log = log;
  });
}

// ---------------------------------------------------------------------------
// ensureFreshGarminToken
// ---------------------------------------------------------------------------

describe("ensureFreshGarminToken", () => {
  it("returns the stored token while it is still valid", async () => {
    const { supabase, updates } = fakeSupabase();
    const { fn, calls } = fakeFetch(() => new Response("", { status: 500 }));
    const token = await ensureFreshGarminToken(
      supabase,
      { access_token: "live", refresh_token: "r", token_expires_at: hourAhead() },
      "u1",
      { fetch: fn, ...creds },
    );
    assertEquals(token, "live");
    assertEquals(calls.length, 0);
    assertEquals(updates.length, 0);
  });

  it("refreshes an expired token and persists it on the integrations row", async () => {
    const { supabase, updates } = fakeSupabase();
    const { fn, calls } = fakeFetch(() =>
      new Response(
        JSON.stringify({ access_token: "fresh", refresh_token: "r2", expires_in: 3600 }),
        { status: 200 },
      )
    );
    const token = await ensureFreshGarminToken(
      supabase,
      { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() },
      "u1",
      { fetch: fn, ...creds },
    );
    assertEquals(token, "fresh");
    assertEquals(calls[0].url, GARMIN_TOKEN_URL);
    assertEquals(updates.length, 1);
    assertEquals(updates[0].table, "integrations");
    assertEquals(updates[0].values.access_token, "fresh");
    assertEquals(updates[0].values.refresh_token, "r2");
    assertEquals(updates[0].filters, [["user_id", "u1"], ["provider", "garmin"]]);
  });

  it("falls back to the stale token when the refresh fails", async () => {
    const { supabase } = fakeSupabase();
    const { fn } = fakeFetch(() => new Response("nope", { status: 400 }));
    const token = await ensureFreshGarminToken(
      supabase,
      { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() },
      "u1",
      { fetch: fn, ...creds },
    );
    assertEquals(token, "stale");
  });

  it("says once per name when the Garmin client env is missing (D9)", async () => {
    const saved = {
      id: Deno.env.get("GARMIN_CLIENT_ID"),
      secret: Deno.env.get("GARMIN_CLIENT_SECRET"),
    };
    Deno.env.delete("GARMIN_CLIENT_ID");
    Deno.env.delete("GARMIN_CLIENT_SECRET");
    try {
      const { supabase } = fakeSupabase();
      const { fn, calls } = fakeFetch(() => new Response("nope", { status: 401 }));
      const row = { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() };
      const lines = await captureConsole(async () => {
        await ensureFreshGarminToken(supabase, row, "u1", { fetch: fn });
        await ensureFreshGarminToken(supabase, row, "u1", { fetch: fn });
      });
      assertEquals(calls.length, 2, "behaviour unchanged: the refresh still runs");
      assertEquals(lines.filter((l) => l === "[garmin] missing env GARMIN_CLIENT_ID").length, 1);
      assertEquals(lines.filter((l) => l === "[garmin] missing env GARMIN_CLIENT_SECRET").length, 1);
    } finally {
      if (saved.id !== undefined) Deno.env.set("GARMIN_CLIENT_ID", saved.id);
      if (saved.secret !== undefined) Deno.env.set("GARMIN_CLIENT_SECRET", saved.secret);
    }
  });

  it("falls back to the stale token when there is no refresh token", async () => {
    const { supabase } = fakeSupabase();
    const { fn, calls } = fakeFetch(() => new Response("", { status: 200 }));
    const token = await ensureFreshGarminToken(
      supabase,
      { access_token: "stale", refresh_token: null, token_expires_at: hourAgo() },
      "u1",
      { fetch: fn, ...creds },
    );
    assertEquals(token, "stale");
    assertEquals(calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// deregisterGarminForUser
// ---------------------------------------------------------------------------

describe("deregisterGarminForUser", () => {
  it("reads the integrations token, refreshes it when expired, and DELETEs the registration", async () => {
    const { supabase } = fakeSupabase({
      integrationRow: { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() },
    });
    const { fn, calls } = fakeFetch((url) => {
      if (url === GARMIN_TOKEN_URL) {
        return new Response(
          JSON.stringify({ access_token: "fresh", expires_in: 3600 }),
          { status: 200 },
        );
      }
      return new Response(null, { status: 204 });
    });

    const outcome = await deregisterGarminForUser(supabase, "u1", { fetch: fn, ...creds });

    assertEquals(outcome, "deregistered");
    const del = calls.find((c) => c.url === GARMIN_DEREGISTRATION_URL);
    assertEquals(del?.method, "DELETE");
    assertEquals(del?.auth, "Bearer fresh");
  });

  it("uses the stored token as is while it is still valid", async () => {
    const { supabase } = fakeSupabase({
      integrationRow: { access_token: "live", refresh_token: "r1", token_expires_at: hourAhead() },
    });
    const { fn, calls } = fakeFetch(() => new Response(null, { status: 204 }));

    await deregisterGarminForUser(supabase, "u1", { fetch: fn, ...creds });

    assertEquals(calls.length, 1);
    assertEquals(calls[0].auth, "Bearer live");
  });

  it("reports no_token when Garmin is not connected, without calling Garmin", async () => {
    const { supabase } = fakeSupabase({ integrationRow: null });
    const { fn, calls } = fakeFetch(() => new Response(null, { status: 204 }));

    const outcome = await deregisterGarminForUser(supabase, "u1", { fetch: fn, ...creds });

    assertEquals(outcome, "no_token");
    assertEquals(calls.length, 0);
  });

  it("logs and reports failed when Garmin refuses, and never throws", async () => {
    const { supabase } = fakeSupabase({
      integrationRow: { access_token: "live", refresh_token: null, token_expires_at: hourAhead() },
    });
    const { fn } = fakeFetch(() => new Response("Unauthorized", { status: 401 }));

    let outcome = "";
    const lines = await captureConsole(async () => {
      outcome = await deregisterGarminForUser(supabase, "u1", {
        fetch: fn,
        ...creds,
        logPrefix: "[test]",
      });
    });

    assertEquals(outcome, "failed");
    assertEquals(lines.some((l) => l.includes("[test]") && l.includes("401")), true);
    // The token itself never reaches the log.
    assertEquals(lines.some((l) => l.includes("live")), false);
  });

  it("reports failed when fetch itself throws", async () => {
    const { supabase } = fakeSupabase({
      integrationRow: { access_token: "live", refresh_token: null, token_expires_at: hourAhead() },
    });
    const fn = (() => Promise.reject(new TypeError("network down"))) as typeof fetch;

    let outcome = "";
    await captureConsole(async () => {
      outcome = await deregisterGarminForUser(supabase, "u1", { fetch: fn, ...creds });
    });
    assertEquals(outcome, "failed");
  });

  it("reports failed when the integrations read fails", async () => {
    const { supabase } = fakeSupabase({ readError: { code: "57014", message: "timeout" } });
    const { fn, calls } = fakeFetch(() => new Response(null, { status: 204 }));

    let outcome = "";
    await captureConsole(async () => {
      outcome = await deregisterGarminForUser(supabase, "u1", { fetch: fn, ...creds });
    });
    assertEquals(outcome, "failed");
    assertEquals(calls.length, 0);
  });
});

// ---------------------------------------------------------------------------
// Token is not active → requires_reauth
// ---------------------------------------------------------------------------

describe("isGarminTokenInactive", () => {
  it("recognises Garmin's inactive-token refusal", () => {
    assertEquals(isGarminTokenInactive(401, "Token is not active"), true);
    assertEquals(isGarminTokenInactive(401, '{"error":"token is not active"}'), true);
  });

  it("leaves a rate limit or a gateway error alone", () => {
    assertEquals(isGarminTokenInactive(429, "rate limit quota violation"), false);
    assertEquals(isGarminTokenInactive(502, "Bad Gateway"), false);
    assertEquals(isGarminTokenInactive(401, "Unauthorized"), false);
  });
});

describe("markGarminRequiresReauth", () => {
  it("stamps the garmin integrations row requires_reauth with the reauth_required code", async () => {
    const { supabase, updates } = fakeSupabase();
    await markGarminRequiresReauth(supabase, "u1");
    assertEquals(updates.length, 1);
    assertEquals(updates[0].table, "integrations");
    assertEquals(updates[0].values.last_sync_status, "requires_reauth");
    // Ticket 37: the column holds a code the app maps to content, never text.
    assertEquals(updates[0].values.last_sync_error, "reauth_required");
    assertEquals(updates[0].filters, [["user_id", "u1"], ["provider", "garmin"]]);
  });

  it("logs an update failure and does not throw", async () => {
    const { supabase } = fakeSupabase({ updateError: { message: "boom" } });
    const lines = await captureConsole(() => markGarminRequiresReauth(supabase, "u1"));
    assertEquals(lines.some((l) => l.includes("boom")), true);
  });
});

// ---------------------------------------------------------------------------
// Ticket 76 (Finding 69-012): status and error code only, never a body
// ---------------------------------------------------------------------------

const leakedB64 = btoa(
  JSON.stringify({ refreshTokenValue: "rt-live-5f2c", garminGuid: "g-guid-1" }),
);
const invalidGrantBody = JSON.stringify({
  error: "invalid_grant",
  error_description: `Invalid refresh token: ${leakedB64}`,
});
const failingRowError = {
  code: "23502",
  message: 'null value in column "token_expires_at" violates not-null constraint',
  details: "Failing row contains (u1, garmin, fresh, rt-live-5f2c, null)",
  hint: "rt-live-5f2c",
};

/** No line holds the token, any 12-character slice of its base64, or Garmin's description. */
function assertNoLeak(lines: string[]) {
  for (const line of lines) {
    assertEquals(line.includes("rt-live-5f2c"), false, line);
    assertEquals(line.includes("Invalid refresh token"), false, line);
    assertEquals(line.includes("error_description"), false, line);
    assertEquals(line.includes("Failing row"), false, line);
    for (let i = 0; i + 12 <= leakedB64.length; i++) {
      assertEquals(line.includes(leakedB64.slice(i, i + 12)), false, line);
    }
  }
}

describe("redaction (ticket 76)", () => {
  it("logs a refused refresh as status and error code only, and keeps the stale token", async () => {
    const { supabase } = fakeSupabase();
    const { fn } = fakeFetch(() => new Response(invalidGrantBody, { status: 400 }));
    let token = "";
    const lines = await captureConsole(async () => {
      token = await ensureFreshGarminToken(
        supabase,
        { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() },
        "u1",
        { fetch: fn, ...creds, logPrefix: "[garmin-backfill]" },
      );
    });
    assertEquals(token, "stale");
    const refreshLine = lines.find((l) => l.includes("Token refresh failed"));
    assertEquals(refreshLine, '[garmin-backfill] Token refresh failed {"status":400,"error_code":"invalid_grant"}');
    assertNoLeak(lines);
  });

  it("logs a failed persist of the refreshed token as code and message only", async () => {
    const { supabase } = fakeSupabase({ updateError: failingRowError });
    const { fn } = fakeFetch(() =>
      new Response(
        JSON.stringify({ access_token: "fresh", refresh_token: "r2", expires_in: 3600 }),
        { status: 200 },
      )
    );
    const lines = await captureConsole(async () => {
      await ensureFreshGarminToken(
        supabase,
        { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() },
        "u1",
        { fetch: fn, ...creds },
      );
    });
    assertEquals(lines.some((l) => l.includes("Failed to persist") && l.includes("23502")), true);
    assertNoLeak(lines);
  });

  it("logs a thrown refresh as the error's name and message", async () => {
    const { supabase } = fakeSupabase();
    const fn = (() => Promise.reject(new TypeError("network down"))) as typeof fetch;
    const lines = await captureConsole(async () => {
      await ensureFreshGarminToken(
        supabase,
        { access_token: "stale", refresh_token: "r1", token_expires_at: hourAgo() },
        "u1",
        { fetch: fn, ...creds },
      );
    });
    assertEquals(lines.some((l) => l.includes("Token refresh error") && l.includes("TypeError: network down")), true);
  });

  it("logs a failed requires_reauth write as code and message only", async () => {
    const { supabase } = fakeSupabase({ updateError: failingRowError });
    const lines = await captureConsole(() => markGarminRequiresReauth(supabase, "u1"));
    assertEquals(lines.some((l) => l.includes("requires_reauth") && l.includes("23502")), true);
    assertNoLeak(lines);
  });

  it("logs a failed deregistration read as code and message only", async () => {
    const { supabase } = fakeSupabase({ readError: failingRowError });
    const { fn } = fakeFetch(() => new Response(null, { status: 204 }));
    let outcome = "";
    const lines = await captureConsole(async () => {
      outcome = await deregisterGarminForUser(supabase, "u1", { fetch: fn, ...creds });
    });
    assertEquals(outcome, "failed");
    assertEquals(lines.some((l) => l.includes("integrations read failed") && l.includes("23502")), true);
    assertNoLeak(lines);
  });
});
