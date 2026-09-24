# 11-010 · Redeem code from the Subscription screen for an account that already has Pro

- kind: followup-test
- status: open
- ticket: 11
- run: w5-20260924T0840Z
- screen: Subscription
- decision: 

**Steps.**
1. Sign in as an account with Pro (a Test Store trial from ticket 05, or the admin).
2. Settings → Subscription → Redeem code; enter a coach code the account does not own, then a made-up code.

**Expected.**
mp-458/mp-495: the same sheet opens from the Subscription screen and behaves the same (paired message, pending pairing; not-found reason with the sheet open). No change to the account's Pro.

**Actual.**
Not run (look-around, ticket 11). This run reached Redeem code only from the paywall.

**Evidence.**
- runs/11/05-paywall-menu.png

**Decision quote.**
> Codes are entered from Redeem code in the paywall's ⋯ menu (mp-494) and on the Subscription screen (mp-495)

**Triage.**

