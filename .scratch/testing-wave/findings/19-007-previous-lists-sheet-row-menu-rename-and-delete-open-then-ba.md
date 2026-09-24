# 19-007 · Previous lists sheet: row menu Rename and Delete, open then Back to current list, Keep it, a second tap on Delete

- kind: followup-test
- status: open
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab) > Previous lists
- decision: 

**Steps.**
1. Previous lists > a row's ⋮ > Rename: an empty name, a very long name, the same name as another list.
2. Previous lists > a row's ⋮ > Delete on a list that is not on screen (the sheet's optimistic path), including the confirmed plan's list from there.
3. Open an older list, then ⋯ > Back to current list.
4. Delete list > Keep it.
5. Delete list > tap Delete twice fast; delete with the network cut (20-004 covers the offline menu).
6. Tap the list that is Open now in the sheet.

**Expected.**
Each path leaves the database and the tab agreeing (SQL on shopping_lists and shopping_items), with no duplicate delete call or stale row left in the sheet.

**Actual.**


**Evidence.**
- runs/19/07-previous-lists.png: the sheet and its row menus.
- runs/19/11-delete-new-list-dialog.png: the dialog with Keep it.

**Decision quote.**
> 

**Triage.**
