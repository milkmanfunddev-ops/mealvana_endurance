# 07: The companion's conversation surface

**Status:** built (2026-09-10); not yet looked at on a device
**Blocked by:** None
**Next:** A simulator look at the sheet on a real screen, then `/mattpocock-skills:implement 08`.

**What to build:** The inside of the sheet, as the design export draws it. A status chip at the top
naming what this exchange is about — "Fuel plan · to do" in orange when there is something to do,
"Update" in electrolyte when there is not. Vana's messages flush left, each with a small filled orange
sparkle avatar. The athlete's own turns right-aligned in a soft cream-tinted bubble. A typing
indicator where the answer will land. At most two quick-reply chips, one filled and one outline, which
vanish the moment the thread has anything in it and do not come back in that exchange. A composer
whose send control is inert until there is a draft and orange once there is.

The generative-UI parts Vana already renders compose inside the message column unchanged.

- [x] Status chip derives from the exchange, not from a hardcoded string; both tones render
- [x] Vana and athlete message treatments match the spec, at iPhone-SE width and at large text
- [x] Quick replies: at most two, one filled and one outline; they retire on the first thread entry and stay retired
- [x] Typing indicator shows only while a turn is in flight, and never alongside quick replies
- [x] Composer send is inert with an empty draft and orange with a non-empty one
- [x] An existing VanaPart (a meal picker) renders inside the sheet's message column unchanged
- [x] Goldens for the four message shapes and both chip tones

## Notes (2026-09-10)

**Where things are.** The inside's widgets (status chip, sparkle avatar, Vana's turn, typing dots,
athlete turn, quick replies, composer) are in
`lib/shared/widgets/kyle_design/navigation/vana_sheet_conversation.dart`, exported from
`vana_sheet.dart`, with the export's sizes and colours. What shows when is
`domain/vana_exchange.dart`; `VanaCompanionSheet` in `vana_companion.dart` composes the two.

**How the exchange is read.**
- **The opening** is Vana's turns before the athlete's first; **the thread** is that turn and
  everything after. The general opener already ends in an `askChoice`, so the opening's `choices`
  part *is* the quick replies: its first two options, the first filled, the second outline. It is
  never also drawn inline, which is what keeps the replies from coming back once the thread starts.
  A `choices` part later in the thread renders as the usual chips.
- The replies retire on the first send and stay retired for the sheet's life, even when that turn
  fails and the controller rolls it out of the transcript.
- **The chip's tone** is from Vana's latest settled turn; the athlete's turns and the turn in flight
  do not count. `to do` when that turn asks for something in the thread (a choice, a meal picker, a
  rule, staples, the pantry), `Update` when it does not. The opening's offers are a menu, not a
  to-do, so the sheet opens on `Update`; the orange `to do` opening the export draws is the
  proactive moment of ticket 09. Answering a question does not finish the to-do; Vana's next turn
  does. No chip before she has said anything.
- **The chip's topic:** a planning part names the meal plan; otherwise the screen underneath does
  (the Fuel Timeline, a fuel log or a session's plan → "Fuel plan"; the Plan tab, a meal or cooking
  mode → "Meal plan"). Anywhere else a to-do is a bare "To do". Strings are content keys.
- The typing indicator is the in-flight turn while it has no prose yet, in Vana's row, so it sits
  where the answer lands. Replies need no turn in flight, so the two never show together.
- Send is grey with an empty or whitespace draft. Orange otherwise.
- A short conversation sits under the chip, as the export draws it; a long one sticks to its
  newest turn.

**For the ruling desk.**
- Send is also grey while a turn is in flight, even with a draft. The ticket and the export key
  the colour on the draft alone. The controller drops a send mid-stream, so an orange button that
  does nothing seemed worse; say if orange-while-streaming is wanted.
- Found in review and fixed before commit: the first build read the chip from the latest turn of
  either side, so it flipped to `Update` the moment the athlete sent.
- The spec's prose says the replies vanish "the moment the athlete types anything"; VS-8, this
  ticket and the export all say "the moment the thread has anything in it". Built to VS-8; typing
  a draft does not hide them.
- The general opener asks for "2–3" options, and the cap is two, so a third is dropped. Changing
  the prompt in `persona.ts` to ask for two would stop that; not done here (server deploy).
- The chip is pinned above the transcript rather than scrolling with it as in the export, so it
  stays readable in a long thread. They look the same while the conversation is short.
- The export's composer placeholder is "Ask about your fueling"; the sheet keeps the general
  placeholder.

**Full history:** `../archive/issues-2026-09-10/11-companion-conversation-surface.md`
