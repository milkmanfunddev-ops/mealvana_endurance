-- A long conversation keeps its opening (mp-277 clause 1, mp-290 clause 2; ticket 14).
--
-- History is chunked, never sliding: every message stays verbatim up to forty, at forty the oldest
-- twenty become one summary message, at sixty the same again. The summary lives in the existing
-- vana_conversations.summary column; summary_index is the message index it covers (20, 40, ...),
-- so the replay knows which messages it stands in for and a background write can tell whether the
-- boundary it is for is already written. No new table, no second writer: the episode sentence no
-- longer fills the summary column.
--
-- Additive and idempotent. Apply to dev; prod follows the meal-planning cutover runbook.

alter table public.vana_conversations add column if not exists summary_index integer;

comment on column public.vana_conversations.summary_index is
  'The message index the rolling history summary in `summary` covers (messages [0, index)). Null = no summary yet. Written by the server in the background of a turn (mp-277).';
