/**
 * Sentry for Supabase Edge Functions (Deno runtime).
 *
 * Spec: .scratch/sentry/spec.md §"Edge functions" (ticket 12).
 *
 * Usage:
 *   import { initSentry, withSentry } from "../_shared/sentry.ts";
 *   initSentry();
 *   serve(withSentry("my-function", async (req) => { ... }));
 *
 * What the wrapper guarantees per request:
 *   - runs under its own `withIsolationScope` (an AsyncLocalStorage context
 *     strategy is installed below, because the Deno SDK ships the stack
 *     strategy, which leaks scope between concurrent requests in one isolate);
 *   - tags `edge_function` (the function name — Sentry drops a tag literally
 *     named `function`, proven on the first probe), `method`,
 *     `component: edge_function`;
 *   - captures an exception that escapes the handler and answers 500;
 *   - flushes before returning so the isolate can be recycled safely.
 *
 * Environment: `SENTRY_ENVIRONMENT` (edge-dev / edge-prod). No DSN → every
 * call is a no-op; functions never fail because Sentry is unconfigured.
 *
 * Testing: `setSentryClientForTesting(fake)` swaps the SDK for a fake that
 * records captures; `wrappedHandlers()` lists every handler registered through
 * `withSentry` so a test can drive them without binding a port.
 */

import * as RealSentry from "npm:@sentry/deno@^8.55.2";
import {
  getDefaultCurrentScope,
  getDefaultIsolationScope,
  setAsyncContextStrategy,
} from "npm:@sentry/core@^8.55.2";
import { AsyncLocalStorage } from "node:async_hooks";

// ---------------------------------------------------------------------------
// Client surface (real SDK or a test fake)
// ---------------------------------------------------------------------------

export type SeverityLevel = "fatal" | "error" | "warning" | "log" | "info" | "debug";

export interface ScopeLike {
  setTag(key: string, value: string): unknown;
  setExtra(key: string, value: unknown): unknown;
}

export interface CaptureContext {
  level?: SeverityLevel;
  tags?: Record<string, string>;
  extra?: Record<string, unknown>;
}

export interface CheckIn {
  checkInId?: string;
  monitorSlug: string;
  status: "in_progress" | "ok" | "error";
}

export interface MonitorConfig {
  schedule: { type: "crontab"; value: string };
  checkinMargin?: number;
  maxRuntime?: number;
  timezone?: string;
}

export interface SentryClientLike {
  init(options: Record<string, unknown>): void;
  withIsolationScope<T>(callback: (scope: ScopeLike) => T): T;
  captureException(error: unknown, context?: CaptureContext): string;
  captureMessage(message: string, context?: CaptureContext): string;
  addBreadcrumb(breadcrumb: {
    category?: string;
    message?: string;
    level?: SeverityLevel;
    data?: Record<string, unknown>;
  }): void;
  captureCheckIn(checkIn: CheckIn, monitorConfig?: MonitorConfig): string;
  flush(timeout?: number): Promise<boolean>;
}

const realClient = RealSentry as unknown as SentryClientLike;
let client: SentryClientLike = realClient;
let _initialized = false;

/** Swap the SDK for a fake (tests). `null` restores the real SDK. */
export function setSentryClientForTesting(fake: SentryClientLike | null): void {
  client = fake ?? realClient;
  _initialized = false;
}

// ---------------------------------------------------------------------------
// Async context: one isolation scope per request, even when requests overlap
// ---------------------------------------------------------------------------

type Scopes = { scope: ReturnType<typeof getDefaultCurrentScope>; isolationScope: ReturnType<typeof getDefaultIsolationScope> };
const scopeStorage = new AsyncLocalStorage<Scopes>();

function currentScopes(): Scopes {
  return scopeStorage.getStore() ?? {
    scope: getDefaultCurrentScope(),
    isolationScope: getDefaultIsolationScope(),
  };
}

setAsyncContextStrategy({
  withScope: (callback) => {
    const s = currentScopes();
    const next = { scope: s.scope.clone(), isolationScope: s.isolationScope };
    return scopeStorage.run(next, () => callback(next.scope));
  },
  withSetScope: (scope, callback) => {
    const s = currentScopes();
    return scopeStorage.run({ scope, isolationScope: s.isolationScope }, () => callback(scope));
  },
  withIsolationScope: (callback) => {
    const s = currentScopes();
    const next = { scope: s.scope.clone(), isolationScope: s.isolationScope.clone() };
    return scopeStorage.run(next, () => callback(next.isolationScope));
  },
  withSetIsolationScope: (isolationScope, callback) => {
    const s = currentScopes();
    return scopeStorage.run({ scope: s.scope.clone(), isolationScope }, () => callback(isolationScope));
  },
  getCurrentScope: () => currentScopes().scope,
  getIsolationScope: () => currentScopes().isolationScope,
});

// ---------------------------------------------------------------------------
// init
// ---------------------------------------------------------------------------

/**
 * Initialise once per cold start from SENTRY_DSN / SENTRY_ENVIRONMENT /
 * SENTRY_RELEASE. Without a DSN the SDK is never initialised and every
 * capture is a safe no-op.
 */
export function initSentry(): void {
  if (_initialized) return;
  _initialized = true;

  const dsn = Deno.env.get("SENTRY_DSN") ?? "";
  if (!dsn) {
    console.warn("[sentry] SENTRY_DSN unset — edge errors are not reported");
    return;
  }

  client.init({
    dsn,
    environment: Deno.env.get("SENTRY_ENVIRONMENT") ?? "edge-dev",
    release: Deno.env.get("SENTRY_RELEASE") ?? undefined,
    // Errors only. Transactions cost quota and nothing reads them.
    tracesSampleRate: 0,
    initialScope: {
      tags: {
        component: "edge_function",
        region: Deno.env.get("SB_REGION") ?? "unknown",
      },
    },
  });
}

// ---------------------------------------------------------------------------
// Capture helpers (used by responses.ts and by catch blocks in functions)
// ---------------------------------------------------------------------------

/**
 * Report an error that a catch block would otherwise only log. Keeps the
 * console line (Supabase logs stay useful) and sends the event under the
 * current request's scope. Safe to call from background tasks: the flush is
 * handed to EdgeRuntime.waitUntil when it exists.
 */
export function captureEdgeError(error: unknown, context?: CaptureContext & { message?: string }): string {
  const { message, ...rest } = context ?? {};
  if (message) console.error(`[sentry] ${message}:`, error);
  const err = error instanceof Error ? error : new Error(describe(error));
  const extra = { ...(rest.extra ?? {}) };
  if (!(error instanceof Error)) extra.raw_error = error;
  if (message) extra.message = message;
  const id = client.captureException(err, { ...rest, extra });
  scheduleFlush();
  return id;
}

/**
 * Report a condition without an error object (a 5xx the code decided on, a
 * non-ok upstream status). Prints one console line so the Supabase log keeps
 * its record of the failure.
 */
export function captureEdgeMessage(message: string, context?: CaptureContext): string {
  console.error(`[sentry] ${message}`, context?.extra ?? "");
  const id = client.captureMessage(message, { level: "error", ...context });
  scheduleFlush();
  return id;
}

/** Record a non-fatal step (a 4xx answer, a skipped branch) on the trail. */
export function edgeBreadcrumb(message: string, data?: Record<string, unknown>, level: SeverityLevel = "warning"): void {
  client.addBreadcrumb({ category: "edge", message, level, data });
}

/** Cron monitor check-in; returns the check-in id to pass back on completion. */
export function edgeCheckIn(checkIn: CheckIn, monitorConfig?: MonitorConfig): string {
  const id = client.captureCheckIn(checkIn, monitorConfig);
  scheduleFlush();
  return id;
}

export async function flushSentry(timeoutMs = 2000): Promise<void> {
  try {
    await client.flush(timeoutMs);
  } catch (e) {
    console.error("[sentry] flush failed:", e);
  }
}

function scheduleFlush(): void {
  // deno-lint-ignore no-explicit-any
  const rt = (globalThis as any).EdgeRuntime;
  const p = flushSentry();
  if (rt?.waitUntil) rt.waitUntil(p);
}

function describe(value: unknown): string {
  if (typeof value === "string") return value;
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

// ---------------------------------------------------------------------------
// Probe: a deliberate throw behind a header no client sends
// ---------------------------------------------------------------------------

/**
 * `x-sentry-probe: <SENTRY_PROBE_TOKEN>` makes the wrapper throw before the
 * handler runs, so the pipeline can be proven end to end on a deployed
 * function. Inert unless the SENTRY_PROBE_TOKEN secret is set (dev only).
 */
export const PROBE_HEADER = "x-sentry-probe";

export class SentryProbeError extends Error {
  constructor(functionName: string) {
    super(`Sentry probe: deliberate throw in ${functionName}`);
    this.name = "SentryProbeError";
  }
}

function probeRequested(req: Request): boolean {
  const token = Deno.env.get("SENTRY_PROBE_TOKEN") ?? "";
  if (!token) return false;
  return req.headers.get(PROBE_HEADER) === token;
}

// ---------------------------------------------------------------------------
// withSentry
// ---------------------------------------------------------------------------

export type Handler = (req: Request) => Promise<Response> | Response;

const registry = new Map<string, Handler>();

/** Every handler registered through `withSentry` in this isolate (tests). */
export function wrappedHandlers(): ReadonlyMap<string, Handler> {
  return registry;
}

/**
 * Wrap a function's handler. `functionName` is the folder name under
 * supabase/functions/ — a test asserts the two agree.
 *
 * The one-argument form exists only so FROZEN legacy folders (never
 * redeployed, never edited without a ruling) keep compiling against this
 * module; nothing live uses it.
 */
export function withSentry(functionName: string, handler: Handler): Handler;
export function withSentry(handler: Handler): Handler;
export function withSentry(nameOrHandler: string | Handler, maybeHandler?: Handler): Handler {
  const functionName = typeof nameOrHandler === "string" ? nameOrHandler : "unnamed";
  const handler = typeof nameOrHandler === "string" ? maybeHandler! : nameOrHandler;
  const wrapped: Handler = (req: Request) => {
    initSentry();
    return client.withIsolationScope(async (scope) => {
      const method = req.method;
      let path = req.url;
      try {
        path = new URL(req.url).pathname;
      } catch {
        // keep the raw url
      }
      scope.setTag("edge_function", functionName);
      scope.setTag("method", method);
      scope.setTag("component", "edge_function");
      scope.setExtra("path", path);
      try {
        if (probeRequested(req)) throw new SentryProbeError(functionName);
        return await handler(req);
      } catch (error) {
        console.error(`[SENTRY_WRAPPER] Unhandled error in ${functionName} ${method} ${path}:`, error);
        client.captureException(error, {
          tags: { edge_function: functionName, method, component: "edge_function" },
          extra: { path },
        });
        return new Response(
          JSON.stringify({ success: false, error: String(error) }),
          { status: 500, headers: { "Content-Type": "application/json" } },
        );
      } finally {
        await flushSentry();
      }
    });
  };
  registry.set(functionName, wrapped);
  return wrapped;
}
