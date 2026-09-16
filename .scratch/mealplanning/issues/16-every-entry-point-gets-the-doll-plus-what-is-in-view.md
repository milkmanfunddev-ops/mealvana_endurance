# 16: Every entry point gets the Doll plus what is in view

**Status:** in-progress (wave 4, 2026-09-15)
**Blocked by:** 13 (touches supabase/functions/_shared/vana/context.ts), 15 (touches lib/features/meal_planning/application/vana_ambient_conversation_controller.dart).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete on the events screens asks about the second race and Vana knows it; the Plan tab's Vana card opens the same conversation the launcher does. The server adds one capped section for the entity in view (EVENTS AHEAD on the events routes, the day's plan on the Plan tab) only while it is in view; the Doll stays the fixed digest; the note card routes to the day's ambient conversation; New meal plan and the plus button start new and leave the launcher's pointer alone.

**Decisions:** mp-273, mp-275, mp-058; approved as mp-294.

**Touches:** supabase/functions/_shared/vana/context.ts, supabase/functions/_shared/vana/situation.ts, supabase/functions/tests/vana/context.test.ts, supabase/functions/tests/vana/situation.test.ts, lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/application/vana_ambient_conversation_controller.dart, test/features/meal_planning/application/vana_ambient_conversation_test.dart

- [x] Events routes in the Situation produce an EVENTS AHEAD section listing every upcoming event; the Plan tab produces the day's plan; any other route produces no section (server seam).
- [x] The Doll block itself is unchanged in shape by any entry point (mp-218 test).
- [x] The Plan tab note card opens the day's ambient conversation, not a fresh one (controller test).
- [x] A conversation started by New meal plan or the plus button does not change the launcher's pointer (controller test).
- [ ] Simulator: note card and launcher land in the same thread.

Next: /implement-lee mealplanning
