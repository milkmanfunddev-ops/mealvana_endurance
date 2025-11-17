-- =====================================================
-- Phase 0 Authentication Migration Script
-- =====================================================
-- Purpose: Add Supabase authentication support to v1 schema
--
-- Changes:
-- 1. Create auth_sessions table for offline session persistence
-- 2. Add auth columns to users table for authentication integration
--
-- Environment: Production (Supabase PostgreSQL)
-- Schema Version: v1 (staying on v1, not bumping to v2)
-- =====================================================

-- =====================================================
-- 1. CREATE auth_sessions TABLE
-- =====================================================
-- Purpose: Custom session persistence to work around Supabase offline
--          limitations (Issue #716). Enables 24-hour offline grace period.
-- =====================================================

CREATE TABLE IF NOT EXISTS auth_sessions (
  -- Primary key: User ID from Supabase auth.uid()
  user_id UUID PRIMARY KEY,

  -- JWT tokens for authentication
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,

  -- Metadata from Supabase auth
  user_metadata JSONB NOT NULL DEFAULT '{}',
  app_metadata JSONB NOT NULL DEFAULT '{}',

  -- Sync tracking
  last_synced_at TIMESTAMPTZ,

  -- User type and provider tracking
  is_anonymous BOOLEAN NOT NULL DEFAULT TRUE,
  provider TEXT NOT NULL DEFAULT 'anonymous',

  -- User contact info (nullable for anonymous users)
  email TEXT,
  phone TEXT,

  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT auth_sessions_provider_check
    CHECK (provider IN ('anonymous', 'email', 'google', 'apple'))
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires_at
  ON auth_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_provider
  ON auth_sessions(provider);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_auth_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auth_sessions_updated_at_trigger
  BEFORE UPDATE ON auth_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_auth_sessions_updated_at();

-- =====================================================
-- 2. ADD AUTH COLUMNS TO users TABLE
-- =====================================================
-- Purpose: Add authentication columns to support Supabase auth integration
--          while maintaining backward compatibility with device_id
-- =====================================================

-- Add auth_user_id column (nullable for gradual migration)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS auth_user_id UUID;

-- Add auth_provider column with default 'anonymous'
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS auth_provider TEXT NOT NULL DEFAULT 'anonymous';

-- Add is_anonymous column with default TRUE
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN NOT NULL DEFAULT TRUE;

-- Add constraint to validate auth_provider values
ALTER TABLE users
  ADD CONSTRAINT IF NOT EXISTS users_auth_provider_check
    CHECK (auth_provider IN ('anonymous', 'email', 'google', 'apple'));

-- Create index on auth_user_id for lookups
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id
  ON users(auth_user_id);

-- Create index on auth_provider for filtering
CREATE INDEX IF NOT EXISTS idx_users_auth_provider
  ON users(auth_provider);

-- =====================================================
-- MIGRATION NOTES
-- =====================================================
--
-- IMPORTANT: This migration is NON-DESTRUCTIVE
-- - All existing data remains intact
-- - device_id remains the primary identifier during transition
-- - auth_user_id is nullable to support gradual migration
-- - New users will use auth_user_id as canonical ID
-- - Old users will be migrated in Phase 1 (anonymous auth implementation)
--
-- ROLLBACK PLAN (if needed):
-- DROP TABLE IF EXISTS auth_sessions CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS auth_user_id;
-- ALTER TABLE users DROP COLUMN IF EXISTS auth_provider;
-- ALTER TABLE users DROP COLUMN IF EXISTS is_anonymous;
-- DROP INDEX IF EXISTS idx_users_auth_user_id;
-- DROP INDEX IF EXISTS idx_users_auth_provider;
--
-- POST-MIGRATION VALIDATION:
-- 1. Verify auth_sessions table exists: \d auth_sessions
-- 2. Verify users table has new columns: \d users
-- 3. Check constraint: SELECT conname FROM pg_constraint WHERE conrelid = 'users'::regclass;
-- 4. Test session insert/update operations
-- 5. Test anonymous user creation
--
-- NEXT STEPS (Phase 1):
-- 1. Update AuthService to use auth_sessions table
-- 2. Create migration service (device_id → auth_user_id)
-- 3. Update AppStartupService to restore sessions
-- 4. Test 24-hour offline grace period
-- =====================================================
