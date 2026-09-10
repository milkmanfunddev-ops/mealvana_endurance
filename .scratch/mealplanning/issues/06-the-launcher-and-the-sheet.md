# 06: The launcher and the sheet

**Status:** blocked
**Blocked by:** 05 (a design-bearing widget needs a ratified spec name)
**Next:** `/mattpocock-skills:implement 06` once 05 is ratified.

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

- [ ] The sheet widget is implemented once under its spec name with the spec header comment, and composed by the shell
- [ ] Launcher shows on every route except the excluded set, proven by a widget test over the router
- [ ] One ambient conversation per person per day; a new day opens a new one, proven through the real notifier
- [ ] The Situation for the underlying screen is sent with each message from the sheet
- [ ] Full-screen affordance opens the chat route with the same conversation
- [ ] Dismissing condenses into the launcher (spec VS-9); it never slides off-screen
- [ ] Goldens for closed, open and streaming on the glass shell
- [ ] Simulator: the Plan tab, the fuel log and settings, and from a fuel-log Situation "what should I eat before this" names that session

**Full history:** `../archive/issues-2026-09-10/10-vana-everywhere.md` and `04-situation.md`
