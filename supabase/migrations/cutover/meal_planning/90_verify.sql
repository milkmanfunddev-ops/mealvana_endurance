-- =====================================================================
-- Meal planning (Vana) — PROD post-apply verification. READ-ONLY.
--
-- Run after `supabase db push` and after the meal_library seed. Every
-- assertion is a boolean/count in one row so the whole result can be pasted
-- into the runbook's status header.
-- =====================================================================
select
  -- ---- structure ---------------------------------------------------
  to_regclass('public.meal_library')        is not null as t_meal_library,
  to_regclass('public.meal_plans')          is not null as t_meal_plans,
  to_regclass('public.plan_meals')          is not null as t_plan_meals,
  -- `plan_days` is NOT a table: 20260827130000 stores the day planner as
  -- `meal_plans.days jsonb`. Its `meal_plans_active_week` index was DROPPED
  -- by 20260831150000 (one draft per conversation) and replaced with
  -- `meal_plans_confirmed_week` — one CONFIRMED plan per athlete-week.
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'meal_plans'
      and column_name = 'days')                           = 1 as meal_plans_has_days,
  to_regclass('public.meal_plans_confirmed_week') is not null as ix_confirmed_week,
  to_regclass('public.meal_plans_active_week')    is null     as ix_active_week_dropped,
  to_regclass('public.user_memories')       is not null as t_user_memories,
  to_regclass('public.user_entitlements')   is not null as t_user_entitlements,
  to_regclass('public.meal_feedback')       is not null as t_meal_feedback,
  to_regclass('public.vana_conversations')  is not null as t_vana_conversations,
  to_regclass('public.vana_messages')       is not null as t_vana_messages,
  to_regclass('public.vana_calls')          is not null as t_vana_calls,

  -- The compat views the SHIPPED 1.23.x app still reads. If any of these is
  -- not a view ('v'), the live app's chat is broken — this is the single
  -- most important line in this file.
  (select relkind from pg_class where oid = to_regclass('public.jade_conversations')) as jade_conversations_relkind,
  (select relkind from pg_class where oid = to_regclass('public.jade_messages'))      as jade_messages_relkind,
  (select relkind from pg_class where oid = to_regclass('public.jade_calls'))         as jade_calls_relkind,
  (select count(*) from public.jade_conversations)                                    as jade_conversations_readable,

  -- ---- RPCs the edge functions and the Dart repositories call --------
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'search_meals', 'match_library', 'recall_memories', 'library_pair_support',
        'set_meal_feedback', 'confirm_meal_plan', 'plan_log_from_plan',
        'has_entitlement', 'refresh_meal_library_pairs'
      ))                                                                              as rpc_count,

  -- ---- cascade safety: every new user-owned table must cascade from
  -- users(id), or delete-user leaves orphans behind.
  (select count(*) from pg_constraint c
     join pg_class t on t.oid = c.conrelid
    where c.contype = 'f' and c.confdeltype = 'c'
      and t.relname in ('meal_plans', 'user_memories', 'user_entitlements', 'meal_feedback'))
                                                                                      as cascading_fks,

  -- ---- seed ---------------------------------------------------------
  (select count(*) from public.meal_library)                                          as library_rows,
  (select count(*) from public.meal_library where embedding is not null)              as library_embedded,
  (select count(*) from public.meal_library where kind = 'assembly')                  as library_assemblies,
  (select count(*) from public.meal_library where kind = 'recipe')                    as library_recipes,
  (select count(*) from public.meal_library where method_steps is not null)           as library_with_steps,
  (select count(*) from public.meal_library_pairs)                                    as library_pairs,

  -- ---- RLS is on for every new table (a table without RLS is world-readable)
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relrowsecurity
      and c.relname in ('meal_plans', 'plan_meals', 'user_memories',
                        'user_entitlements', 'meal_feedback', 'vana_conversations',
                        'vana_messages', 'vana_calls'))                               as rls_enabled_tables;

-- Expected on a clean apply — the numbers below were MEASURED on dev
-- (vlmtsdzpnjnavdgytcmi) on 2026-09-02, not assumed:
--   every t_* true; meal_plans_has_days true; ix_confirmed_week true;
--   ix_active_week_dropped true (20260831150000 replaces the older index);
--   all three *_relkind = 'v'; rpc_count = 9; cascading_fks = 6;
--   rls_enabled_tables = 8 (eight tables — see the plan_days note above);
--   library_rows = 1922, library_embedded = 1922, library_with_steps = 1922,
--   library_assemblies = 1675, library_recipes = 247, library_pairs = 8106.
--
-- The library counts are the dev snapshot's, so they hold only if prod was
-- seeded from `data/meal-library.snapshot.json` (06 §3). A prod re-scrape
-- would legitimately differ; a SHORTFALL never is — it means the seed
-- stopped early and `refresh_meal_library_pairs()` ran on a partial table.
