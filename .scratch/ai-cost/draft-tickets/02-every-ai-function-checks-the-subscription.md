# 02: Every AI function checks the subscription

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 02 ai-cost`
**Model:** opus
**Due:** before 2026-10-01

**What to build:** `describe-meal`, `analyze-meal-photo`, `ai-coach` and `jade-chat` check credits only. Add the same entitlement check the four Vana functions use. Depends on mp-430 clause 9 being approved; the code is the same either way, so build it and hold the deploy if the card is rejected.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/vana-cost-and-pricing.md; mp-430 clause 9; mp-320

**Touches:** supabase/functions/_shared/vana/entitlement.ts, supabase/functions/describe-meal/, supabase/functions/analyze-meal-photo/, supabase/functions/ai-coach/, supabase/functions/jade-chat/

- [ ] An account with pack credits and no active entitlement gets the gate response from each of the four (one handler test each).
- [ ] An entitled account is unaffected; existing tests stay green.
- [ ] The client shows the paywall, not the top-up sheet, on that response.

Next: /mattpocock-skills:implement 02 ai-cost
