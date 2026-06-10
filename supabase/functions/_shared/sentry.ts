/**
 * Sentry integration for Supabase Edge Functions (Deno runtime).
 *
 * Usage:
 *   import { initSentry, withSentry } from "../_shared/sentry.ts";
 *   initSentry();
 *   serve(withSentry(async (req) => { ... }));
 *
 * If SENTRY_DSN is not set, all calls are no-ops — functions never crash
 * because of missing Sentry config.
 */

// @sentry/deno via esm.sh — consistent with this project's CDN import convention.
// Pin to a stable 8.x release that matches the edge-function runtime.
import * as Sentry from "https://esm.sh/@sentry/deno@8.53.0";

// ---------------------------------------------------------------------------
// Internal state
// ---------------------------------------------------------------------------

let _initialized = false;

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

/**
 * Initialize Sentry once per cold-start.
 * Reads SENTRY_DSN and SENTRY_ENVIRONMENT from Deno environment.
 * If DSN is absent or empty the SDK is never initialized and all subsequent
 * calls are safe no-ops (Sentry SDK guards itself when DSN is falsy).
 */
export function initSentry(): void {
  if (_initialized) return;
  _initialized = true;

  const dsn = Deno.env.get("SENTRY_DSN") ?? "";
  if (!dsn) {
    // No DSN configured — edge functions operate without error reporting.
    // This is intentional for local dev and CI where the secret may not be set.
    return;
  }

  const environment = Deno.env.get("SENTRY_ENVIRONMENT") ?? "edge-dev";

  Sentry.init({
    dsn,
    environment,
    // Capture all errors, sample 10 % of transactions (breadcrumbs only).
    tracesSampleRate: 0.1,
    // Keep the edge function payload lean — no source-map upload needed here.
    release: Deno.env.get("SENTRY_RELEASE") ?? undefined,
  });
}

// ---------------------------------------------------------------------------
// withSentry
// ---------------------------------------------------------------------------

type Handler = (req: Request) => Promise<Response>;

/**
 * Wraps a Deno HTTP handler so that any uncaught exception is captured by
 * Sentry before a 500 response is returned.
 *
 * Response shape on unhandled error matches the project's serverError() helper
 * so callers see a consistent JSON body:
 *   { "success": false, "error": "<message>" }
 *
 * The original handler's own error handling is NOT changed — this only fires
 * when an exception escapes the handler entirely (i.e. a genuine bug).
 *
 * Sentry.flush(2000) is awaited before returning so the event is delivered
 * before the Deno isolate is recycled.
 */
export function withSentry(handler: Handler): Handler {
  return async (req: Request): Promise<Response> => {
    // Ensure Sentry is initialised on every cold-start (idempotent).
    initSentry();

    try {
      return await handler(req);
    } catch (error) {
      const url = req.url;
      const method = req.method;

      console.error(`[SENTRY_WRAPPER] Unhandled error in ${method} ${url}:`, error);

      Sentry.captureException(error, {
        tags: {
          component: "edge_function",
          http_method: method,
        },
        extra: {
          url,
        },
      });

      // Best-effort flush — 2 s budget so Deno doesn't kill the isolate
      // before the event is sent.
      await Sentry.flush(2000);

      return new Response(
        JSON.stringify({ success: false, error: String(error) }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }
  };
}
