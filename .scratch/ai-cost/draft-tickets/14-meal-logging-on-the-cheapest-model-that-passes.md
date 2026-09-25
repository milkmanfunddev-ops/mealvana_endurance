# 14: Meal logging runs on the cheapest model that passes

**Status:** ready-for-agent
**Blocked by:** 13, 06
**Next:** `/mattpocock-skills:implement 14 ai-cost`
**Model:** opus
**Due:** after 13

**What to build:** Candidates cost 50 to 90% less per call than Sonnet 4.6. Worth $0.40 to $0.57 per typical athlete a month.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-model-bakeoff.md; ai-cost-claude-platform.md item 4

**Touches:** supabase/functions/_shared/ai/model.ts, supabase/functions/describe-meal/, supabase/functions/analyze-meal-photo/, supabase/functions/ai-coach/

- [ ] Run Haiku 4.5, Gemini 3 Flash, Gemini 3.1 Flash-Lite, GPT-5 mini and Sonnet 5 (thinking off) over the truth set; results table in this ticket. About $60 of calls from the eval key.
- [ ] Model per job is one env var.
- [ ] `ai-coach` drops its temperature setting so it survives a Sonnet 5 move.
- [ ] Lee rules the switch from the table; nothing changes in production without it.

Next: /mattpocock-skills:implement 14 ai-cost
