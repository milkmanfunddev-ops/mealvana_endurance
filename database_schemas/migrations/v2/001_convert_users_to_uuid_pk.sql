-- ============================================================================
-- Migration 001: Convert users.id to UUID Primary Key
-- ============================================================================
-- Description: Ensure users.id is UUID (already is, but standardize)
-- Date: 2025-01-07
-- ============================================================================

BEGIN;

-- Users table already has UUID primary key, but let's verify and clean up
-- Check current structure
DO $$
DECLARE
  users_id_type TEXT;
BEGIN
  SELECT data_type INTO users_id_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'id';

  IF users_id_type = 'uuid' THEN
    RAISE NOTICE 'users.id is already UUID - migration is idempotent';
  ELSE
    RAISE EXCEPTION 'users.id is not UUID! Expected uuid, got %', users_id_type;
  END IF;
END $$;

-- Ensure device_id remains UNIQUE and NOT NULL (for current auth)
ALTER TABLE public.users
  ALTER COLUMN device_id SET NOT NULL;

-- Add constraint if not exists
DO $$ BEGIN
  ALTER TABLE public.users
    ADD CONSTRAINT users_device_id_unique UNIQUE (device_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Add index for faster device_id lookups (should already exist)
CREATE INDEX IF NOT EXISTS idx_users_device_id ON public.users (device_id);

-- Add comments
COMMENT ON COLUMN public.users.id IS 'Primary key - canonical user identifier (UUID)';
COMMENT ON COLUMN public.users.device_id IS 'Device identifier for current device-based authentication';

COMMIT;

SELECT 'users.id verified as UUID primary key' AS status;
