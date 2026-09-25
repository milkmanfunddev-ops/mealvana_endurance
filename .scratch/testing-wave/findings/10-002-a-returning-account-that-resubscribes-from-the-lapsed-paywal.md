# 10-002 · A returning account that resubscribes from the lapsed paywall is greeted with the new-account snackbar "Welcome to Mealvana Endurance!"

- kind: idea
- status: closed
- ticket: 10
- run: w8-20260924T1418Z
- screen: Timeline
- decision: 

**Steps.**
Idea for triage: account D signed up on 09-24 12:30Z, paid, lapsed, and resubscribed at 14:21Z from the full-screen lapsed paywall. The app then opened on Timeline with the teal snackbar "Welcome to Mealvana Endurance!", the same greeting a brand-new account gets after its first purchase. For a returning athlete (mp-280's "they subscribe on 12 October and land back in their plan") a "Welcome back" line, or none, fits better. Needs a copy decision: what a resubscribing account is told.

**Expected.**


**Actual.**
Snackbar "Welcome to Mealvana Endurance!" over the timeline at 14:21:04Z, 4 s after the purchase.

**Evidence.**
- runs/10/04-after-purchase.png

**Decision quote.**
> 

**Triage.**
Fix ticket 80 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.

Closed by retest ticket 87 (wave 25, build 5e05f8a6): pass, evidence in runs/87/verdicts.md.
