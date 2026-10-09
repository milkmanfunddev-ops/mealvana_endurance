# 68-014 · Follow-up Review & Log: untried paths (Log with zero items, two swipes inside 3 s, diary_closed items_logged 0 after a log)

- kind: followup-test
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal > Describe > Review & Log
- decision: 

**Steps.**
1. Seen in this run: after swiping the only item away, 'Log this meal' stayed enabled with Total '— kcal'. After Log this meal, the console sent diary_closed {duration_sec: 259, items_logged: 0}.

**Expected.**
Next wave tries: tap Log this meal with zero items (what is written?); two items removed inside the 3 s window then Undo; change only the meal type then Back; check whether diary_closed should count a Describe log in items_logged.


**Actual.**
Not run (look-around).


**Evidence.**
- runs/68/09c-after-undo.png: zero items, Log enabled.
- runs/68/console-redacted.log: diary_closed items_logged 0 at 18:27:32 local.

**Decision quote.**
> 

**Triage.**
- triaged · retest ticket B (meal logging), cut after fix wave 8 for test wave 9 · Lee, 2026-10-09
