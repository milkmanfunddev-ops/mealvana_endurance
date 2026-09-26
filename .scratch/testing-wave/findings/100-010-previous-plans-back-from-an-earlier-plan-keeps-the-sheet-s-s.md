# 100-010 · Previous plans: Back from an earlier plan keeps the sheet's scroll position on a list long enough to scroll

- kind: followup-test
- status: triaged
- ticket: 100
- run: w39-20260926T1013Z
- screen: Previous plans (sheet) > earlier plan
- decision: 

**Steps.**
1. An account with more previous plans than the sheet shows at once.
2. Scroll the sheet, open a lower row, tap Back.

**Expected.**
The sheet again, at the same scroll position (ticket 97 item 3).

**Actual.**
Not run: test@test.com has five rows, which fit without scrolling; Back did return to the sheet.

**Evidence.**
- runs/100/52-after-back-from-earlier.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
