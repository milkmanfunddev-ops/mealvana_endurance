# 11-009 · The coach sees, accepts and declines a pairing that came from a code

- kind: followup-test
- status: triaged
- ticket: 11
- run: w5-20260924T0840Z
- screen: none
- decision: 

**Steps.**
1. A new athlete redeems DEVCOACH30 (pending pairing, requested_by athlete).
2. Sign in as the coach (test@test.com, on the web coach app or the app's coach screens) and look for the request; accept it. Repeat with a second athlete and decline.
3. As the athlete, look for any sign of the pairing (pending, then active or declined), and redeem DEVCOACH30 again after a decline (the handler reopens a declined pairing, but mp-535 refuses the same code twice).

**Expected.**
The coach sees the request as an athlete-requested pairing and can accept or decline it; the athlete's view follows. After a decline there is a stated way back (the same code is refused as already used, so the athlete needs another path; record what the app offers).

**Actual.**
Not run (look-around, ticket 11). This run saw only the database row; the web coach app is out of this spec's scope, so the in-app coach view is the one to try.

**Evidence.**
- runs/11/db-A-after-step3.txt (the pending row)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
