# 07: The cache reads everything that repeats

**Status:** ready-for-agent
**Blocked by:** 02 (touches supabase/functions/_shared/vana/chat.ts), 04 (touches supabase/functions/_shared/vana/chat.ts), 05 (touches supabase/functions/_shared/vana/chat.ts), 06 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** Nothing changes for the athlete. A planning turn reads 80% or more of its input from the cache, against 43% today, and costs about a cent.

**Decisions:** mp-420, mp-276, mp-290; approved as mp-472.

**Touches:** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/context-cache.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/prompt_cache.test.ts

- [ ] First, the one-line dev experiment with the gateway's automatic caching on ten planning turns; first-step cached tokens are recorded in this ticket.
- [ ] The system prompt is two system messages, persona then athlete context. A context rebuild leaves the first byte-identical (extends the prompt cache test). Each gets an explicit marker where automatic caching does not mark it.
- [ ] Calls are pinned to Anthropic and carry a session id per conversation. The tool list never varies per turn.
- [ ] The screen line and the opener's hidden first message are stored with the transcript; a stored conversation replays byte-for-byte as first sent (test).
- [ ] The shared prefix uses the one-hour lifetime if the setting survives the gateway; the dev result is recorded either way.
- [ ] The opener's start-time test stays at 3.5 seconds.
- [ ] Dev, after: the read share on ten planning turns is recorded in this ticket. Target 80% or better.

Next: /implement-lee ai-cost
