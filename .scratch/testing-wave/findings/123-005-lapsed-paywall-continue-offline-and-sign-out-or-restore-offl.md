# 123-005 · Lapsed paywall: Continue offline, and Sign out or Restore offline

- kind: followup-test
- status: triaged
- ticket: 123
- run: w38-20260926T0341Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
1. A lapsed account on the full-screen paywall; cut the network (netcut on --relaunch).
2. Continue with Monthly.
3. ⋯ → Restore purchases; ⋯ → Sign out.

**Expected.**
A MealvanaSnackbar says the store cannot be reached; Continue does not stay busy; Restore says it could not check; Sign out still reaches Welcome, or says why not, and never leaves the account half signed out.

**Actual.**
Not run (look-around, ticket 123).

**Evidence.**
- runs/123/13-A-lapsed-paywall-menu.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
