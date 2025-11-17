-- =====================================================
-- Phase 0 Authentication Migration - ENUM Fix
-- =====================================================
-- Purpose: Replace CHECK constraint with proper ENUM type
-- Run this AFTER the initial migration to fix auth_provider
-- =====================================================

-- 1. Create auth_provider_enum type
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'auth_provider_enum') THEN
    CREATE TYPE auth_provider_enum AS ENUM ('anonymous', 'email', 'google', 'apple');
  END IF;
END $$;

-- 2. Update users table to use enum
DO $$
BEGIN
  -- Drop the CHECK constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_auth_provider_check'
  ) THEN
    ALTER TABLE users DROP CONSTRAINT users_auth_provider_check;
  END IF;

  -- Alter column to use enum type
  -- This converts existing TEXT values to ENUM
  ALTER TABLE users
    ALTER COLUMN auth_provider TYPE auth_provider_enum
    USING auth_provider::auth_provider_enum;
END $$;

-- 3. Update auth_sessions table to use enum
DO $$
BEGIN
  -- Drop the CHECK constraint if it exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'auth_sessions_provider_check'
  ) THEN
    ALTER TABLE auth_sessions DROP CONSTRAINT auth_sessions_provider_check;
  END IF;

  -- Alter column to use enum type
  ALTER TABLE auth_sessions
    ALTER COLUMN provider TYPE auth_provider_enum
    USING provider::auth_provider_enum;
END $$;

-- =====================================================
-- VALIDATION
-- =====================================================
-- Verify the enum type was created and columns updated

-- Check enum type exists
SELECT typname, enumlabel
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE typname = 'auth_provider_enum'
ORDER BY enumlabel;

-- Verify users.auth_provider is using enum
SELECT
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'users'
  AND column_name = 'auth_provider';

-- Verify auth_sessions.provider is using enum
SELECT
  table_name,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns
WHERE table_name = 'auth_sessions'
  AND column_name = 'provider';

-- =====================================================
-- SUCCESS!
-- =====================================================
-- auth_provider_enum created with values:
--   - anonymous
--   - email
--   - google
--   - apple
--
-- Both tables now use proper ENUM type instead of TEXT + CHECK constraint
-- =====================================================
