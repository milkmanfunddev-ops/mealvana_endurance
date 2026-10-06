/**
 * Sign in with Apple on Android: the return-URL relay (ticket 17, Sentry
 * MEALVANA-ENDURANCE-A6 / BY).
 *
 * On Android, `sign_in_with_apple` runs Apple's web sign-in in a Chrome Custom
 * Tab. Apple ends that flow by POSTing (`response_mode=form_post`) the result
 * (`code`, `id_token`, `state`, and `user` on the first consent) to the Services
 * ID's registered return URL. The plugin only gets the result back when that
 * URL answers with a redirect to
 *
 *   intent://callback?<the posted fields>#Intent;package=<app id>;scheme=signinwithapple;end
 *
 * (sign_in_with_apple README, "Android"). Supabase's own `/auth/v1/callback`
 * cannot be that URL: it only completes flows Supabase started itself and
 * answers a foreign POST with `bad_oauth_callback` / "OAuth state parameter
 * missing", leaving the user on an error page with the app waiting forever.
 *
 * This module is pure so the tests drive it without binding a port.
 */

/** Android application id per Supabase project ref (flavor = project). */
export const ANDROID_PACKAGE_BY_PROJECT_REF: Record<string, string> = {
  vlmtsdzpnjnavdgytcmi: "com.milkman.mealvanaendurance.dev",
  wvmvsodrvbkxfydabqed: "com.milkman.mealvanaendurance",
};

const PROD_PACKAGE = "com.milkman.mealvanaendurance";

/**
 * The Android package the intent targets. `ANDROID_APP_PACKAGE` wins when set;
 * otherwise the project ref in `SUPABASE_URL` picks the flavor; prod otherwise.
 */
export function resolveAndroidPackage(env: {
  ANDROID_APP_PACKAGE?: string;
  SUPABASE_URL?: string;
}): string {
  const explicit = env.ANDROID_APP_PACKAGE?.trim();
  if (explicit) return explicit;
  const url = env.SUPABASE_URL ?? "";
  for (const [ref, pkg] of Object.entries(ANDROID_PACKAGE_BY_PROJECT_REF)) {
    if (url.includes(ref)) return pkg;
  }
  return PROD_PACKAGE;
}

/** Builds the `intent://` URL the plugin's callback activity listens for. */
export function buildIntentUrl(fields: URLSearchParams, androidPackage: string): string {
  return `intent://callback?${fields.toString()}` +
    `#Intent;package=${androidPackage};scheme=signinwithapple;end`;
}

/**
 * Reads Apple's callback fields: the form body of a POST (form_post), or the
 * query string of a GET (Apple's `query` response mode, and a hand test).
 */
export async function readCallbackFields(req: Request): Promise<URLSearchParams> {
  if (req.method === "POST") {
    const body = await req.text();
    return new URLSearchParams(body);
  }
  return new URL(req.url).searchParams;
}

/** The whole relay: Apple's callback in, a 303 to the Android intent out. */
export async function relayAppleCallback(
  req: Request,
  env: { ANDROID_APP_PACKAGE?: string; SUPABASE_URL?: string },
): Promise<Response> {
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }
  const fields = await readCallbackFields(req);
  const location = buildIntentUrl(fields, resolveAndroidPackage(env));
  return new Response(null, { status: 303, headers: { Location: location } });
}
