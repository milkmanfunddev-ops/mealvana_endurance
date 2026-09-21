# 13: Day notes regenerate only when the plan changed

**Status:** in-progress (wave 2, 2026-09-21)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/daynotes.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** The Plan tab's day notes are always current and are written again only for the days a plan edit touched. Opening the Plan tab on an unchanged plan calls no model.

**Decisions:** mp-432; approved as mp-478.

**Touches:** supabase/functions/vana-day-notes, supabase/functions/_shared/vana/daynotes.ts, lib/features/meal_planning/data/meal_plan_repository.dart

- [x] A plan edit regenerates only the days it touched (server test).
- [x] The endpoint returns the stored notes when the plan is unchanged and calls no model (test).
- [x] A claim row makes two simultaneous requests share one model call (test with two parallel requests).
- [x] The client's refresh cannot start a second generation.
- [ ] On dev, generations per athlete per day are recorded in this ticket before and after. **after: owed, measured by the wave lead after deploy.**

## Comments

**Generations per athlete per day on DEV — before (2026-09-21, read-only).** Counted from
`public.vana_calls` where `function_name = 'vana.daynotes'`; one row is one Haiku call that wrote a
plan's notes, which is the only place day-note generations are logged.

```sql
select created_at::date as d, user_id, count(*) as generations, sum(coalesce(output_tokens,0)) as out_tok
from public.vana_calls where function_name = 'vana.daynotes'
group by 1,2 order by 1 desc, 3 desc;
```

62 generations over 17 athlete-days (5 athletes), all of history: **mean 3.6 per athlete per day,
median 1, peak 13** (`37129f7e…` on 09-03). The heavy days are the ones with plan editing in them —
08-31 (10), 09-01 (9), 09-16 (8), 09-03 (13) — because every plan mutation flipped
`day_notes_stale` and every regeneration rewrote all seven days.

Last 14 days: 14 generations over 5 athlete-days, peak 8 (09-16).

**after: owed, measured by the wave lead after deploy** — the same query once
`vana-day-notes` and the migration are on DEV, over a day of plan editing. What should move: a
plan edit costs one call for the days it touched instead of one for all seven, and a second
request while one is running costs none.

Next: /implement-lee ai-cost
