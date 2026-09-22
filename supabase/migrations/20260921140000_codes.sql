-- paywall ticket 07 (mp-458, mp-429 clauses 4 and 8): our own codes — coach, influencer and giveaway.
--
-- `codes` holds each code with its type, its owner, its validity window and its perk.
--   code             stored upper-case with no spaces (the function normalises what the caller types)
--   type             coach | influencer | giveaway
--   owner_user_id    the coach or influencer the code belongs to; required for a coach code,
--                    optional for an influencer code, unused for a giveaway
--   valid_from       the window opens here (inclusive)
--   valid_until      and closes here (exclusive); null = no end
--   perk_days        days of `pro` the code grants: to the owner of a coach code when they enter it
--                    (30), to the redeemer of a giveaway (365); an athlete entering a coach or
--                    influencer code gets the attribution and a pending pairing, not days
--   max_redemptions  how many accounts may redeem it; null = no limit. A giveaway with no limit set
--                    is treated as single-use by `code_claim` (mp-458 clause 5, "once").
--
-- `code_redemptions` is one row per account per code; `code_claim` writes it under a lock on the code
-- row, so a single-use code cannot be redeemed twice by two callers at once, and an account cannot
-- redeem the same code twice. The redeem-code function deletes the row again when a later step (the
-- RevenueCat grant or attribute) fails, so a code is never spent on nothing.
--
-- Only the service role reads or writes either table: RLS on, no policies, and the table grants
-- revoked from anon and authenticated. Codes are seeded by hand with SQL.
--
-- All timestamps are timestamptz (UTC instants), not naive local time.
-- Additive and idempotent: safe to re-run, safe to apply ahead of the function deploy (playbook §3).

create table if not exists public.codes (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  type text not null,
  owner_user_id uuid references public.users(id) on delete cascade,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  perk_days integer not null default 0,
  max_redemptions integer,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint codes_code_key unique (code),
  constraint codes_code_format check (code = upper(code) and code !~ '\s' and length(code) between 3 and 32),
  constraint codes_type_check check (type in ('coach', 'influencer', 'giveaway')),
  constraint codes_coach_has_owner check (type <> 'coach' or owner_user_id is not null),
  constraint codes_perk_days_check check (perk_days >= 0),
  constraint codes_max_redemptions_check check (max_redemptions is null or max_redemptions > 0),
  constraint codes_window_check check (valid_until is null or valid_until > valid_from)
);

comment on table public.codes is
  'Our own codes (mp-458): coach, influencer and giveaway. Written only by the service role; redeemed through the redeem-code function.';

create index if not exists idx_codes_owner on public.codes (owner_user_id) where owner_user_id is not null;

create table if not exists public.code_redemptions (
  id uuid primary key default gen_random_uuid(),
  code_id uuid not null references public.codes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  constraint code_redemptions_code_user_key unique (code_id, user_id)
);

comment on table public.code_redemptions is
  'One row per account per redeemed code (mp-458). Written only by code_claim and the redeem-code function.';

create index if not exists idx_code_redemptions_user on public.code_redemptions (user_id);

alter table public.codes enable row level security;
alter table public.code_redemptions enable row level security;
revoke all on table public.codes from anon, authenticated;
revoke all on table public.code_redemptions from anon, authenticated;

-- The claim: 'claimed' (one redemption row written), or why not — 'not_found', 'already_redeemed'
-- (this account has redeemed it), 'used' (at its redemption limit). The lock on the code row makes
-- two claims on one code run one after the other, so the second counts the first one's row.
create or replace function public.code_claim(p_code_id uuid, p_user_id uuid)
returns text
language plpgsql volatile security invoker set search_path = public as $$
declare
  v_type text;
  v_max int;
  v_limit int;
  v_count int;
begin
  select type, max_redemptions into v_type, v_max
    from public.codes
   where id = p_code_id
     for update;
  if not found then
    return 'not_found';
  end if;

  if exists (select 1 from public.code_redemptions where code_id = p_code_id and user_id = p_user_id) then
    return 'already_redeemed';
  end if;

  v_limit := case when v_type = 'giveaway' then coalesce(v_max, 1) else v_max end;
  if v_limit is not null then
    select count(*) into v_count from public.code_redemptions where code_id = p_code_id;
    if v_count >= v_limit then
      return 'used';
    end if;
  end if;

  insert into public.code_redemptions (code_id, user_id) values (p_code_id, p_user_id);
  return 'claimed';
end $$;

revoke all on function public.code_claim(uuid, uuid) from public, anon, authenticated;
grant execute on function public.code_claim(uuid, uuid) to service_role;
