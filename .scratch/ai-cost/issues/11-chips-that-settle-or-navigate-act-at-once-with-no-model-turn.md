# 11: Chips that settle or navigate act at once, with no model turn

**Status:** in-progress (wave 6, 2026-09-23)
**Blocked by:** 04 (touches supabase/functions/_shared/vana/actions.ts), 05 (touches lib/features/meal_planning/application/vana_chat_controller.dart), 07 (touches supabase/functions/_shared/vana/persona.ts), 09 (touches supabase/functions/_shared/vana/actions.ts).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** Tapping "Draft my whole week", "Same as last time", the batch-cooking answer, a coverage answer, "Open shopping list", "Lay it across the week", "Use what I have" or the pantry card's "Use these" does the thing at once. No model runs, nothing is drawn from the budget, and Vana writes no line. On her next turn Vana knows what was tapped and what it produced.

**Decisions:** mp-464; approved as mp-476.

**Touches:** lib/features/meal_planning/presentation/widgets/choice_chips.dart, lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/widgets/pantry_card.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, lib/features/meal_planning/data/vana_action_client.dart, supabase/functions/_shared/vana/actions.ts, supabase/functions/_shared/vana/persona.ts, supabase/functions/_shared/vana/contracts.ts

- [ ] Each chip named above runs its action on the no-model endpoint; a transport that counts shows no chat request for any of them (widget tests through the real chat controller).
- [ ] The result arrives with no written line from Vana and nothing templated in her voice.
- [ ] The tap and what it produced are stored in the conversation; Vana's next turn is sent them, and a stored conversation still replays byte-for-byte (extends ticket 07's test).
- [ ] These taps draw nothing from the monthly budget and are logged as taps.
- [ ] The persona's chip instructions shrink to the chips that still reach Vana.
- [ ] Chips Vana named herself, "Adjust", openers and typed messages still go to Vana (test).
- [ ] Checked on a pool simulator: a plan drafted, a coverage answer and "Open shopping list", each with no model call in the log.

Next: /implement-lee ai-cost
