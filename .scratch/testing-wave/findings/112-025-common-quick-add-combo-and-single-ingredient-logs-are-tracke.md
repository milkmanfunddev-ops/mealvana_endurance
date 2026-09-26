# 112-025 · Common quick-add combo and single-ingredient logs are tracked with method manual, not common

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Common)
- decision: none

**Steps.**
1. test@test.com, Log a Meal → Common: log the quick-add combo "Oatmeal + raisins" and the single ingredient "Egg".
2. Log "Eggs" from a search result on the same screen.
3. Read the `meal_logged` analytics event in the console for each.

**Expected.**
All three logs come from the Common tab, so each event carries method `common`.

**Actual.**
The combo and the single ingredient are tracked with method `manual`; only the search/catalog tap passes `logMethod: 'common'` (`log_meal_screen.dart` around line 691; the other paths fall back to `source.wireValue`, `meal_log_providers.dart` line 489). The run noted it as "known noise: analytics labels only"; filed by the wave lead, since analytics counts per method would undercount Common.

**Evidence.**
- runs/112/notes.md ("Analytics:" line)

**Decision quote.**
> none

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
