# 123-007 · Lapsed paywall: Delete account for a plan that ended versus one still renewing

- kind: followup-test
- status: open
- ticket: 123
- run: w38-20260926T0341Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
1. A lapsed account whose store plan ended: ⋯ → Delete account; read the confirm.
2. An account whose store plan will still renew (only reachable on a device, or an Admin): Delete account from Settings; read the confirm.

**Expected.**
02-004: only a renewing store subscription adds "Deleting your account does not cancel your subscription…" and a Manage button; the lapsed one gets the plain confirm; the account and its rows go and the app lands on Welcome with no paywall frame (87-003).

**Actual.**
Not run (look-around, ticket 123).

**Evidence.**
- runs/123/13-A-lapsed-paywall-menu.png

**Decision quote.**
> 

**Triage.**
