# 13: Day notes regenerate only when the plan changed

**Status:** ready-for-agent
**Blocked by:** 02 (touches supabase/functions/_shared/vana/daynotes.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** The Plan tab's day notes are always current and are written again only for the days a plan edit touched. Opening the Plan tab on an unchanged plan calls no model.

**Decisions:** mp-432; approved as mp-478.

**Touches:** supabase/functions/vana-day-notes, supabase/functions/_shared/vana/daynotes.ts, lib/features/meal_planning/data/meal_plan_repository.dart

- [ ] A plan edit regenerates only the days it touched (server test).
- [ ] The endpoint returns the stored notes when the plan is unchanged and calls no model (test).
- [ ] A claim row makes two simultaneous requests share one model call (test with two parallel requests).
- [ ] The client's refresh cannot start a second generation.
- [ ] On dev, generations per athlete per day are recorded in this ticket before and after.

Next: /implement-lee ai-cost
