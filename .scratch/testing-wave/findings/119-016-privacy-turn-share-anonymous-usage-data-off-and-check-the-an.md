# 119-016 · Privacy: turn Share anonymous usage data off and check the analytics events stop

- kind: followup-test
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Privacy
- decision: 

**Steps.**
1. Settings > Privacy: turn "Share anonymous usage data" off.
2. Open a few screens; grep the console for `[ANALYTICS]` lines.
3. Relaunch and repeat; turn it back on.

**Expected.**
"Turning this off stops usage data immediately": no analytics events after the switch, and it stays off after a relaunch.

**Actual.**
Not run.

**Evidence.**
- runs/119/28-privacy.png: the switch

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
