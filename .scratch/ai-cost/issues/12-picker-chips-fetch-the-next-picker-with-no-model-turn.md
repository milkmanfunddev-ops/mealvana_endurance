# 12: Picker chips fetch the next picker with no model turn

**Status:** in-progress (wave 7, 2026-09-23)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/tools.ts), 04 (touches supabase/functions/_shared/vana/actions.ts), 05 (touches lib/features/meal_planning/application/vana_chat_controller.dart), 06 (touches supabase/functions/_shared/vana/tools.ts), 07 (touches supabase/functions/_shared/vana/persona.ts), 09 (touches supabase/functions/_shared/vana/actions.ts), 11 (touches lib/features/meal_planning/presentation/widgets/picker_chips.dart).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** "Other options", "No recipe only" and "Under 20 min" bring the next picker at once with no model. "I like these" and "Next" do the same when the next step is simply the next meal type's picker; when the next step is a question or the wrap-up, the tap goes to Vana as today. "Different protein" stays with Vana.

**Decisions:** mp-464; approved as mp-477.

**Touches:** lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, supabase/functions/_shared/vana/actions.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts

- [ ] A no-model action returns the next picker for the same meal type with the same filters, leaving out meals already shown (server test against the picker's frozen contract fixture).
- [ ] "No recipe only" and "Under 20 min" map to fixed picker arguments in one table, tested.
- [ ] "I like these" and "Next" run the no-model action when the next step is the next meal type's picker, and go to Vana when it is a question or the wrap-up (tests for both).
- [ ] No written line; the tap and the picker are stored for Vana's next turn; nothing drawn from the budget; logged as taps.
- [ ] Checked on a pool simulator: a week planned with "Other options" and "I like these", with model calls in the log only where Vana asks or wraps up.
- [ ] On dev, the model calls and input tokens for a scripted five-picker conversation are recorded in this ticket before and after.

Next: /implement-lee ai-cost
