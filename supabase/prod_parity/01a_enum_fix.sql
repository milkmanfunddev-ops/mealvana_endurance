-- ============================================================================
-- STEP 1A: ENUM FIX (must run OUTSIDE transaction)
-- ============================================================================
-- Run on: PRODUCTION Supabase SQL Editor
-- IMPORTANT: ALTER TYPE ... ADD VALUE cannot run inside a transaction.
-- Run this ALONE, before anything else.
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumtypid = 'activity_status_enum'::regtype
      AND enumlabel = 'archived_for_brick'
  ) THEN
    ALTER TYPE activity_status_enum ADD VALUE 'archived_for_brick';
  END IF;
END $$;
