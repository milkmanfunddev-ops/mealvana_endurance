-- Add auth_skipped_at column to track when a user explicitly skipped authentication.
-- This supports anonymous reminder flows across devices.

alter table public.users
  add column if not exists auth_skipped_at timestamp with time zone;
