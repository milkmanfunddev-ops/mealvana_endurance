/**
 * Tests for the apple-signin-callback relay (ticket 17).
 *
 * Run with:
 *   deno test --allow-env supabase/functions/apple-signin-callback/relay.test.ts
 */
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { buildIntentUrl, relayAppleCallback, resolveAndroidPackage } from "./relay.ts";

// Producer-shaped: Apple's form_post body (first consent carries `user`).
const APPLE_FORM_POST =
  "state=abc&code=c0de.1-x&id_token=eyJhbGciOiJSUzI1NiJ9.eyJhdWQiOiJ4In0.sig_-" +
  "&user=%7B%22name%22%3A%7B%22firstName%22%3A%22Ann%22%2C%22lastName%22%3A%22Lee%22%7D%2C%22email%22%3A%22a%40b.c%22%7D";

Deno.test("POST form_post relays every field to the dev package on the dev project", async () => {
  const req = new Request("https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/apple-signin-callback", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: APPLE_FORM_POST,
  });
  const res = await relayAppleCallback(req, {
    SUPABASE_URL: "https://vlmtsdzpnjnavdgytcmi.supabase.co",
  });
  assertEquals(res.status, 303);
  const location = res.headers.get("Location")!;
  assertEquals(location.startsWith("intent://callback?"), true);
  assertEquals(
    location.endsWith("#Intent;package=com.milkman.mealvanaendurance.dev;scheme=signinwithapple;end"),
    true,
  );
  // What the plugin's Dart side reads back (Uri.queryParameters semantics).
  const query = new URLSearchParams(location.slice("intent://callback?".length, location.indexOf("#")));
  assertEquals(query.get("code"), "c0de.1-x");
  assertEquals(query.get("id_token"), "eyJhbGciOiJSUzI1NiJ9.eyJhdWQiOiJ4In0.sig_-");
  assertEquals(query.get("state"), "abc");
  assertEquals(JSON.parse(query.get("user")!).name.firstName, "Ann");
});

Deno.test("prod project targets the prod package", () => {
  assertEquals(
    resolveAndroidPackage({ SUPABASE_URL: "https://wvmvsodrvbkxfydabqed.supabase.co" }),
    "com.milkman.mealvanaendurance",
  );
});

Deno.test("ANDROID_APP_PACKAGE overrides the project map", () => {
  assertEquals(
    resolveAndroidPackage({ ANDROID_APP_PACKAGE: "x.y", SUPABASE_URL: "https://vlmtsdzpnjnavdgytcmi.supabase.co" }),
    "x.y",
  );
});

Deno.test("an Apple error (user cancelled) is relayed so the plugin can raise it", async () => {
  const req = new Request("https://example.supabase.co/functions/v1/apple-signin-callback?error=user_cancelled_authorize&state=s");
  const res = await relayAppleCallback(req, {});
  const location = res.headers.get("Location")!;
  assertEquals(location, buildIntentUrl(new URLSearchParams("error=user_cancelled_authorize&state=s"), "com.milkman.mealvanaendurance"));
});

Deno.test("other methods are refused", async () => {
  const res = await relayAppleCallback(new Request("https://e.co/x", { method: "PUT" }), {});
  assertEquals(res.status, 405);
});
