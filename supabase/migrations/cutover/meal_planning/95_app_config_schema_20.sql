-- =====================================================================
-- Meal planning (Vana) — app_config schema-version bump to 20.
--
-- ⚠️  RUN LAST, AND ONLY AFTER the 1.24.x binary carrying Drift v20 is LIVE
-- on the App Store / Play. Not with the DDL.
--
-- ⚠️  PROD app_config is written ONLY at Xuan's explicit direction, in
-- default (non-auto) permission mode, after the read-only check below —
-- docs/deployment/supabase-deploy-playbook.md §7.
--
-- Why it is safe to be late and unsafe to be early: VersionCheckService
-- treats `latest_schema_version` as the target and
-- `min_supported_schema_version` as the floor. With the compatibility window
-- enabled (both keys present), a client whose local Drift schema is below
-- latest but at or above the floor is simply OK — it does not resync. So
-- bumping late costs nothing, while bumping before the binary ships tells
-- nobody anything and only muddies the ledger.
--
-- The floor is NOT moved: this release is additive, no force-update.
-- =====================================================================

-- 1. Read first. Paste the result into the runbook status header.
select key, value from public.app_config
 where key in ('current_schema_version', 'latest_schema_version',
               'min_supported_schema_version', 'min_app_version')
 order by key;

-- 2. Then, and only then, the write (idempotent).
-- update public.app_config set value = '20' where key = 'current_schema_version';
-- update public.app_config set value = '20' where key = 'latest_schema_version';

-- 3. Re-read to confirm.
-- select key, value from public.app_config
--  where key in ('current_schema_version', 'latest_schema_version') order by key;
