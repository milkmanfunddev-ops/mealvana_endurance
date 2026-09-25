# 04: A hard monthly budget on every gateway key

**Status:** ready-for-human
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 04 ai-cost`
**Model:** opus
**Due:** before 2026-10-01

**What to build:** Lee creates three AI Gateway keys in the Vercel dashboard (prod, dev, eval and agents), each with a monthly budget and alerts, and sets them as function secrets. An agent does the code half.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-vercel-and-services.md; ai-cost-claude-platform.md item 5

**Touches:** supabase/functions/_shared/ai/model.ts, supabase/functions/_shared/vana/env.ts, supabase/functions/_shared/vana/chat.ts, scripts/vana-eval/, secrets/ai_gateway.env (Lee)

- [ ] Three keys exist with budgets: Lee picks the numbers; suggested $150 prod for October, $40 dev, $25 eval.
- [ ] A 402 from the gateway surfaces as "Vana is unavailable right now", never as the top-up sheet or a crash (handler test with a stubbed 402).
- [ ] The `npm:ai` import is pinned to an exact version in every function.
- [ ] The default chat model id matches the gateway catalogue spelling; one dev call confirms it resolves.
- [ ] The changelog script's `DRY_RUN` calls no model.

Next: /mattpocock-skills:implement 04 ai-cost
