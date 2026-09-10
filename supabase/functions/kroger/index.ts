import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { jsonResponse } from "../_shared/responses.ts";
import { authenticate } from "../_shared/vana/auth.ts";
import { requirePro } from "../_shared/vana/entitlement.ts";
import { config, KrogerClient } from "../_shared/kroger/client.ts";
import { KrogerError } from "../_shared/kroger/catalog.ts";
import { KrogerService } from "../_shared/kroger/service.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  const auth = await authenticate(req);
  if (!auth.ok) return jsonResponse({ error: auth.error }, 401);
  try {
    if (Number(req.headers.get("content-length") ?? 0) > 65536) {
      throw new KrogerError("invalid_body");
    }
    const raw = await req.text();
    if (raw.length > 65536) throw new KrogerError("invalid_body");
    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      throw new KrogerError("invalid_body");
    }
    if (!body || typeof body.action !== "string") {
      throw new KrogerError("invalid_body");
    }
    // Disconnect is available even after entitlement expiry or disabling the integration.
    if (body.action === "disconnect") {
      for (const table of ["kroger_connections", "kroger_oauth_sessions"]) {
        const { error } = await auth.v.admin.from(table).delete().eq(
          "user_id",
          auth.v.userId,
        );
        if (error) throw new KrogerError("storage_unavailable", 503);
      }
      return jsonResponse({ connected: false });
    }
    let cfg;
    try {
      cfg = config();
    } catch (e) {
      if (body.action === "status") {
        const connection = await auth.v.admin.from("kroger_connections").select(
          "environment",
        ).eq("user_id", auth.v.userId).maybeSingle();
        return jsonResponse({
          available: false,
          connected: !!connection.data,
          environment: connection.data?.environment,
          reason: "not_configured",
        });
      }
      throw e;
    }
    const pro = await requirePro(auth.v.admin, auth.v.userId);
    if (body.action === "status") {
      const status = await new KrogerService(
        auth.v.admin,
        auth.v.userId,
        new KrogerClient(cfg),
      ).run("status", body);
      return jsonResponse({
        ...status,
        available: pro.ok,
        reason: pro.ok ? null : pro.reason,
      });
    }
    // Coverage stays behind Pro with everything else. It is answerable without
    // a Kroger sign-in, which is what the feature needs; letting it past the
    // entitlement as well would put Kroger's application-wide daily Locations
    // budget — a resource every paying shopper shares — behind nothing but
    // `claim_kroger_request`, which is a 60-per-minute burst guard and not a
    // daily cap. A non-entitled shopper is told Pro is required instead, and
    // an unanswered Coverage check leaves the entry point in place.
    if (!pro.ok) return jsonResponse({ error: pro.reason }, 403);
    const limit = await auth.v.admin.rpc("claim_kroger_request", {
      p_user: auth.v.userId,
    });
    if (limit.error) throw new KrogerError("storage_unavailable", 503);
    if (!limit.data) throw new KrogerError("rate_limited", 429);
    const result = await new KrogerService(
      auth.v.admin,
      auth.v.userId,
      new KrogerClient(cfg),
    ).run(body.action, body);
    return jsonResponse(result);
  } catch (e) {
    // Never log upstream response bodies, authorization codes, or tokens.
    const error = e instanceof KrogerError
      ? e
      : new KrogerError("kroger_unavailable", 503);
    return jsonResponse({ error: error.code }, error.status);
  }
});
