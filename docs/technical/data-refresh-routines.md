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

The pipeline already exists (`scripts/update_catalog.js`): Shopify Storefront
GraphQL → food-only filter → FDA FoodData Central nutrition enrichment → upsert on
`shopify_product_id`/`shopify_variant_id` → logs to `catalog_sync_runs`. It is
already idempotent. The routine mostly **schedules it and adds a Claude review of
the diff.**

### Flow
1. Run `update_catalog.js` against **dev** (writes go to dev catalog).
2. Claude reads the resulting `catalog_sync_runs` row + diff and curates:
   - **New products** → classify activity types (`classify_catalog_products.js`),
     sanity-check nutrition enrichment.
   - **Changed** → price / availability / nutrition deltas (accept).
   - **Disappeared from feed** → mark `is_active = false` (soft, never hard-delete)
     — **but only if the diff is plausible** (see §5).
3. Promote to **prod** (run the same pipeline against prod, or copy the vetted
   dev rows — to be finalized in build).
4. Audit summary to the run log.

### Cadence
Weekly or nightly (it's API-backed and cheap). Tunable.

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

## 9. Rollout plan

1. **Feed routine first** (lower risk — pipeline exists): feed Phase 0 audit →
   schedule `update_catalog.js` + Claude diff-review + anti-wipeout guard + Notion
   summary. *(Build order TBD with Lee — Lee leaned "design both first.")*
2. **Events routine:** generalize `/populate-events` → `refresh-events` skill
   (rollover scan + bucket-rotation discovery + confidence gate) → `events_coverage`
   + `events_refresh_runs` tables → schedule.
3. Tune cadence + bucket size from the first few real runs.

---
*Related: [[supabase-schema-via-datagrip]] (apply method), [[project_data_refresh_routine]] (memory).*
