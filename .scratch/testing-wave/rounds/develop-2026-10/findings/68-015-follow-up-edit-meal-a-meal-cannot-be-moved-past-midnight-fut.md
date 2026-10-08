# 68-015 · Follow-up Edit Meal: a meal cannot be moved past midnight, future times are allowed, and Remove deletes with no confirm

- kind: followup-test
- status: open
- ticket: 68
- run: w7-20261008T2309Z
- screen: Timeline card > Edit food (Edit Meal)
- decision: 

**Steps.**
1. Time eaten 11:59 PM at ~6:38 PM local: accepted, card sorted last. Then 12:30 AM: log_date stayed 2026-10-08, eaten_at 2026-10-08 05:30 UTC, the card jumped to the top of the day.
2. Card menu Remove at 23:47:5xZ: the meal was soft-deleted at once; no confirm dialog and no Undo seen.

**Expected.**
Next wave and triage: should a future time be allowed for today; should a time after midnight move the meal to the next day (today it moves it ~23.5 h back); should Remove confirm or offer Undo; Re-scan photo (not run, cap).


**Actual.**
Recorded as above; not a verdict.


**Evidence.**
- runs/68/11g-timeline-after-1159pm.png: 11:59 PM last.
- runs/68/11i-timeline-after-1230am.png: 12:30 AM first.
- runs/68/db-meal-after-1230am.txt: eaten_at 05:30 UTC same log_date.
- runs/68/db-meal-logs-end.txt: is_deleted true after Remove.

**Decision quote.**
> 

**Triage.**

