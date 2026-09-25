# 19-005 · Previous lists shows several identical Week of rows marked From plan with no way to tell the confirmed plan's list from archived drafts' lists

- kind: idea
- status: triaged
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab) > Previous lists
- decision: 

**Steps.**
Idea. Previous lists on test@test.com shows four "Week of 2026-09-20 · From plan" rows and seven "Week of 2026-09-13 · From plan" rows; only date and item count differ. One of each week is the confirmed plan's list, the rest belong to drafts that confirming archived. Mark the confirmed plan's list (for example "Confirmed") and either hide archived drafts' lists or mark them "Draft, not used", so the athlete can pick the right one.

**Expected.**
The athlete can tell which list goes with the plan they confirmed.

**Actual.**
Every plan list reads the same. The confirmed list is only told apart by being "Open now" at the top; after it was deleted, an archived draft's list took its place and looked the same (19-001).

**Evidence.**
- runs/19/07-previous-lists.png: identical rows.
- runs/19/db-00-before.txt: which list belongs to which plan and status.

**Decision quote.**
> 

**Triage.**
Fix ticket 84 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.
