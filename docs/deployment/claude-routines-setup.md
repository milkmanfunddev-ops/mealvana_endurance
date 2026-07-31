# Weekly data-refresh via Claude Routines — DO-THIS guide

This sets up two always-on weekly **Claude Cloud Routines** that keep the data fresh:
- **Events** — discovers/rolls over marathons, halfs, 10K/5K, triathlons, etc. into
  `public_events`.
- **Feed** — keeps `catalog_products`/`catalog_variants` current with TheFeed.

They run on Anthropic's infrastructure (on even when your machine is off), weekly,
with web search.

---

## ⚠️ Confirmation: this part requires YOU — there is no other way

I (the agent in your terminal) **cannot create these routines for you, and there is
no workaround**:
- There is **no API/tool** I can call to create a Claude Cloud Routine. I checked
  every tool available to me — the only schedulers I have (`CronCreate`/`/loop`) are
  **session-only**: they stop the moment this terminal closes and expire after 7
  days, so they cannot be an always-on weekly schedule.
- Cloud routines are created **only** in a surface I can't drive: the
  **`claude.ai/code` web UI**, the **Claude Desktop app**, or the **`/schedule`**
  command you type yourself in a Claude session.
- A cloud routine **clones the repo fresh and cannot read your local files or
  secrets**, so the credentials below must be added **by you** in the routine's
  settings.

Everything that *can* be prepared in code is done (scripts, SQL, prompts). What's
left is genuinely yours: paste the prompts, add credentials, set the schedule.

---

## Prerequisites (one-time)

1. **Push `develop`** to GitHub. The **Feed** routine runs repo scripts, so it must
   be able to clone them. (The **Events** routine's prompt is self-contained and
   does NOT need the repo — you can set it up even before pushing.)
2. **Give the routines Supabase access.** Pick ONE:
   - **Easiest — Supabase MCP connector:** connect Supabase in `claude.ai` settings →
     Connectors, then enable it on each routine. The routine writes via MCP.
   - **Or routine secrets** (Environment variables on the routine):
     - `SUPABASE_ACCESS_TOKEN` — same value as your GitHub secret of that name.
     - `DEV_SUPABASE_SERVICE_ROLE_KEY`, `PROD_SUPABASE_SERVICE_ROLE_KEY` — from
       `secrets/supabase_service_role_keys.md`.
     - `USDA_API_KEY` — from `.env` (optional; enables feed nutrition enrichment).
   - Dev project ref = `vlmtsdzpnjnavdgytcmi`; prod ref = `wvmvsodrvbkxfydabqed`.

---

## Step 1 — Create the EVENTS routine

`claude.ai/code` → **Routines → New routine** (or type `/schedule` in a session):
- **Name:** `Weekly events refresh`
- **Schedule:** Weekly (e.g. Monday 09:17).
- **Repository:** none required (the prompt is self-contained). Attaching the repo
  is fine too.
- **Supabase access:** MCP connector or the secrets above.
- **Prompt:** paste this verbatim ⤵️

```
You are the events refresh routine for the Mealvana "public_events" race catalog
(Supabase). Run against DEV (project vlmtsdzpnjnavdgytcmi) first; after it verifies,
repeat on PROD (project wvmvsodrvbkxfydabqed). Use the Supabase MCP connector if
present; otherwise install the Supabase CLI and run SQL with:
  supabase db query --linked   (after: supabase link --project-ref <ref>, using
  SUPABASE_ACCESS_TOKEN). Never use `supabase db push`.

Tables: public_events has a UNIQUE index public_events_canonical_key_uniq on
(lower(event_name), event_date, lower(coalesce(city,''))) — that is the canonical
identity of a race occurrence. There is a run-log table events_refresh_runs and a
coverage ledger events_coverage(bucket_key, state, category, last_swept_at,
last_found_count).

Do this:
1. Open a run log: INSERT INTO events_refresh_runs (status, mode) VALUES
   ('running','both') RETURNING id;  (keep the id).

2. ROLLOVER. Find recurring races about to leave the search window (search filters
   event_date >= today):
     SELECT event_name, city, state, event_subtype, max(event_date) latest
     FROM public_events GROUP BY 1,2,3,4 HAVING max(event_date) < (now()::date + INTERVAL '90 days')
     ORDER BY latest;
   For each, web-search the OFFICIAL race site, confirm the next occurrence's date(s)
   and start time, and upsert (step 5). Record the source URL. If you cannot confirm
   a date, do NOT guess — increment events_flagged and note it.

3. DISCOVERY — major-races pass (ALWAYS do this). For the marquee races — World
   Marathon Majors (Boston, London, Berlin, Chicago, New York, Tokyo, Sydney) and big
   US races (Marine Corps, Twin Cities, Honolulu, Philadelphia, Portland, Los Angeles,
   Houston, Walt Disney World weekend, Big Sur, Grandma's, Pittsburgh, Rock 'n' Roll
   series) plus IRONMAN / 70.3 world championships — check the canonical key; if there
   is no row dated >= today, web-confirm the next occurrence from the official site and
   upsert (step 5).

4. DISCOVERY — breadth pass. Seed events_coverage once if empty: a row per
   (state, category) for all 50 states × {marathon, half_marathon, 10k, 5k, triathlon}
   (bucket_key = state||'|'||category, ON CONFLICT (bucket_key) DO NOTHING). Then take
   the ~40 stalest buckets (ORDER BY last_swept_at NULLS FIRST LIMIT 40). For each,
   run BROAD race-calendar web searches (RunSignUp, MarathonGuide, Athlinks, findarace,
   halfmarathons.net state pages) for upcoming events in that state+category. Skip any
   already present (query the canonical key); upsert the rest (step 5). Mark each bucket:
   UPDATE events_coverage SET last_swept_at=now(), last_found_count=$n, updated_at=now()
   WHERE bucket_key=$k;

5. UPSERT CONTRACT (idempotent). For each event set source = site used, external_id =
   slug(event_name)-slug(city)-event_date, is_active = true, country default 'USA',
   event_type ∈ {running,cycling,swimming,triathlon,duathlon,multisport}, event_subtype
   ∈ {marathon,half_marathon,5k,10k,olympic_triathlon,half_ironman,...}; if unsure of
   subtype use 'custom_distance' — never guess a wrong enum. event_date is a DATE.
     INSERT INTO public_events (event_name,event_type,event_subtype,city,state,country,
       event_date,start_time,registration_url,website_url,source,external_id,is_active)
     VALUES (...)
     ON CONFLICT (lower(event_name), event_date, lower(coalesce(city,'')))
     DO UPDATE SET registration_url=EXCLUDED.registration_url,
       website_url=EXCLUDED.website_url,
       start_time=COALESCE(EXCLUDED.start_time, public_events.start_time), is_active=true;

6. Only write events you confirmed from a real source (prefer the official race site).
   Low-confidence finds: do NOT write — increment events_flagged and list in notes.

7. Close the run log: UPDATE events_refresh_runs SET status='completed',
   completed_at=now(), buckets_swept=$b, events_added=$a, events_updated=$u,
   events_flagged=$f, notes=$notes WHERE id=$runId;

8. After DEV verifies (search returns the new/rolled-over races, no dupes), repeat all
   of the above on PROD. Finish with a short summary: counts added/updated/flagged per
   environment, and any flagged items needing a human.
```

## Step 2 — Create the FEED routine

(Requires `develop` pushed.) New routine:
- **Name:** `Weekly feed refresh`
- **Schedule:** Weekly (e.g. Monday 09:41).
- **Repository:** this repo (so it can run the scripts).
- **Supabase access:** the secrets above (the importer needs the service-role keys).
- **Prompt:** paste this verbatim ⤵️

```
You are the TheFeed catalog refresh routine. Run against DEV first, verify, then PROD.
For each environment export the right credentials and run:
  DEV:  SUPABASE_URL=https://vlmtsdzpnjnavdgytcmi.supabase.co
        SUPABASE_SERVICE_ROLE_KEY=$DEV_SUPABASE_SERVICE_ROLE_KEY  ref=vlmtsdzpnjnavdgytcmi
  PROD: SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
        SUPABASE_SERVICE_ROLE_KEY=$PROD_SUPABASE_SERVICE_ROLE_KEY  ref=wvmvsodrvbkxfydabqed
  also export FDA_API_KEY=$USDA_API_KEY (optional; enables nutrition enrichment).

Steps per environment:
1. node scripts/update_catalog.js
   (non-destructive UPSERT that preserves classification + nutrition, and deactivates
   variants of products no longer in the feed, guarded by a 10% anti-wipeout
   threshold). If the output shows "ANTI-WIPEOUT ... Skipping deactivation", STOP and
   report — likely a Shopify outage — and do NOT proceed to prod.
2. npm i -g supabase ; supabase link --project-ref <ref> ;
   supabase db query --linked -f scripts/classify_unclassified_by_type.sql
   (classifies only NEW products; never overwrites existing 'claude' classifications).
3. Verify: supabase db query --linked "SELECT
     count(*) FILTER (WHERE classification_source IS NULL) AS unclassified,
     count(*) FILTER (WHERE classification_source='claude') AS claude_preserved
   FROM public.catalog_products;" — unclassified should be 0 and claude_preserved must
   not drop. Flag any product whose Shopify type isn't mapped (needs a new SQL mapping).
Use `supabase db query --linked`, never `supabase db push`. Do DEV, verify, then PROD,
then report counts per environment.
```

## Step 3 — Verify after the first run
- Events: `SELECT count(*) FILTER (WHERE event_date>=now()::date) FROM public_events;`
  should grow over runs; check `events_refresh_runs` for the logged run + any flagged.
- Feed: `catalog_sync_runs` shows a completed run; `catalog_products` unclassified = 0.

---

## Reference
- Routine logic also lives in `.claude/commands/refresh-events.md` /
  `refresh-feed.md` (local skills) and `docs/technical/data-refresh-routines.md`.
- Scripts: `scripts/update_catalog.js`, `scripts/classify_unclassified_by_type.sql`.
