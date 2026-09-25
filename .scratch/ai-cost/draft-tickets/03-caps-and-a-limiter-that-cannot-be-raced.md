# 03: Daily caps, and a rate limiter that cannot be raced

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 03 ai-cost`
**Model:** opus
**Due:** before 2026-10-01

**What to build:** Bound what one account can spend in a day and close the free paths.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-internal-audit.md findings 3, 7; vana-cost-and-pricing.md; mp-430 clause 8

**Touches:** supabase/functions/_shared/vana/rate-limit.ts, supabase/functions/_shared/vana/chat.ts, supabase/functions/vana-chat/index.ts, supabase/functions/_shared/ai/credits.ts, supabase/functions/vana-action/ (pantry_photo), supabase/functions/describe-meal/, supabase/functions/analyze-meal-photo/, supabase/functions/ai-coach/

- [ ] A request with a conversation id and an empty message returns 400, runs no model and stores no row.
- [ ] The opener window is actually called: 3 a minute and 40 in 24 hours. Chat adds 150 turns in 24 hours. The 41st opener and 151st turn are refused (handler tests).
- [ ] The limiter counts calls in flight: five parallel requests against a limit of four let four through (test).
- [ ] `pantry_photo`, `describe-meal`, `analyze-meal-photo` and `ai-coach` use the limiter.
- [ ] The credit check fails closed when the database errors, and check-then-debit is one atomic debit; a drained balance serves nothing (test).
- [ ] `stopWhen` has a per-turn token ceiling.
- [ ] The refusal copy comes from the content system, not a hardcoded string.

Next: /mattpocock-skills:implement 03 ai-cost
