# 118-011 · Paywall redeem: a second DEVCOACH30 on the same account, an invalid code and a code while offline, each with the message clear of Continue

- kind: followup-test
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Paywall; Redeem a code sheet
- decision: 

**Steps.**
1. New athlete on the paywall, redeem DEVCOACH30, then redeem it again.
2. Redeem ZZZZ, then a code with the network cut (netcut).
3. Watch where each message sits and whether Continue takes a tap while it shows.

**Expected.**
Each answer names what happened (already used, not found, needs a connection) and none covers the plans or Continue.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/28-redeem-success-t1.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
