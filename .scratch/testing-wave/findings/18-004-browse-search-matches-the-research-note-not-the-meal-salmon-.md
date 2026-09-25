# 18-004 · Browse search matches the research note, not the meal: salmon returns eight meals with no salmon, and every result shows the note as its subtitle

- kind: bug
- status: triaged
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals (search)
- decision: 

**Steps.**
1. Browse meals > search button > type "salmon" (test@test.com, a vegetarian account).
2. Read the results. Then clear search and apply Filters > Dinner.

**Expected.**
Search finds meals by what they are (name, ingredients). A search for an ingredient the athlete does not eat returns no results or says why. The card subtitle is written for the athlete.

**Actual.**
"salmon" returned 8 meals, none containing salmon (Rice, miso soup, natto & egg; Tofu, quinoa, asparagus & spinach salad; Lentils, brown rice & kale; ...). Each matched on the research note printed under the name, for example: "Dinner: salmon, tofu or steak with some quinoa and asparagus and a spinach salad." — her own stated dinner, with protein named as interchangeable; and the Primal/keto endurance pattern (Mark Sisson's Primal Blueprint, echoed by Zach Bitter's recovery-day "salmon, eggs and red meat") .... Every flat result (search or filter) shows such a note as its subtitle ("his dinner base is ...", "one of your saved meals"), which reads as sourcing notes rather than a description. The same MealCatalogBrowser backs Food > Meals, so the Meals tab is likely the same (not checked).

**Evidence.**
- runs/18/17-search-salmon.png: 8 results for salmon, none with salmon.
- runs/18/20-filter-dinner.png: Dinner results with research-note subtitles.
- runs/18/notes.md: the search step.

**Decision quote.**
> 

**Triage.**

Fix ticket 60 (Lee, 2026-09-25). Closed by the retest after it merges.
