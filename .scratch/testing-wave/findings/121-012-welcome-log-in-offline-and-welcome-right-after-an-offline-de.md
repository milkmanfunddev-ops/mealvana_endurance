# 121-012 · Welcome: log in offline, and Welcome right after an offline delete

- kind: followup-test
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Welcome
- decision: 

**Steps.**
1. Cut the app's network, tap I already have an account → Log in with email with a real account.
2. After 121-007's offline delete lands on Welcome, log straight back in to the supposedly deleted account.

**Expected.**
1: a clear no-connection message, no hang. 2: until 121-007 is fixed the account logs in, lands on the paywall, and its data is there.

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/32-after-offline-delete.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
