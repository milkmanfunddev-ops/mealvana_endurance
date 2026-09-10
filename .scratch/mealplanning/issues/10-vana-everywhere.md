# 10: Vana everywhere — the launcher and the sheet

**What to build:** An athlete on any ordinary screen sees Vana in the bottom-right corner, taps her,
and a glass sheet rises over the screen they were on. They ask about what is in front of them and she
answers with the Situation. Closing the sheet condenses it back into the launcher and returns them
exactly where they were. Opening it again later that day continues the same ambient conversation; the
next day starts a new one. A full-screen affordance opens the existing chat route with the same
conversation. The launcher is absent on auth, onboarding, privacy consent, paywall, force-upgrade, and
all Vana routes. Gating follows the app's gate; nothing Vana-specific.

**Blocked by:** 09 Vana sheet spec (ratification — Q-VS1 and Q-VS2 are answered by the export and need
confirming; Q-VS3 and Q-VS4 are still open but do not block a passive build)

**Status:** ready-for-agent once the spec is confirmed

**Scope note (Lee, 2026-09-10):** everywhere, not home-first. The Situation plumbing already reports
from fifteen screens, so the launcher has something to say wherever it appears.

- [ ] The sheet widget is implemented once under its spec name with the spec header comment, and composed by the shell
- [ ] Launcher shows on every route except the excluded set, proven by a widget test over the router
- [ ] One ambient conversation per person per day; a new day opens a new one, proven through the real notifier
- [ ] The Situation for the underlying screen is sent with each message from the sheet
- [ ] Full-screen affordance opens the chat route with the same conversation
- [ ] Dismissing condenses into the launcher (spec VS-9); it never slides off-screen
- [ ] Goldens for closed, open and streaming on the glass shell
- [ ] Verified on the simulator on at least the Plan tab, fuel log, and settings
