-- =====================================================
-- Phase 0 Authentication Migration - Complete
-- =====================================================
-- Purpose: Add Supabase authentication support to v1 schema
--          Links public.users to auth.users (Supabase-managed)
--
-- Architecture:
-- - auth.users: Managed by Supabase Auth (don't touch)
-- - public.users: Our app data, linked via auth_user_id
-- - Sessions: Managed by Supabase SDK (stored in platform secure storage)
--
-- Changes:
-- 1. Create auth_provider_enum type
-- 2. Add auth columns to public.users table
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
-- 2. ADD AUTH COLUMNS TO public.users TABLE
-- =====================================================

-- Add auth_user_id column - links to auth.users.id
-- Nullable for gradual migration from device_id to auth_user_id
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

-- Add auth_provider column with enum type
-- Tracks which OAuth provider the user authenticated with
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'auth_provider'
  ) THEN
    ALTER TABLE users ADD COLUMN auth_provider TEXT NOT NULL DEFAULT 'anonymous';
  END IF;
END $$;

-- Add is_anonymous column
-- TRUE for anonymous users, FALSE after linking to email/google/apple
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

-- Convert auth_provider column from TEXT to ENUM type
-- Handles case where column was already created as TEXT
DO $$
BEGIN
  -- Check if column is TEXT type (needs conversion)
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

    -- Drop the default, convert type, set new default
    ALTER TABLE users ALTER COLUMN auth_provider DROP DEFAULT;
    ALTER TABLE users
      ALTER COLUMN auth_provider TYPE auth_provider_enum
      USING auth_provider::auth_provider_enum;
    ALTER TABLE users ALTER COLUMN auth_provider SET DEFAULT 'anonymous'::auth_provider_enum;
  END IF;
END $$;

-- Create index on auth_user_id for fast lookups
-- Used to find user data by Supabase auth.users.id
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id
  ON users(auth_user_id);

-- Create index on auth_provider for filtering
-- Used for analytics and provider-specific queries
CREATE INDEX IF NOT EXISTS idx_users_auth_provider
  ON users(auth_provider);

-- =====================================================
-- 3. ADD FOREIGN KEY TO auth.users (Optional)
-- =====================================================
-- Uncomment if you want to enforce referential integrity
-- This requires auth.users to exist (it's created by Supabase)
--
-- DO $$
-- BEGIN
--   IF NOT EXISTS (
--     SELECT 1 FROM pg_constraint
--     WHERE conname = 'users_auth_user_id_fkey'
--   ) THEN
--     ALTER TABLE users
--       ADD CONSTRAINT users_auth_user_id_fkey
--       FOREIGN KEY (auth_user_id) REFERENCES auth.users(id)
--       ON DELETE CASCADE;
--   END IF;
-- END $$;

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
SELECT 'public.users.auth_provider column info:' as info;
SELECT
  table_name,
  column_name,
  data_type,
  udt_name,
  column_default
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name = 'auth_provider';

-- Show auth columns in users table
SELECT 'Auth columns in public.users:' as info;
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name IN ('auth_user_id', 'auth_provider', 'is_anonymous')
ORDER BY column_name;

-- =====================================================
-- MIGRATION NOTES
-- =====================================================
--
-- ARCHITECTURE:
-- - auth.users (Supabase-managed): Canonical authentication table
-- - public.users (our table): App data linked via auth_user_id
-- - Sessions: Handled by Supabase SDK (no custom table needed)
--
-- IMPORTANT: This migration is NON-DESTRUCTIVE and IDEMPOTENT
-- - Safe to run multiple times
-- - All existing data remains intact
-- - device_id remains the primary identifier during transition
-- - auth_user_id is nullable to support gradual migration
-- - Handles TEXT to ENUM conversion by dropping/recreating default
--
-- SESSION MANAGEMENT:
-- - Supabase SDK stores sessions in platform secure storage
-- - iOS: Keychain, Android: KeyStore
-- - Sessions persist across app restarts
-- - Auto-refresh before expiry (access: 1hr, refresh: 7 days)
-- - No custom auth_sessions table needed
--
-- ROLLBACK PLAN (if needed):
-- ALTER TABLE users DROP COLUMN IF EXISTS auth_user_id;
-- ALTER TABLE users DROP COLUMN IF EXISTS auth_provider;
-- ALTER TABLE users DROP COLUMN IF EXISTS is_anonymous;
-- DROP INDEX IF EXISTS idx_users_auth_user_id;
-- DROP INDEX IF EXISTS idx_users_auth_provider;
-- DROP TYPE IF EXISTS auth_provider_enum;
--
-- NEXT STEPS (Phase 1):
-- 1. Implement anonymous auth as default onboarding
-- 2. Create account linking flow (anonymous → email/OAuth)
-- 3. Migrate existing device_id users to anonymous auth
-- 4. Update RLS policies to use auth.uid()
-- =====================================================
