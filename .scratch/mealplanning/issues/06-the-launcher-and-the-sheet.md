# 06: The launcher and the sheet

**Status:** built; simulator pass done except the fuel-log screen itself (2026-09-10)
**Blocked by:** None for the code. The spec is still PROPOSED: 05 has not ratified it and it is not
mirrored into `docs/ssot/`. Built against Q-VS1 and Q-VS2 as the export answered them (Lee chose to
start 06 ahead of 05).
**Next:** `/mattpocock-skills:implement 07` or `08`. The launcher-over-bottom-CTA overlap seen on
the device needs a ruling first (see the simulator notes).

**What to build:** An athlete on any ordinary screen sees Vana in the bottom-right corner, taps her,
and a glass sheet rises over the screen they were on. They ask about what is in front of them and she
answers with the Situation. Closing condenses the sheet back into the launcher and returns them
exactly where they were. Opening it again later the same day continues the same ambient conversation;
the next day starts a new one. A full-screen affordance opens the existing chat route with the same
conversation.

The launcher is absent on auth, onboarding, privacy consent, paywall, force-upgrade and all Vana
routes. Gating follows the app's gate; nothing Vana-specific.

**Scope (Lee, 2026-09-10): everywhere, not home-first.** The Situation plumbing already reports from
fifteen screens, so the launcher has something to say wherever it appears.

**The Situation's own device check rides here.** Ticket 04 of the old set — the Situation — is built
and unit-verified but has never been looked at on a device. The simulator pass below covers it: the
sheet is what will exercise the reporting for real.

- [x] The sheet widget is implemented once under its spec name with the spec header comment, and composed by the shell
- [x] Launcher shows on every route except the excluded set, proven by a widget test over the router
- [x] One ambient conversation per person per day; a new day opens a new one, proven through the real notifier
- [x] The Situation for the underlying screen is sent with each message from the sheet
- [x] Full-screen affordance opens the chat route with the same conversation
- [x] Dismissing condenses into the launcher (spec VS-9); it never slides off-screen
- [x] Goldens for closed, open and streaming on the glass shell
- [~] Simulator: the Plan tab, the fuel log and settings, and from a fuel-log Situation "what should I eat before this" names that session

## Simulator pass (iPhone 17 Pro, dev, 2026-09-10)

- **Timeline:** the opener landed and knew today was a rest day (the `/main` Situation).
- **Plan tab:** "which of the meals on this plan has the most protein" named the plan's meals and
  their protein. Reopening later continued the same conversation (VS-5).
- **Settings:** "what screen am I looking at" answered "the settings screen". That is the
  route-only Situation. Before the fix it would have been the Plan tab.
- **A session:** the test account had none, so a 12 mi run was created for today on dev. On its
  activity-detail screen, "what should I eat before this" named the 12 mi run. **The fuel-log
  screen itself was not reached**: it only opens for a completed session. It resolves to the same
  activity server-side.
- Under the calendar sheet the launcher has no node. Scrim and close returned to the same screen.

**Found on the device, fixed:** the launcher's `Semantics` merged into the app's root node, so
VoiceOver read the whole screen as one "Ask Vana" button. It is its own node now, with a test.

**Found on the device, not fixed:**
- **The launcher covers the right end of full-width bottom buttons** ("Generate Plan" on the
  new-activity screen) and the right edge of the pre-workout card on the session screen. This is
  Q-VS4 widened to every screen. It needs a ruling: a clearance inset per screen, or hiding the
  launcher on flow screens.
- **Dev builds:** the accessibility-tools buttons (red checker, blue wrench) sit on the launcher,
  and the wrench covers the sheet's send button. Return still sends.
- **Server, pre-existing:** a reloaded transcript loses assistant text that came before a tool
  part. The opener's "Today is a full rest day…" and the "I'll pull up the meals…" preamble were
  gone on reopen, and only the text after the tool call came back. The chat route has the same
  problem.
- **Server, pre-existing:** the activity Situation sentence read "1h 48m" as "starting at 108
  minutes", and Vana asked what time the run was on "Thursday" (it was today, 9:30 pm). The
  resolver's sentence should carry the start time and say "today".

## Notes (2026-09-10)

**Where things are.** The design widgets (`VanaLauncher`, `VanaSheet`, `VanaSheetRoute`) are in
`lib/shared/widgets/kyle_design/navigation/vana_sheet.dart`. The host, the navigator observer and
the conversation inside the sheet are in `lib/features/meal_planning/presentation/widgets/vana_companion.dart`,
composed in `root_app_widget.dart` under `AppStartupWidget`, so there is no launcher before startup
resolves. The route rule is `domain/vana_launcher_rule.dart`. The ambient conversation is
`application/vana_ambient_conversation_controller.dart`, a per-user, per-day pointer in
SharedPreferences, so it is per device: a second phone opens its own ambient conversation that day.

**How it behaves.**
- The sheet is a popup route on the root Navigator. The page underneath keeps its state and scroll
  position, and scrim tap and system back pop the sheet for free. Every pop runs the condense,
  because the motion is chosen from the animation's direction, not from the path that closed it.
- The launcher is hidden under any dialog or bottom sheet, its own included, through
  `VanaCompanionObserver` on the router.
- Without Pro, the launcher opens the paywall, the same as the chat route's gate.

**The Situation needed a fix.** A screen with no `VanaSituationScope` (settings, most screens)
reported nothing, so the last scoped screen, say the fuel log, went on speaking for the athlete
from settings. The host now tells the controller which route is on top. A report counts only while
the route it was made under is on top; anywhere else the Situation is that route alone. A scope also
re-reports when its route comes back on top, so meal A → meal B → back reads as A again. All
the main tabs share `/main`, so the tab shell now speaks for every tab (the day on the Timeline,
`/learn` and so on elsewhere). A tab's own scope reports after the shell and wins, and Food → Learn
no longer leaves Food speaking.

**Adoption.** The host, not the sheet, adopts the id the server gives the day's first
conversation. So closing the sheet, or going full screen, before the opener's first event still
leaves the day holding that conversation.

**Full screen, VS-3.** The chat route is opened with the sheet's own provider key: `c=<id>` when
the day already had a conversation, no `c` when the sheet started one. Either way the chat screen
reads the same notifier, so it is the same conversation, in-flight turn included.

**Deliberately not here.**
- The three heights and the grabber drag are 08; the sheet rests at 75%.
- The export's inside of the sheet (status chip, quick replies, sparkle avatar, no-bubble prose) is
  07. The body today reuses `VanaMessageCard`.
- A part's planning actions (pick a meal, accept a rule, the pantry, swap) open the full-screen
  chat on the same conversation, where the plan bar lives. They do not run in the sheet.

**For the ruling desk.**
- The spec says top radius 26; the `glass-sheet` token is 24. The token wins in code.
- The export's scrim is blackberry 45%; the token's 60% is used.
- Everywhere means the launcher sits over bottom-right content on screens that have a full-width
  bottom CTA. That is Q-VS4's question, widened to every screen. It needs a look on the device.
- The export has no full-screen button. It is a second 30 px glass circle beside dismiss.

**Full history:** `../archive/issues-2026-09-10/10-vana-everywhere.md` and `04-situation.md`
