-- =====================================================================
-- Meal planning (Vana) — PROD pre-check. READ-ONLY: run this first and read
-- the row before applying anything (06-sync-schema-envs.md §"Prod DDL").
--
-- Prod ref wvmvsodrvbkxfydabqed · dev ref vlmtsdzpnjnavdgytcmi.
--
-- Every column below must read as documented in ../README.md §"Expected
-- pre-check answer". A different answer means prod drifted since
-- 2026-09-02 and the runbook needs re-deriving, not overriding.
-- =====================================================================
select
  -- Extensions. pgvector is NOT installed on prod as of 2026-09-02; the
  -- first migration creates it (`create extension if not exists vector`),
  -- which needs the migration to run as the owner/superuser role — this is
  -- why the apply goes through `supabase db push`, not the SQL editor.
  (select installed_version is not null from pg_available_extensions where name = 'vector')  as has_pgvector,
  (select installed_version is not null from pg_available_extensions where name = 'pg_trgm') as has_pg_trgm,

  -- Enum parity with dev. `meal_library.diets_ok` / `.allergens` are arrays
  -- of these, so a mismatch is a hard stop, not a warning.
  (select string_agg(e.enumlabel, ',' order by e.enumsortorder)
     from pg_type t join pg_enum e on e.enumtypid = t.oid
    where t.typname = 'dietary_preference_enum')                                             as diet_enum,
  (select string_agg(e.enumlabel, ',' order by e.enumsortorder)
     from pg_type t join pg_enum e on e.enumtypid = t.oid
    where t.typname = 'allergy_enum')                                                        as allergy_enum,

  -- Objects the apply creates. All must be false/absent before the run.
  to_regclass('public.vana_conversations') is not null                                       as has_vana_conversations,
  to_regclass('public.meal_library')       is not null                                       as has_meal_library,
  to_regclass('public.meal_plans')         is not null                                       as has_meal_plans,
  to_regclass('public.plan_meals')         is not null                                       as has_plan_meals,
  to_regclass('public.user_memories')      is not null                                       as has_user_memories,
  to_regclass('public.user_entitlements')  is not null                                       as has_user_entitlements,

  -- The jade_* tables the 20260827120000 migration RENAMES. They must still
  -- be real TABLES here: if they are already views, a previous partial apply
  -- ran and the rename branch will no-op, leaving the views pointing at
  -- nothing. `relkind` r = table, v = view.
  (select relkind from pg_class where oid = to_regclass('public.jade_conversations'))        as jade_conversations_relkind,
  (select count(*) from public.jade_conversations)                                           as jade_conversation_rows,
  (select count(*) from public.jade_messages)                                                as jade_message_rows,

  -- Out-of-band drift found on 2026-09-02: `plan_recalc_log` exists on prod
  -- but is NOT in the migration ledger, and `activities` has `deleted_at`
  -- but not `planned_time`/`actual_time`. Both 2026-08-14 migrations are
  -- idempotent and ride along with this push — see ../README.md §"What else
  -- this push carries".
  to_regclass('public.plan_recalc_log') is not null                                          as has_plan_recalc_log,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'activities'
      and column_name in ('planned_time', 'actual_time'))                                    as activities_two_time_cols,

  -- app_config, so the schema-version bump in 95_ is made against what is
  -- actually there rather than what the last runbook said.
  (select value from public.app_config where key = 'current_schema_version')                 as current_schema_version,
  (select value from public.app_config where key = 'latest_schema_version')                  as latest_schema_version,
  (select value from public.app_config where key = 'min_supported_schema_version')           as min_supported_schema_version,
  (select value from public.app_config where key = 'min_app_version')                        as min_app_version;
