# Catalog MVP Plan (with Feed Artifacts + API/Scrape Details)

## Summary
Build a simple catalog schema for external products, starting with The Feed.
Keep existing `public.foods`, `public.template_foods`, and `public.user_foods` behavior unchanged in MVP.
Search flow remains: local -> catalog -> OpenFoodFacts fallback.
Sync cadence is manual only.

## Feed Artifacts Already Pulled
- **Exported dataset**: `thefeed_products.json`
- **Current contents**: product-level Feed catalog export (2319 products), no variant barcode fields yet.
- **Export script**: `scrape_thefeed_products.js`
- **Current behavior**: Shopify Storefront GraphQL pagination, product-level fields.
- **Existing OFF lookup function used by app**: `lookup-product/index.ts`

## How We Interact with Feed API (and "Scrape")
We do API-first scraping (not HTML parsing): call the same backend APIs the Feed frontend uses.

**Primary source for Feed import: Shopify Storefront GraphQL**
- Endpoint: `https://thefeed.myshopify.com/api/2024-10/graphql.json`
- Auth header: `x-shopify-storefront-access-token: <storefront-token>`
- Query pattern: cursor pagination (`products(first:250, after:cursor)`), sorted by ID.

**Feed fields we pull for MVP:**
- Product: `id`, `handle`, `title`, `vendor`, `productType`, `image`, `updatedAt`
- Variant: `id`, `title`, `sku`, `barcode`

**Optional Feed enrichment source:**
- Algolia endpoint used by Feed frontend for `meta.pim.*` fields (carbs/protein/fat/calories/sodium where available).
- Use only as supplemental nutrition source; not as canonical full catalog source.

**Guardrail:**
- We do not crawl CSS/JS assets for data extraction.
- We only ingest from stable API responses and keep raw payload snapshots in DB.

## Implementation Changes

### 1) Database (minimal)
- Create `catalog.items` (single searchable row per item/variant record).
- Create `catalog.sync_runs` (manual run audit log).
- Add extensions: `pg_trgm`, `vector`.
- Add constraints/indexes:
  - `UNIQUE(source, source_item_id)`
  - `UNIQUE(normalized_barcode) WHERE normalized_barcode IS NOT NULL`
  - trigram indexes on name/brand
  - nullable `embedding vector(1536)` + vector index (enabled now, backfill later).

### 2) Feed import pipeline (manual)
- Extend Feed script to export variant-level rows with barcode/sku and core display fields.
- Add importer that upserts into `catalog.items` with simple dedupe:
  - barcode match first
  - else source key match.
- Log each run to `catalog.sync_runs`.

### 3) OFF enrichment + fallback
- Update `lookup-product` behavior to:
  - check catalog barcode first
  - fallback to OFF
  - persist OFF result to catalog with guardrails (fill-nulls first, no destructive overwrite of Feed values).
- Mark provenance fields (`source`, `nutrition_source`, `confidence`).

### 4) App integration
- Keep local filtering exactly as-is.
- Add catalog search call before OFF search in current food search controllers.
- Keep saving selected results into `user_foods` unchanged (no catalog FK in MVP).

## Public Interfaces / Contracts

**New edge function: `search-catalog`**
- Request: `{ query, limit, offset }`
- Response: `{ items, total }` in app-friendly normalized shape.

**Existing edge function: `lookup-product`**
- Keep request/response compatible; add non-breaking metadata (`resolved_source`, `catalog_hit`).

## Test Plan
- Migration tests for schema, constraints, indexes.
- Feed import idempotency test (rerun gives no duplicates).
- Barcode resolution test (known Feed barcode resolves from catalog).
- OFF fallback test (unknown barcode resolves via OFF and persists).
- Search quality test (`drink mix morten` returns Maurten).
- Flutter regression test: existing local/template/user-food behavior unchanged.

## Assumptions / Defaults Locked
- Anonymous users can search via edge functions.
- OFF fallback results are persisted with guardrails.
- Feed wins on conflicts in MVP.
- No `user_foods` link to catalog in MVP.
- Manual sync only.
- English-only search.
- pgvector enabled now, embedding backfill deferred.
