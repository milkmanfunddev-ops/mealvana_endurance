# 122-001 · A second giveaway on a running Grant is spent and adds no days, yet says You have 365 days of Pro

- kind: bug
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Subscription
- decision: 

**Steps.**
1. After `seed-codes.mjs seed`, a new account redeems E2EGIVE365 on the onboarding paywall (a 365-day promotional `pro` Grant, 2026-09-26 03:55:09Z -> 2027-09-26 03:55:09Z).
2. Settings -> Subscription ("Pro from a code", "365 days left") -> Redeem code -> E2EGIVEMANY -> Redeem (03:56:18Z).
3. Read RevenueCat's subscriptions, `user_entitlements` and `code_redemptions` for the account.

**Expected.**
87-005 step 1: the athlete is told what happened to the days: they are added (the Grant now ends about 2028-09-25), or they are not added because Pro is already running. In the second case the code is left unspent, so it can be used later. mp-535: "the days a Code grants are set on its row".

**Actual.**
The sheet closed with "Code redeemed. You have 365 days of Pro." and the screen still said "365 days left". The code is spent: a `code_redemptions` row for E2EGIVEMANY at 03:56:20Z, and `redeem-code` logged `redeemed giveaway code E2EGIVEMANY → giveaway`. No days were added. RevenueCat holds one promotional subscription, still ending 2027-09-26 03:55:09Z. A second 365-day grant from 03:56 would end about a minute later, and none shows. `user_entitlements.active_until` is unchanged at 2027-09-26 03:55:09.816Z. `grantPro` raised no error, so RevenueCat accepted the call and changed nothing (`grant_entitlement` with an `expires_at` does not extend a live promotional grant). The athlete spends a code and gets nothing for it, while the message says they did.

**Evidence.**
- runs/122/27-A-givemany-doubletap.png (snackbar over "365 days left")
- runs/122/revenuecat-A-after-givemany.txt (one promotional subscription, end unchanged)
- runs/122/db-A-after-giveaway.txt (entitlement before the second code)
- runs/122/notes.md (03:56Z entries: redemption row, function log line)

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Ruling: a giveaway is refused while any Pro is active, a running Grant ("You already have free Pro until <date>") or a paying subscription ("You already have Pro"), and the code is not spent (140). Closed by the retest after it merges. Record: `triage-20260926.md`.
