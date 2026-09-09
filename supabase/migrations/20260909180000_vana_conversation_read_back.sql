-- Lazy extraction (the Voodoo Doll spec, ticket 06).
--
-- A conversation is read back exactly once: when the athlete's NEXT conversation opens, the most
-- recent one with read_back_at still null is fed to one Haiku call, and the sentences it returns
-- are written as Memories. Stamping the column is how a conversation is never extracted twice —
-- there is no scheduler and no queue.
--
-- Idempotent. Apply to dev; prod follows the meal-planning cutover runbook (pgvector is not on
-- prod yet, so nothing in this feature runs there).

alter table public.vana_conversations add column if not exists read_back_at timestamptz;

comment on column public.vana_conversations.read_back_at is
  'When lazy extraction read this conversation back. Null = not yet read. Set once, by the server.';

-- The lookup the opener makes: this athlete's most recent conversation still waiting to be read.
create index if not exists vana_conversations_pending_read_back
  on public.vana_conversations (user_id, last_message_at desc)
  where read_back_at is null and not is_deleted;
