# Ticket 110 run notes

- RUN: w30-20260925T2103Z
- Build commit: e3367d2c914d59f0fcde4b854ff4805416a6dc20 (app on UDID D4247B9A-8B05-4811-BB04-0C1447247DE8, wave-pool-1)
- Worktree base: a8ebba2930c878a8c865a66a72c4e9e036236bc9 (checked 21:03Z); main clone mealplanning has not moved.
- Slot claimed 21:03:10Z.
- Account: test@test.com (607f9dd5-6fa7-48ee-a628-720d4a0506a1). Confirmed plan 666be167, list c667902d.

## Timeline (UTC)
- 21:05:53Z Food > Shopping opens on c667902d 'Week of Sep 20' (confirmed plan 666be167), 3 rows; Kroger button in the a11y tree but blank area on screen (05-shopping.png)
- 21:06:37Z opened be6abf2f's list 2a4cbd64 (archived once-confirmed plan) from Previous lists, read-only: Farro/Spelt/Quinoa/Wholewheat pasta under Bakery & Grains, Mixed vegetables under Produce; no meal-count badge on Farro (2 meals) on this earlier list
- 21:07:30Z back on c667902d (Back to current list)
- 21:08:11Z [16-009 step 4] ticked Avocado + Wholewheat pasta on c667902d (confirmed plan's list), online
- 21:08:34Z cold relaunch (netcut, online); 21:08:5xZ Shopping shows c667902d
- 21:09Z [16-009] steps not run on purpose: 5 (metric switch) — units are an account setting and ticket 111 checks the Kroger screen's units on the same account (22-003); 6 (edit the plan) — would edit the confirmed plan 666be167 and rebuild its list, which the prompt forbids; 7 (Kroger with no connection) — the connection is 111's to write. Step 1 (Farro count): the confirmed list has no row used by two meals; on be6abf2f's earlier list Farro (2 meals) shows no count.
- [20-001 A] 21:09:5xZ netcut ON; 21:09:39Z on live c667902d: ticked Mixed vegetables, unticked Avocado (offline)
- [20-001 A] first Avocado untick tap (y425, right as the offline notice slid in) did not take; 21:09:52Z tapped Avocado again (y437) to untick
- [20-001 A] console: only two 'tick queued' lines (21:09:38 Mixed veg, 21:09:52 Avocado) — the 21:09:39 Avocado tap left no trace; DB unchanged (Avocado t, pasta t, Mixed f) at 21:10:0xZ
- [20-001 B] 21:10:21Z cold restart with netcut, cut immediately after launch
- [20-001 B] 21:10:40Z offline copy ('Shopping list', offline notice, no Kroger, no row menus, no Add an item) shows Avocado TICKED, Mixed vegetables UNTICKED, pasta ticked = the server's state; the two offline ticks from A are not shown although both sit in the tick store (pending-ticks-after-offline-restart.json, both carry listId c667902d)
- [20-001 B] 21:11:14Z ticked Mixed vegetables in the offline copy
- [20-004] 21:11:31Z offline copy ⋯ shows New list + Previous lists only; Previous lists sheet says 'No earlier lists yet.' (account has 7)
- [20-004/19-010 step 4] 21:11:41Z tapped New list offline
- [20-004] 21:11:43Z New list offline -> error snackbar 'Could not update the list. Check your connection and try again.'; tab stays on offline copy
- [20-004] 21:12:0xZ Share on the offline copy -> share sheet, Copy gives plain text (share-offline-copy.txt), all three rows ☑
- [20-001 B] 21:12:09Z second offline cold restart
- [20-001 B] 21:11:34Z console "shopping tick dropped: no row for "Mixed vegetables"" — the retry timer threw away the tick made in the offline copy 20 s after it was made; 21:12:23Z after the second offline restart Mixed vegetables shows unticked; store (pending-ticks-after-second-offline-restart.json) holds only the two live-list ticks from A.
- [20-001 C] 21:12:42Z ticked Mixed vegetables in the offline copy (again), then network back
online since 21:12:45Z
- [20-001 C] 21:12:45Z network back; by 21:13:10Z the tab swapped to live c667902d (Kroger back) and the DB has the A ticks replayed: Avocado false, Mixed vegetables true (db-01-after-reconnect.txt); tick store empty. The C tick matched A's value so this does not tell C apart; clean C rerun next.
- [20-001 C clean] offline cold restart 21:13:1xZ; 21:13:48Z ticked Avocado in the offline copy; network back 5 s later
- [20-001 C clean, try 1] 21:13:43Z offline copy after cold restart shows Mixed vegetables UNticked although the server row and server mirror say checked since the 21:12:45 replay (db-03-plan-mirror.txt): the phone's copy of the plan was not refreshed after the replay (31-clean-C-avocado-ticked-offline.png). The Avocado tap at 21:13:4xZ did not show in the 1 s screenshot (tap likely landed before the list was ready); 21:14:18Z live list online, DB unchanged (db-02-clean-C.txt). Retrying.
- [20-001 C clean, try 2] offline cold restart 21:14:46Z; 21:15:11Z ticked Avocado in the offline copy; network back ~5 s later
- [20-001 C clean, try 2] store held {Avocado checked true, planId only} at 21:15:12Z; 21:15:16Z console 'shopping tick dropped: no row for "Avocado"'; live list and DB Avocado unchecked (db-04-clean-C2.txt, 35-clean-C2-30s.png). FAIL.
- [20-005 step 1] cold launch online 21:15:5xZ; 21:16:03.495Z tapped Avocado's box (y425) ~0.3 s after opening Shopping
- [20-005 step 1] 36-20-005-first-second.png: Shopping shows a spinner until the server list arrives (no local copy shown first), so the early tap hit nothing; DB unchanged. [step 2] ~21:16:25Z double-tapped Avocado's box (mobile MCP double tap)
- [20-005 step 2] 21:16:41.663-21:16:41.905Z three taps fired in parallel on Avocado, Mixed vegetables, Wholewheat pasta (expect Avocado on, Mixed off, pasta off)
- [20-005 step 2] parallel idb taps changed nothing on screen or in DB (41-20-005-three-fast-5s.png) — treated as a harness miss (parallel idb calls), not app behaviour. Sequential: 21:17:00.467-21:17:00.984Z taps on Avocado, Mixed, pasta
- [20-005] 21:17:06Z after sequential fast taps: screen = DB (Avocado t, Mixed f, pasta f) (43-..., db-08-...). Ticks on c667902d now: Avocado checked; Mixed + pasta unchecked (as at start except Avocado).
- 2026-09-25T21:17:18Z wrote SHARED/110-lists-start; list-making checks begin
- [19-006] 21:17:27Z ⋯ > New list (first) on c667902d
- [19-006] 21:17:31Z new list e2a7a1c5 'List 2026-09-25' opens, subtitle 'Made Sep 25, 2026 · An earlier list' (44-new-list-1.png)
- [19-006] 21:17:4xZ Timeline then Food: still shows e2a7a1c5 (the list just made) (45-...)
- [19-006] 21:17:53Z cold relaunch online
- [19-006] 21:18:11Z after cold relaunch the tab opens c667902d 'Week of Sep 20' (confirmed plan's), Kroger shown (46-...)
- [19-006] 21:18:35Z offline cold restart: offline copy is the plan's 3 rows (47-new-list-offline.png); network back 21:18:35Z
- [19-010 step 5] 21:19:2xZ opened e2a7a1c5 from Previous lists; header Share on the empty list: nothing happens, no sheet, no message (49-share-empty-list.png)
- [19-010 step 1] 21:19:50Z added 'Figs' (no qty) to e2a7a1c5
- [19-010 step 1] 21:20:15Z added a 74-character name (olive oil) to e2a7a1c5
- [19-010 step 1] 21:20:45Z added '2 lb chicken thighs' in the Item field (Qty empty)
- [19-010 step 1] 21:21:01Z ticked Figs on e2a7a1c5
- [19-010 step 1] 21:21:25Z renamed e2a7a1c5 to 'Race week extras' (title tap > Rename list sheet)
- [19-010 step 2] 21:21:4xZ Share on 'Race week extras' -> plain text (share-handmade-list.txt), titled 'Mealvana shopping list', not the list's name; '3 items to buy' counts the ticked Figs
- [19-010 step 3] 21:21:49Z New list (second of the day) from 'Race week extras'
- [19-010 step 3] 21:22:03Z New list (third of the day, from the empty 0cfd283c) to get two unrenamed lists
- [19-010 step 3] 21:22:15Z Previous lists: two rows 'List 2026-09-25 · 0 items' (dfd97e91, 0cfd283c) indistinguishable (59-...)
- [19-001] 21:22:41Z deleted dfd97e91 (own empty hand-made list, on screen)
- [19-001] 21:22:4xZ after Delete the tab falls back to c667902d 'Week of Sep 20' with Kroger (61-...); DB: dfd97e91 gone, c667902d untouched (db-09-after-19-001.txt)
- [18-002] target: planning conversation 7cc15497 (meal_planning, made 20:28 after the confirm, no plan). Reached by deep link /vana/browse?c=7cc15497-... so no chat opener runs (no COST spend; wave cost 0/3 plan, 0/5 chat at 21:24Z). Expected write: a new draft for week 2026-09-20 owned by 7cc15497, and a list for it (mp-244 allows), while the Shopping tab stays on c667902d.
- [18-002] 21:24:10Z Browse (conv 7cc15497): + on Sweet rice cake with jam
- [18-002] 21:24:12Z the first + made draft 9be88811 (week 2026-09-20, conversation 7cc15497, 1 meal x4 servings) and its list 8719653f 'Week of Sep 20' (5 rows) (db-11, db-12). [18-006] rice row reads 'Short-grain rice 280 g' for 4 servings of 'Cooked short-grain rice 200g' = the dry amount (800 g cooked / ~2.9). Strawberry jam lands in Produce.
- [18-002] 21:24:31Z second + on Sweet rice cake with jam
- [18-002] 21:24:47Z Browse Done -> chat for 7cc15497 shows its stored opener, header 'No plan yet' and plan bar 'Your plan · 0 meals' although draft 9be88811 holds Sweet rice cake x4 (68-, 69-). No vana_calls rows for the account since 21:03Z (db-14-vana-calls.txt): no AI spend.
- [18-002] 21:25:2xZ Food > Plan still the confirmed 1-meal plan (70-); Food > Shopping still c667902d 'Week of Sep 20', Confirmed, Kroger (71-)
- [18-002/18-006] 21:26Z after cold relaunch the tab opens c667902d (72-); Previous lists lists the draft's list 8719653f first as 'Week of Sep 20 · From plan · 5 items' with no draft marker (73-); opened it: 'Made Sep 25, 2026 · An earlier list', Shop with Kroger offered, Short-grain rice 10 oz, Strawberry jam under Produce (74-)
- [cleanup] 21:26:32Z unticked Avocado on c667902d (back to all three unchecked, the start state)
- [cleanup] 21:27:03Z deleted 0cfd283c (empty 'List 2026-09-25') from Previous lists row menu
- [cleanup/look-around] 21:27:4xZ after deleting 0cfd283c from Previous lists, the tab shows c667902d headed 'Confirmed Sep 25, 2026 · An earlier list' although it is the default list (75-)
- [cleanup] 21:27:39Z deleted e2a7a1c5 'Race week extras' from Previous lists row menu

## Console and edge logs (read after each screen, summarised here)
- known noise: every "Network is unreachable" / VANA_TRANSPORT / VanaOfflineException / "Could not confirm remote user row" / "is_admin read failed" / integration "No internet connection" line falls inside a netcut window (21:09:33-21:12:45, 21:13:34-21:13:53, 21:14:46-21:15:16, 21:18:20-21:18:35) — the run cut the network on purpose.
- known noise: TrainingPeaks "Token refresh failed (status: 400)", V.O2 "Please reconnect", "Date-range endpoint unavailable", "No intensity distribution hints", "No distance data available" — the test account's stale integrations, Finding 21-004.
- known noise: garmin-push "record failed ... no_user_mapping" in edge-function-logs.txt — another user's Garmin fan-out, Finding 18-012; not this run.
- SHOPPING_LIST lines: filed as 110 Findings (tick dropped).
- edge-vana-action-requests.txt: 95 vana-action requests in the run window, all 200.
- vana_calls: no rows for test@test.com since 21:03Z (db-14-vana-calls.txt), so no AI spend; no COST spend taken. The Food tab's Vana card ("Looking at your day…", later "Swim 30m and core work…") made no vana_calls row in the window.

## Left on the account
- Draft 9be88811 (week 2026-09-20, conversation 7cc15497, Sweet rice cake with jam x4) and its list 8719653f "Week of Sep 20" (5 rows), made by 18-002 at 21:24:12Z. Left in place: removing it means editing the draft; it is not the default list and no other run reads it.
- c667902d: all three rows unchecked again at 21:26:32Z (start state). Hand-made lists e2a7a1c5, 0cfd283c, dfd97e91 all deleted.
- No accounts created.
- 21:30:09Z log stream stopped, app terminated, slot released
