# 13: Every turn after the first is cached

**Status:** in-progress (wave 1, 2026-09-15)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete's second turn in a conversation is served from a cached prefix. Caching is on through the gateway's automatic mode; the context block is assembled once when a conversation opens and reused for its turns, refreshed only on a tool write or a new day; per-message memory recall leaves the block; the prompt order is tools, persona, context, messages; every call logs its cache-read tokens beside its input tokens, so the vana_calls table shows a non-zero read on turn two.

**Decisions:** mp-276, mp-290, mp-218; approved as mp-291.

**Touches:** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/context.ts, supabase/functions/_shared/vana/log.ts, supabase/functions/tests/vana/context_block.test.ts, supabase/functions/vana-eval

- [x] The gateway call carries automatic caching and the cache-read token count is written to vana_calls per call.
- [x] The context block is built once per conversation open and reused; a tool write (plan, memory, pantry, home) or a day change rebuilds it; nothing else does.
- [x] Per-message memory recall is out of the block; recall remains a tool.
- [x] Prompt order is tools, persona, context, messages, and the block is byte-identical across two turns with no writes between (mp-218 test extended).
- [x] The eval records cache reads per case and fails a case whose second turn reads zero.
- [x] Dev deploy of vana-chat; a two-turn conversation on the dev account shows a non-zero cache read on turn two.

Next: /implement-lee mealplanning
