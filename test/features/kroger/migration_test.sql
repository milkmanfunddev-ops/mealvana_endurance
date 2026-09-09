-- Run ONLY against a new, disposable PostgreSQL instance (see docs/kroger/TESTING.md).
\set ON_ERROR_STOP on
begin;
create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
create table public.meal_plans (id uuid primary key, user_id uuid not null, is_deleted boolean not null default false);
insert into auth.users values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), ('cccccccc-cccc-4ccc-8ccc-cccccccccccc');
insert into public.meal_plans values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', false);
\ir ../../../supabase/migrations/20260907120000_kroger_shopping.sql
-- Reapplying must also succeed without changing data/grants semantics.
\ir ../../../supabase/migrations/20260907120000_kroger_shopping.sql
set role authenticated;
set request.jwt.claim.sub = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
do $$
declare n integer;
begin
  n := public.save_kroger_draft('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 0, '{"planId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","lines":[]}');
  assert n = 1, 'first revision';
  n := public.save_kroger_draft('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 1, '{"planId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","lines":[]}');
  assert n = 2, 'second revision';
  begin
    perform public.save_kroger_draft('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 1, '{"planId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}');
    raise exception 'stale revision accepted';
  exception when raise_exception then
    if sqlerrm <> 'draft_conflict' then raise; end if;
  end;
  assert (select count(*) from public.kroger_drafts) = 1, 'owner can read draft';
  assert not has_table_privilege(current_user, 'public.kroger_connections', 'SELECT'), 'tokens inaccessible';
  assert not has_table_privilege(current_user, 'public.kroger_oauth_sessions', 'SELECT'), 'OAuth state inaccessible';
  assert not has_table_privilege(current_user, 'public.kroger_exports', 'INSERT'), 'receipt reservation server-only';
end $$;
set request.jwt.claim.sub = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
do $$ begin
  assert (select count(*) from public.kroger_drafts) = 0, 'RLS isolates owners';
  begin
    perform public.save_kroger_draft('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 2, '{"planId":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}');
    raise exception 'cross-account write accepted';
  exception when raise_exception then
    if sqlerrm <> 'plan_not_found' then raise; end if;
  end;
end $$;
reset role;
set role service_role;
do $$ begin
  for i in 1..60 loop assert public.claim_kroger_request('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 'within rate limit'; end loop;
  assert not public.claim_kroger_request('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), 'rate limit enforced';
end $$;
rollback;
\echo Kroger migration, grants, RLS, CAS and rate-limit assertions passed.
