# 08-023 · Follow-up: Timeline order of same-time activities and net balance change between launches

- kind: followup-test
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Timeline
- decision: 

**Steps.**
1. Three 7:00 AM activities showed Bike, R-CORE, Swim on the first launch and R-CORE, Bike, Swim after sign-in; net balance read −483, −487 and −489 kcal at 11:06, 11:10 and 11:12Z on the same day with no new logs. Check whether order is meant to be stable and whether the balance accrues with time of day (likely).

**Expected.**
Same-time rows keep one order; the balance moves only for a known reason.

**Actual.**


**Evidence.**
- runs/08/a03-timeline-test-account.png
- runs/08/b11-timeline-after-signin.png
- runs/08/b14-offline-timeline.png

**Decision quote.**
> 

**Triage.**
