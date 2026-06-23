-- Rocket City Marathon 2026 race-weekend events
-- Bug 387e3fdb: full Rocket City Marathon missing from race search — only the
-- half marathon surfaced. Root cause: a DATA GAP, not a code bug. The search
-- function search_public_events_hybrid filters `event_date >= today_date`. The
-- original Rocket City seed (20251213205711) dated every event to December 2025,
-- so all of those are now past and filtered out. A later migration
-- (20260302110000_populate_southeast_half_marathons) re-added ONLY the 2026
-- Rocket City HALF Marathon (2026-12-13). The full marathon, early-start
-- marathon, 10K, 5K, and 1-mile were never re-added for 2026.
--
-- This migration adds the missing 2026 race-weekend events. The 2026 Half
-- Marathon already exists (2026-12-13) and is intentionally NOT re-added here.
--
-- Race weekend mirrors the 2025 layout: Saturday = 10K/5K/1mi, Sunday = full
-- marathon (+ early start) and the half. 2026-12-13 is a Sunday (matches the
-- existing half row); the Saturday events use 2026-12-12.
-- ⚠️ If the official 2026 race-weekend dates differ, adjust the dates below.
--
-- Idempotent: each row is guarded by NOT EXISTS on (event_name, event_date), so
-- re-running is safe. (public_events has no usable natural unique key for
-- ON CONFLICT — the only unique index is partial on (source, external_id)
-- WHERE external_id IS NOT NULL, and these rows leave external_id NULL.)

INSERT INTO public.public_events (
  event_name, event_type, event_subtype, location, city, state, country,
  event_date, start_time, registration_url, website_url, description,
  organizer_name, is_active, source
)
SELECT
  v.event_name, v.event_type, v.event_subtype, v.location, v.city, v.state,
  v.country, v.event_date, v.start_time, v.registration_url, v.website_url,
  v.description, v.organizer_name, v.is_active, v.source
FROM (VALUES
  -- Saturday, December 12, 2026
  (
    'Rocket City 10K', 'running'::activity_type_enum, '10k'::event_subtype_enum,
    'Downtown Huntsville', 'Huntsville', 'AL', 'USA',
    DATE '2026-12-12', TIME '07:00:00',
    'https://www.rocketcitymarathon.run/register', 'https://www.rocketcitymarathon.run',
    'The 10K starts at 7:00 AM in front of the Von Braun Center on Monroe Street, part of the Rocket City Marathon race weekend.',
    'Rocket City Marathon', true, 'manual_entry'
  ),
  (
    'Rocket City 5K', 'running'::activity_type_enum, '5k'::event_subtype_enum,
    'Downtown Huntsville', 'Huntsville', 'AL', 'USA',
    DATE '2026-12-12', TIME '09:00:00',
    'https://www.rocketcitymarathon.run/register', 'https://www.rocketcitymarathon.run',
    'The 5K begins at 9:00 AM, winding through Downtown Huntsville, part of the Rocket City Marathon race weekend.',
    'Rocket City Marathon', true, 'manual_entry'
  ),
  (
    'Rocket City 1 Mile Family Run/Walk', 'running'::activity_type_enum, '1k'::event_subtype_enum,
    'Downtown Huntsville', 'Huntsville', 'AL', 'USA',
    DATE '2026-12-12', TIME '10:30:00',
    'https://www.rocketcitymarathon.run/register', 'https://www.rocketcitymarathon.run',
    'The 1 Mile Family Run/Walk starts at 10:30 AM, part of the Rocket City Marathon race weekend.',
    'Rocket City Marathon', true, 'manual_entry'
  ),
  -- Sunday, December 13, 2026
  (
    'Rocket City Marathon (Early Start)', 'running'::activity_type_enum, 'marathon'::event_subtype_enum,
    'Downtown Huntsville', 'Huntsville', 'AL', 'USA',
    DATE '2026-12-13', TIME '06:00:00',
    'https://www.rocketcitymarathon.run/register', 'https://www.rocketcitymarathon.run',
    'Early start option for the full marathon at 6:00 AM for those requiring extra time. The race includes running past the U.S. Space and Rocket Center to run beside rockets and the space shuttle, and through the Huntsville Botanical Gardens. All races start and finish in Downtown Huntsville at the VBC.',
    'Rocket City Marathon', true, 'manual_entry'
  ),
  (
    'Rocket City Marathon', 'running'::activity_type_enum, 'marathon'::event_subtype_enum,
    'Downtown Huntsville', 'Huntsville', 'AL', 'USA',
    DATE '2026-12-13', TIME '07:00:00',
    'https://www.rocketcitymarathon.run/register', 'https://www.rocketcitymarathon.run',
    'The full marathon starts at 7:00 AM. The race includes running past the U.S. Space and Rocket Center to run beside rockets and the space shuttle, and through the Huntsville Botanical Gardens. All races start and finish in Downtown Huntsville at the VBC.',
    'Rocket City Marathon', true, 'manual_entry'
  )
) AS v (
  event_name, event_type, event_subtype, location, city, state, country,
  event_date, start_time, registration_url, website_url, description,
  organizer_name, is_active, source
)
WHERE NOT EXISTS (
  SELECT 1 FROM public.public_events p
  WHERE p.event_name = v.event_name AND p.event_date = v.event_date
);
