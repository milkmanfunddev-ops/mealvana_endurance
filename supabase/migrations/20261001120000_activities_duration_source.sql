-- P3 (ruled 2026-09-30): provenance for an importer-derived duration.
--
-- The importer estimates a duration for a synced workout that arrives with a
-- distance but no duration (FinalSurge sends distance-only plans), so that a
-- genuinely long workout becomes nudge-eligible instead of silently missing
-- the 90-minute threshold. This column records that the number is ours.
--
-- ONLY EVER WRITTEN AS 'estimated'. NULL means authoritative — provider-
-- supplied, athlete-entered, or predating this column. That asymmetry is the
-- design, not an omission: the three ruled clauses ("mark it estimated",
-- "never overwrite a provider or athlete duration", "re-estimate only while
-- still estimated") all reduce to `duration_source = 'estimated'`, so nothing
-- needs back-filling and no existing row changes meaning.
--
-- Additive and nullable, so it is safe to apply at any time and in either
-- order relative to the app release: an older client never selects it, a newer
-- client does not require it.
--
-- DRIFT VERSION: 21 -> 22, not 20 -> 21. v21 is reserved as a no-op upgrade
-- step because develop already spends it on the Vana tables; shipping this as
-- v21 would make `from == to` for a develop-built client, skip onUpgrade
-- entirely, and trip the local-DB wipe (the July 2026 DEV-60/61 failure).
--
-- This column implies no resync of its own. The `app_config` pointers still
-- move to 22 at P7 step 1 for hygiene (§7: `current` should equal the shipped
-- Drift version); clients on 20 or 21 stay inside the compatibility window
-- because min_supported_schema_version is far below them, so they read `ok`
-- rather than resyncing. Nothing here touches the support floor.
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS duration_source TEXT;

COMMENT ON COLUMN public.activities.duration_source IS
  'Only ever ''estimated'' (importer-derived from distance x usual pace). NULL = authoritative: provider, athlete, or legacy. Never overwrite a row whose duration_source is not ''estimated''.';
