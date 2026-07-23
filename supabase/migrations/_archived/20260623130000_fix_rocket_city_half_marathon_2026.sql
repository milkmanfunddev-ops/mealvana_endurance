-- Fix 2026 Rocket City Half Marathon data quality (follow-up to 387e3fdb).
-- The half was seeded by 20260302110000 as TWO duplicate rows, both with a
-- 07:00 start time. The official Rocket City Marathon FAQ confirms the half
-- runs Sunday 2026-12-13 at 9:00 AM. This migration:
--   1. removes the duplicate row (keeps the earliest id), and
--   2. corrects the start time to 09:00.
-- Idempotent: the DELETE is a no-op once deduped; the UPDATE re-sets 09:00.

-- 1. De-duplicate: keep the lowest id for the 2026 half marathon.
DELETE FROM public.public_events
WHERE event_name = 'Rocket City Half Marathon'
  AND event_date = '2026-12-13'
  AND id > (
    SELECT min(id) FROM public.public_events
    WHERE event_name = 'Rocket City Half Marathon'
      AND event_date = '2026-12-13'
  );

-- 2. Correct the start time (official: 9:00 AM Sunday).
UPDATE public.public_events
SET start_time = '09:00:00'
WHERE event_name = 'Rocket City Half Marathon'
  AND event_date = '2026-12-13';
