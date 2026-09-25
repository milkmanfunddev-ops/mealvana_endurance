# 19-001 · Deleting the confirmed plan's list opens an archived draft's list as the current list, with Shop with Kroger

- kind: bug
- status: triaged
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Sign in as test@test.com (confirmed plan be6abf2f, week 2026-09-20; its list 03c4c52b on the Shopping tab).
2. Food > Shopping > ⋯ > Delete list > Delete (16:53:1xZ).
3. Look at the tab, then at Previous lists and the Plan sub-tab.

**Expected.**
With the confirmed plan's list gone, the tab shows either the empty state or a list that belongs to the plan the athlete is on. It does not present a list from a plan that was archived.

**Actual.**
The tab fell back to list 9bdc9556 "Week of 2026-09-20", 6 items (Bell pepper, Mushroom, Spinach, Egg, Butter, Heavy cream), headed "Made Sep 24, 2026", with Shop with Kroger. That list belongs to draft 54a02440, which is `archived` (confirming be6abf2f archived it). The Plan sub-tab still shows the confirmed 4-meal plan (farro and pasta bowls), so the Shopping tab now lists ingredients for meals the athlete is not planning to eat, and offers to send them to Kroger. Cause, from reading the code: `getList(null)` picks the most recent list by coalesce(confirmed_at, created_at) across every list the athlete has, archived drafts' lists included.

**Evidence.**
- runs/19/16-after-delete-plan-list-4s.png: the archived draft's list shown as current, with Shop with Kroger.
- runs/19/18-plan-tab-after-deletes.png: the Plan sub-tab still on the confirmed 4-meal plan.
- runs/19/db-04-after-delete-plan-list.txt: 9bdc9556 (plan 54a02440) now tops the lists; be6abf2f confirmed with shopping_len 0; 54a02440 archived.
- runs/19/notes.md: the timeline.

**Decision quote.**
> 

**Triage.**
Fix ticket 35 (Lee, 2026-09-25). Closed by the retest after it merges.
