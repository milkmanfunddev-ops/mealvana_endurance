# 16-011 · Retest ticket 16 once Confirm is scoped to the conversation: confirm a Draft while the week has another confirmed plan

- kind: followup-test
- status: triaged
- ticket: 16
- run: w9-20260924T1446Z
- screen: Vana chat → Review plan sheet
- decision: 

**Steps.**
1. After 16-001 is fixed: start a Draft in a new conversation for a week that already has a confirmed plan (one COST plan spend; the Draft this run used is archived).
2. Have a second Draft for the same week in another conversation.
3. Confirm the first Draft from its Review sheet.
4. SQL: plans of the week, the lists and their items; compare the confirmed list's rows with the Draft's meal ingredients (the `grocery.ts` rules), as runs/16/list-vs-plan-be6abf2f.txt does.

**Expected.**
The confirmed Draft is the only confirmed plan for the week; the old confirmed plan and the other Draft are archived (mp-241); its list is confirmed with rows equal to its meals' ingredients (mp-244); the athlete lands on Food > Shopping (mp-235).

**Actual.**


**Evidence.**
- runs/16/list-vs-plan-be6abf2f.txt — the comparison method.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25).
