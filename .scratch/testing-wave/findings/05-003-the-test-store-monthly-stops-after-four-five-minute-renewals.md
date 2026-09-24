# 05-003 · The Test Store monthly stops after four five-minute renewals and expires 25 minutes after purchase, so the kept paid account is Lapsed

- kind: idea
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: none
- decision: 

**Steps.**
Tickets 06 to 09 were planned to reuse the paid account this ticket keeps. The Test Store monthly does not stay paid: bought at 08:50:45Z, it renewed four times at five-minute periods and RevenueCat set it `expired`, `will_not_renew`, `ends_at 09:15:45Z`, with no cancel from anyone. The kept account (`lee+e2e-05-20260924T0849Z`, marked in the credentials file) is Lapsed by the time any later ticket runs.
Ideas for triage: (a) tickets 06 to 09 each buy again from the Lapsed paywall at the start of the run (that also exercises resubscribe, story 47) and finish within 25 minutes of buying, or use the annual product if its Test Store renewals run longer; (b) or they start from a Grant (`grant-customer-entitlement`) whose length they pick; (c) ticket 07's cancellation run can use this natural expiry as its "watch it go from open to Lapsed in one run" (story 44) instead of a short Grant.

**Expected.**
Criterion 5: the paid account is kept for tickets 06 to 09.

**Actual.**
Kept, but no longer paid: RevenueCat `pro` inactive since 09:15:45Z; `user_entitlements.active_until = 09:15:45.967Z`; the app lands on the full-screen paywall on resume.

**Evidence.**
- runs/05/revenuecat-B-subscriptions-1047Z.json (status expired, will_not_renew)
- runs/05/edge-logs-webhook-through-expiry.txt
- runs/05/db-B-after-expiry.txt
- runs/05/21-after-resume.png

**Decision quote.**
> 

**Triage.**

