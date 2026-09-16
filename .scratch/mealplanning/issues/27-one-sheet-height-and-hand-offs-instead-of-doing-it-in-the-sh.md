# 27: One sheet height, and hand-offs instead of doing it in the sheet

**Status:** in-progress (wave 4, 2026-09-15)
**Blocked by:** 15 (touches lib/features/meal_planning/presentation/widgets/vana_companion.dart), 26 (touches supabase/functions/_shared/vana/tools.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** The sheet opens at one standard height and its contents scroll; the close button or a plain drag down dismisses it; nothing grows on send or resizes while Vana streams; full screen happens only from its button. When the athlete asks for something the app has a screen for, Vana answers with a hand-off button (meal plan to the meal-planning page, fuelling a workout to new activity, planning an event to the event screen, carb loading to the picks) instead of doing it in the sheet; the button is a new part in the wire contract that the app renders.

**Decisions:** mp-265, mp-061; approved as mp-305.

**Touches:** lib/shared/widgets/kyle_design/navigation/vana_sheet.dart, lib/features/meal_planning/presentation/widgets/vana_companion.dart, lib/features/meal_planning/presentation/widgets/vana_part_renderer.dart, supabase/functions/_shared/vana/contracts.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/tests/vana/contract.test.ts, docs/ssot/spec/design/components/vana-sheet.md

- [x] One height, no auto or three-quarter state, no custom thresholds; goldens regenerated and the component spec updated with its version.
- [x] A hand-off part in the contract (target screen, label, entity id) rendered as a button that navigates; the frozen fixtures carry it (contract test).
- [ ] The persona names the four hand-offs and the eval shows a meal-plan request in the sheet answered with the button, not a picker.
- [ ] Simulator: ask for a plan from the sheet, tap the button, land on the meal-planning page.

Next: /implement-lee mealplanning
