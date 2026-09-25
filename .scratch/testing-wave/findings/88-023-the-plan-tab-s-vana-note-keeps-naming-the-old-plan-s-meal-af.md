# 88-023 · The Plan tab's Vana note keeps naming the old plan's meal after a confirm until the app restarts

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Food > Plan (Vana note card)
- decision: 

**Steps.**
1. Confirm 8ebeb6da (20:21:43Z; Wholewheat pasta and Quinoa, mixed veg & walnuts). Food > Plan (20:22:42Z, 20:26Z).
2. Relaunch the app (20:34Z) and open Food > Plan.

**Expected.**
The note speaks about the confirmed plan (vana.daynotes ran at 20:21:51Z and 20:28:17Z).

**Actual.**
Until the relaunch the note still read "Easy swim and core work: the spelt lentil bowl covers your lighter 419g carb target." (the spelt bowl was in be6abf2f, now archived). After the relaunch it read the new note ("…your standard dinner pasta, mixed veg & avocado"). The new day notes also contain "aim for 835C carbs" (a stray C).

**Evidence.**
- runs/88/102-plan-tab-after-confirm.png, runs/88/109-14-008-plan-tab-with-draft.png: old note.
- runs/88/132-plan-tab-final.png, runs/88/db-30-day-notes.txt: new note after relaunch.

**Decision quote.**
> 

**Triage.**
