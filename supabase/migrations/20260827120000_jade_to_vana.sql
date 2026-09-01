-- Rename the AI-chat tables jade_* → vana_* (dev, 2026-08-27, Lee's call). Compatibility views keep the
-- Flutter app's jade-chat edge function working until it is pointed at vana_* (security_invoker → table RLS applies).
do $$ begin
  if to_regclass('public.jade_conversations') is not null and to_regclass('public.vana_conversations') is null then
    alter table public.jade_conversations rename to vana_conversations;
    alter table public.jade_messages rename to vana_messages;
    alter table public.jade_calls rename to vana_calls;
  end if;
end $$;
alter table public.vana_conversations add column if not exists kind text not null default 'meal_planning';   -- 'meal_planning' | 'coach'
alter table public.vana_conversations add column if not exists last_message_at timestamptz;
alter table public.vana_conversations add column if not exists summary text;
alter table public.vana_messages add column if not exists parts jsonb;       -- AI SDK UI message parts (text + tool parts)
create index if not exists vana_conversations_user_recent on public.vana_conversations (user_id, last_message_at desc) where not is_deleted;
create index if not exists vana_messages_conv_idx on public.vana_messages (conversation_id, created_at);
do $$ begin
  if exists (select 1 from pg_policies where tablename='vana_conversations' and policyname='Users manage own jade conversations') then
    alter policy "Users manage own jade conversations" on public.vana_conversations rename to "Users manage own vana conversations";
    alter policy "Users manage own jade messages" on public.vana_messages rename to "Users manage own vana messages";
    alter policy "Users read own jade calls" on public.vana_calls rename to "Users read own vana calls";
  end if;
end $$;
-- compatibility views (drop these once supabase/functions/jade-chat reads vana_*)
create or replace view public.jade_conversations with (security_invoker = true) as select * from public.vana_conversations;
create or replace view public.jade_messages      with (security_invoker = true) as select * from public.vana_messages;
create or replace view public.jade_calls         with (security_invoker = true) as select * from public.vana_calls;
grant select, insert, update, delete on public.jade_conversations, public.jade_messages, public.jade_calls to authenticated, service_role;
