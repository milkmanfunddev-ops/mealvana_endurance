# 72: Confirm lands on the shopping list

**Status:** in-progress (wave 23, 2026-09-25)
**Blocked by:** 70 (touches lib/features/meal_planning/presentation/screens/vana_chat_screen.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** After Confirm the athlete lands on Food with its Shopping part open and the tab bar showing (mp-235); the `food=shopping` route query is applied. The main clone holds another session's uncommitted edits for this (Food segment landing, since 2026-09-23: food_screen, tabs_screen, app_router, plan_tab and others); read them first (`git -C <main clone> diff -- lib/`) and finish that work rather than starting over, then say which of those edits the ticket took.

**Findings:** 16-002 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-235

**Touches:** lib/features/meal_planning/presentation/screens/food_screen.dart, lib/shared/widgets/tabs_screen.dart, lib/shared/core/app_router.dart

- [ ] A router or widget test: the confirm route opens Food on Shopping.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
