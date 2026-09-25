# 06: The cache reads everything that repeats

**Status:** ready-for-agent
**Blocked by:** 05 (touches chat.ts)
**Next:** `/mattpocock-skills:implement 06 ai-cost`
**Model:** fable
**Due:** before 2026-10-01

**What to build:** Planning turns read 43% of input from cache. Split what never changes from what does, make replay byte-stable, and make the meal-logging prompts cacheable. Implements mp-420 clauses 4 and 5 (proposed; build on dev, hold production for the ruling).

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/vana-cost-and-pricing.md lever 1, 2; ai-cost-vercel-and-services.md items 1 to 3; ai-cost-claude-platform.md item 3

**Touches:** supabase/functions/_shared/vana/chat.ts, supabase/functions/_shared/vana/context-cache.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/describe-meal/, supabase/functions/analyze-meal-photo/, supabase/functions/ai-coach/, supabase/functions/tests/vana/, lib/features/ (photo resize before upload)

- [ ] First, the one-line experiment: `providerOptions.gateway.caching: 'auto'` on dev, ten planning turns, step-one `cache_read_tokens` recorded here.
- [ ] The system prompt is two system messages, persona then athlete context. A context rebuild leaves the first byte-identical (shape test). Explicit `cacheControl` on each where automatic mode does not cover it.
- [ ] Provider pinned to `anthropic`; a per-conversation `x-session-affinity` is sent. The tool list never varies per turn.
- [ ] The Situation line and the opener's first message are stored with the transcript; assistant steps replay as sent. A replayed conversation reproduces the bytes first sent (shape test).
- [ ] The shared prefix uses the 1-hour TTL if the setting survives the gateway; the dev result is recorded either way.
- [ ] `describe-meal` and `analyze-meal-photo` send fixed instructions first with a 1-hour marker and the athlete's input last. `totals` is computed in the function; `not_food` is in the schema.
- [ ] Photos are capped at 1,000 px on the long edge and portrait photos bill the same as landscape.
- [ ] Dev, after: planning turn read share recorded here. Target 80% or better; planning turn about $0.012.

Next: /mattpocock-skills:implement 06 ai-cost
