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
    .select("provider, data")
    .order("fetched_at", { ascending: true });
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const rows = (data ?? []).map((r) => ({
    provider: r.provider as string,
    payload: r.data as Json,
  }));
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
    stratum: n.stratum,
    optionalKeysInStratum: n.optionalKeysInStratum,
    exemplar: scrub(
      n.exemplar,
      censusFor(n.provider),
      newScrubContext(),
      keepEnumFor(n.provider),
    ),
  }));

  return new Response(
    JSON.stringify({ scanned: rows.length, exemplars }),
    { headers: { "Content-Type": "application/json" } },
  );
}));
