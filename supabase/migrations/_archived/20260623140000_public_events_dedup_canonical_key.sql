-- Phase 0: public_events de-duplication + canonical natural key
--
-- Foundation for an automated race-catalog refresh routine. Today there is no
-- reliable uniqueness key: the partial index on (source, external_id) cannot
-- catch the duplicates that actually occur, because the same race is ingested
-- from different sources with different external_id formats (e.g.
-- halfmarathonsearch/austin-half-2026 vs manual/austin_half_2026), and many
-- manually-seeded rows have external_id = NULL. Result: 90+ duplicate groups.
--
-- This migration establishes (lower(event_name), event_date, lower(city)) as
-- the CANONICAL uniqueness key — the natural identity of a race occurrence —
-- so a recurring refresh routine can UPSERT (ON CONFLICT) without ever creating
-- duplicates. City is included so same-name/same-date races in different cities
-- (e.g. Turkey Trots) remain distinct. Verified: no current duplicate group
-- spans more than one city, so de-duplication cannot merge distinct events.
--
-- Idempotent: re-running deletes nothing new, backfills nothing new, and the
-- index already exists.

-- 1. De-duplicate. Keep ONE row per canonical key — preferring a row that
--    already has an external_id (more traceable), then the lowest id — and
--    delete the rest.
DELETE FROM public.public_events pe
USING (
  SELECT id,
         row_number() OVER (
           PARTITION BY lower(event_name), event_date, lower(coalesce(city, ''))
           ORDER BY (external_id IS NULL), id
         ) AS rn
  FROM public.public_events
) ranked
WHERE pe.id = ranked.id
  AND ranked.rn > 1;

-- 2. Backfill missing external_id with a deterministic slug (name-city-date) so
--    every row is traceable and refreshable. City keeps it unique across
--    same-name/same-date races in different cities.
UPDATE public.public_events
SET external_id =
      lower(regexp_replace(event_name, '[^a-zA-Z0-9]+', '-', 'g'))
      || '-' || lower(regexp_replace(coalesce(city, 'na'), '[^a-zA-Z0-9]+', '-', 'g'))
      || '-' || to_char(event_date, 'YYYY-MM-DD')
WHERE external_id IS NULL
  AND event_date IS NOT NULL;

-- 3. Canonical uniqueness guard. A FULL (non-partial) unique index the refresh
--    routine can ON CONFLICT against. Creates cleanly now that dups are gone.
CREATE UNIQUE INDEX IF NOT EXISTS public_events_canonical_key_uniq
  ON public.public_events (lower(event_name), event_date, lower(coalesce(city, '')));
