-- user_feedback — the app's own feedback sink (2026-09-09).
-- Product/Vana feedback the athlete types into the in-app sheet ("Give feedback for me here" on the first Vana
-- conversation, and later entry points). Bug reports with screenshots keep going to Wiredash; this table is for
-- what Wiredash cannot give back (its SDK returns only submitted=true/false). Idempotent.
create table if not exists public.user_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null,                       -- vana_opener | vana_chat | settings | ...
  conversation_id uuid null,                  -- vana_conversations.id when it came from a chat
  rating smallint null check (rating between -1 and 1),  -- -1 thumbs down · 1 thumbs up · null none
  message text not null check (length(message) between 1 and 2000),
  metadata jsonb not null default '{}'::jsonb,
  app_version text null,
  created_at timestamptz not null default now()
);
create index if not exists user_feedback_user_created on public.user_feedback (user_id, created_at desc);
create index if not exists user_feedback_created on public.user_feedback (created_at desc);

alter table public.user_feedback enable row level security;
grant all on public.user_feedback to service_role;
grant select, insert on public.user_feedback to authenticated;
drop policy if exists user_feedback_insert_own on public.user_feedback;
create policy user_feedback_insert_own on public.user_feedback for insert to authenticated with check (user_id = auth.uid());
drop policy if exists user_feedback_select_own on public.user_feedback;
create policy user_feedback_select_own on public.user_feedback for select to authenticated using (user_id = auth.uid());
