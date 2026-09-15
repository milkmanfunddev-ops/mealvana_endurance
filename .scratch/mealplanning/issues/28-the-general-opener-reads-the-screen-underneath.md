# 28: The general opener reads the screen underneath

**Status:** in-progress (wave 4, 2026-09-15)
**Blocked by:** 15, 20 (touches lib/features/meal_planning/presentation/screens/vana_chat_screen.dart).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete opens the sheet on the event screen and Vana's first line is about that event; on a screen that says nothing useful, she says the most relevant personal thing she holds. The general opener reads the resolved Situation before anything else; the example chips are removed from the empty state; offline, rate limit and out-of-trial keep their one visible outcome each.

**Decisions:** mp-268, mp-008; approved as mp-306.

**Touches:** supabase/functions/_shared/vana/moment.ts, supabase/functions/tests/vana/moment.test.ts, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart

- [ ] The general opener with a Situation naming an event, a meal or a session opens on it; with a bare route it falls back to the personal opener (server seam).
- [ ] The three example chips are gone from the empty state (golden).
- [ ] Simulator: open the sheet on an event and hear about the event.

Next: /implement-lee mealplanning
