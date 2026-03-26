-- ============================================================================
-- Replace catalog_items regular view with a materialized view for performance.
--
-- The regular view JOINs catalog_products + catalog_variants on every query.
-- Since catalog data only changes during Shopify imports, a materialized view
-- with proper indexes is much faster for search and barcode lookups.
--
-- After Shopify imports, run:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY catalog_items_mv;
-- ============================================================================

-- 1. Drop the old regular view
DROP VIEW IF EXISTS catalog_items;

-- 2. Create the materialized view with the same query
CREATE MATERIALIZED VIEW catalog_items AS
SELECT
  v.id,
  p.shopify_product_id,
  v.shopify_variant_id,
  p.handle,
  p.title,
  v.variant_title,
  p.brand,
  p.shopify_product_type AS product_type,
  p.tags,
  v.barcode,
  v.sku,
  v.price_cents,
  v.currency_code,
  v.available_for_sale,
  COALESCE(v.image_url, p.image_url) AS image_url,
  p.product_url,
  v.calories_per_serving,
  v.carbs_g,
  v.protein_g,
  v.fat_g,
  v.sodium_mg,
  v.serving_size,
  v.serving_grams,
  v.caffeine_mg,
  v.sugar_g,
  v.fiber_g,
  p.ingredients,
  v.servings_per_container,
  v.nutrition_source,
  v.nutrition_confidence,
  v.nutrition_enriched_at,
  v.raw_payload,
  COALESCE(v.shopify_updated_at, p.shopify_updated_at) AS shopify_updated_at,
  v.created_at,
  v.updated_at,
  p.product_type_id,
  p.categories,
  p.allergens,
  p.excluded_diets,
  p.is_electrolyte,
  p.is_liquid,
  p.activity_types,
  p.classification_source,
  p.classification_confidence
FROM catalog_variants v
JOIN catalog_products p ON p.id = v.catalog_product_id;

-- 3. Create a unique index (required for CONCURRENTLY refresh)
CREATE UNIQUE INDEX idx_catalog_items_mv_id ON catalog_items (id);

-- 4. Indexes for text search (pg_trgm trigram matching)
CREATE INDEX idx_catalog_items_mv_title_trgm ON catalog_items USING GIN (title gin_trgm_ops);
CREATE INDEX idx_catalog_items_mv_brand_trgm ON catalog_items USING GIN (brand gin_trgm_ops);
CREATE INDEX idx_catalog_items_mv_variant_title_trgm ON catalog_items USING GIN (variant_title gin_trgm_ops);

-- 5. Indexes for filtered lookups
CREATE INDEX idx_catalog_items_mv_barcode ON catalog_items (barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_catalog_items_mv_available ON catalog_items (available_for_sale) WHERE available_for_sale = TRUE;
CREATE INDEX idx_catalog_items_mv_nutrition_confidence ON catalog_items (nutrition_confidence DESC NULLS LAST);
CREATE INDEX idx_catalog_items_mv_product_type_id ON catalog_items (product_type_id);

-- 6. Grant permissions (materialized views need explicit grants)
GRANT SELECT ON catalog_items TO anon;
GRANT SELECT ON catalog_items TO authenticated;
GRANT ALL ON catalog_items TO service_role;
