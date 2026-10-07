# 08-015 · Follow-up: reach AI Credits the in-app way (insufficient-credits paywall, credit balance chip)

- kind: followup-test
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: AI Credits (/buy-credits)
- decision: 

**Steps.**
1. On an account with too few credits, start a Describe or Photo log, let the insufficient-credits dialog open /buy-credits, then Back.
2. Tap the credit balance chip wherever it is mounted.

**Expected.**
AI Credits opens on a stack with Back to the screen that opened it; nothing is bought.

**Actual.**


**Evidence.**
- runs/08/c12-buy-credits.png deep-link render: balance 49897485 credits, packs $4.99/$19.99/$0.99, no Back

**Decision quote.**
> 

**Triage.**
