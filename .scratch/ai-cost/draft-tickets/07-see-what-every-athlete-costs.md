# 07: See what every athlete costs

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 07 ai-cost`
**Model:** opus
**Due:** before 2026-10-01

**What to build:** October's traffic sets the allowance, so the log has to be able to answer. mp-420 clause 6.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/vana-cost-and-pricing.md "Log from day one"; ai-cost-fees-credits-and-no-model-paths.md part 5

**Touches:** supabase/migrations/, supabase/functions/_shared/vana/log.ts, supabase/functions/_shared/vana/chat.ts, lib/features/meal_planning/ (tap or typed flag on send), docs/database/

- [ ] `vana_calls` gains cache-write tokens, step count, gateway cost, debited, tap-or-typed, plan and trial state. Idempotent migration, applied to dev.
- [ ] The app sends whether a message was a chip tap or typed.
- [ ] A saved SQL view gives, per week: cost per athlete by plan, step-one cache hit rate, cost per confirmed plan, share of spend in conversations that never add a meal, share of turns that are fixed-label taps.
- [ ] A daily check flags any account over $1.50 in a day to Sentry.
- [ ] `vana_calls`, `ai_usage` and `plan_generation_log` get a retention sweep (raw rows 90 days, weekly rollups kept).

Next: /mattpocock-skills:implement 07 ai-cost
