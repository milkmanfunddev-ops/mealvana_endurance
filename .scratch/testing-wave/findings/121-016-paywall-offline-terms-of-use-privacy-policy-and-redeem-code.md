# 121-016 · Paywall offline: Terms of Use, Privacy Policy and Redeem code

- kind: followup-test
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Paywall
- decision: 

**Steps.**
1. Paywall with `netcut.sh on --relaunch`.
2. Tap Terms of Use and Privacy Policy (scroll down).
3. ⋯ → Redeem code, enter a seeded code.

**Expected.**
Links fail with a readable message; Redeem code says it needs a connection and grants nothing; no way off the paywall.

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/25-offline-paywall.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
