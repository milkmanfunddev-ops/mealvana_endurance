# 19-002 · A confirmed plan's shopping list can be deleted with the same dialog as any list, leaving the confirmed plan with no list

- kind: idea
- status: open
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
Idea / product question. Today: Food > Shopping > ⋯ > Delete list on the confirmed plan's list shows the same "Delete this list? Everything on it goes with it." dialog as a hand-made list, and Delete removes the list and its 15 rows and empties meal_plans.shopping of the confirmed plan (be6abf2f), which stays `confirmed` with no list. Nothing tells the athlete the list will come back on the next plan edit, or that Kroger and the offline copy lose it too.

Decide one of: (a) the confirmed plan's list cannot be deleted, only cleared or hidden; (b) it can, and the dialog says it is the plan's list and when it comes back; (c) deleting it rebuilds a fresh copy at once. mp-244 says the server builds the list at confirm and after every edit, but no decision says whether the athlete may delete it.

**Expected.**
A decision on whether the plan's own list is deletable and what the athlete is told.

**Actual.**
Tried as the ticket's last action at 16:53Z: deleted with no warning beyond the generic dialog. SQL afterwards: shopping_lists 03c4c52b gone, 0 orphan shopping_items, meal_plans be6abf2f status confirmed, shopping [] (updated_at 16:53:19.994Z). This matches the server contract (contracts.ts delete_shopping_list: "a plan's list empties the plan's mirror too"). No decision covers it, so it is filed as an idea, not an ssot-conflict.

**Evidence.**
- runs/19/14-delete-plan-list-dialog.png: the same generic dialog on the confirmed plan's list.
- runs/19/db-03-after-delete-new.txt: before (03c4c52b present, 15 rows, mirror 15).
- runs/19/db-04-after-delete-plan-list.txt: after (list gone, mirror 0, plan still confirmed).

**Decision quote.**
> 

**Triage.**
