# 02-010 · Describe with a photo from Camera or Gallery plus text, one token

- kind: followup-test
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. On Describe, tap Gallery (and Camera on a device), pick a meal photo, add a line of text, Analyze (one AI logging spend).
2. Remove the photo (`describe.remove_photo`) before sending: does it fall back to text-only?
3. Log the result; read `meal_logs.photo_path`, `source` and the ledger.

**Expected.**
Photo + text is one analysis and one token (log_meal_screen.dart: "one analysis, one token"); the row stores source `photo` and the storage path; removing the photo before send costs nothing.

**Actual.**


**Evidence.**
- runs/02/06-log-meal-sheet.png — Camera and Gallery buttons on the Describe tab

**Decision quote.**
> 

**Triage.**
retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets)
