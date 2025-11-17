-- =====================================================
-- Phase 0 Authentication Migration - Complete
-- =====================================================
-- Purpose: Add Supabase authentication support to v1 schema
--          Safe to run multiple times (idempotent)
--
-- Changes:
-- 1. Create auth_provider_enum type
-- 2. Create auth_sessions table for offline session persistence
-- 3. Add auth columns to users table
--
-- Environment: Production (Supabase PostgreSQL)
-- Schema Version: v1 (staying on v1, not bumping to v2)
-- =====================================================

-- =====================================================
-- 1. CREATE auth_provider_enum TYPE
-- =====================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'auth_provider_enum') THEN
    CREATE TYPE auth_provider_enum AS ENUM ('anonymous', 'email', 'google', 'apple');
  END IF;
END $$;

-- =====================================================
-- 2. CREATE auth_sessions TABLE
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
  provider auth_provider_enum NOT NULL DEFAULT 'anonymous',

  -- User contact info (nullable for anonymous users)
  email TEXT,
  phone TEXT,

  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires_at
  ON auth_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_provider
  ON auth_sessions(provider);

-- Create updated_at trigger function (idempotent)
CREATE OR REPLACE FUNCTION update_auth_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger (idempotent)
DROP TRIGGER IF EXISTS auth_sessions_updated_at_trigger ON auth_sessions;
CREATE TRIGGER auth_sessions_updated_at_trigger
  BEFORE UPDATE ON auth_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_auth_sessions_updated_at();

-- =====================================================
-- 3. ADD AUTH COLUMNS TO users TABLE
-- =====================================================

-- Add auth_user_id column (nullable for gradual migration)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'auth_user_id'
  ) THEN
    ALTER TABLE users ADD COLUMN auth_user_id UUID;
  END IF;
END $$;

-- Add auth_provider column with enum type and default 'anonymous'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'auth_provider'
  ) THEN
    ALTER TABLE users ADD COLUMN auth_provider auth_provider_enum NOT NULL DEFAULT 'anonymous';
  END IF;
END $$;

-- Add is_anonymous column with default TRUE
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'is_anonymous'
  ) THEN
    ALTER TABLE users ADD COLUMN is_anonymous BOOLEAN NOT NULL DEFAULT TRUE;
  END IF;
END $$;

-- Convert auth_provider column to use enum type if it's currently TEXT
DO $$
BEGIN
  -- Check if column exists and is TEXT type
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users'
    AND column_name = 'auth_provider'
    AND data_type = 'text'
  ) THEN
    -- Drop any CHECK constraint if it exists
    IF EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'users_auth_provider_check'
    ) THEN
      ALTER TABLE users DROP CONSTRAINT users_auth_provider_check;
    END IF;

    -- Convert TEXT to ENUM
    ALTER TABLE users
      ALTER COLUMN auth_provider TYPE auth_provider_enum
      USING auth_provider::auth_provider_enum;
  END IF;
END $$;

-- Convert auth_sessions.provider to enum if needed
DO $$
BEGIN
  -- Check if column exists and is TEXT type
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'auth_sessions'
    AND column_name = 'provider'
    AND data_type = 'text'
  ) THEN
    -- Drop any CHECK constraint if it exists
    IF EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = 'auth_sessions_provider_check'
    ) THEN
      ALTER TABLE auth_sessions DROP CONSTRAINT auth_sessions_provider_check;
    END IF;

    -- Convert TEXT to ENUM
    ALTER TABLE auth_sessions
      ALTER COLUMN provider TYPE auth_provider_enum
      USING provider::auth_provider_enum;
  END IF;
END $$;

-- Create index on auth_user_id for lookups
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id
  ON users(auth_user_id);

-- Create index on auth_provider for filtering
CREATE INDEX IF NOT EXISTS idx_users_auth_provider
  ON users(auth_provider);

-- =====================================================
-- VALIDATION QUERIES
-- =====================================================

-- Check enum type exists
SELECT 'auth_provider_enum values:' as info;
SELECT enumlabel as value
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE typname = 'auth_provider_enum'
ORDER BY enumlabel;

-- Verify users.auth_provider is using enum
SELECT 'users.auth_provider column info:' as info;
SELECT
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name = 'auth_provider';

-- Verify auth_sessions.provider is using enum
SELECT 'auth_sessions.provider column info:' as info;
SELECT
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'auth_sessions'
  AND column_name = 'provider';

-- =====================================================
-- MIGRATION NOTES
-- =====================================================
--
-- IMPORTANT: This migration is NON-DESTRUCTIVE and IDEMPOTENT
-- - Safe to run multiple times
-- - All existing data remains intact
-- - device_id remains the primary identifier during transition
-- - auth_user_id is nullable to support gradual migration
-- - Handles TEXT to ENUM conversion if needed
--
-- ROLLBACK PLAN (if needed):
-- DROP TABLE IF EXISTS auth_sessions CASCADE;
-- ALTER TABLE users DROP COLUMN IF EXISTS auth_user_id;
-- ALTER TABLE users DROP COLUMN IF EXISTS auth_provider;
-- ALTER TABLE users DROP COLUMN IF EXISTS is_anonymous;
-- DROP INDEX IF EXISTS idx_users_auth_user_id;
-- DROP INDEX IF EXISTS idx_users_auth_provider;
-- DROP TYPE IF EXISTS auth_provider_enum;
--
-- NEXT STEPS (Phase 1):
-- 1. Update AuthService to use auth_sessions table
-- 2. Create migration service (device_id → auth_user_id)
-- 3. Update AppStartupService to restore sessions
-- 4. Test 24-hour offline grace period
-- =====================================================
