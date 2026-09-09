# 10: Vana everywhere

**What to build:** An athlete on any ordinary screen sees Vana in the bottom corner, taps her, and a glass sheet rises over the screen they were on. They ask about what is in front of them and she answers with the Situation. Closing the sheet returns them exactly where they were. Opening it again later that day continues the same ambient general conversation; the next day starts a new one. A full-screen affordance opens the existing chat route. The launcher is absent on auth, onboarding, privacy consent, paywall, force-upgrade, and all Vana routes. Gating follows the app's gate; nothing Vana-specific.

**Blocked by:** 04 Situation, 09 Vana sheet spec

**Status:** ready-for-agent

- [ ] The sheet widget is implemented once under its spec name with the spec header comment, and composed by the shell
- [ ] Launcher shows on every route except the excluded set, proven by a widget test over the router
- [ ] One ambient conversation per person per day; a new day opens a new one, proven through the real notifier
- [ ] The Situation for the underlying screen is sent with each message from the sheet
- [ ] Full-screen affordance opens the chat route with the same conversation
- [ ] Goldens for closed, open, and streaming states on the glass shell
- [ ] Verified on the simulator on at least the Plan tab, fuel log, and settings
