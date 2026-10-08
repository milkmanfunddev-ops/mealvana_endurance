# 49-008 · Edit Meal: untried paths after wave 5 (Re-scan photo, a time after now or across midnight, Discard and Keep editing, Hide details alone)

- kind: followup-test
- status: open
- ticket: 49
- run: w5-20261008T1719Z
- screen: Edit Meal
- decision: 

**Steps.**
1. Re-scan photo on a photo meal (an analyze-meal-photo call: spend first): one debit; the "Replace items?" dialog; Cancel keeps the items; Replace then Back asks to save.
2. Time eaten -> a time later than now (11:59 PM today) and a time that would cross midnight: is a future time allowed, and does the card sort and the Net Balance follow?
3. Back with unsaved edits -> Discard: nothing written (row updated_at unchanged). Keep editing: stays with the edits.
4. Only toggle Hide details / Add more detail, then Back: no "Discard changes?" dialog expected (it writes nothing).

**Expected.**
A re-scan costs one token and replaces items only on Replace; a time choice follows a written rule; Discard writes nothing; a pure view toggle is not an unsaved change.

**Actual.**
Not run. This run checked Change (12:38 -> 10:38 AM, eaten_at 15:38Z), a notes edit, Hide details, Back -> dialog -> Save (all worked). Re-scan was over the ticket's spend cap.

**Evidence.**
- runs/49/45-edit-meal.png — Edit Meal with Re-scan photo
- runs/49/50-back-unsaved.png — the Discard changes? dialog

**Decision quote.**
> 

**Triage.**
