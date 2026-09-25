# 89-001 · Offline, a confirmed plan whose list was deleted makes the Shopping tab say No shopping list and Confirm a meal plan, with no offline notice

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. test@test.com with this week's plan confirmed (be6abf2f), its shopping list deleted (mirror `meal_plans.shopping` = []) and a hand-made list 90c2fefc on the account (the state 19-009 starts from). Online, Shopping opens 90c2fefc.
2. Cold relaunch with the app's network cut (netcut) and open Food > Shopping.
3. Tap Share in the header.

**Expected.**
The offline copy says it is offline (the tab's own `_OfflineNotice`) and shows the last list read, or at least does not tell an athlete who has confirmed a plan to confirm one.

**Actual.**
The tab shows the first-run empty state: "No shopping list · Confirm a meal plan and the shopping list builds itself." and a New list button, with no offline notice. The controller's read fails ("shopping list read failed; showing the plan mirror"), the mirror is empty, and `ShoppingTab` takes the empty-state branch before it reaches the offline notice. Share does nothing (no sheet, no message). Once the network was back the tab showed 90c2fefc again within 25 s without a tap, so the recovery works. Build e3367d2c.

**Evidence.**
- runs/89/07-19-009-shopping-offline-cold.png: the offline tab.
- runs/89/08-19-009-share-offline-empty.png: after the Share tap, nothing.
- runs/89/02-shopping-before-19-009.png: the same account online, showing 90c2fefc.
- runs/89/console-redacted.log: 14:55:28 local, "shopping list read failed; showing the plan mirror".
- runs/89/notes.md: 19-009 section, 19:55-19:56Z.

**Decision quote.**
> 

**Triage.**
