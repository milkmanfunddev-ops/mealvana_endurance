# 19-003 · Previous lists sheet does not scroll: with 14 lists the bottom overflows by 80 px and the last lists cannot be reached

- kind: bug
- status: closed
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab) > Previous lists
- decision: 

**Steps.**
1. Sign in as test@test.com (14 shopping lists on the account).
2. Food > Shopping > ⋯ > Previous lists.
3. Swipe up inside the sheet.

**Expected.**
Every list can be reached; the sheet scrolls when the lists do not fit.

**Actual.**
The sheet shows a yellow-black "BOTTOM OVERFLOWED BY 80 PIXELS" stripe over the 12th to 13th rows and does not scroll; the swipe did nothing. The last rows ("List 2026-09-16" 0 items, "Week of 2026-09-13" 16 and 14 items) sit under the stripe or off screen, so they cannot be opened, renamed or deleted from here. After two lists were deleted (13 lists) the stripe still showed (overflow 24 px). The sheet puts every row in a plain Column (ShoppingPreviousListsSheet), with no scroll view. The log stream carried no overflow line.

**Evidence.**
- runs/19/07-previous-lists.png: 14 lists, overflow by 80 px.
- runs/19/08-previous-lists-scrolled.png: the same after a swipe up; nothing moved.
- runs/19/17-previous-lists-after-deletes.png: 13 lists, overflow by 24 px.

**Decision quote.**
> 

**Triage.**
Fix ticket 49 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 89 (run w29-20260925T1950Z, build e3367d2c): pass, evidence in runs/89/verdicts.md.
