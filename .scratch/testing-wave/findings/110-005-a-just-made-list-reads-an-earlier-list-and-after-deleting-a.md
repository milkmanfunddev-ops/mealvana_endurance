# 110-005 · A just-made list reads An earlier list, and after deleting a list from history the default list reads An earlier list too

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. On the confirmed plan's list, ⋯ > New list (21:17:28Z). The new empty list opens.
2. Later, from Previous lists, delete another hand-made list (row ⋯ > Delete, 21:27:4xZ) while the confirmed plan's list is open.

**Expected.**
A list made a moment ago is not labelled as earlier; the confirmed plan's list, the tab's default, is not labelled as earlier.

**Actual.**
Step 1: the new list's subtitle reads "Made Sep 25, 2026 · An earlier list" (it drops the label once an item is added). Step 2: the confirmed plan's list reads "Confirmed Sep 25, 2026 · An earlier list", while its ⋯ menu has no "Back to current list" (it treats the list as current). The label disagrees with the menu and with what the athlete just did.

**Evidence.**
- runs/110/44-new-list-1.png — new list labelled An earlier list.
- runs/110/75-after-delete-from-history.png — default list labelled An earlier list.
- runs/110/notes.md — timeline.

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
