/**
 * corpus-export — novelty-gated, server-side-scrubbed exemplar export
 * (real-payload-corpus@v1, L-7 item 5).
 *
 * POST { known: string[] }  →  { exemplars: [...] }
 *
 * Reads captured raw payloads (service role), runs the novelty sampler, and
 * SCRUBS every novel exemplar before it leaves the server — raw never leaves
 * un-scrubbed (the intake's standing boundary). The caller (qa
 * scripts/corpus-export.sh) owns the append-only registry: it sends the
 * fingerprint ids it already holds and writes only what comes back.
 *
 * Auth: shared secret in x-export-token vs CORPUS_EXPORT_TOKEN (verify_jwt
 * off in config.toml — the caller is a repo script, not an app session).
 */
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { selectNovelExemplars } from "../_shared/corpus/sampler.ts";
import {
  FS_KEEP_ENUM,
  FS_SCRUB_CENSUS,
  GARMIN_KEEP_ENUM,
  GARMIN_SCRUB_CENSUS,
  type KeepEnum,
  newScrubContext,
  scrub,
  type ScrubCensus,
  TP_KEEP_ENUM,
  TP_SCRUB_CENSUS,
} from "../_shared/corpus/scrub.ts";
import type { Json } from "../_shared/corpus/fingerprint.ts";

const EXPORT_TOKEN = Deno.env.get("CORPUS_EXPORT_TOKEN") ?? "";

function censusFor(provider: string): ScrubCensus {
  if (provider === "training_peaks") return TP_SCRUB_CENSUS;
  if (provider === "final_surge") return FS_SCRUB_CENSUS;
  return GARMIN_SCRUB_CENSUS;
}

/**
 * Provenance is keyed on SOURCE MATERIAL — the environment a payload came
 * from and how its values arose — resolved per raw row from the account whose
 * integration produced it. NOT on provider: the moment TrainingPeaks gains
 * real-account material (the next thing this corpus ingests), a
 * provider-keyed stamp would label it "sandbox, hand-typed" and be silently
 * wrong. Unknown source material returns null and the caller refuses to
 * write — an exemplar with an inaccurate stamp is worse than no exemplar.
 *
 * Account ids stay SERVER-SIDE: this maps them to a label, and only the
 * label crosses the wire.
 */
const DEV_REF = "vlmtsdzpnjnavdgytcmi";

/**
 * Source-material stamps, resolved SERVER-SIDE so account ids never cross
 * the wire. Lookup is specific-then-class, and unknown material returns null
 * so the caller refuses to write — an exemplar with an inaccurate stamp is
 * worse than no exemplar.
 */
const SOURCE_MATERIAL: Record<string, string> = {
  // Specific (dev provider_raw_payloads): the two known accounts.
  "dev|provider_raw_payloads|c2c7e005|training_peaks":
    "TP sandbox host, specimens hand-typed for the corpus (2026-09-20)",
  "dev|provider_raw_payloads|607f9dd5|final_surge":
    "real account (owner's own, promoted by ruling 2026-09-20), " +
    "fail-safe scrub under the default-deny standard (@v1.1)",
  // Class (dev Garmin wing): several athletes, so the stamp describes the
  // CLASS of material rather than enumerating accounts — enumerating them
  // would drag identity into the very files that exist to avoid it.
  "dev|garmin_health_data|*|*":
    "real-account (dev Garmin athletes), promoted by ruling 2026-09-20",
  // Class (prod): every prod athlete is the same class of material.
  "prod|provider_raw_payloads|*|*":
    "real-account (prod), promoted by ruling 2026-09-20",
  "prod|garmin_health_data|*|*":
    "real-account (prod), promoted by ruling 2026-09-20",
};

function envName(): string {
  return (Deno.env.get("SUPABASE_URL") ?? "").includes(DEV_REF) ? "dev" : "prod";
}

function sourceMaterialFor(
  table: string,
  userId: string | undefined,
  provider: string,
): string | null {
  const env = envName();
  const u = userId ? userId.slice(0, 8) : "";
  return SOURCE_MATERIAL[`${env}|${table}|${u}|${provider}`] ??
    SOURCE_MATERIAL[`${env}|${table}|*|*`] ?? null;
}

function keepEnumFor(provider: string): KeepEnum {
  if (provider === "training_peaks") return TP_KEEP_ENUM;
  if (provider === "final_surge") return FS_KEEP_ENUM;
  return GARMIN_KEEP_ENUM;
}

initSentry();

serve(withSentry(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  if (!EXPORT_TOKEN || req.headers.get("x-export-token") !== EXPORT_TOKEN) {
    return new Response("unauthorized", { status: 401 });
  }

  // `rescrubIds` is the sanctioned frozen-exemplar correction path (the
  // intake allows touching an exemplar only "to correct it … or fix a
  // discovered leak"): it re-emits EXACTLY those fingerprints, ignoring the
  // novelty gate, so a caller can overwrite known-bad files in place.
  const { known = [], rescrubIds = [] } = await req.json().catch(() => ({}));
  const rescrub: string[] = rescrubIds;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data, error } = await supabase
    .from("provider_raw_payloads")
    .select("user_id, provider, data")
    .order("fetched_at", { ascending: true });
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const rows: {
    provider: string;
    userId: string;
    payload: Json;
    channel?: string;
    table: string;
  }[] = (data ?? []).map((r) => ({
    provider: r.provider as string,
    userId: r.user_id as string,
    payload: r.data as Json,
    table: "provider_raw_payloads",
  }));

  // DI-28: the Garmin wing. Garmin raw lives in garmin_health_data's generic
  // (data_type, data jsonb) store rather than provider_raw_payloads, so it is
  // scanned separately and each data_type is its own capture channel.
  const GARMIN_TYPES = [
    "activity_raw",
    "activity_detail_raw",
    "activity_detail_full",
  ];
  const { data: gData, error: gError } = await supabase
    .from("garmin_health_data")
    .select("user_id, data_type, data")
    .in("data_type", GARMIN_TYPES)
    .order("created_at", { ascending: true });
  if (gError) {
    return new Response(JSON.stringify({ error: gError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
  for (const r of gData ?? []) {
    rows.push({
      provider: "garmin",
      userId: r.user_id as string,
      payload: r.data as Json,
      channel: `garmin/${r.data_type}`,
      table: "garmin_health_data",
    });
  }
  const novel = rescrub.length > 0
    ? (await selectNovelExemplars(rows, [])).filter((n) =>
      rescrub.includes(n.fingerprintId)
    )
    : await selectNovelExemplars(rows, known);

  // Scrub server-side; one context per exemplar file — ids stay referentially
  // consistent WITHIN an exemplar (parent/child), while separate exemplars
  // share nothing (an exemplar file must stand alone, frozen).
  const exemplars = novel.map((n) => ({
    fingerprintId: n.fingerprintId,
    provider: n.provider,
    sourceMaterial: sourceMaterialFor(
      n.table ?? "provider_raw_payloads",
      n.userId,
      n.provider,
    ),
    stratum: n.stratum,
    optionalKeysInStratum: n.optionalKeysInStratum,
    ...(() => {
      // ONE context for the exemplar and its companions, so the synthetic
      // ids resolve WITHIN the file — that is what makes the embedded set
      // coherent rather than merely co-located.
      const ctx = newScrubContext();
      const census = censusFor(n.provider);
      const keep = keepEnumFor(n.provider);
      const exemplar = scrub(n.exemplar, census, ctx, keep);
      const linkedCompanions = n.companions.map((c) =>
        scrub(c, census, ctx, keep)
      );
      return linkedCompanions.length > 0
        ? { exemplar, linkedCompanions }
        : { exemplar };
    })(),
  }));

  return new Response(
    JSON.stringify({ scanned: rows.length, exemplars }),
    { headers: { "Content-Type": "application/json" } },
  );
}));
