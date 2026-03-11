-- Product Catalog MVP
-- Creates catalog_items (The Feed product variants) and catalog_sync_runs tables
-- with pg_trgm trigram indexes for fast text search

-- Enable pg_trgm extension for trigram text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- catalog_items: one row per product variant (each flavor/size)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.catalog_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Shopify identifiers
  shopify_product_id TEXT NOT NULL,
  shopify_variant_id TEXT,
  handle TEXT NOT NULL,

  -- Product info
  title TEXT NOT NULL,
  variant_title TEXT,
  brand TEXT,
  product_type TEXT,
  tags TEXT[],

  -- Variant identifiers
  barcode TEXT,
  sku TEXT,

  -- Pricing
  price_cents INTEGER,
  currency_code TEXT DEFAULT 'USD',

  -- Availability
  available_for_sale BOOLEAN DEFAULT true,

  -- Media & links
  image_url TEXT,
  product_url TEXT,

  -- Nutrition (per serving)
  calories_per_serving INTEGER,
  carbs_g DOUBLE PRECISION,
  protein_g DOUBLE PRECISION,
  fat_g DOUBLE PRECISION,
  sodium_mg INTEGER,
  serving_size TEXT,
  serving_grams DOUBLE PRECISION,
  caffeine_mg INTEGER,

  -- Nutrition metadata
  nutrition_source TEXT,          -- 'algolia', 'fda', 'openfoodfacts', null
  nutrition_confidence DOUBLE PRECISION, -- 0.0-1.0

  -- Raw data
  raw_payload JSONB,

  -- Timestamps
  shopify_updated_at TIMESTAMPTZ,
  nutrition_enriched_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- catalog_sync_runs: audit log for import script executions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.catalog_sync_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running',
  total_products_fetched INTEGER DEFAULT 0,
  variants_imported INTEGER DEFAULT 0,
  variants_skipped INTEGER DEFAULT 0,
  nutrition_enriched INTEGER DEFAULT 0,
  nutrition_failed INTEGER DEFAULT 0,
  errors JSONB DEFAULT '[]'::jsonb,
  script_version TEXT
);

-- ============================================================
-- Indexes
-- ============================================================

-- Upsert dedup on Shopify variant ID
CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_items_shopify_variant_id
  ON public.catalog_items (shopify_variant_id)
  WHERE shopify_variant_id IS NOT NULL;

-- Fast barcode lookup (non-unique — variants can share barcodes, e.g. multi-packs)
CREATE INDEX IF NOT EXISTS idx_catalog_items_barcode
  ON public.catalog_items (barcode)
  WHERE barcode IS NOT NULL;

-- Trigram text search indexes
CREATE INDEX IF NOT EXISTS idx_catalog_items_title_trgm
  ON public.catalog_items USING GIN (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_catalog_items_brand_trgm
  ON public.catalog_items USING GIN (brand gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_catalog_items_variant_title_trgm
  ON public.catalog_items USING GIN (variant_title gin_trgm_ops);

-- Category filtering
CREATE INDEX IF NOT EXISTS idx_catalog_items_product_type
  ON public.catalog_items (product_type);

-- Active items only
CREATE INDEX IF NOT EXISTS idx_catalog_items_available
  ON public.catalog_items (available_for_sale)
  WHERE available_for_sale = true;

-- ============================================================
-- Auto-update updated_at trigger
-- ============================================================
CREATE OR REPLACE FUNCTION update_catalog_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER catalog_items_updated_at
  BEFORE UPDATE ON public.catalog_items
  FOR EACH ROW
  EXECUTE FUNCTION update_catalog_items_updated_at();

-- ============================================================
-- Row Level Security
-- ============================================================

-- Enable RLS
ALTER TABLE public.catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_sync_runs ENABLE ROW LEVEL SECURITY;

-- Catalog items: authenticated users can read (public catalog)
CREATE POLICY "Authenticated users can read catalog items"
  ON public.catalog_items
  FOR SELECT
  TO authenticated
  USING (true);

-- Sync runs: authenticated users can read (admin visibility)
CREATE POLICY "Authenticated users can read sync runs"
  ON public.catalog_sync_runs
  FOR SELECT
  TO authenticated
  USING (true);

-- Service role has full access (used by import script)
-- Service role bypasses RLS by default, so no explicit policy needed
