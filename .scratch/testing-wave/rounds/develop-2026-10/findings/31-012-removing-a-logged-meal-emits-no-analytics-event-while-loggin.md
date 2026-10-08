# 31-012 · Removing a logged meal emits no analytics event, while logging and editing do

- kind: idea
- status: open
- ticket: 31
- run: w3-20261008T1256Z
- screen: Timeline
- decision: 

**Steps.**
1. Console during the two Timeline removes (13:12:59Z, 13:13:14Z) shows no `meal_log_*` analytics line; `meal_logged` and `meal_log_updated` do fire. Idea: emit `meal_log_deleted {log_id}` so removes are countable.

**Expected.**


**Actual.**


**Evidence.**
- runs/31/console-redacted.log — meal_* analytics lines; none at 08:13 local

**Decision quote.**
> 

**Triage.**

