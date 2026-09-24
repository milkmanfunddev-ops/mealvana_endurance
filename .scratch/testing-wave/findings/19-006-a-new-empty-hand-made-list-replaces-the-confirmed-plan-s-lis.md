# 19-006 · A new empty hand-made list replaces the confirmed plan's list as the list the Shopping tab opens by default

- kind: followup-test
- status: open
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. With a confirmed plan's list on the tab, ⋯ > New list (makes "List <date>", empty).
2. Leave Food, come back; then cold relaunch the app; then go offline and open the tab.
3. Check which list shows each time, and what Kroger (Shop with Kroger) and the offline copy use.

**Expected.**
Decide and check: the tab should keep offering the confirmed plan's list (or a clear way back to it), and Kroger and the offline copy should keep using the plan's list. This run saw the new empty list take over at once (the server picks the most recent list by coalesce(confirmed_at, created_at), and a new list is newer than any confirm), and deleted it before relaunching.

**Actual.**


**Evidence.**
- runs/19/10-after-new-list-tap.png: the new empty list on the tab.
- runs/19/db-02-after-new-list.txt: f3210e86 tops the lists.

**Decision quote.**
> 

**Triage.**
