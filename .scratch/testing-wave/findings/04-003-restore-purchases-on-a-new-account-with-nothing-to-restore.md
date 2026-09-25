# 04-003 · Restore purchases on a new account with nothing to restore

- kind: followup-test
- status: closed
- ticket: 04
- run: w4-20260924T0418Z
- screen: Paywall
- decision: 

**Steps.**
1. A new account on the paywall: ⋯ → Restore purchases.

**Expected.**
The "nothing to restore" info message (`paywallRestoreNone`), the account stays on the paywall, and
no `user_entitlements` row appears. Also check the SDK's anonymous customer on a cloned simulator
(ticket 02 saw one with an active entitlement) is not what gets restored.

**Actual.**
Not run (look-around, ticket 04).

**Evidence.**
- runs/04/16-paywall-menu.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 121 when 107 was split (Lee, 2026-09-25).

Run by retest ticket 121 (run w34-20260925T2320Z, build e3367d2c): pass.
