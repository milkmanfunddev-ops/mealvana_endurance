# 89-008 · Browse meals opens with the Meals tab search results while its search box is empty

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Browse meals (Vana chat > Add > Browse meals)
- decision: 

**Steps.**
1. test@test.com. Food > Meals > Search meals, type "spinach" (7 results). Leave the tab.
2. Open a planning conversation > Add > Browse meals.
3. Tap the search button.

**Expected.**
Browse opens on its own rails (Recents, My Foods, ...) with no search, or shows the carried search term in its box.

**Actual.**
Browse opened straight onto the seven spinach results, with the search button lit but no field shown. Tapping it showed an empty "Search meals" field over the spinach results. The athlete sees a filtered catalog with nothing saying why. Clearing the field (typing and deleting) brought the rails back.

**Evidence.**
- runs/89/51-18-004-meals-tab-search-spinach.png: the Meals tab search.
- runs/89/57-browse.png: Browse on open.
- runs/89/58-browse-search-open.png: the empty field over the results.

**Decision quote.**
> 

**Triage.**

Fix ticket 128 (Lee, 2026-09-25). Closed by the retest after it merges.
