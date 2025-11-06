-- Migration: Add sync tracking columns to nutrition_plans table
-- Created: 2025-11-05
-- Purpose: Enable offline-first sync for nutrition plans (matches calendar tables pattern)

-- ============================================================================
-- Add sync tracking columns to nutrition_plans
-- ============================================================================

-- Add columns with safe defaults
ALTER TABLE nutrition_plans
  ADD COLUMN IF NOT EXISTS needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add comments for documentation
COMMENT ON COLUMN nutrition_plans.needs_upload IS 'Flag indicating record needs upload to Supabase (offline-first sync)';
COMMENT ON COLUMN nutrition_plans.local_updated_at IS 'Timestamp of last local modification (for conflict resolution)';

-- ============================================================================
-- Add partial index for efficient sync queries
-- ============================================================================
-- Partial index only indexes rows where needs_upload = true for faster queries

CREATE INDEX IF NOT EXISTS idx_nutrition_plans_needs_upload
  ON nutrition_plans(needs_upload, device_id)
  WHERE needs_upload = true;

COMMENT ON INDEX idx_nutrition_plans_needs_upload IS 'Partial index for efficient sync queries (only indexes dirty records)';
