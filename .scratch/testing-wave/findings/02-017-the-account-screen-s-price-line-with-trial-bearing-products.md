# 02-017 · The account screen's price line with trial-bearing products

- kind: followup-test
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Create Your Account
- decision: 

**Steps.**
The Test Store products show '$9.95 a month or $69.00 a year. Cancel any time.' with no free-week wording, and the Test Store purchase was a NORMAL period, not a trial. Run the account screen and the paywall against products that carry the 7-day trial (sandbox).

**Expected.**
The line reads like mp-417's example: '7 days free, then <monthly> a month or <annual> a year. Cancel any time.'

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).
