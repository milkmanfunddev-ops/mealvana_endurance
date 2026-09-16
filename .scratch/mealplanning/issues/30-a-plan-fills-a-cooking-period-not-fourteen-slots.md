# 30: A plan fills a cooking period, not fourteen slots

**Status:** done (wave 5, 2026-09-16)
**Blocked by:** 15 (touches supabase/functions/_shared/vana/persona.ts), 22 (touches lib/features/meal_planning/presentation/widgets/review_sheet.dart), 26 (touches supabase/functions/_shared/vana/tools.ts), 27 (touches supabase/functions/_shared/vana/tools.ts), 29 (touches supabase/functions/_shared/vana/plan-math.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete who batches picks a few meals and the servings scale so the batch covers their period; coverage counts servings against the period; one who does not batch plans per day; the walk covers only the meal types they plan, in any order; one tap drafts the period from what they ate last time; Draft it for me stays deterministic and the model only presents it.

**Decisions:** mp-231, mp-232; approved as mp-308.

**Touches:** supabase/functions/_shared/vana/plan-math.ts, supabase/functions/_shared/vana/plan.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/doll.test.ts, lib/features/meal_planning/domain/plan_coverage.dart, lib/features/meal_planning/application/plan_coverage_service.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart

- [x] Coverage counts servings against the period from the settings; batch mode scales servings to cover it; per-day mode counts days (server and client seams agree on fixtures).
- [x] The walk visits only the types the athlete plans, in the order they choose (server seam).
- [x] "Same as last time" drafts the period from the previous confirmed plan deterministically (server seam).
- [ ] Simulator: a ten-day period in batch mode shows servings scaled and coverage against ten days.

Next: /implement-lee mealplanning
