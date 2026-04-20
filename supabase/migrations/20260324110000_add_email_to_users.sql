-- Add email column to public.users table
-- Captures user's email for Wiredash feedback prefill and profile display
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email text;
