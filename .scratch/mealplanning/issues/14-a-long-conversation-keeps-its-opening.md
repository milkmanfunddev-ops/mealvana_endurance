# 14: A long conversation keeps its opening

**Status:** ready-for-agent
**Blocked by:** 13 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete forty turns into a planning conversation asks about the meal they picked in turn three and Vana knows it. Every message stays verbatim to forty; at forty the oldest twenty become one summary and the last twenty stay; at sixty the same again, rolling. The summary is written in the background at thirty and applied at forty, stored on the conversation row keyed by the message index it covers. The mid-conversation episode writer and its opening-half prompt are removed.

**Decisions:** mp-277, mp-290; approved as mp-292.

**Touches:** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/memory.ts, supabase/migrations/20260916100000_vana_conversation_summary_index.sql, supabase/functions/tests/vana/open_episode.test.ts, supabase/functions/tests/vana/extract.test.ts

- [ ] Replay at 39, 40 and 61 messages gives all verbatim, one summary plus twenty, one rolled summary plus twenty.
- [ ] The summary is written in the background when the count reaches thirty and the turn returns before that call does; it is applied from forty.
- [ ] The summary lives on the conversation row with the index it covers; a migration adds the index column and nothing else.
- [ ] writeOpenEpisode, the opening-half prompt and the open-episode test are gone; the episode row stays for the end-of-conversation writer.
- [ ] Dev deploy; a 45-turn eval conversation answers a question about turn three.

Next: /implement-lee mealplanning
