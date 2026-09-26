# 118-014 · Browse: filters combined with search, an empty result, and Done versus Back after picks

- kind: followup-test
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Browse meals
- decision: 

**Steps.**
1. From a planning conversation's Browse, search a word, then add Dinner and Recipes filters.
2. Pick a combination with no results.
3. Pick a meal, leave with Back instead of Done; reopen Browse.

**Expected.**
An empty result says so with a way to clear filters; Back and Done both keep the pick and the plan bar counts it.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/61-browse-filtered.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
