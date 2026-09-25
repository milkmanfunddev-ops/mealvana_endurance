# 121-017 · Paywall ⋯ menu: Sign out offline from the paywall

- kind: followup-test
- status: open
- ticket: 121
- run: w34-20260925T2320Z
- screen: Paywall ⋯ menu
- decision: 

**Steps.**
1. A never-paid account on the paywall, app cut off.
2. ⋯ → Sign out → Sign out.
3. Online again: relaunch, log back in.

**Expected.**
Sign-out either works locally with a clean Welcome and the account intact, or refuses clearly; RevenueCat's logOut failure does not leave the SDK identified as the old account (03-002).

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/27-offline-menu.png

**Decision quote.**
> 

**Triage.**

