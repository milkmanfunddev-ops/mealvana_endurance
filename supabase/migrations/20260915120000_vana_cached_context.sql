-- The repeated prefix is cached and the context block does not churn (mp-276, mp-290; ticket 13).
--
-- vana_conversations.context holds the AthleteContext assembled when the conversation opened, and
-- context_day the athlete-local day it was built for. A turn reuses it while the day matches; a
-- tool write (plan, memory, pantry, home) nulls it for every conversation of the athlete, so the
-- next turn rebuilds. That is what keeps the system prompt byte-identical between turns and the
-- gateway's cache warm.
--
-- vana_calls.cache_read_tokens is the prompt-cache read count the gateway reported for the call,
-- beside input_tokens, so a zero on a second turn is visible in the table.
--
-- Additive and idempotent. Apply to dev; prod follows the meal-planning cutover runbook.

alter table public.vana_conversations add column if not exists context jsonb;
alter table public.vana_conversations add column if not exists context_day date;
alter table public.vana_calls add column if not exists cache_read_tokens integer;
