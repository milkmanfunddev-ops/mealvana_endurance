# 02-016 · Delete account for a Lapsed account from the paywall menu

- kind: followup-test
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Paywall
- decision: 

**Steps.**
1. An account whose Test Store subscription has lapsed (5-minute periods make this quick). 2. ⋯ → Delete account.

**Expected.**
Same result as a new account: auth user and rows gone; the lapsed subscription and RevenueCat record noted.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).
