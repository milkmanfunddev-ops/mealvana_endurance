# 10: Vana everywhere

**What to build:** An athlete on any ordinary screen sees Vana in the bottom corner, taps her, and a glass sheet rises over the screen they were on. They ask about what is in front of them and she answers with the Situation. Closing the sheet returns them exactly where they were. Opening it again later that day continues the same ambient general conversation; the next day starts a new one. A full-screen affordance opens the existing chat route. The launcher is absent on auth, onboarding, privacy consent, paywall, force-upgrade, and all Vana routes. Gating follows the app's gate; nothing Vana-specific.

**Blocked by:** 04 Situation, 09 Vana sheet spec

**Status:** not started — blocked (2026-09-09)

- [ ] The sheet widget is implemented once under its spec name with the spec header comment, and composed by the shell
- [ ] Launcher shows on every route except the excluded set, proven by a widget test over the router
- [ ] One ambient conversation per person per day; a new day opens a new one, proven through the real notifier
- [ ] The Situation for the underlying screen is sent with each message from the sheet
- [ ] Full-screen affordance opens the chat route with the same conversation
- [ ] Goldens for closed, open, and streaming states on the glass shell
- [ ] Verified on the simulator on at least the Plan tab, fuel log, and settings

**Notes (2026-09-09).** Not started, and correctly blocked.

The sheet is a design-bearing widget, so it may only be implemented once under its spec name with a
header comment citing the spec path and version. Ticket 09's spec is PROPOSED with four unanswered
questions, two of which decide what gets built: the sheet's rest height (Q-VS1) and whether the
launcher collapses with the tab bar on scroll (Q-VS3). Building against a PROPOSED spec would mean
guessing those and then rebuilding.

The Situation half of this ticket is already done and shipped by ticket 04: every screen in the
table reports, the controller keeps the last reported screen for 30 minutes, and the chat controller
sends it. The sheet inherits that with no further work — whatever screen is underneath is already
the Situation.

What remains once the spec is ratified: the widget under its spec name, the launcher in the shell's
reserved bottom-right slot with the exclusion set proven by a widget test over the router, one
ambient conversation per person per day through the real notifier, goldens for closed / open /
streaming, and a simulator pass.

