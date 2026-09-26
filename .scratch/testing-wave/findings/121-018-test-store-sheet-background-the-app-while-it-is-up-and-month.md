# 121-018 · Test Store sheet: background the app while it is up, and Monthly's 5-minute renewal on the paywall

- kind: followup-test
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Test Store sheet
- decision: 

**Steps.**
1. Continue → Test Store sheet; press Home; come back after 30 s; pick Test valid purchase.
2. Separately, buy Monthly and stay on the timeline over two renewals (5 min each).

**Expected.**
1: one purchase, the app lands on the timeline, Continue not left spinning. 2: one RENEWAL each period in the webhook, user_entitlements.active_until moves, no paywall flash.

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/21-test-store-sheet-monthly.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
