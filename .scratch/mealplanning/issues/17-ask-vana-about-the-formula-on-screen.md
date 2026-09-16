# 17: Ask Vana about the formula on screen

**Status:** in-progress (wave 5, 2026-09-16)
**Blocked by:** 15 (touches supabase/functions/_shared/vana/schemas.ts), 16 (touches supabase/functions/_shared/vana/situation.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete editing a formula taps Ask Vana and a new conversation opens that sees the draft as it is on screen, unsaved edits included, plus everything Vana knows about them. The editor's Situation carries the draft as structured fields (phase, sub-phase, durations, activities, component ids and quantities, a name capped at forty characters); the server validates the shape and builds a FORMULA section; the one-shot insight panel is retired in favour of that conversation. Coach formula feedback is a Vana conversation like any other (mp-209).

**Decisions:** mp-274, mp-273, mp-209, mp-275; approved as mp-295.

**Touches:** supabase/functions/_shared/vana/situation.ts, supabase/functions/_shared/vana/schemas.ts, supabase/functions/tests/vana/situation.test.ts, lib/features/formula_kit/presentation/screens/formula_editor_screen.dart, lib/features/formula_kit/presentation/widgets/coach_insight_panel.dart, lib/features/formula_kit/application/coach_insight_controller.dart, lib/features/meal_planning/application/vana_situation_controller.dart, lib/features/meal_planning/presentation/widgets/vana_situation_scope.dart

- [ ] The Situation schema accepts a formula draft for the editor route only; any other route with a draft is refused (server seam).
- [ ] A draft in produces a FORMULA section out with its components and targets; an empty draft produces a one-line section (server seam).
- [ ] Ask Vana from the editor starts a new conversation and does not move the launcher's pointer (controller test).
- [ ] The insight panel's one-shot call is removed from the editor; the ai-coach function is left as it is for other callers.
- [ ] Simulator: edit a component, tap Ask Vana, she names the edited quantity.

Next: /implement-lee mealplanning
