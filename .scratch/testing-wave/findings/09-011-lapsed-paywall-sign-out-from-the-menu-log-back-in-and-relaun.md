# 09-011 · Lapsed paywall: Sign out from the menu, log back in, and relaunch while offline

- kind: followup-test
- status: triaged
- ticket: 09
- run: w7-20260924T1219Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
1. As account D (Lapsed), on the full-screen paywall, ⋯ → Sign out.
2. Log in again with email and password.
3. Terminate, turn the network off, launch.

**Expected.**
Sign out lands on welcome with no paywall frame; logging back in lands straight on the full-screen paywall again (mp-280, the account stays the same); offline, the Gate uses RevenueCat's saved copy and still shows the paywall, never the app.

**Actual.**


**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
