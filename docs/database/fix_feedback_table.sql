-- URGENT FIX: Change reuse_intent from INTEGER to TEXT
-- Run this in your Supabase SQL Editor to fix the data type mismatch

-- Step 1: Change the column type from INTEGER to TEXT
ALTER TABLE public.feedback ALTER COLUMN reuse_intent TYPE TEXT;

-- That's it! The column will now accept string values like 'yes', 'maybe', 'no'