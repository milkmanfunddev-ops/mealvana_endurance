-- public_events data-quality cleanup (refresh-routine maintenance).
--
-- 1. Delete past-dated events. They never appear in search (the function filters
--    `is_active = true AND event_date >= today`) and nothing references
--    public_events (no FKs), so they are pure dead weight in a race-PLANNING
--    catalog. Recurring races get their next occurrence re-added by the routine.
-- 2. De-duplicate the "<Race> YYYY" naming antipattern: where a race exists both
--    with a year suffix and without (same date+city), drop the year-suffixed
--    duplicate, keeping the clean one.
-- 3. Strip the trailing " YYYY" suffix from any remaining names so naming is
--    consistent (e.g. "Boston Marathon 2026" -> "Boston Marathon"). The canonical
--    key includes event_date, so distinct years stay distinct rows.
--
-- Idempotent.

-- 1. Past-dated.
DELETE FROM public.public_events WHERE event_date < now()::date;

-- 2. Drop year-suffixed duplicates that have a clean sibling at the same
--    (normalized name, date, city).
DELETE FROM public.public_events pe
USING public.public_events keep
WHERE pe.event_name ~ '\s+(19|20)[0-9]{2}$'
  AND keep.id <> pe.id
  AND keep.event_date = pe.event_date
  AND lower(coalesce(keep.city, '')) = lower(coalesce(pe.city, ''))
  AND lower(keep.event_name) = lower(regexp_replace(pe.event_name, '\s+(19|20)[0-9]{2}$', ''));

-- 3. Strip the year suffix from the survivors.
UPDATE public.public_events
SET event_name = regexp_replace(event_name, '\s+(19|20)[0-9]{2}$', '')
WHERE event_name ~ '\s+(19|20)[0-9]{2}$';
