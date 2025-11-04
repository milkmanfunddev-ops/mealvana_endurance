-- Migration: Mark Redundant Migrations as Applied
-- Date: 2025-09-30  
-- Description: Marks migrations as applied that would add columns we already have in our new tables

-- Insert these migrations into the history so they're marked as applied
-- This prevents them from trying to run and failing on "column already exists"

-- Note: The supabase CLI tracks migrations in supabase_migrations.schema_migrations
-- We can't insert directly, so this migration does nothing and we'll skip those files

-- This migration intentionally does nothing - it exists only to move past the redundant migrations
SELECT 1;
