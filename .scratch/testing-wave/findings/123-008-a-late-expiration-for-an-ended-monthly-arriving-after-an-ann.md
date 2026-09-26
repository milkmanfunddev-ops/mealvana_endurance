# 123-008 · A late EXPIRATION for an ended monthly, arriving after an Annual purchase, sets will_renew false on the Annual's Entitlement row

- kind: bug
- status: open
- ticket: 123
- run: w38-20260926T0341Z
- screen: none
- decision: 

**Steps.**
Seen during 10-003 step 1 / 10-005 step 3.
1. Account A's second Test Store monthly ends at 04:41:20Z (last period `will_not_renew`); the app lands on the lapsed paywall.
2. At 04:41:46.7Z A resubscribes with Annual (Test valid purchase). The INITIAL_PURCHASE webhook writes the row: `active_until 05:41:47.468`, `will_renew: true` (04:41:49 local log; db-A-after-annual.txt at 04:42:01Z).
3. At 04:42:12Z RevenueCat's EXPIRATION webhook for the ended monthly arrives, 52 s after its end and 25 s after the Annual purchase.

**Expected.**
The Annual is live and renewing, so the row stays `active_until 05:41:47`, `will_renew: true`. The webhook's own rule (entitlements.ts): `will_renew` is true when RevenueCat reports a live `pro` whose end is the row's end. mp-679 and ticket 67: a renewing account keeps the 15-minute server grace past its period end.

**Actual.**
After the late EXPIRATION the row read `active_until 05:41:47.468`, `will_renew: false`, `event_at 04:42:11.731` (poll-A.log 04:42:16Z). The end date was right (the 09-009 fix held) but the renewal flag took the ended monthly's value. RevenueCat at the same moment listed the Annual `will_renew`. Had the account lived on, the server would have refused Pro calls at 05:41:47 until the RENEWAL webhook, with no renewal grace. No "allowance forfeited" line was logged for this EXPIRATION, so the wallet looks untouched (not checked in the wallet table). The account was deleted at 04:42:40Z, so the next Annual renewal was not watched. The same may happen on the App Store when an athlete switches plans and the old one's EXPIRATION lands after the new purchase.

**Evidence.**
- runs/123/poll-A.log (04:41:46Z `will_renew: true` → 04:42:16Z `will_renew: false`, same `active_until`)
- runs/123/edge-logs-account-A.txt (23:41:49 INITIAL_PURCHASE, 23:42:12 EXPIRATION local)
- runs/123/db-A-after-annual.txt
- runs/123/revenuecat-A-after-annual.json

**Decision quote.**
> 

**Triage.**
