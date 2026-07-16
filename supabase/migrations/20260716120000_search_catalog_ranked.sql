-- =============================================================================
-- search_catalog_ranked — relevance-ranked catalog text search
-- =============================================================================
-- Replaces the whole-phrase ILIKE in supabase/functions/search-catalog/index.ts,
-- which returned 0 results for any multi-word query whose tokens span columns:
--   'rx bar'  -> 0   (brand='RXBAR', title='Protein Bar'; no column contains
--                     the contiguous substring 'rx bar')
--   'rxbar'   -> 13
-- Only 47.9% of a 117-term sweep found the food on prod. See
-- docs/architecture/food-search-scan-audit-2026-07-16.md §9c.
--
-- WHY THIS SHAPE (all measured against prod, 2026-07-16 — do not "simplify"):
--
--  * Tokenized AND is NOT enough. It fixes 'rx bar' (13) but still returns 0 for
--    'nuun electrolyte tablets' and 'clif shot bloks' — those product names do
--    not contain the words "electrolyte" / "shot" at all. Requiring every token
--    to match cannot work when the user types a word the product lacks.
--    => threshold is "at least half the tokens", not "all".
--
--  * Full-text search CANNOT work here. Postgres never splits a solid ASCII
--    token, so 'RXBAR' indexes as the single lexeme `rxbar` while 'rx bar'
--    parses to 'rx' & 'bar'. Measured: websearch_to_tsquery -> 0 hits.
--
--  * pg_trgm alone is too loose: word_similarity > 0.4 matched 681 of 3469 rows.
--
--  * pgvector rejected: this is a lexical (substring) problem, not a semantic
--    one; embeddings would also worsen precision and cost ~500ms p90 per query
--    against a 300ms debounce budget.
--
--  * Threshold must be on MATCHED TOKEN COUNT, not on the weighted score.
--    Gating on score >= 2 returns only 5 rows for the single-word query 'gel'
--    (of 544 gel products), because a title-only match scores 1.
--
--  * brand is weighted 2x so 'nuun electrolyte tablets' ranks Nuun products
--    above a rival's "Tactical Electrolyte Tablets".
--
--  * variant_title is deliberately NOT matched (it is still returned for
--    display). Flavour names are why 'banana bread' returned 5 energy bars and
--    'oreo' returned a Clif bar. Excluding it: 'banana bread' -> 0.
--
--  * This must be an RPC: PostgREST cannot rank (ts_rank/score ordering is
--    unsupported) and .or() ORs whole per-column predicates, which is the
--    original bug.
--
-- PERFORMANCE: seq scan over 3,469 sellable rows = ~37ms. No index required at
-- this corpus size; trigram GIN indexes already exist on brand/title.
--
-- Idempotent: CREATE OR REPLACE.
-- =============================================================================

create or replace function public.search_catalog_ranked(
  q                 text,
  lim               int  default 20,
  p_product_type    text default null,
  p_product_type_id text default null
)
returns table (
  id                    uuid,
  title                 text,
  variant_title         text,
  brand                 text,
  product_type          text,
  barcode               text,
  image_url             text,
  product_url           text,
  price_cents           integer,
  currency_code         text,
  available_for_sale    boolean,
  calories_per_serving  integer,
  carbs_g               double precision,
  protein_g             double precision,
  fat_g                 double precision,
  sodium_mg             integer,
  serving_size          text,
  serving_grams         double precision,
  caffeine_mg           integer,
  nutrition_source      text,
  nutrition_confidence  double precision,
  product_type_id       text,
  categories            text[],
  is_electrolyte        boolean,
  is_liquid             boolean,
  allergens             text[],
  excluded_diets        text[],
  score                 integer
)
language sql
stable
as $$
  with toks as (
    -- Mirrors lib/shared/utils/search_token_matcher.dart:tokenizeSearchQuery so
    -- client-side and server-side matching agree.
    select array_remove(
             string_to_array(
               regexp_replace(lower(trim(coalesce(q, ''))), '[^a-z0-9]+', ' ', 'g'),
               ' '
             ),
             ''
           ) as t
  ),
  scored as (
    select
      c.*,
      (select count(*)
         from unnest((select t from toks)) tok
        where coalesce(c.brand, '') || ' ' || coalesce(c.title, '') ilike '%' || tok || '%'
      ) as matched,
      (
        2 * (select count(*) from unnest((select t from toks)) tok
              where coalesce(c.brand, '') ilike '%' || tok || '%')
        +   (select count(*) from unnest((select t from toks)) tok
              where coalesce(c.title, '') ilike '%' || tok || '%')
      )::int as sc
    from public.catalog_items c
    where c.available_for_sale
      and (p_product_type    is null or c.product_type    = p_product_type)
      and (p_product_type_id is null or c.product_type_id = p_product_type_id)
  )
  select
    s.id, s.title, s.variant_title, s.brand, s.product_type, s.barcode,
    s.image_url, s.product_url, s.price_cents, s.currency_code, s.available_for_sale,
    s.calories_per_serving, s.carbs_g, s.protein_g, s.fat_g, s.sodium_mg,
    s.serving_size, s.serving_grams, s.caffeine_mg,
    s.nutrition_source, s.nutrition_confidence,
    s.product_type_id, s.categories, s.is_electrolyte, s.is_liquid,
    s.allergens, s.excluded_diets,
    s.sc as score
  from scored s
  where s.matched > 0
    and s.matched >= ceil(
      (select coalesce(array_length(t, 1), 0) from toks) / 2.0
    )
  order by s.sc desc, s.nutrition_confidence desc nulls last, s.title
  limit greatest(1, least(coalesce(lim, 20), 50));
$$;

comment on function public.search_catalog_ranked is
  'Relevance-ranked catalog text search. Tokenizes the query, requires >= half '
  'the tokens to match brand||title, scores 2x brand + 1x title, orders by score. '
  'Deliberately does NOT match variant_title (flavour names cause false '
  'positives). See docs/architecture/food-search-scan-audit-2026-07-16.md §9c.';

grant execute on function public.search_catalog_ranked(text, int, text, text)
  to anon, authenticated, service_role;
