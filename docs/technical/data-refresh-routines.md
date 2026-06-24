# Data Refresh Routines — Design (for sign-off)

**Status:** Proposed (design only — no routine built yet). **Author:** Claude Code, 2026-06-23.
**Decision needed:** Lee's sign-off on this design before any building.

## 1. Goal

Two datasets change over time and today are only updated when a human runs a
command, with no staleness detection and no schedule:

| Dataset | Table(s) | Manual tool today |
|---|---|---|
| **Race catalog** | `public_events` | `/populate-events` command (Claude web research per query) |
| **Product catalog** | `catalog_products`, `catalog_variants` | `scripts/update_catalog.js` (TheFeed Shopify API → FDA enrich → upsert) |

We want **scheduled routines** that keep both current automatically:
- **Events:** roll over recurring races to their next occurrence AND discover new races.
- **Feed:** pick up new/changed/discontinued products from TheFeed.

### Locked decisions (Lee, 2026-06-23)
- **Autonomy:** full-auto to **dev + prod** — but with confidence gating + audit (below).
- **Maintenance bar:** low-maintenance, "not janky."
- **Events discovery source:** Claude web-search (no new external API dependency).
- **Substrate:** cloud Claude routine preferred (see §6).

## 2. Shared architecture

Both routines follow the same shape:

```
schedule → pull/scan → normalize → confidence gate → upsert dev (verify) → upsert prod → audit-log
```

Principles applied to both:

1. **Canonical key + idempotent upsert.** Every write is an `UPSERT … ON CONFLICT`
   on a natural key, so re-runs never duplicate.
   - Events: `(lower(event_name), event_date, lower(coalesce(city,'')))` — the
     `public_events_canonical_key_uniq` index added in **Phase 0** (done 2026-06-23).
   - Feed: `shopify_product_id` / `shopify_variant_id` (already `UNIQUE`) — the
     existing pipeline is already idempotent.
2. **Apply via `supabase db query --linked` (or PostgREST), NEVER `supabase db push`.**
   (`db push` is broken here — issue #29.)
3. **Dev-first.** Apply + verify on dev, then prod. Same flow used for the Rocket
   City fix this session.
4. **Confidence gating.** Only auto-write changes above a confidence threshold.
   Anything ambiguous is **flagged, not written** (see §5).
5. **Audit every change** with its source URL + confidence to a run log (see §7),
   so "full auto" is always reviewable after the fact.
6. **No destructive mass-action on a suspicious diff** (see §5 safety rails).

## 3. Routine A — Events (`public_events`)

Two jobs in one weekly run.

### 3a. Rollover (keep existing fresh)
- **Staleness scan (SQL):** find recurring races whose latest occurrence is about
  to leave the search window. Search filters `event_date >= today`, so a race with
  no future date silently disappears (this was the Rocket City bug). Target:
  ```sql
  SELECT event_name, city, state, max(event_date) AS latest
  FROM public_events
  GROUP BY event_name, city, state
  HAVING max(event_date) < (now()::date + INTERVAL '90 days');
  ```
- For each, Claude confirms next year's date from the official race site (citing
  the URL), maps to our enums, and upserts the new occurrence on the canonical key.

### 3b. Discovery (find new) — Claude web-search
- **Coverage model.** Define buckets = `state × distance/type × next 12 months`
  (e.g. "marathons in AL in next 12mo"). Maintain a small `events_coverage` ledger
  of when each bucket was last swept.
- **Each run sweeps the N stalest buckets** (rotating, to bound cost/time). For
  each bucket: Claude searches race calendars (RunSignUp, MarathonGuide, Athlinks,
  findarace, official sites), extracts events, **skips any already present** (query
  the canonical key first), maps to our schema/enums, and upserts the new ones.
- **Why bucket-rotation:** a full nationwide sweep every run is expensive and
  janky; rotating a bounded set keeps each run cheap and predictable while
  achieving full coverage over a cycle.

### Per-event write contract
- Set `source` = the calendar/site used; set deterministic `external_id`
  (`name-city-date` slug, matching Phase 0 backfill); `is_active = true`;
  `country` default `'USA'`.
- Upsert: `ON CONFLICT (lower(event_name), event_date, lower(coalesce(city,'')))
  DO UPDATE` (refresh url/time/etc.) — never insert a duplicate.
- Map `event_type`/`event_subtype` to the enums in `/populate-events`; if subtype
  is unclear → `custom_distance` (never guess a wrong enum → avoids the 22P02 class
  of errors).

### Cadence
Weekly (rollover scan is cheap; discovery rotates buckets). Tunable.

## 4. Routine B — Feed (`catalog_products` / `catalog_variants`)

The pipeline exists (`scripts/update_catalog.js`): Shopify Storefront GraphQL →
food-only filter → FDA nutrition enrichment (in-run) → write products+variants →
logs to `catalog_sync_runs`. BUT a code read (2026-06-23) found two behaviours that
make "just schedule it" unsafe — the routine must address them first:

### ⚠️ Findings that reshape this routine
1. **The importer is destructive to classification.** For every fetched product it
   does `DELETE FROM catalog_products WHERE shopify_product_id IN (...)` then
   `INSERT` fresh (`update_catalog.js:332`). The re-insert writes only Shopify
   fields (title/brand/tags/image/ingredients) — it **omits** `product_type_id`,
   `categories`, `allergens`, `is_electrolyte`, `activity_types`,
   `classification_source`. So **every run wipes all product classification** (and
   CASCADE-drops/reinserts variants). Today that's masked because classification is
   re-applied afterward by `classify_catalog_products.js` — i.e. it's really a
   multi-step pipeline, not a one-shot. A naive scheduled run would leave the
   catalog unclassified until re-classification ran.
2. **Removed products are never handled.** Only products *present in the fetch* are
   touched; products that have left TheFeed are left as stale rows forever (no
   deactivation). (Upside: a partial/empty Shopify response can't mass-wipe the
   catalog — it only ever touches fetched products. So the §5 "anti-wipeout" rail is
   less critical here than for a true full-replace, but stale-accumulation is the
   real problem to solve.)

### Build approach (recommended): make the importer non-destructive, then orchestrate
- **B0 (foundation):** change the product write from delete+insert to a **true
  UPSERT on `shopify_product_id`** that updates only Shopify-sourced columns and
  **leaves classification columns untouched**. Same for variants on
  `shopify_variant_id` (preserve nutrition unless re-enriching). This makes re-runs
  safe and cheap and stops the classification wipe. (Analogous to events Phase 0 —
  fix the write semantics before automating.)
- **B1 removed-product handling:** after a successful fetch, mark products/variants
  **not seen in this run** as `available_for_sale = false` (soft) — guarded by the
  §5 anti-wipeout threshold.
- **B2 classify new only:** run `classify_catalog_products.js` against just the
  newly-added/unclassified products (cheap, since B0 preserves existing
  classification).

### Flow (per scheduled run)
1. Snapshot dev catalog counts (products, variants, active, classified).
2. `node scripts/update_catalog.js` against **dev** (now non-destructive via B0).
3. B1: deactivate products/variants not seen this run (anti-wipeout guarded).
4. B2: classify any new/unclassified products; spot-check nutrition.
5. Claude reviews the computed before/after diff (added / changed / deactivated).
6. Promote to **prod**: re-run the pipeline against prod creds (decided: run twice).
7. Audit summary → `catalog_sync_runs` + Notion.

### Cadence
Weekly or nightly (API-backed, cheap). Tunable.

## 5. Guardrails & safety rails

- **Confidence gate (events):** each discovered/rolled-over event carries a
  confidence + source URL. Below threshold → write a "needs human" row to the audit
  log / Notion, do **not** touch the DB.
- **Anti-wipeout (feed):** if a sync would deactivate more than X% of the catalog
  (e.g. >10%), treat it as a likely source/API failure — **abort the deactivation**
  and flag for a human. Prevents an empty/partial Shopify response from nuking the
  catalog.
- **Dev-first, always.** Verify row counts + a search/spot-check on dev before prod.
- **Kill switch:** a config flag (env/Notion/DB) the routine checks first, so you
  can pause it without editing code.
- **Idempotent + canonical-keyed** so a re-run after a partial failure is safe.
- **Cost bound:** events discovery rotates a fixed number of buckets per run.

## 6. Scheduling substrate

| Option | Always-on | Maintenance | Web research | Recommendation |
|---|---|---|---|---|
| **Cloud Claude routine** | ✅ | none (just a schedule) | ✅ | **Preferred** |
| GitHub Actions + headless Claude | ✅ | a YAML + secrets | ✅ | Equivalent fallback if cloud runs unavailable |
| Claude cron on Mac | ❌ (Mac must be awake) | low | ✅ | Rejected — janky |
| Supabase pg_cron / Vercel cron (plain code) | ✅ | bespoke code | ❌ | Only fits the feed's deterministic pull, not events discovery |

**Plan:** run both routines as scheduled **cloud Claude routines**, reusing the
`/populate-events` (→ generalized `refresh-events`) skill and the `update_catalog.js`
pipeline. GitHub Actions is the drop-in fallback if cloud scheduled runs aren't
enabled on the account.

## 7. Observability / audit log

- **Feed:** `catalog_sync_runs` already exists — reuse it (counts, timing, status).
- **Events:** add an `events_refresh_runs` log table (run timestamp, buckets swept,
  events added/updated/flagged, errors) — mirrors `catalog_sync_runs`.
- **Notion:** post a per-run summary + any "needs human" items to a Notion "Data
  Refresh Log" board (same workspace as the Bug Reports board), so there's a
  human-visible trail and a place for flagged items. (Create during build.)

## 8. Prerequisites & what's needed

- **Events Phase 0 — DONE** (dedup + canonical unique index, dev+prod,
  commit `18bf6c92`).
- **Feed Phase 0 — DONE / not needed (audited 2026-06-23).** `catalog_products`
  (646) + `catalog_variants` (4511) are identical on dev+prod and CLEAN: 0 dup
  shopify_product_ids, 0 dup handles, 0 dup barcodes, 0 null variant ids, 0
  unclassified products. The unique Shopify-id design has kept it clean — no dedup
  migration required. **Finding:** the catalog is ~3 months stale (last update
  2026-03-23/24) and ~5% of variants lack nutrition (271 dev / 252 prod) — exactly
  what the routine fixes.
- **Prod-promotion mechanism — DECIDED: run twice.** `update_catalog.js` targets an
  env purely via `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`; dev/prod already
  match. So: run with dev creds → verify → run with prod creds. No copy logic.
- **Secrets the routine needs:** `SUPABASE_URL` (have, per-env), service role key
  (in `secrets/supabase_service_role_keys.md`), `THEFEED_STOREFRONT_TOKEN`
  (hardcoded default in script + overridable), AI/model creds for Claude.
  ⚠️ **`FDA_API_KEY` is NOT set in any env file** — the script treats it as optional
  (null → skips nutrition enrichment, which is why ~250-270 variants have none). To
  enable nutrition backfill, provide `FDA_API_KEY` (or `USDA_API_KEY`) wherever the
  routine runs; otherwise the routine still works, just without enrichment.

## 9. Rollout status

### Feed routine — BUILT + RUN on dev + prod (2026-06-23/24)
- B0 non-destructive importer, B1 removed-product deactivation (10% anti-wipeout
  guard), B2 classify-new (`scripts/classify_unclassified_by_type.sql`, deterministic,
  preserves existing 'claude' classifications). All committed.
- Executed on **dev and prod**: both 689 products, 0 unclassified, 646 'claude'
  preserved, 38 removed products deactivated, catalog refreshed (prod was 3 months
  stale). 0 errors.
- **Key realization:** with the SQL classification fallback, the feed routine is
  **fully deterministic — no Claude-in-the-loop needed** for the happy path. So the
  right scheduler is plain CI, not a Claude routine. Claude is only needed to handle
  flags (anti-wipeout abort; a novel Shopify product_type the SQL can't map).
- **Scheduler:** `.github/workflows/refresh-feed.yml` (weekly cron; manual-trigger
  by default, inert until secrets added + `schedule:` uncommented). Skill:
  `.claude/commands/refresh-feed.md`.
- **Substrate note:** the in-session `CronCreate` tool is session-bound (only fires
  while this REPL runs; recurring jobs expire after 7 days) — too janky for an
  always-on routine. GitHub Actions (or Codemagic scheduled / Supabase pg_cron) is
  the always-on home. Pick one and add the secrets in §8.

### Events routine — NOT built (Phase 0 done)
- Phase 0 (dedup + canonical key) done. Still to build: generalize `/populate-events`
  → `refresh-events` (rollover staleness scan + bucket-rotation web-search discovery
  + confidence gate) → `events_coverage` + `events_refresh_runs` tables → schedule.
- Unlike the feed, events discovery **does** need Claude (web research), so its
  scheduler is a cloud Claude routine or GitHub-Actions-headless-Claude.

---
*Related: [[supabase-schema-via-datagrip]] (apply method), [[project_data_refresh_routine]] (memory).*
