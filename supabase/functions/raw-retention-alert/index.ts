/**
 * raw-retention-alert — the sweep's reporting leg
 * (real-payload-corpus@v1, lifecycle.md L-7 item 4; Sentry ticket 12).
 *
 * Called by the database itself: the pg_cron sweep wrapper
 * (raw_retention_sweep_and_notify) posts here via pg_net on EVERY run since
 * migration 20261006120000 — before that, only when an alert direction fired.
 * Two jobs per call:
 *
 *   1. Sentry cron check-in for monitor `raw-retention-sweep` (schedule
 *      17 3 * * *, 30-minute grace): `in_progress` on entry, then `ok` or
 *      `error`. A night with no check-in means the scheduler, the SQL, or
 *      pg_net died — the dead-man signal the audit row alone cannot raise.
 *      Gated by SENTRY_CRON_MONITORS=1 because the free plan carries one
 *      monitor and it is spent on prod (research/sentry-plan-and-supabase.md).
 *   2. The alert email (Resend, RESEND_API_KEY), only when an alert fired.
 *
 * Body (new shape): { audit, sweep_status: 'ok'|'error', sweep_error?, alerted }
 * Body (legacy shape, pre-migration callers): the audit row itself, which
 * always meant "alert fired".
 *
 * Auth: pg_net cannot mint Supabase JWTs, so the gateway check is disabled
 * (config.toml verify_jwt=false, same as revenuecat-webhook) and the caller
 * presents a shared secret in x-alert-token, checked against the
 * RAW_RETENTION_ALERT_TOKEN function secret. The token also lives in Vault
 * so the SQL wrapper can send it.
 *
 * Recipient comes from RAW_RETENTION_ALERT_TO (no default — an unset
 * recipient is a deploy mistake worth a loud 500, never a silent drop:
 * silence is the failure mode this whole meter exists to kill).
 */
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  captureEdgeError,
  captureEdgeMessage,
  edgeBreadcrumb,
  edgeCheckIn,
  initSentry,
  withSentry,
} from "../_shared/sentry.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const ALERT_TOKEN = Deno.env.get("RAW_RETENTION_ALERT_TOKEN") ?? "";
const ALERT_TO = Deno.env.get("RAW_RETENTION_ALERT_TO") ?? "";
const FROM_EMAIL = "support@mealvana.io";

export const MONITOR_SLUG = "raw-retention-sweep";
export const MONITOR_CONFIG = {
  schedule: { type: "crontab" as const, value: "17 3 * * *" },
  checkinMargin: 30, // minutes of grace before a missed check-in alerts
  maxRuntime: 30,
  timezone: "UTC",
};

initSentry();

function gb(bytes: number): string {
  return (bytes / 1073741824).toFixed(2) + " GB";
}

type SweepReport = {
  audit: Record<string, unknown>;
  sweepStatus: "ok" | "error";
  sweepError?: string;
  alerted: boolean;
};

/** Accept both the post-migration envelope and the legacy bare audit row. */
export function parseSweepReport(body: Record<string, unknown>): SweepReport {
  if (body && ("sweep_status" in body || "alerted" in body || typeof body.audit === "object")) {
    const audit = (body.audit && typeof body.audit === "object" ? body.audit : {}) as Record<string, unknown>;
    return {
      audit,
      sweepStatus: body.sweep_status === "error" ? "error" : "ok",
      sweepError: typeof body.sweep_error === "string" ? body.sweep_error : undefined,
      alerted: body.alerted === true || alertFired(audit),
    };
  }
  return { audit: body ?? {}, sweepStatus: "ok", alerted: true };
}

function alertFired(audit: Record<string, unknown>): boolean {
  const flows = audit.underarrival_alerts;
  return audit.oversize_alert === true || (Array.isArray(flows) && flows.length > 0);
}

function cronMonitorsEnabled(): boolean {
  return Deno.env.get("SENTRY_CRON_MONITORS") === "1";
}

function checkIn(status: "in_progress" | "ok" | "error", checkInId?: string): string | undefined {
  if (!cronMonitorsEnabled()) return undefined;
  return edgeCheckIn({ monitorSlug: MONITOR_SLUG, status, checkInId }, MONITOR_CONFIG);
}

function jsonBody(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sendAlertEmail(audit: Record<string, unknown>): Promise<Response | null> {
  const env = Deno.env.get("SUPABASE_URL")?.includes("vlmtsdzpnjnavdgytcmi")
    ? "DEV"
    : "PROD";
  const flows = (audit.underarrival_alerts ?? []) as string[];
  const oversize = audit.oversize_alert === true;

  const parts: string[] = [];
  if (oversize) {
    parts.push(
      `<p><b>Over-size:</b> raw tables at ${gb(Number(audit.raw_total_bytes ?? 0))} ` +
        `(database ${gb(Number(audit.db_total_bytes ?? 0))}). The 90-day L-7 ruling ` +
        `asked to be re-evaluated at this size.</p>`,
    );
  }
  if (flows.length > 0) {
    parts.push(
      `<p><b>Under-arrival:</b> expected flow(s) produced zero/few rows in ` +
        `their window while their precondition held: ` +
        `<code>${flows.join(", ")}</code>. A silently-broken sync looks ` +
        `exactly like this — last_sync_status will still say success.</p>`,
    );
  }

  const subject =
    `[Mealvana ${env}] raw-retention alert: ` +
    [oversize ? "over-size" : "", flows.length ? `${flows.length} flow(s) dry` : ""]
      .filter(Boolean)
      .join(" + ");

  const html = `<html><body style="font-family:-apple-system,Segoe UI,Arial,sans-serif;max-width:600px">
    <h3>Raw-retention sweep alert (${env})</h3>
    ${parts.join("\n")}
    <p>Sweep at <code>${audit.swept_at}</code> · counts
    <code>${JSON.stringify(audit.row_counts)}</code> · purged
    <code>${JSON.stringify(audit.purged)}</code></p>
    <p style="color:#888">Contract: lifecycle.md L-7 item 4 (real-payload-corpus@v1).
    Read on demand: qa/scripts/query-ledger.sh retention.</p>
  </body></html>`;

  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: FROM_EMAIL, to: [ALERT_TO], subject, html }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    captureEdgeMessage(`Resend rejected the raw-retention alert email: ${resp.status}`, {
      extra: { status: resp.status, detail, audit_id: audit.id },
    });
    return jsonBody({ success: false, error: `resend ${resp.status}` }, 502);
  }
  return null;
}

serve(withSentry("raw-retention-alert", async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  if (!ALERT_TOKEN || req.headers.get("x-alert-token") !== ALERT_TOKEN) {
    edgeBreadcrumb("raw-retention-alert: bad or missing x-alert-token");
    return new Response("unauthorized", { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (e) {
    captureEdgeError(e, { message: "raw-retention-alert: body is not JSON" });
    return jsonBody({ success: false, error: "invalid json" }, 400);
  }
  const report = parseSweepReport(body);

  const checkInId = checkIn("in_progress");
  let outcome: "ok" | "error" = report.sweepStatus;

  try {
    if (report.sweepStatus === "error") {
      captureEdgeMessage(`raw_retention_sweep failed: ${report.sweepError ?? "unknown"}`, {
        extra: { audit: report.audit },
      });
      return jsonBody({ success: true, sweep: "error", alerted: false });
    }

    if (!report.alerted) {
      return jsonBody({ success: true, sweep: "ok", alerted: false });
    }

    if (!ALERT_TO) {
      outcome = "error";
      captureEdgeMessage("RAW_RETENTION_ALERT_TO not configured — alert email dropped", {
        extra: { audit_id: report.audit.id },
      });
      return jsonBody({ success: false, error: "recipient not configured" }, 500);
    }

    const failure = await sendAlertEmail(report.audit);
    if (failure) {
      outcome = "error";
      return failure;
    }
    return jsonBody({ success: true, sweep: "ok", alerted: true });
  } catch (e) {
    outcome = "error";
    throw e; // the wrapper captures and answers 500
  } finally {
    checkIn(outcome, checkInId);
  }
}));
