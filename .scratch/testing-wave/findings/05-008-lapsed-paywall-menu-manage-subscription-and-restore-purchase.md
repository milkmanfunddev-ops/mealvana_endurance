# 05-008 · Lapsed paywall menu: Manage subscription and Restore purchases for an expired Test Store subscription

- kind: followup-test
- status: triaged
- ticket: 05
- run: w5-20260924T0839Z
- screen: Paywall
- decision: 

**Steps.**
1. Sign in as account B (Lapsed since 09:15:45Z; Test Store subscription expired, `will_not_renew`).
2. ⋯ → Manage subscription: where does it go for a Test Store subscription?
3. ⋯ → Restore purchases: expect "nothing to restore" and no Gate change, since the subscription has expired.
4. ⋯ → Redeem code with an athlete code: does the Gate open?

**Expected.**
mp-494: the menu lists Restore purchases, Redeem code, Manage subscription (the account has a subscription to manage), Sign out, Delete account. Each item answers without leaving the account in a half state.

**Actual.**
Not run. The menu showed all five items for account B after it lapsed (22-lapsed-paywall-menu.png).

**Evidence.**
- runs/05/22-lapsed-paywall-menu.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 123 when 107 was split (Lee, 2026-09-25).
