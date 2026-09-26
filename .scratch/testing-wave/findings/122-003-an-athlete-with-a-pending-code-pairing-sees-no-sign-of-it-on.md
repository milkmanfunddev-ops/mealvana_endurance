# 122-003 · An athlete with a pending code pairing sees no sign of it on Coach Connection

- kind: bug
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Coach Connection
- decision: 

**Steps.**
1. A new athlete with Pro redeems DEVCOACH30 from Settings -> Subscription -> Redeem code: "Code redeemed. Your coach will see your request to pair." A pending, athlete-requested pairing with test@test.com is written.
2. Settings -> Coach Connection.

**Expected.**
11-009: "As the athlete, look for any sign of the pairing (pending, then active or declined)". The athlete can see that a request to a coach is waiting, and ideally withdraw it.

**Actual.**
Coach Connection shows only "Connect with Your Coach", "Enter Coach Code" (the 24-hour pairing code, ABC123) and Connect. Nothing names the coach or says a request is pending. The only trace of the code pairing is the snackbar, gone after a few seconds. A second try of either coach code is refused ("You've already used that code." / "You've already asked this coach to pair."), which is the only other hint.

**Evidence.**
- runs/122/31-A-coach-connection-pending.png
- runs/122/50-B-devcoach30-same-coach.png

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
