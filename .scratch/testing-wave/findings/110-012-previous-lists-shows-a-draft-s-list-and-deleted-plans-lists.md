# 110-012 · Previous lists shows a draft's list and deleted plans' lists as From plan, like the others, and the draft's list offers Shop with Kroger

- kind: idea
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab) > Previous lists
- decision: 

**Steps.**
Idea (look-around after 19-005 passed). After Browse + built draft 9be88811's list, Previous lists showed it first as "Week of Sep 20 · From plan · 5 items", next to two more "Week of Sep 20 · From plan" rows that belong to a deleted plan (8ebeb6da, is_deleted) and an archived one (be6abf2f). Only the confirmed plan's list carries "This week's plan". Opening the draft's list shows "Made Sep 25, 2026 · An earlier list" and Shop with Kroger. Mark a draft's list as "Draft" (and perhaps hide Kroger on it), and mark or hide lists of deleted plans.

**Expected.**
The athlete can tell a draft's list from an old plan's list.

**Actual.**
Three identical "From plan" rows for the same week.

**Evidence.**
- runs/110/73-previous-lists-after-browse.png
- runs/110/74-draft-list-opened.png
- runs/110/db-11-after-browse-add.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Ruling: no list for a draft (see standing rules) (133). Closed by the retest after it merges. Record: `triage-20260926.md`.
