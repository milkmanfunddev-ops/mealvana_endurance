/**
 * Fake Sentry client for edge-function tests (ticket 12).
 *
 * Records every capture together with the isolation scope that was current
 * when it happened, so a test can assert "one capture, under its own scope".
 * Installed with `setSentryClientForTesting(fake)`.
 */
import type {
  CaptureContext,
  CheckIn,
  MonitorConfig,
  ScopeLike,
  SentryClientLike,
} from "./sentry.ts";

export interface FakeScope extends ScopeLike {
  id: number;
  tags: Record<string, string>;
  extras: Record<string, unknown>;
}

export interface Capture {
  kind: "exception" | "message";
  error?: unknown;
  message?: string;
  context?: CaptureContext;
  scope: FakeScope | null;
}

export class FakeSentry implements SentryClientLike {
  captures: Capture[] = [];
  breadcrumbs: Array<{ message?: string; level?: string; data?: Record<string, unknown> }> = [];
  checkIns: Array<CheckIn & { monitorConfig?: MonitorConfig }> = [];
  flushes = 0;
  inits: Record<string, unknown>[] = [];
  current: FakeScope | null = null;
  private nextScopeId = 1;
  private nextEventId = 1;

  init(options: Record<string, unknown>): void {
    this.inits.push(options);
  }

  withIsolationScope<T>(callback: (scope: ScopeLike) => T): T {
    const scope: FakeScope = {
      id: this.nextScopeId++,
      tags: {},
      extras: {},
      setTag(key, value) {
        this.tags[key] = value;
      },
      setExtra(key, value) {
        this.extras[key] = value;
      },
    };
    const previous = this.current;
    this.current = scope;
    const restore = () => {
      this.current = previous;
    };
    try {
      const result = callback(scope);
      if (result instanceof Promise) {
        return result.finally(restore) as unknown as T;
      }
      restore();
      return result;
    } catch (e) {
      restore();
      throw e;
    }
  }

  captureException(error: unknown, context?: CaptureContext): string {
    this.captures.push({ kind: "exception", error, context, scope: this.current });
    return `event-${this.nextEventId++}`;
  }

  captureMessage(message: string, context?: CaptureContext): string {
    this.captures.push({ kind: "message", message, context, scope: this.current });
    return `event-${this.nextEventId++}`;
  }

  addBreadcrumb(breadcrumb: { message?: string; level?: string; data?: Record<string, unknown> }): void {
    this.breadcrumbs.push(breadcrumb);
  }

  captureCheckIn(checkIn: CheckIn, monitorConfig?: MonitorConfig): string {
    this.checkIns.push({ ...checkIn, monitorConfig });
    return checkIn.checkInId ?? `checkin-${this.nextEventId++}`;
  }

  flush(_timeout?: number): Promise<boolean> {
    this.flushes++;
    return Promise.resolve(true);
  }

  reset(): void {
    this.captures = [];
    this.breadcrumbs = [];
    this.checkIns = [];
    this.flushes = 0;
  }
}

/**
 * Stop `serve(...)` / `Deno.serve(...)` from binding a port when a function's
 * index.ts is imported. The wrapper's registry is how tests reach handlers.
 */
export function stubServers(): void {
  // deno-lint-ignore no-explicit-any
  const d = Deno as any;
  if (d.__sentryTestStubbed) return;
  d.__sentryTestStubbed = true;
  const addr = { transport: "tcp", hostname: "127.0.0.1", port: 0 };
  d.serve = () => ({
    addr,
    finished: new Promise<void>(() => {}),
    ref() {},
    unref() {},
    shutdown: () => Promise.resolve(),
    [Symbol.asyncDispose]: () => Promise.resolve(),
  });
  d.listen = () => ({
    addr,
    rid: 0,
    accept: () => new Promise(() => {}),
    close() {},
    ref() {},
    unref() {},
    [Symbol.asyncIterator]: async function* () {},
    [Symbol.dispose]() {},
  });
}
