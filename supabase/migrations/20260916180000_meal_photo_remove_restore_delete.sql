-- Taking a photograph down, putting an old one back, and deleting one for good
-- (ADR 0003, meal-imagery ticket 06).
--
-- Ticket 04 gave a Meal's photographs their two tables and the one-transaction
-- `meal_photo_add`. This adds its three siblings, each the same shape: one
-- transaction that moves the Meal's current-photo fields and writes the audit
-- event together, answering the Meal's new current photo (or null).
--
--   meal_photo_remove   clears the current photo. History is left exactly as it
--                       is, and NO older photograph comes back — "remove" does
--                       what it says (story 42). The Meal then shows nothing.
--   meal_photo_restore  makes a History row the current photo again, so a
--                       mistake or a vandal's photograph is one tap to undo
--                       (story 38).
--   meal_photo_delete   removes a History row for good. The Meal stops wearing
--                       it if it was wearing it, the row leaves History so it
--                       can never be restored, and the audit events stay —
--                       photo_id goes null (the ticket-04 FK is ON DELETE SET
--                       NULL) and the address stays on the event itself, so
--                       what happened is still readable afterwards (story 44).
--
-- The stored FILE is not deleted here: SQL cannot reach the bucket. `delete`
-- answers the row's storage_path and the edge function removes the object with
-- the service role, after this transaction has committed. That order is on
-- purpose — a file with no row is litter, a row with no file draws nothing and
-- would be a lie.
--
-- All three are `security definer` and granted to `service_role` only, exactly
-- like `meal_photo_add`: they take the account as a parameter, so a client that
-- could call them directly would be able to sign somebody else's name to an
-- event. The Tester check lives in the edge function, which is the only caller.
--
-- Errors, both raised with errcode `no_data_found` (P0002) and told apart by
-- their message, which the function maps to two different 404s:
--   meal_not_found    no such Meal in the library
--   photo_not_found   no such History row for this Meal
--
-- Idempotent (`create or replace`). Dev first; prod takes it with the
-- meal-planning cutover.

begin;

-- ------------------------------------------------- 1. remove
-- Clearing the current photo is not the same as deleting it: the row stays in
-- History, so the photograph the Tester just took down is still one tap from
-- coming back.
--
-- A Meal that already shows nothing is a no-op that answers 200 rather than an
-- error — but writes NO event. The event log answers "who changed this photo",
-- and a removal that removed nothing is not a change (story 44).
create or replace function public.meal_photo_remove(
  p_meal_id text,
  p_account uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url        text;
  v_history_id uuid;
begin
  select photo_url, photo_history_id
    into v_url, v_history_id
    from public.meal_library
   where id = p_meal_id
     for update;

  if not found then
    raise exception 'meal_not_found' using errcode = 'no_data_found';
  end if;

  if v_url is null then
    return jsonb_build_object('photo', null);
  end if;

  update public.meal_library
     set photo_url        = null,
         photo_credit     = null,
         photo_credit_url = null,
         photo_history_id = null
   where id = p_meal_id;

  -- photo_url is kept on the event so the record still says WHICH photograph
  -- was taken down, even after that History row is later deleted for good.
  insert into public.meal_photo_events (action, meal_id, photo_id, photo_url, account_id)
  values ('remove', p_meal_id, v_history_id, v_url, p_account);

  return jsonb_build_object('photo', null);
end;
$$;

comment on function public.meal_photo_remove is
  'Clear a Meal''s current Dish photo, leaving History untouched, and record the '
  'removal. Called only by the meal-photo edge function, which does the Tester check.';

-- ------------------------------------------------- 2. restore
-- The History row becomes the current photo again, with its own credit. The
-- row is looked up BY MEAL as well as by id, so a photo id belonging to another
-- Meal is a 404 rather than a way to paste one Meal's photograph onto another.
create or replace function public.meal_photo_restore(
  p_meal_id  text,
  p_photo_id uuid,
  p_account  uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.meal_photo_history%rowtype;
begin
  -- Locked for the same reason `remove` locks: two Testers on the same Meal at
  -- once must queue, not interleave, or the Meal can end up wearing one
  -- photograph while pointing at another's History row.
  perform 1 from public.meal_library where id = p_meal_id for update;
  if not found then
    raise exception 'meal_not_found' using errcode = 'no_data_found';
  end if;

  select * into v_row
    from public.meal_photo_history
   where id = p_photo_id
     and meal_id = p_meal_id;

  if not found then
    raise exception 'photo_not_found' using errcode = 'no_data_found';
  end if;

  update public.meal_library
     set photo_url        = v_row.url,
         photo_credit     = v_row.credit,
         photo_credit_url = v_row.credit_url,
         photo_history_id = v_row.id
   where id = p_meal_id;

  insert into public.meal_photo_events (action, meal_id, photo_id, photo_url, account_id)
  values ('restore', p_meal_id, v_row.id, v_row.url, p_account);

  -- The same shape `meal_photo_add` answers: the app parses a photograph with
  -- one parser wherever it arrives from.
  return jsonb_build_object(
    'photo', jsonb_build_object(
      'url', v_row.url,
      'credit', v_row.credit,
      'creditUrl', v_row.credit_url,
      'historyId', v_row.id
    )
  );
end;
$$;

comment on function public.meal_photo_restore is
  'Make one of a Meal''s History rows its current Dish photo again, and record '
  'the restore. Called only by the meal-photo edge function.';

-- ------------------------------------------------- 3. delete
-- For good: the row leaves History, so an inappropriate photograph cannot be
-- restored by the next person to find the 7-tap gesture (story 39).
--
-- Answers the storage path, if the file was ours, so the caller can delete the
-- object once this has committed — and `photo`, the Meal's current photo after
-- the deletion, which is null when the deleted row was the one being worn.
-- Deleting the current photo leaves the Meal showing nothing; it does NOT pull
-- an older photograph forward, for the same reason `remove` doesn't.
create or replace function public.meal_photo_delete(
  p_meal_id  text,
  p_photo_id uuid,
  p_account  uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row       public.meal_photo_history%rowtype;
  v_was_worn  boolean;
  v_photo     jsonb;
begin
  -- Locked like its two siblings: a delete racing a restore on one Meal must
  -- queue rather than interleave.
  perform 1 from public.meal_library where id = p_meal_id for update;
  if not found then
    raise exception 'meal_not_found' using errcode = 'no_data_found';
  end if;

  select * into v_row
    from public.meal_photo_history
   where id = p_photo_id
     and meal_id = p_meal_id;

  if not found then
    raise exception 'photo_not_found' using errcode = 'no_data_found';
  end if;

  select photo_history_id = v_row.id
    into v_was_worn
    from public.meal_library
   where id = p_meal_id;

  if coalesce(v_was_worn, false) then
    update public.meal_library
       set photo_url        = null,
           photo_credit     = null,
           photo_credit_url = null,
           photo_history_id = null
     where id = p_meal_id;
  end if;

  -- The event is written BEFORE the row goes, so the deletion is recorded even
  -- if what follows fails; the FK then sets photo_id to null and the address on
  -- the event is what keeps the record readable.
  insert into public.meal_photo_events (action, meal_id, photo_id, photo_url, account_id)
  values ('delete', p_meal_id, v_row.id, v_row.url, p_account);

  delete from public.meal_photo_history where id = v_row.id;

  select case
           when photo_url is null then null
           else jsonb_build_object(
             'url', photo_url,
             'credit', photo_credit,
             'creditUrl', photo_credit_url,
             'historyId', photo_history_id
           )
         end
    into v_photo
    from public.meal_library
   where id = p_meal_id;

  return jsonb_build_object(
    'photo', v_photo,
    -- Null for a web address, which is shown where it lives and has no file of
    -- ours to delete.
    'storagePath', v_row.storage_path
  );
end;
$$;

comment on function public.meal_photo_delete is
  'Delete one of a Meal''s History rows for good, clearing the current photo if '
  'it was the one shown, keeping the audit events, and answering the storage '
  'path so the caller can delete the file. Called only by the meal-photo edge function.';

-- ------------------------------------------------- 4. service role only
revoke all on function public.meal_photo_remove(text, uuid)
  from public, authenticated, anon;
grant execute on function public.meal_photo_remove(text, uuid)
  to service_role;

revoke all on function public.meal_photo_restore(text, uuid, uuid)
  from public, authenticated, anon;
grant execute on function public.meal_photo_restore(text, uuid, uuid)
  to service_role;

revoke all on function public.meal_photo_delete(text, uuid, uuid)
  from public, authenticated, anon;
grant execute on function public.meal_photo_delete(text, uuid, uuid)
  to service_role;

commit;

-- ------------------------------------------------------------ verify (read-only)
--   select proname, proacl from pg_proc
--    where proname in ('meal_photo_remove', 'meal_photo_restore', 'meal_photo_delete');
--   -- each granted to service_role only
--
--   select action, count(*) from public.meal_photo_events group by action;
--   -- 'remove' / 'restore' / 'delete' appear once the function has been used
