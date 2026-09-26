# 119-018 · Subscription on a code-Pro account: tap Redeem code with 355 days left

- kind: followup-test
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Subscription
- decision: 

**Steps.**
1. On test@test.com (Subscription reads "Pro from a code · 355 days left"), tap Redeem code; try a valid athlete code and an invalid one; cancel.

**Expected.**
A code-Pro account gets a clear answer (already Pro, or days added); nothing changes on Cancel.

**Actual.**
Not run. The Subscription screen for code Pro has Redeem code but no Manage subscription.

**Evidence.**
- runs/119/20-subscription.png: Pro from a code, 355 days left

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
