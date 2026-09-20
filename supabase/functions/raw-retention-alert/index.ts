/**
 * raw-retention-alert — email leg of the two-sided retention meter
 * (real-payload-corpus@v1, lifecycle.md L-7 item 4).
 *
 * Called by the database itself: the pg_cron sweep wrapper
 * (raw_retention_sweep_and_notify) posts the audit row here via pg_net ONLY
 * when an alert direction fired (over-size or under-arrival). Delivery is
 * fire-and-forget at the pg_net layer, so this function is a convenience
 * channel — the audit row is the record, and the dead-man Sentry check plus
 * qa's query-ledger retention arm do not depend on it.
 *
 * Auth: pg_net cannot mint Supabase JWTs, so the gateway check is disabled
 * (config.toml verify_jwt=false, same as revenuecat-webhook) and the caller
 * presents a shared secret in x-alert-token, checked against the
 * RAW_RETENTION_ALERT_TOKEN function secret. The token also lives in Vault
 * so the SQL wrapper can send it.
 *
 * Email mechanics follow send-nutrition-plan-email (Resend, RESEND_API_KEY).
 * Recipient comes from RAW_RETENTION_ALERT_TO (no default — an unset
 * recipient is a deploy mistake worth a loud 500, never a silent drop:
 * silence is the failure mode this whole meter exists to kill).
 */
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const ALERT_TOKEN = Deno.env.get("RAW_RETENTION_ALERT_TOKEN") ?? "";
const ALERT_TO = Deno.env.get("RAW_RETENTION_ALERT_TO") ?? "";
const FROM_EMAIL = "support@mealvana.io";

initSentry();

function gb(bytes: number): string {
  return (bytes / 1073741824).toFixed(2) + " GB";
}

serve(withSentry(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  if (!ALERT_TOKEN || req.headers.get("x-alert-token") !== ALERT_TOKEN) {
    return new Response("unauthorized", { status: 401 });
  }
  if (!ALERT_TO) {
    console.error("RAW_RETENTION_ALERT_TO not configured");
    return new Response(
      JSON.stringify({ success: false, error: "recipient not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const audit = await req.json();
  const env = Deno.env.get("SUPABASE_URL")?.includes("vlmtsdzpnjnavdgytcmi")
    ? "DEV"
    : "PROD";
  const flows: string[] = audit.underarrival_alerts ?? [];
  const oversize: boolean = audit.oversize_alert === true;

  const parts: string[] = [];
  if (oversize) {
    parts.push(
      `<p><b>Over-size:</b> raw tables at ${gb(audit.raw_total_bytes ?? 0)} ` +
        `(database ${gb(audit.db_total_bytes ?? 0)}). The 90-day L-7 ruling ` +
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
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [ALERT_TO],
      subject,
      html,
    }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    console.error(`Resend rejected the alert email: ${resp.status} ${detail}`);
    return new Response(
      JSON.stringify({ success: false, error: `resend ${resp.status}` }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
}));
