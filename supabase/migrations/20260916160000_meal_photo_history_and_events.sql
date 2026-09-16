-- A Meal's photo History and its audit log (ADR 0003, meal-imagery ticket 04).
--
-- Ticket 01 gave meal_library the current Dish photo as three fields. This adds
-- the two tables behind them:
--
--   meal_photo_history  one row per photograph a Meal has ever shown — the
--                       address, its credit, the storage path when the file is
--                       ours, who added it and when. Replacing a photo keeps
--                       the old row, so nothing is lost by trying a new one.
--   meal_photo_events   one row per action (add, remove, restore, delete) with
--                       the account and the time, so vandalism by anyone who
--                       found the 7-tap gesture can be found and undone. A
--                       deleted photo's row keeps its events: photo_id goes
--                       null and the address is kept on the event itself.
--
-- Both have RLS on and NO client policies: only the service role writes them,
-- and only through the photo edge function. The function refuses anyone whose
-- users.is_internal is not true, so the hidden button is not the only gate.
--
-- Every write runs in ONE transaction through a SECURITY DEFINER SQL function
-- (meal_photo_add / meal_photo_history), which updates the Meal's current-photo
-- fields, inserts the History row and the event together, and answers the
-- Meal's new current photo. An unknown Meal raises `meal_not_found`, which the
-- function maps to 404.
--
-- Ticket 04 needs `add_address` and `history` only. `remove`, `restore` and
-- `delete` (ticket 06) and the storage-backed `add_upload` (ticket 05) write
-- the same two tables; storage_path is here from the start so ticket 05 adds no
-- column.
--
-- Idempotent. Dev first; prod takes it with the meal-planning cutover.

begin;

-- ------------------------------------------- 1. the pointer to History
-- Which History row the Meal is currently showing. Null when it shows nothing,
-- and null for the 170 photographs the ticket-01 switchover copied across:
-- History starts empty on purpose, so a rejected pipeline picture can never be
-- restored with a tap (ADR 0003).
alter table public.meal_library
  add column if not exists photo_history_id uuid;

comment on column public.meal_library.photo_history_id is
  'The meal_photo_history row photo_url came from, or null when the Meal shows '
  'nothing or its photo predates History (the ADR 0003 switchover). Written only '
  'by meal_photo_add and its siblings.';

-- --------------------------------------------------- 2. History
create table if not exists public.meal_photo_history (
  id           uuid primary key default gen_random_uuid(),
  meal_id      text not null references public.meal_library(id) on delete cascade,
  url          text not null check (url ~ '^https://'),
  credit       text,
  credit_url   text,
  storage_path text,
  added_by     uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now()
);

comment on table public.meal_photo_history is
  'Every photograph a Meal has shown, newest last. Replacing a photo keeps the '
  'old row so a mistake is one tap to undo (ADR 0003). Server-written only.';
comment on column public.meal_photo_history.storage_path is
  'Object path in the meal-images bucket when the file is ours, null for a web '
  'address. Deleting a row for good deletes that file too (ticket 06).';
comment on column public.meal_photo_history.added_by is
  'The Tester who added it. Null once their account is gone; the event log still '
  'carries what happened.';

create index if not exists meal_photo_history_meal
  on public.meal_photo_history (meal_id, created_at desc);

-- --------------------------------------------------- 3. the event log
create table if not exists public.meal_photo_events (
  id         uuid primary key default gen_random_uuid(),
  action     text not null check (action in ('add', 'remove', 'restore', 'delete')),
  meal_id    text not null,
  photo_id   uuid references public.meal_photo_history(id) on delete set null,
  photo_url  text,
  account_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.meal_photo_events is
  'Who changed a Meal''s photograph, how and when — the safety net for the '
  'accepted risk that anyone who finds the 7-tap gesture becomes a Tester '
  '(ADR 0003). Kept after the photo it names is deleted: photo_id goes null and '
  'photo_url keeps the address.';
comment on column public.meal_photo_events.meal_id is
  'Deliberately NOT a foreign key: an event outlives the Meal it describes.';

create index if not exists meal_photo_events_meal
  on public.meal_photo_events (meal_id, created_at desc);
create index if not exists meal_photo_events_account
  on public.meal_photo_events (account_id, created_at desc);

-- --------------------------------------------------- 4. RLS: server only
-- On, with no policies at all. `authenticated` is granted nothing, so a client
-- holding the anon key reads and writes nothing here even if it tries.
alter table public.meal_photo_history enable row level security;
alter table public.meal_photo_events  enable row level security;

grant all on public.meal_photo_history to service_role;
grant all on public.meal_photo_events  to service_role;

revoke all on public.meal_photo_history from authenticated, anon;
revoke all on public.meal_photo_events  from authenticated, anon;

-- --------------------------------------------------- 5. one add, one transaction
-- The Meal's current photo, the History row and the event move together or not
-- at all. Answers the Meal's new current photo as json, which the edge function
-- returns verbatim, so the app never has to read back through a second query
-- and see a half-written state.
create or replace function public.meal_photo_add(
  p_meal_id      text,
  p_url          text,
  p_credit       text default null,
  p_credit_url   text default null,
  p_storage_path text default null,
  p_account      uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_photo_id uuid;
  v_created_at timestamptz;
  v_credit     text := nullif(btrim(coalesce(p_credit, '')), '');
  v_credit_url text := nullif(btrim(coalesce(p_credit_url, '')), '');
begin
  -- An unknown Meal is a 404, not a half-written History row.
  if not exists (select 1 from public.meal_library where id = p_meal_id) then
    raise exception 'meal_not_found' using errcode = 'no_data_found';
  end if;

  insert into public.meal_photo_history
    (meal_id, url, credit, credit_url, storage_path, added_by)
  values
    (p_meal_id, p_url, v_credit, v_credit_url,
     nullif(btrim(coalesce(p_storage_path, '')), ''), p_account)
  returning id, created_at into v_photo_id, v_created_at;

  -- The newest confirmed photo is the one shown, whatever was there before —
  -- including a photograph the frozen pipeline chose.
  update public.meal_library
     set photo_url        = p_url,
         photo_credit     = v_credit,
         photo_credit_url = v_credit_url,
         photo_history_id = v_photo_id
   where id = p_meal_id;

  insert into public.meal_photo_events (action, meal_id, photo_id, photo_url, account_id)
  values ('add', p_meal_id, v_photo_id, p_url, p_account);

  -- camelCase on purpose: this json reaches the app unchanged, and the app
  -- already parses a photograph in exactly this shape (MealPhoto.fromJsonOrNull,
  -- the Vana MealDetail.photo contract). One parser, one shape.
  --
  -- `entry` is the History row as the `history` action lists it, so the app can
  -- show the new row with the server's own id, account and clock. Without it the
  -- device would have to invent "who and when", and a Tester reading the record
  -- would be shown a client clock (stories 37, 44).
  return jsonb_build_object(
    'photo', jsonb_build_object(
      'url', p_url,
      'credit', v_credit,
      'creditUrl', v_credit_url
    ),
    'entry', jsonb_build_object(
      'id', v_photo_id,
      'url', p_url,
      'credit', v_credit,
      'creditUrl', v_credit_url,
      'storagePath', nullif(btrim(coalesce(p_storage_path, '')), ''),
      'addedBy', p_account,
      'createdAt', v_created_at,
      'isCurrent', true
    )
  );
end;
$$;

comment on function public.meal_photo_add is
  'Add a photograph to a Meal: History row, current-photo fields and the audit '
  'event in one transaction, answering the Meal''s new current photo. Called '
  'only by the meal-photo edge function, which does the Tester check.';

-- Service role only: this writes tables the client may not touch, and it takes
-- the account as a parameter, so a client calling it directly could sign a row
-- as somebody else.
revoke all on function public.meal_photo_add(text, text, text, text, text, uuid)
  from public, authenticated, anon;
grant execute on function public.meal_photo_add(text, text, text, text, text, uuid)
  to service_role;

commit;

-- ------------------------------------------------------------ verify (read-only)
--   select count(*) from public.meal_photo_history;   -- 0 on a fresh apply
--   select count(*) from public.meal_photo_events;    -- 0 on a fresh apply
--   select relrowsecurity from pg_class
--    where relname in ('meal_photo_history', 'meal_photo_events');  -- both true
--   select count(*) from pg_policies
--    where tablename in ('meal_photo_history', 'meal_photo_events'); -- 0
