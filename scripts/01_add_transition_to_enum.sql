-- ============================================================================
-- Script 1 of 2: Add 'transition' to activity_type_enum
-- Run this FIRST, then run script 2
-- Date: 2026-01-23
-- ============================================================================

-- Add 'transition' to activity_type_enum
-- Current enum: running, cycling, swimming, triathlon, duathlon, multisport, brick
ALTER TYPE activity_type_enum ADD VALUE IF NOT EXISTS 'transition';

-- Verify it was added
SELECT enumlabel FROM pg_enum
WHERE enumtypid = 'activity_type_enum'::regtype
ORDER BY enumsortorder;
