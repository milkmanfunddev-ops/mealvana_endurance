# 25-002 · Log a Meal Manual tab: untried paths (empty name, no macros, Time eaten change, two-decimal and huge values, a second log in a row, back mid-entry)

- kind: followup-test
- status: open
- ticket: 25
- run: w14-20260924T2015Z
- screen: Log a Meal → Manual tab
- decision: 

**Steps.**
1. Log a Meal → Manual. Ticket 25 saved one full entry (all macros, sodium, notes, Breakfast) and one decimal-kcal entry; nothing else was tried.

**Expected.**
Each path below behaves sensibly and saves what was entered:
- Save with an empty name (validator says "Name is required"), and with a name but no macros at all (does it save a null-everything row, and how does the timeline show it?).
- Time eaten → Change to a time earlier than now and to one after now; the row's eaten_at and log_date match. The shown time is the time the form opened (3:17 PM shown, saved at 3:18 with eaten_at 20:17Z); same kind as 26-009 on the quick log sheet.
- Very large values (99999 kcal, 1000 g carbs), a leading dot (".5"), and three-decimal grams (12.345) against the numeric columns.
- A second entry straight after the first (the form clears and stays open): both rows saved, the second not carrying the first's slot or notes.
- Back arrow with the form half filled: nothing saved, no prompt, or a discard prompt.
- Log a Meal for a past day (Previous day on the timeline, then + Add Food): log_date is that day.
- Offline save: local row first, uploaded later (offline-first rule).

**Actual.**
Not run in ticket 25.

**Evidence.**
- runs/25/06-manual-tab.png
- runs/25/08-manual-saved.png

**Decision quote.**
> 

**Triage.**
