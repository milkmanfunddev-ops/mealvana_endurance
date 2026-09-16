-- Several shopping lists, with hand edits (Lee's playtest 2026-09-16, triage §5 option C and §6).
--
-- Until now the list was one jsonb column, `meal_plans.shopping`, rebuilt from the plan's meals on every
-- edit and keyed by lowercased name: no line id, no owner, nothing survives a re-plan except `checked` /
-- `have`. These two tables give a list its own row and every line an id.
--
--   shopping_lists   one per plan (plan_id set, made on the first refreshShopping / confirm) or made by hand
--                    (plan_id null). "Most recent" = coalesce(confirmed_at, created_at) desc.
--   shopping_items   the lines. source='plan' rows are replaced from the plan's meals on every refresh;
--                    source='manual' rows and edited=true rows are kept untouched (matched by id).
--
-- `meal_plans.shopping` keeps being written as a mirror of the plan's list so Kroger and older readers
-- keep working; the Shopping tab reads the list. Idempotent. RLS like meal_plans (owner = user_id).
-- A plan has at most one list: partial unique index, so the server does select-then-insert, never an
-- upsert onConflict on plan_id (42P10).

create table if not exists public.shopping_lists (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  plan_id       uuid references public.meal_plans(id) on delete set null,
  name          text not null default '',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  confirmed_at  timestamptz
);
create index if not exists shopping_lists_user_recent_idx on public.shopping_lists (user_id, coalesce(confirmed_at, created_at) desc);
create unique index if not exists shopping_lists_plan_idx on public.shopping_lists (plan_id) where plan_id is not null;

create table if not exists public.shopping_items (
  id             uuid primary key default gen_random_uuid(),
  list_id        uuid not null references public.shopping_lists(id) on delete cascade,
  user_id        uuid not null references public.users(id) on delete cascade,
  name           text not null,
  qty            text not null default '',
  aisle          text not null default 'Other',
  checked        boolean not null default false,
  have           boolean not null default false,
  source         text not null default 'manual' check (source in ('plan','manual')),
  from_meal_ids  text[] not null default '{}',
  edited         boolean not null default false,
  position       integer not null default 0,
  created_at     timestamptz not null default now()
);
create index if not exists shopping_items_list_idx on public.shopping_items (list_id, position);

alter table public.shopping_lists enable row level security;
alter table public.shopping_items enable row level security;
drop policy if exists "shopping_lists owner" on public.shopping_lists;
create policy "shopping_lists owner" on public.shopping_lists for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "shopping_items owner" on public.shopping_items;
create policy "shopping_items owner" on public.shopping_items for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.shopping_lists to authenticated;
grant select, insert, update, delete on public.shopping_items to authenticated;
