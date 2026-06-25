# Scheduled data refresh via Claude Routines

We schedule the data-refresh routines as **Claude Cloud Routines** — they run on
Anthropic infrastructure on a weekly schedule, autonomously, even when no machine
is on, and (unlike CI) they can do **web search**, so the events routine works too.

> The CLI `CronCreate`/`/loop` tools are session-only (they stop when the terminal
> closes) and auto-expire after 7 days — NOT used here. Cloud Routines are the
> always-on mechanism.

## How to create each routine
In `claude.ai/code` → **Routines → New routine** (or run `/schedule` in a session):
set the name, paste the prompt below, attach this repo, choose a **weekly** schedule,
and configure access (below). Min interval is 1 hour; weekly is plenty.

### Access the routine needs (one-time setup in the routine config)
A cloud routine **clones the repo fresh and cannot read local files/secrets**, so
provide credentials in the routine's environment/connectors:
- **Supabase** — the routines write to dev + prod. Provide either a Supabase MCP
  connector, or these as routine secrets: `SUPABASE_ACCESS_TOKEN`,
  `DEV_SUPABASE_SERVICE_ROLE_KEY`, `PROD_SUPABASE_SERVICE_ROLE_KEY`,
  and (optional) `USDA_API_KEY`. (Values: access token = same as the GitHub secret;
  service-role keys = `secrets/supabase_service_role_keys.md`.)
- The repo must be **pushed** so the routine can clone the feed scripts.
- Network: keep Trusted access (includes web search + package registries); add
  `thefeed.myshopify.com` and `*.supabase.co` if domain-restricted.

---

## Routine 1 — Feed catalog (weekly)
**Prompt:**
> Refresh the TheFeed product catalog for dev then prod. For each environment, set
> `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (dev: project `vlmtsdzpnjnavdgytcmi`;
> prod: `wvmvsodrvbkxfydabqed`) and `FDA_API_KEY=$USDA_API_KEY`, then:
> 1. `node scripts/update_catalog.js` — non-destructive import (UPSERT, preserves
>    classification + nutrition) + deactivation of products no longer in the feed,
>    guarded by a 10% anti-wipeout threshold. If you see "ANTI-WIPEOUT … Skipping",
>    STOP and report (likely a Shopify outage); do not continue to prod.
> 2. `supabase link --project-ref <ref>` then
>    `supabase db query --linked -f scripts/classify_unclassified_by_type.sql`.
> 3. Verify: 0 unclassified products and the existing 'claude' classification count
>    did not drop. Report counts. Flag any product whose Shopify type isn't mapped
>    in the SQL (needs a new mapping / Claude classification).
> Do dev, verify, then prod. Use `supabase db query --linked`, never `db push`.

(Full reference: `.claude/commands/refresh-feed.md`, `docs/technical/data-refresh-routines.md`.)

## Routine 2 — Events catalog (weekly)
**Prompt:** use the body of `.claude/commands/refresh-events.md` verbatim — it is a
complete, self-contained routine: open a run log in `events_refresh_runs`; do the
ROLLOVER pass (races whose latest date < today+90d → web-confirm next date → upsert);
do the DISCOVERY passes (major-races pass + ~40 bucket-rotation sweeps via broad
race-calendar web searches); upsert every event on the canonical key
`(lower(event_name), event_date, lower(coalesce(city,'')))` with a deterministic
`external_id`; confidence-gate (flag, don't write, anything unconfirmed); close the
run log. dev first, verify, then prod.

> Paste that file's content as the routine prompt (it's gitignored, so it must be
> copied into the routine, not referenced).

---

## Notes
- Both routines are dev-first → prod, idempotent (canonical-key / Shopify-id upserts),
  and log to `events_refresh_runs` / `catalog_sync_runs`.
- If you'd rather keep a human in the loop, set the routine to open a PR / post a
  summary instead of writing prod directly.
