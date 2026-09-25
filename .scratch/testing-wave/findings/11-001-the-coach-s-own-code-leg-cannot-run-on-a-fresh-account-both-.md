# 11-001 · The coach's-own-code leg cannot run on a fresh account: both dev coach codes belong to test@test.com, which has already redeemed them

- kind: followup-test
- status: triaged
- ticket: 11
- run: w5-20260924T0840Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Read the dev `codes` rows (SELECT only): DEVCOACH30 and DEVCOACH18 are both `coach` codes owned by test@test.com (607f9dd5-…), 30 perk days, no limit, and each already has a `code_redemptions` row for that owner (2026-09-22 and 2026-09-23). They are the only codes on dev.
2. To retest mp-458's "a coach enters her own Code and gets `pro` for 30 days" in the app, one of these is needed (Lee's call; this run wrote nothing to `codes`):
   a. a coach code seeded by service-role SQL whose owner is a throwaway `lee+e2e-*` account made for the run, which then enters it from the paywall ⋯ menu; or
   b. a new code for test@test.com, entered from the Subscription screen (the admin never sees the paywall, 12-001).
3. On that account also enter the same code a second time.

**Expected.**
The sheet closes with "Code redeemed…" and the coach message; `coaches` has an approved row for the account; RevenueCat shows a 30-day promotional `pro` Grant and `user_entitlements` mirrors it; the Gate opens and the account leaves the paywall. The second entry is refused "You've already used that code." and no second Grant appears (mp-535).

**Actual.**
Not run. A new athlete cannot own an existing code, so both dev codes could only be tested as "an athlete entering a coach code" (paired, see runs/11/expected.md). The ticket's first leg ("a coach's own code gives 30 days of Pro and marks the account a coach") is untested in the app on this run. The handler has a seam test for it (supabase/functions/redeem-code/handler.test.ts), and mp-535's example says DEVCOACH30 gave its owner 30 days on 22 September.

**Evidence.**
- runs/11/db-codes-before.txt
- runs/11/expected.md

**Decision quote.**
> A coach entering their own Code is marked as a coach and gets 30 days of `pro`; an athlete entering a coach Code gets a pending pairing with that coach

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 122 when 107 was split (Lee, 2026-09-25).
