-- ============================================================================
-- Catalog Products + Variants Schema
-- Restructures catalog_items (one row per variant) into:
--   catalog_products (one per product, ~500-800 rows)
--   catalog_variants (one per flavor/size, ~4500 rows)
-- Adds food classification fields matching foods/template_foods schema.
-- ============================================================================

-- Ensure pg_trgm extension is available (should already exist)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- 1. catalog_products — one row per unique Shopify product
-- ============================================================================
CREATE TABLE public.catalog_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shopify_product_id TEXT NOT NULL UNIQUE,
  handle TEXT NOT NULL,
  title TEXT NOT NULL,
  brand TEXT,

  -- Classification (matching foods/template_foods schema)
  product_type_id TEXT,                          -- our product_type_enum values
  categories TEXT[] DEFAULT '{}',                 -- before_run, during_run, after_run, transition
  allergens TEXT[] DEFAULT '{}',                  -- dairy, gluten, soy, etc.
  excluded_diets TEXT[] DEFAULT '{}',             -- vegan, vegetarian, etc.
  is_electrolyte BOOLEAN NOT NULL DEFAULT FALSE,
  is_liquid BOOLEAN NOT NULL DEFAULT FALSE,
  activity_types TEXT[] DEFAULT '{"running","cycling","swimming"}',

  -- Shopify metadata
  shopify_product_type TEXT,                     -- original Shopify product_type ("gels", "bars", etc.)
  tags TEXT[] DEFAULT '{}',
  image_url TEXT,
  product_url TEXT,
  ingredients TEXT,                               -- product-level ingredients (shared across variants)

  -- Classification metadata
  classification_source TEXT,                    -- 'claude', 'manual'
  classification_confidence DOUBLE PRECISION,    -- 0.0-1.0
  classified_at TIMESTAMPTZ,

  -- Timestamps
  shopify_updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. catalog_variants — one row per Shopify variant (flavor/size)
-- ============================================================================
CREATE TABLE public.catalog_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_product_id UUID NOT NULL REFERENCES catalog_products(id) ON DELETE CASCADE,
  shopify_variant_id TEXT UNIQUE,
  variant_title TEXT,

  -- Variant-specific identifiers
  barcode TEXT,
  sku TEXT,

  -- Pricing
  price_cents INTEGER,
  currency_code TEXT NOT NULL DEFAULT 'USD',
  available_for_sale BOOLEAN NOT NULL DEFAULT TRUE,

  -- Variant-specific image
  image_url TEXT,

  -- Nutrition (per serving — varies by variant/size)
  calories_per_serving INTEGER,
  carbs_g DOUBLE PRECISION,
  protein_g DOUBLE PRECISION,
  fat_g DOUBLE PRECISION,
  sodium_mg INTEGER,
  serving_size TEXT,
  serving_grams DOUBLE PRECISION,
  caffeine_mg INTEGER,
  sugar_g DOUBLE PRECISION,
  fiber_g DOUBLE PRECISION,
  servings_per_container DOUBLE PRECISION,

  -- Nutrition metadata
  nutrition_source TEXT,
  nutrition_confidence DOUBLE PRECISION,
  nutrition_enriched_at TIMESTAMPTZ,

  -- Raw Shopify data
  raw_payload JSONB,

  -- Timestamps
  shopify_updated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. Indexes
-- ============================================================================

-- catalog_products indexes
CREATE INDEX idx_catalog_products_handle ON catalog_products(handle);
CREATE INDEX idx_catalog_products_title_trgm ON catalog_products USING GIN (title gin_trgm_ops);
CREATE INDEX idx_catalog_products_brand_trgm ON catalog_products USING GIN (brand gin_trgm_ops);
CREATE INDEX idx_catalog_products_product_type_id ON catalog_products(product_type_id);
CREATE INDEX idx_catalog_products_categories ON catalog_products USING GIN (categories);
CREATE INDEX idx_catalog_products_is_electrolyte ON catalog_products(is_electrolyte) WHERE is_electrolyte = TRUE;

-- catalog_variants indexes
CREATE INDEX idx_catalog_variants_product_id ON catalog_variants(catalog_product_id);
CREATE INDEX idx_catalog_variants_barcode ON catalog_variants(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX idx_catalog_variants_available ON catalog_variants(available_for_sale) WHERE available_for_sale = TRUE;
CREATE INDEX idx_catalog_variants_variant_title_trgm ON catalog_variants USING GIN (variant_title gin_trgm_ops);

-- ============================================================================
-- 4. Backward-compatible view (matches old catalog_items shape)
-- ============================================================================
CREATE OR REPLACE VIEW public.catalog_items_v AS
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
  -- New classification fields (from product)
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

-- ============================================================================
-- 5. RLS Policies
-- ============================================================================

ALTER TABLE catalog_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_variants ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read (public catalog)
CREATE POLICY "Authenticated users can read catalog_products"
  ON catalog_products FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can read catalog_variants"
  ON catalog_variants FOR SELECT
  TO authenticated
  USING (true);

-- Service role has full access (for import scripts)
CREATE POLICY "Service role full access on catalog_products"
  ON catalog_products FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role full access on catalog_variants"
  ON catalog_variants FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 6. Updated_at trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_catalog_products_updated_at
  BEFORE UPDATE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_catalog_variants_updated_at
  BEFORE UPDATE ON catalog_variants
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
