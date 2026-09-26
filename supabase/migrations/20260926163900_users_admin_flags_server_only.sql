-- users.is_admin and users.is_internal are written only by the service role
-- (testing-wave 139, 122-004; security review 2026-09-26).
--
-- The server's Pro gate (_shared/vana/entitlement.ts) now lets an Admin
-- through on public.users.is_admin. That column lives on a table whose
-- users_update_own / users_insert_own policies are row-scoped only, and the
-- app's profile upsert proves `authenticated` holds table-level UPDATE, so
-- until now any signed-in athlete could PATCH their own row with
-- {"is_admin": true} and open every AI function (and the meal_reviews
-- policies), and {"is_internal": true} for whatever keys off that flag.
--
-- This trigger pins both flags on every insert or update that is not made by
-- the service role: an insert gets false, an update keeps the old value. The
-- flags stay "set by hand in the database" as the 09-16 migration says; the
-- Management API / SQL editor runs as postgres or service_role and is
-- unaffected, and so are the edge functions' service-role clients.
--
-- Idempotent. Apply to dev now; prod follows the cutover runbook.

create or replace function public.users_pin_admin_flags()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  -- PostgREST 10+ sets only request.jwt.claims (JSON); the per-claim setting is
  -- the old form, kept as a fallback (review of wave 42).
  role text := coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
begin
  -- No JWT claim (psql, the SQL editor, migrations) or the service role:
  -- trusted, write as asked.
  if role = '' or role = 'service_role' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.is_admin := false;
    new.is_internal := false;
  else
    new.is_admin := coalesce(old.is_admin, false);
    new.is_internal := coalesce(old.is_internal, false);
  end if;
  return new;
end;
$$;

comment on function public.users_pin_admin_flags() is
  'BEFORE INSERT OR UPDATE on public.users: a non-service-role caller cannot set is_admin or is_internal (testing-wave 139).';

drop trigger if exists users_pin_admin_flags on public.users;
create trigger users_pin_admin_flags
  before insert or update on public.users
  for each row execute function public.users_pin_admin_flags();
