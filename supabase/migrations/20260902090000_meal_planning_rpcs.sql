-- =====================================================================
-- 20260902_090000 · meal-planning RPCs (Phase 2 backend — docs/implement_mealplanning/03-backend.md §2.5)
--
-- Small SQL functions the edge functions (vana-action / vana-chat tools) call for the writes that must be one
-- transaction, and that the Dart repositories can replay directly when an offline-first edit is uploaded.
-- All are SECURITY INVOKER: table RLS (owner = auth.uid()) does the authorisation, so a caller can only ever
-- touch their own plans. Granted to `authenticated` (+ service_role for scripts/tests).
--
-- Conventions: dates are plain `date`s in the athlete's local day (the caller passes them); no timezone maths here.
-- Idempotent — safe to re-run.
-- =====================================================================

-- ------------------------------------------------------------ confirm_meal_plan
-- The plan becomes the week's ONE confirmed plan: status → confirmed, the (TS-built) shopping list is stored, and every
-- other non-archived plan of the same athlete-week (drafts from other conversations, a previously confirmed plan) is
-- archived. Returns the updated meal_plans row so the caller has its remote ack in one round trip.
create or replace function public.confirm_meal_plan(p_plan_id uuid, p_shopping jsonb default null)
returns public.meal_plans
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_plan public.meal_plans;
begin
  select * into v_plan from public.meal_plans where id = p_plan_id and not is_deleted for update;
  if not found then raise exception 'plan not found: %', p_plan_id; end if;

  update public.meal_plans
     set status = 'archived', updated_at = now()
   where user_id = v_plan.user_id and week_start = v_plan.week_start
     and id <> p_plan_id and status <> 'archived' and not is_deleted;

  update public.meal_plans
     set status = 'confirmed',
         shopping = coalesce(p_shopping, shopping),
         day_notes_stale = true,
         updated_at = now()
   where id = p_plan_id
  returning * into v_plan;
  return v_plan;
end $$;
revoke all on function public.confirm_meal_plan(uuid, jsonb) from public;
grant execute on function public.confirm_meal_plan(uuid, jsonb) to authenticated, service_role;

-- ------------------------------------------------------------ plan_log_from_plan
-- "Ate one serving": decrement servings_left and write the meal_logs row (source = 'plan', plan_meal_id set).
-- plan_meals macros are PER SERVING (coverage multiplies by servings), so the log row carries them as stored.
-- Returns the new meal_logs.id.
create or replace function public.plan_log_from_plan(p_plan_meal_id uuid, p_meal_type text default null, p_log_date date default current_date)
returns uuid
language plpgsql volatile security invoker set search_path = public as $$
declare
  m       public.plan_meals;
  v_items jsonb := '[]'::jsonb;
  v_id    uuid;
begin
  select * into m from public.plan_meals where id = p_plan_meal_id for update;
  if not found then raise exception 'plan meal not found: %', p_plan_meal_id; end if;

  if m.source = 'library' and m.library_meal_id is not null then
    select coalesce(ingredients_json, '[]'::jsonb) into v_items from public.meal_library where id = m.library_meal_id;
  elsif m.saved_meal_id is not null then
    select coalesce(items, '[]'::jsonb) into v_items from public.saved_meals where id = m.saved_meal_id;
  end if;

  update public.plan_meals set servings_left = greatest(0, servings_left - 1), updated_at = now() where id = m.id;

  insert into public.meal_logs (user_id, log_date, slot, name, source, items, calories, carbs_g, protein_g, fat_g, saved_meal_id, plan_meal_id, eaten_at)
  values (m.user_id, coalesce(p_log_date, current_date), coalesce(p_meal_type, m.meal_type), m.name, 'plan', coalesce(v_items, '[]'::jsonb),
          m.kcal, m.carbs_g, m.protein_g, m.fat_g, m.saved_meal_id, m.id, now())
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.plan_log_from_plan(uuid, text, date) from public;
grant execute on function public.plan_log_from_plan(uuid, text, date) to authenticated, service_role;

-- ------------------------------------------------------------ plan_set_servings
-- servings ≤ 0 removes the row (returns null); otherwise servings_left keeps what was already eaten.
-- Flags the plan's day notes stale (the caller / next Plan-tab load rebuilds shopping + notes).
create or replace function public.plan_set_servings(p_plan_meal_id uuid, p_servings integer)
returns public.plan_meals
language plpgsql volatile security invoker set search_path = public as $$
declare
  m public.plan_meals;
begin
  select * into m from public.plan_meals where id = p_plan_meal_id for update;
  if not found then raise exception 'plan meal not found: %', p_plan_meal_id; end if;
  update public.meal_plans set day_notes_stale = true, updated_at = now() where id = m.plan_id;
  if p_servings <= 0 then
    delete from public.plan_meals where id = m.id;
    return null;
  end if;
  update public.plan_meals
     set servings = p_servings,
         servings_left = greatest(0, p_servings - (m.servings - m.servings_left)),
         updated_at = now()
   where id = m.id
  returning * into m;
  return m;
end $$;
revoke all on function public.plan_set_servings(uuid, integer) from public;
grant execute on function public.plan_set_servings(uuid, integer) to authenticated, service_role;

-- ------------------------------------------------------------ plan_remove_meal
create or replace function public.plan_remove_meal(p_plan_meal_id uuid)
returns void
language sql volatile security invoker set search_path = public as $$
  select public.plan_set_servings(p_plan_meal_id, 0);
$$;
revoke all on function public.plan_remove_meal(uuid) from public;
grant execute on function public.plan_remove_meal(uuid) to authenticated, service_role;

-- ------------------------------------------------------------ plan_toggle_shopping
-- Flip `checked` or `have` on one shopping item (matched by name, case-insensitive). Returns the updated list.
create or replace function public.plan_toggle_shopping(p_plan_id uuid, p_name text, p_field text, p_value boolean)
returns jsonb
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_items jsonb;
begin
  if p_field not in ('checked', 'have') then raise exception 'p_field must be checked or have'; end if;
  select shopping into v_items from public.meal_plans where id = p_plan_id and not is_deleted for update;
  if not found then raise exception 'plan not found: %', p_plan_id; end if;
  select coalesce(jsonb_agg(case when lower(i->>'name') = lower(p_name) then jsonb_set(i, array[p_field], to_jsonb(p_value)) else i end order by ord), '[]'::jsonb)
    into v_items
    from jsonb_array_elements(coalesce(v_items, '[]'::jsonb)) with ordinality as t(i, ord);
  update public.meal_plans set shopping = v_items, updated_at = now() where id = p_plan_id;
  return v_items;
end $$;
revoke all on function public.plan_toggle_shopping(uuid, text, text, boolean) from public;
grant execute on function public.plan_toggle_shopping(uuid, text, text, boolean) to authenticated, service_role;

-- ------------------------------------------------------------ plan_set_day_slot
-- Put a DaySlotRef ({source, id, name, kcal?, carbsG?}) into one slot of one day on meal_plans.days, or clear it
-- (p_ref null). Returns that day's slots.
create or replace function public.plan_set_day_slot(p_plan_id uuid, p_date date, p_slot text, p_ref jsonb default null)
returns jsonb
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_days jsonb;
  v_day  jsonb;
  v_key  text := to_char(p_date, 'YYYY-MM-DD');
begin
  if p_slot not in ('breakfast', 'lunch', 'dinner', 'snack') then raise exception 'p_slot must be breakfast|lunch|dinner|snack'; end if;
  select coalesce(days, '{}'::jsonb) into v_days from public.meal_plans where id = p_plan_id and not is_deleted for update;
  if not found then raise exception 'plan not found: %', p_plan_id; end if;
  v_day := coalesce(v_days -> v_key, '{}'::jsonb);
  if p_ref is null then v_day := v_day - p_slot; else v_day := jsonb_set(v_day, array[p_slot], p_ref, true); end if;
  v_days := jsonb_set(v_days, array[v_key], v_day, true);
  update public.meal_plans set days = v_days, updated_at = now() where id = p_plan_id;
  return v_day;
end $$;
revoke all on function public.plan_set_day_slot(uuid, date, text, jsonb) from public;
grant execute on function public.plan_set_day_slot(uuid, date, text, jsonb) to authenticated, service_role;
