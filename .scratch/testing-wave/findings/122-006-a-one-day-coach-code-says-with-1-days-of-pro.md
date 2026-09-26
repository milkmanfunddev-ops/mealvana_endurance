# 122-006 · A one-day coach code says with 1 days of Pro

- kind: bug
- status: open
- ticket: 122
- run: w38-20260926T0340Z
- screen: Timeline
- decision: 

**Steps.**
1. Sign up, `seed-codes.mjs own <id> --days 1`, then redeem that code from the paywall ⋯ -> Redeem code.

**Expected.**
"You're set up as a coach, with 1 day of Pro." The Subscription screen already has a one-day form ("1 day left").

**Actual.**
The snackbar on the timeline says "You're set up as a coach, with 1 days of Pro." `redeem_code.success_coach` and `success_giveaway` use "{days} days" with no singular form. A real code with `perk_days` 1 is unlikely, so this is low.

**Evidence.**
- runs/122/45-D-own-1day.png

**Decision quote.**
> 

**Triage.**

