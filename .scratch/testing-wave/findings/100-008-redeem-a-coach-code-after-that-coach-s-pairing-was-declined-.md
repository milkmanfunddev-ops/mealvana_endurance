# 100-008 · Redeem: a coach code after that coach's pairing was declined or archived, and the same code a second time

- kind: followup-test
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Paywall > ⋯ > Redeem code
- decision: 

**Steps.**
1. New athlete redeems DEVCOACH30 (pairing pending with test@test.com).
2. Coach declines the pairing (or archives it); athlete redeems DEVCOACH18.
3. Athlete redeems DEVCOACH30 a second time while the pairing is pending.

**Expected.**
Step 2: the code pairs again (alreadyPaired only checks pending/active). Step 3: "You've already used that code." (already_redeemed), no new row.

**Actual.**
Not run. Ticket 95's alreadyPaired reads status pending/active only; the declined and archived paths and the same-code answer were not tried on a device.

**Evidence.**
- runs/100/db-A-after-devcoach18.txt

**Decision quote.**
> 

**Triage.**

