# Ticket 110 verdicts (wave 30, run w30-20260925T2103Z, build e3367d2c)

All on test@test.com, simulator wave-pool-1. Paths are under `runs/110/`.

## Retests

| id | verdict | evidence | new bug |
|---|---|---|---|
| 16-007 | pass | 09-be6abf2f-list.png, 10-be6abf2f-list-scrolled.png, db-00-before.txt (Farro, Spelt in Bakery & Grains; Mixed vegetables in Produce; plan lists read "Week of Sep 20", old ones shown in words) | — |
| 18-002 | pass | db-11-after-browse-add.txt, 70-food-plan-after-browse.png, 71-shopping-after-browse.png, 72-shopping-after-browse-relaunch.png (Browse + in conversation 7cc15497 made draft 9be88811 and list 8719653f; the Shopping tab stayed on the confirmed plan's list c667902d, also after a cold relaunch) | — (110-009, 110-012 found on the way) |
| 18-006 | pass | db-12-draft-list-items.txt, 74-draft-list-opened.png (4 servings of "Cooked short-grain rice 200g" give "Short-grain rice 280 g" = 10 oz, the dry amount) | — (110-008 found on the way) |
| 19-001 | pass | 60-delete-confirm.png, 61-after-delete-own-list.png, db-09-after-19-001.txt (deleted own hand-made list dfd97e91 while on screen; tab fell back to c667902d with Kroger; the confirmed plan's list was not deleted, by the prompt's rule) | — |
| 19-005 | pass | 08-previous-lists.png ("This week's plan" on the confirmed plan's list) | — (110-012 idea) |
| 19-006 | pass | 44-new-list-1.png, 45-leave-food-return.png, 46-new-list-cold-relaunch.png, 47-new-list-offline.png (new list opens once; cold relaunch opens c667902d; offline copy is the plan's) | — (110-005 found on the way) |
| 20-001 | fail | 23-offline-cold-shopping.png, 29-offline-second-restart.png, 34-clean-C2-avocado-tapped.png, 35-clean-C2-30s.png, db-04-clean-C2.txt, pending-ticks-*.json, console-redacted.log (ticks made on the live list while offline are kept and sent on reconnect; ticks made in the offline copy are dropped by the retry timer within 20 s and never sent; live-list offline ticks do not show on the offline copy after a restart) | 110-001, 110-002 (also 110-003) |
| 20-002 | pass | 20-offline-live-ticks-0s.png, 23-offline-cold-shopping.png, 27-offline-new-list.png (offline notice on the live list and on the offline copy; Shop with Kroger hidden offline; a failed write, New list offline, shows the error snackbar; Share still works offline and sends plain text) | — (a tick lost in silence is 110-001) |

## Follow-up tests

| id | verdict | evidence | new Findings |
|---|---|---|---|
| 16-009 | pass (steps 2-4 only; 1, 5, 6, 7 not run) | 12-row-menu.png, 13-row-edit-sheet.png, share-confirmed-list.txt, 15-two-ticked.png, 16-after-subtab-switch.png, 18-after-relaunch-shopping.png | 110-013 (the steps not run), 110-006, 110-011 |
| 19-010 | pass | 50-..-56-*.png, 57-share-handmade.png, share-handmade-list.txt, 58-new-list-2.png, 59-previous-lists-two-same-names.png, 27-offline-new-list.png, 49-share-empty-list.png (rows land on the new list's id; rename saved; Share plain text; New list offline shows the snackbar) | 110-007, 110-010, 110-011 |
| 20-005 | pass | 36-20-005-first-second.png, 39-20-005-doubletap-4s.png, db-06-20-005-doubletap.txt, 43-20-005-seq-fast-5s.png, db-08-20-005-seq-fast.txt, edge-vana-action-requests.txt (no local copy is shown before the server list any more, so no swap race; a double tap ends unticked on screen and in the DB; three taps in 0.5 s end the same on screen and in the DB) | 110-014 |
| 20-004 | pass | 25-offline-list-menu.png, 26-offline-previous-lists.png, 27-offline-new-list.png, share-offline-copy.txt (⋯ offers New list and Previous lists only; New list says it needs the connection; Share sends plain text; no Kroger, no Add an item, no row menus on the offline copy; no count or hidden row on this list to try) | 110-004 |
