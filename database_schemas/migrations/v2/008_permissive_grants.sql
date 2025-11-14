-- ============================================================================
-- Migration 008: Permissive Grants
-- ============================================================================
-- Description: Grant broad permissions for fast development iteration
-- Date: 2025-01-07
-- WARNING: This is wide open! Only for development/early stage
-- ============================================================================

BEGIN;

-- ============================================================================
-- Grant all permissions to all Supabase roles
-- ============================================================================

-- Grant on all existing tables
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;

-- Grant on all sequences (for BIGSERIAL)
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- Grant on all functions
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated, service_role;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;

-- ============================================================================
-- Verify grants
-- ============================================================================

DO $$
DECLARE
  table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO table_count
  FROM pg_tables
  WHERE schemaname = 'public';

  RAISE NOTICE 'Granted ALL permissions on % tables to anon, authenticated, service_role', table_count;
END $$;

COMMIT;

SELECT 'Permissive grants applied successfully' AS status;
