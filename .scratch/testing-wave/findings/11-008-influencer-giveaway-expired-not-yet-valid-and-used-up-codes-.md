# 11-008 · Influencer, giveaway, expired, not-yet-valid and used-up codes have no dev rows and have never been redeemed in the app

- kind: followup-test
- status: triaged
- ticket: 11
- run: w5-20260924T0840Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. Seed, with Lee's go and service-role SQL, one row per case on dev: an influencer code with an owner; a giveaway with 365 perk days and no limit (single use); a code with `valid_until` in the past; one with `valid_from` in the future.
2. As a new athlete: redeem the influencer code; the giveaway; the giveaway again from a second account; the expired and not-yet-valid codes. As the influencer: their own code.

**Expected.**
Influencer: "attributed" message, `influencer_code` attribute, no pairing row. Giveaway: sheet closes with "Code redeemed. You have 365 days of Pro.", a 365-day Grant, the Gate opens. Second account: "That code has already been used." Expired: "That code has expired." Not yet valid: "That code isn't active yet." Own influencer code: "That's your own code. Share it with your athletes." (mp-458, mp-535, mp-598's example).

**Actual.**
Not run. `codes` on dev holds only DEVCOACH30 and DEVCOACH18 (runs/11/db-codes-before.txt), and this run may not write to it.

**Evidence.**
- runs/11/db-codes-before.txt

**Decision quote.**
> an influencer Code records who referred the account but never pairs, since an influencer is not a coach. A Code that is wrong, expired or already used gets a plain reason

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 122 when 107 was split (Lee, 2026-09-25).
