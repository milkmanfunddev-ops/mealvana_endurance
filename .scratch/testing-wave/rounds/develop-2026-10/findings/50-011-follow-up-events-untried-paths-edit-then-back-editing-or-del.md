# 50-011 · Follow-up: Events untried paths (edit-then-Back, editing or deleting a TrainingPeaks-imported event, then sync)

- kind: followup-test
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: Events, Event Details, Edit Event
- decision: 

**Steps.**
1. Edit Event: change a field, Back: decide whether a discard prompt is wanted (today the edit drops silently).
2. TrainingPeaks-imported "IM NC 70.3": Edit its date or name, then TP Sync Now: does the sync overwrite the edit,
   duplicate the event, or keep it? Delete it, then sync: does it come back?
3. Upcoming event More options (only the past event's menu was opened on Test; IM NC's showed the same two items).
4. Create new event with only a name, Back; and the "Carb loading window has passed" control on a past event.

**Expected.**
Clear states; an imported event's edits and deletes survive the next sync or the app says they will not.

**Actual.**
Not run (steps 2-4). Step 1 seen: no prompt, nothing written (k03, db-event-test-after-edit-back.txt).

**Evidence.**
- runs/50/k03-edit-back-with-change.png back on Event Details after an unsaved edit
- runs/50/k05-im-nc-more-options.png Edit / Delete on the imported event

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 69 check 6 ran it; 69-002, 69-003, 69-004, 69-005 carry what failed or waits) · lead, 2026-10-09
