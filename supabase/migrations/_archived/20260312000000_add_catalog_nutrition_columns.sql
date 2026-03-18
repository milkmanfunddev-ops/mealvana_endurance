-- Add additional nutrition columns to catalog_items
-- These columns capture data available from Shopify PIM metafields
-- that wasn't included in the original schema.

ALTER TABLE public.catalog_items
  ADD COLUMN IF NOT EXISTS sugar_g DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS fiber_g DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS ingredients TEXT,
  ADD COLUMN IF NOT EXISTS servings_per_container DOUBLE PRECISION;
