# 12: Picker chips fetch the next picker with no model turn

**Status:** in-progress (wave 7, 2026-09-23)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/tools.ts), 04 (touches supabase/functions/_shared/vana/actions.ts), 05 (touches lib/features/meal_planning/application/vana_chat_controller.dart), 06 (touches supabase/functions/_shared/vana/tools.ts), 07 (touches supabase/functions/_shared/vana/persona.ts), 09 (touches supabase/functions/_shared/vana/actions.ts), 11 (touches lib/features/meal_planning/presentation/widgets/picker_chips.dart).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** "Other options", "No recipe only" and "Under 20 min" bring the next picker at once with no model. "I like these" and "Next" do the same when the next step is simply the next meal type's picker; when the next step is a question or the wrap-up, the tap goes to Vana as today. "Different protein" stays with Vana.

**Decisions:** mp-464; approved as mp-477.

**Touches:** lib/features/meal_planning/presentation/widgets/picker_chips.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, supabase/functions/_shared/vana/actions.ts, supabase/functions/_shared/vana/tools.ts, supabase/functions/_shared/vana/persona.ts

- [x] A no-model action returns the next picker for the same meal type with the same filters, leaving out meals already shown (server test against the picker's frozen contract fixture).
- [x] "No recipe only" and "Under 20 min" map to fixed picker arguments in one table, tested.
- [x] "I like these" and "Next" run the no-model action when the next step is the next meal type's picker, and go to Vana when it is a question or the wrap-up (tests for both).
- [x] No written line; the tap and the picker are stored for Vana's next turn; nothing drawn from the budget; logged as taps.
- [x] Checked on a pool simulator: a week planned with "Other options" and "I like these", with model calls in the log only where Vana asks or wraps up.
- [x] On dev, the model calls and input tokens for a scripted five-picker conversation are recorded in this ticket before and after.

## Measurements

Scripted five-picker conversation on DEV (`scripts/vana-eval/picker-chip-cost.ts`), a fresh Pro athlete with both
rule-4 forks settled (batch on, dinners and lunches): new-plan opener, typed "Quick weeknights" (Vana's first dinner
picker), then "Other options", "Under 20 min", "Next: Lunch", "Other options" (four more pickers) and "I like these"
(walk spent, so Vana wraps up). Figures read back from `vana_calls` for each conversation, 2026-09-23.

| | code on dev | model calls | input tokens | of which cache reads | taps with no model |
|---|---|---|---|---|---|
| Before | base `1ad254fc` (vana-chat v81, vana-action v45, deployed 11:05 UTC for this measurement) | 7 | 232,528 | 192,382 | 0 |
| After | ticket 12 `7315501d` (vana-chat v82, vana-action v46, deployed 11:06 UTC) | 3 | 87,004 | 63,849 | 4 |

- Before, conversation `a1637ce6-7fec-4d7e-9e8d-b43fcaa4030e`: opener 15,101 · typed 31,833 · the five chip taps
  33,599 / 35,400 / 37,124 / 38,893 / 40,578 (each two model steps, each debited).
- After, conversation `97786436-bac1-4088-9d05-3b2188a2ca37`: opener 15,087 · typed 31,784 · four
  `vana.tap.next_picker.meal_planning` rows (model `none`, 0 tokens, not debited, `input_mode` tap) · "I like these"
  handed to Vana for the wrap-up 40,133.
- The four picker chips that used to cost 145,016 input tokens and four debited turns cost nothing; the wrap-up still
  costs one turn, as it should. The same five pickers appeared in both runs (dinner, dinner, dinner, lunch, lunch).
- An earlier run against the functions dev had before this ticket's deploys (vana-chat v80 from 09-22, which predates
  ticket 04's compaction) cost 7 calls and 726,530 input tokens; it is not the base code, so it is not the before figure.

**Device check (wave-pool-1, iOS 26.2, dev flavor, 2026-09-23 11:12-11:16 UTC).** The dev account (per-night cooking,
dinners only) planned a five-dinner week in conversation `f6a0f7fa-6cc0-42c2-bbb7-9aca997c535d`: "Other options" twice
and "Under 20 min" once each brought a picker at once with no line from Vana and logged
`vana.tap.next_picker.meal_planning` (model `none`, not debited). The model calls in the log are the opener, Vana's own
"Quick weeknight options" chip, and the three "I like these" taps, which the server handed to Vana because the walk
(dinners only) had no next type; the third one was her wrap-up. The first two she answered with another dinner picker,
since five nights were not yet covered (see the open question in the wave report).

Next: /implement-lee ai-cost
