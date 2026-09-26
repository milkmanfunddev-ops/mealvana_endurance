/**
 * Finding 121-010 (ticket 138): garmin-auth logged every request header,
 * caller IPs included, and the expected client id on every push.
 *
 * Run with: deno test --allow-all supabase/functions/_shared/garmin/auth.test.ts
 */

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { validateGarminRequest } from "./auth.ts";

function captureConsole(run: () => void): string[] {
  const lines: string[] = [];
  const saved = { log: console.log, warn: console.warn, error: console.error };
  const push = (...args: unknown[]) =>
    lines.push(args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" "));
  console.log = push;
  console.warn = push;
  console.error = push;
  try {
    run();
  } finally {
    console.log = saved.log;
    console.warn = saved.warn;
    console.error = saved.error;
  }
  return lines;
}

const CLIENT_ID = "expected-client-id-123";

describe("validateGarminRequest logging", () => {
  it("logs nothing for a valid request", () => {
    const req = new Request("https://x.test/garmin-push", {
      method: "POST",
      headers: {
        "garmin-client-id": CLIENT_ID,
        "x-forwarded-for": "203.0.113.9",
        "user-agent": "Garmin",
      },
    });
    let result: string | null = "unset";
    const lines = captureConsole(() => {
      result = validateGarminRequest(req, CLIENT_ID);
    });
    assertEquals(result, null);
    assertEquals(lines, []);
  });

  it("never prints the caller's headers, IP, or the expected client id", () => {
    const req = new Request("https://x.test/garmin-push", {
      method: "POST",
      headers: {
        "garmin-client-id": "someone-else",
        "x-forwarded-for": "203.0.113.9",
      },
    });
    const lines = captureConsole(() => validateGarminRequest(req, CLIENT_ID));
    assertEquals(lines.length, 1, "one mismatch line");
    const joined = lines.join("\n");
    assertEquals(joined.includes("203.0.113.9"), false);
    assertEquals(joined.includes(CLIENT_ID), false);
    assertEquals(joined.includes("someone-else"), false);
    assertEquals(joined.includes("mismatch"), true);
  });

  it("keeps the missing-header warning", () => {
    const req = new Request("https://x.test/garmin-push", { method: "POST" });
    const lines = captureConsole(() => validateGarminRequest(req, CLIENT_ID));
    assertEquals(lines.length, 1);
    assertEquals(lines[0].includes("No garmin-client-id header"), true);
    assertEquals(lines[0].includes(CLIENT_ID), false);
  });
});
