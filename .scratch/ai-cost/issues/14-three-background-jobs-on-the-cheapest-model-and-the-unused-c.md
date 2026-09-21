# 14: Three background jobs on the cheapest model, and the unused coach insight removed

**Status:** in-progress (wave 2, 2026-09-21)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/extract.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Nothing changes for the athlete. The memory extraction, the rolling summary and the saved-meal ingredient list run on the cheapest gateway model that gives the same structured answer. The Formula Kit coach insight, which nothing calls, is removed. Chat stays on Haiku and meal logging on Sonnet.

**Decisions:** mp-465; approved as mp-479.

**Touches:** supabase/functions/_shared/vana/extract.ts, supabase/functions/_shared/vana/saved-ingredients.ts, supabase/functions/_shared/vana/env.ts, supabase/functions/ai-coach, supabase/functions/_shared/ai_coach, supabase/functions/_shared/ai/model.ts, lib/features/formula_kit/data/ai_coach_client.dart

- [ ] The three jobs read their model from one new setting, apart from the chat model.
- [ ] On 20 stored dev conversations the candidate's answers are compared by hand with Haiku's; the comparison and the model chosen are recorded in this ticket. If none matches, the setting stays on Haiku.
- [ ] The existing extract and saved-ingredients tests stay green.
- [ ] The coach insight route, its dead shared tools and the app's unused client are removed; the function is undeployed from dev.
- [ ] No helper model is called from inside a Vana turn.

Next: /implement-lee ai-cost
