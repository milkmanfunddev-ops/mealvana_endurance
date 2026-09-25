# 88-004 · After Remove in the Review sheet the removed meal stays in the sheet and the plan bar, so Confirm shows a plan the server no longer has

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Review plan sheet; Vana chat plan bar
- decision: 

**Steps.**
1. Retest of 09-006 steps 1–2. Conversation `0401b3d8`, draft 173cebb2 with 3 meals. Review plan > Remove on "Toast with peanut butter & honey" (20:05:33Z).
2. Look at the sheet at 2 s and 12 s; Keep planning; expand the plan bar and scroll its cards; Back and reopen the conversation.
3. Retest in the new draft 8ebeb6da: Review > Remove on Egg & Veggie Scramble (20:20:59Z), then Confirm.

**Expected.**
The removed meal leaves the sheet at once, the counts drop ("2 meals · 12 servings"), and the plan bar shows 2 meals (09-006: "Removing a meal drops it from the plan").

**Actual.**
The server row is deleted at once (plan_meals has 2 rows), but the sheet keeps listing Toast with "3 meals · 16 servings". After Keep planning the bar still reads "Your plan · 3 meals" and its cards include Toast; Back and reopening the conversation in the same app session still shows 3 meals. Only after the app was relaunched (20:14Z netcut relaunch, later opens) did it show 2. In 8ebeb6da the sheet kept "3 meals · 3 servings" with Egg & Veggie Scramble after the remove, and Confirm plan confirmed a 2-meal plan while the sheet showed 3. Tapping Remove again on a meal that still shows is untested.

**Evidence.**
- runs/88/47-09-006-review-after-remove.png, runs/88/48-09-006-review-after-remove-15s.png: Toast still listed, "3 meals · 16 servings".
- runs/88/db-09-09-006-after-remove.txt: plan_meals without Toast at 20:05:45Z and 20:06:50Z.
- runs/88/51-09-006-bar-scrolled.png: plan bar card for Toast after Keep planning.
- runs/88/52-0401b3d8-reopened-after-remove.png: reopened, still 3 meals.
- runs/88/95-09-006-after-remove-egg.png, runs/88/98-confirm-1s.png: Egg still shown while Confirm runs; runs/88/db-22-after-confirm.txt: 2 meals confirmed.

**Decision quote.**
> 

**Triage.**

Fix ticket 127 (Lee, 2026-09-25). Closed by the retest after it merges.
