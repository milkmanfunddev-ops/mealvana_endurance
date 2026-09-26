# 112-022 · Log a Meal opens on Describe with a "253%" chip: check the default tab and what the chip means

- kind: followup-test
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Describe)
- decision: 

**Steps.**
1. Open Log a Meal from the timeline's + Add Food on a fresh sign-in: it opens on Describe, not Recent.
2. Read the orange chip "253%" next to the Describe text (no AI call made).

**Expected.**
The default tab is the intended one; the chip says what it counts (an AI budget used past 100%?) in words an athlete understands.

**Actual.**


**Evidence.**
- runs/112/07-log-a-meal-4s.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
