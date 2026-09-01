# Schema Parity: Prod vs Dev

Comparison of `docs/prod_schema.txt` (3520 lines) and `docs/dev_schema.txt` (3276 lines) performed 2026-04-24.

## TL;DR

**The structural schemas are already at parity.** All tables, columns, types,
indexes, functions, constraints, views, and materialized views are functionally
identical between prod and dev. The 244-line size delta is almost entirely
explained by grants/comments, not by missing structure.

Run the SQL in [`bring_dev_to_prod_parity.sql`](#sql-to-bring-dev-to-prod-parity)
below to sync the handful of non-structural drift items.

## Inventory counts (structural items)

| Item            | Prod | Dev |
| --------------- | ---- | --- |
| tables          | 35   | 35  |
| enum types      | 18   | 18  |
| functions       | 45   | 45  |
| indexes         | 123  | 123 |
| unique indexes  | 6    | 6   |
| views           | 1    | 1   |
| matviews        | 1    | 1   |
| alter table     | 36   | 36  |
| operator class  | 2    | 2   |

All 229 structural items matched by name across both schemas.

## Differences found

### 1. Column ordering in `templates` (cosmetic only)

Prod declares columns in order `… excluded_diets, has_liquid_base, food_names`.
Dev declares them in order `… excluded_diets, food_names, has_liquid_base`.

Postgres does not expose column order as user-visible behavior (it affects
physical storage only). No migration needed.

### 2. FK constraint rendering in `carb_loading_user_foods.user_id` (cosmetic only)

Both prod and dev have the same TWO foreign keys on this column (one unnamed
inline, one named `fk_carb_loading_user_foods_user`). pg_dump just renders
them in opposite order. Functionally identical.

### 3. `pg_trgm` extension function grants

Prod has `grant execute` on every `pg_trgm` function (`similarity`, `gtrgm_*`,
`gin_trgm_*`, `show_trgm`, `set_limit`, `show_limit`, etc.) to `anon`,
`authenticated`, `postgres`, and `service_role`. Dev is missing those grants
(~124 grant statements).

This means the `pg_trgm` extension was likely installed/relocated into the
`public` schema in prod but remains in the default `extensions` schema in dev.
If `pg_trgm` is in `extensions` in dev, those grants would fail — the SQL
below only attempts them if the functions exist in `public`.

### 4. Stale / missing column comments

| Column                              | Prod comment                                     | Dev comment                                        |
| ----------------------------------- | ------------------------------------------------ | -------------------------------------------------- |
| `users.unit_system`                 | "Unit system preference: imperial or metric"    | *(missing)*                                         |
| `users.typical_bike_bottles`        | "Number of water bottles typically carried on bike (0-6)" | "Number of water bottles typically carried on bike (1-4)" — stale, does not match the `CHECK (… 0 … 6)` constraint |
| `template_foods.drink_pool_phases`  | *(missing)*                                      | "Which phases this drink can be selected for: meal, snack, top_up" |
| `template_foods.is_drink_pool`      | *(missing)*                                      | "Whether this food is available in the drink selection pool" |
| `templates.food_names`              | *(missing)*                                      | "Denormalized array of food_name values from JSONB foods for fast conflict avoidance" |

The last three comments in dev describe real columns and look useful — you
probably want to add them to prod rather than drop them from dev. The first
two should be synced dev → prod's wording.

## What was checked (and matched)

- Every column of every table compared by name and definition. Only one
  cosmetic FK-rendering diff (described above).
- Every function compared by signature AND body (normalized whitespace). All
  45 match.
- Every enum type compared by name and values. All 18 match.
- Every index compared by name and definition. All 129 match.
- Every `alter table` statement compared. All 36 match.
- `search_public_events_hybrid`, `upsert_nutrition_plan_versioned`,
  `delete_nutrition_plan_versioned`, `is_approved_coach`, and the other
  business-logic functions are identical.

## What the dumps do NOT cover

These dumps appear to omit:
- RLS policies (`CREATE POLICY`) — 0 found in either file
- Triggers (`CREATE TRIGGER`) — 0 found in either file
- Supabase `auth.*`, `storage.*`, `realtime.*` schemas

If you want to confirm RLS parity you'll need a separate dump (e.g.
`pg_dump --schema=public --section=post-data` or query `pg_policies`
directly against each environment).

## SQL to bring dev to prod parity

Minimal, safe, idempotent. Save as a Supabase migration if you want to
version it.

```sql
-- =================================================================
-- Bring dev schema into parity with prod schema
-- Source: docs/prod_schema.txt vs docs/dev_schema.txt (2026-04-24)
-- =================================================================

-- -----------------------------------------------------------------
-- 1. Sync column comments (dev → prod wording where prod is correct,
--    prod → dev where dev has better documentation)
-- -----------------------------------------------------------------

-- Prod has this, dev is missing it
COMMENT ON COLUMN public.users.unit_system IS
  'Unit system preference: imperial or metric';

-- Dev's comment is stale ("1-4"); prod matches the actual CHECK
-- constraint which allows 0-6
COMMENT ON COLUMN public.users.typical_bike_bottles IS
  'Number of water bottles typically carried on bike (0-6)';

-- -----------------------------------------------------------------
-- 2. pg_trgm grants (only needed if pg_trgm is installed in the
--    public schema in dev — the default Supabase location is the
--    `extensions` schema, in which case the grants below are not
--    required and you should SKIP this block)
--
-- To check: SELECT extnamespace::regnamespace, extname FROM pg_extension WHERE extname='pg_trgm';
--
-- If it reports `public`, run these grants. If it reports `extensions`,
-- skip — prod likely has pg_trgm in public and dev does not, which
-- is a Supabase-standard difference, not real schema drift.
-- -----------------------------------------------------------------

DO $$
DECLARE
  trgm_schema text;
BEGIN
  SELECT extnamespace::regnamespace::text INTO trgm_schema
  FROM pg_extension WHERE extname = 'pg_trgm';

  IF trgm_schema = 'public' THEN
    -- Grant EXECUTE on all pg_trgm functions to the four Supabase roles
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.similarity(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.similarity_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.similarity_dist(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.word_similarity(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.word_similarity_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.word_similarity_commutator_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.word_similarity_dist_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.word_similarity_dist_commutator_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.strict_word_similarity(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.strict_word_similarity_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.strict_word_similarity_commutator_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.strict_word_similarity_dist_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.show_trgm(text) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.set_limit(real) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.show_limit() TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_in(cstring) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_out(public.gtrgm) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_compress(internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_decompress(internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_options(internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_union(internal, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_same(public.gtrgm, public.gtrgm, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_penalty(internal, internal, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gtrgm_picksplit(internal, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gin_extract_value_trgm(text, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal) TO anon, authenticated, postgres, service_role';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal) TO anon, authenticated, postgres, service_role';
  ELSE
    RAISE NOTICE 'pg_trgm is in schema %, skipping public-schema grants (this is the Supabase default and does NOT represent real schema drift).', trgm_schema;
  END IF;
END $$;

-- -----------------------------------------------------------------
-- 3. (OPTIONAL) Backport dev's useful column comments to prod
-- These are IN DEV BUT NOT PROD. Apply to prod, not dev.
-- -----------------------------------------------------------------
-- COMMENT ON COLUMN public.template_foods.drink_pool_phases IS
--   'Which phases this drink can be selected for: meal, snack, top_up';
-- COMMENT ON COLUMN public.template_foods.is_drink_pool IS
--   'Whether this food is available in the drink selection pool';
-- COMMENT ON COLUMN public.templates.food_names IS
--   'Denormalized array of food_name values from JSONB foods for fast conflict avoidance';
```

## Recommendation

Given that the structural schemas are already at parity, I'd double-check
that the prod dump really is "more up to date" than you expected. Some
possibilities:

1. **The dumps are actually in sync** (happy case). Dev has already caught up
   via recent migrations. If so, only run section 1 of the SQL above. The
   pg_trgm grants can be ignored — they're a Supabase-standard Prod vs Dev
   artifact, not drift.
2. **Prod has drift that was never committed as a migration.** If you know of
   a specific feature/column/table added directly to prod via SQL console,
   point me at it and we'll extract it precisely.
3. **The dump command used was different on each side.** Verify the dumps
   were generated with identical `pg_dump` flags — one could be omitting
   RLS policies, triggers, or extensions that the other includes.
