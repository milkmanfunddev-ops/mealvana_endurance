# 08: Day notes regenerate only when the plan changed

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 08 ai-cost`
**Model:** opus
**Due:** October

**What to build:** Dev shows 3.7 day-note generations per user per day against an assumed 2 a week; 20 of 63 came within two minutes of the last.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/ai-cost-internal-audit.md finding 5

**Touches:** supabase/functions/vana-day-notes/, supabase/functions/_shared/vana/daynotes.ts, lib/features/meal_planning/ (the 7-second stale poll)

- [ ] A plan edit regenerates only the days it touched.
- [ ] Two isolates cannot generate for the same athlete and day at once (claim row; test).
- [ ] The endpoint returns stored notes when the plan is unchanged and calls no model.
- [ ] The client poll cannot start a second generation.

Next: /mattpocock-skills:implement 08 ai-cost
