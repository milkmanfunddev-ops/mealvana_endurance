-- vana-eval's Run users (eval-v2 ticket 02). DEV ONLY: vana-eval is never deployed to prod, so this
-- table is never applied there. Leave this file loose; do not add it to a prod cutover.
--
-- Each Run of the eval system gets a throwaway dev auth user seeded from an Eval athlete snapshot. This row
-- says the user is one of those (vana-eval refuses to run Vana as any user without one), keeps the snapshot
-- taken right after seeding so the end call can return it beside the after-snapshot, and dates the copy for
-- the sweep that removes copies a Run left behind. It goes with the auth user.
--
-- Service role only: RLS on, no policies. Idempotent.

create table if not exists public.vana_eval_run_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  source_user_id uuid not null,
  created_by uuid not null,
  before jsonb,
  created_at timestamptz not null default now()
);

create index if not exists vana_eval_run_users_created_at on public.vana_eval_run_users (created_at);

alter table public.vana_eval_run_users enable row level security;

comment on table public.vana_eval_run_users is
  'vana-eval throwaway users (eval-v2 ticket 02), dev only. Service role only; the row goes with the auth user.';
