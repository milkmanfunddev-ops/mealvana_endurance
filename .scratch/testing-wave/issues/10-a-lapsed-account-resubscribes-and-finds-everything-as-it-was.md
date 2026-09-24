# 10: A lapsed account resubscribes and finds everything as it was

**Status:** in-progress (wave 8, 2026-09-24)
**Blocked by:** 09.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete whose plan ended in ticket 09 buys again from the full-screen paywall and lands back in the app with their data as they left it. The account is then deleted.

**Decisions:** mp-280.

**Touches:** ticket 09's lapsed account

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Uses the lapsed account from ticket 09.
- [x] After buying: the Gate opens, RevenueCat and the Entitlement row agree on the new expiry, and a plan and a logged meal made before the lapse are still there.
- [x] The account is deleted in the app at the end and marked deleted in the credentials file.

Next: /implement-lee testing-wave
