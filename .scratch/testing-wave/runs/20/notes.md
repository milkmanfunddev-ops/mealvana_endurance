# Ticket 20 run notes (w10-20260924T1614Z)

- Worktree HEAD ba89bdf4 (base check passed, no reset); main clone mealplanning also at ba89bdf4.
- App on UDID 7F452347-DC0E-48DF-AF9F-88E2EA070CA5 (wave-pool-1) built from 52c68764b2cde49951a27220a8dbdb3a463116f7 (dev simulator's testing build, copied; the wave lead cleared its data).
- 16:14:51Z slot claimed (LOCK claim slot testing-wave-20).
- 16:15:42Z db-before.txt: matches the prompt (list 03c4c52b, 15 rows, none checked).
- Read from code before the run (for the offline plan, not a Finding by itself): ShoppingListController ticks go straight to vana-action (`update_shopping_item`), optimistic on screen, reverted on failure; there is no local write or queue. Offline, a failed list read falls back to the plan's mirror (`meal_plans.shopping` in Drift), read-only, where a tick changes only the screen.
- 16:16:19Z launched with the console to console.log; simctl launch left SpringBoard in front, tapped the Endurance Dev icon. Welcome, signed out (01-welcome-signed-out.png).
- 16:17:19Z logged in by email as test@test.com (password through CRED type). The What's New sheet, then the TrainingPeaks sharing sheet stacked (12-008, seen again, not refiled); closed the sharing sheet with X (leaves sharing on, no setting changed). The dev tools button sits over "Got it" (12-002, seen again).
- 16:18:15Z Food > Shopping first showed "No shopping list" for several seconds, then the list at 16:18:33Z (16-003, seen again, not refiled). 15 items, imperial (oz, ½), nine-aisle order, matches db-before.txt.
- Online ticks 16:18:44-45Z (Avocado, Carrot, Wholewheat pasta): shopping_items and the meal_plans.shopping mirror both checked within a second (db-after-online-ticks.txt). meal_plans be6abf2f `updated_at` moves on every tick: known noise, by design (mirrorToPlan rewrites the plan's jsonb mirror); status stays confirmed.
- 16:19:03Z cold restart online. iOS notification prompt at launch (03-004, seen again; tapped Don't Allow). Food opened on the Plan sub-tab, not Shopping where I left it: known noise, the Food tab has no remembered sub-tab (not a ticket-20 question). Shopping: ticks kept (09-*.png); the list jumps down ~60 pt when the server list replaces the local copy (20-003). PASS for "checked state across a cold restart".
- Net balance on the Timeline moved −1,039 → −1,043 → −1,044 → −1,047 → −1,050 → −1,054 across the relaunches: known noise, the day's burn accrues with the clock (about 1 kcal a minute over 16:17-16:26Z), nothing was logged.

## Offline method (criterion 3)
- Constraint: never the host network. Two methods tried, both scoped to this app's process on UDID 7F452347 only.
- Tried 1 (16:20:14Z), failed: launch with `SIMCTL_CHILD_http_proxy/https_proxy/HTTP_PROXY/HTTPS_PROXY=127.0.0.1:9` (a refusing port). `ps -E` showed the variables in the app process, but a TrainingPeaks call still got HTTP 400 back: Dart's HttpClient does not read proxy variables by default. Not a cut.
- Used 2 (16:21:19Z on): a 30-line interpose library, SCRATCH/netcut.c → netcut.dylib (built with `xcrun -sdk iphonesimulator clang`, a helper, not an app build), injected with `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` into the app launch only. While `SCRATCH/offline.flag` exists, `connect`/`connectx` to any non-loopback IPv4/IPv6 address fail with ENETUNREACH; removing the flag brings the network back without a restart. `vmmap` showed the library in pid 97036 (this app) and not in 95239 (ticket 30's app on wave-pool-2, untouched). netcut.log recorded blocked connects only from this app's pids; the console shows "Network is unreachable, errno = 51" for vana-action, PostgREST and TrainingPeaks.
- Limit: the OS still reports Wi-Fi, so `connectivity_plus` says online; only real network failures were exercised (20-006). Native SDK traffic (RevenueCat, Sentry) is cut too, since it also goes through connect.
- Offline windows: 16:22:07-16:24:56Z (ticks on live list 16:22:32-34Z; offline restarts 16:23:09Z and 16:24:10Z), and 16:25:46-16:26:38Z (offline restart, tick in the offline copy, live reconnect).
- Results: 20-001 (offline ticks never saved), 20-002 (no offline sign, silent rollback). On reconnect without a restart the tab swapped the offline copy for the server's list within 5 s by itself.
- Offline restarts: the log says "[IS_ADMIN] is_admin read failed; treating as not admin" each time; no paywall appeared (the account also holds Pro Grants). Related to 12-006 (admin on a slow network), not refiled; noted here as known noise for this account because its entitlement, not admin, keeps it past the gate.

## End state
- 16:27:39-41Z unticked Avocado, Carrot, Wholewheat pasta in the app (online). db-after.txt: list 03c4c52b 15 rows, 15 names, 0 checked, 0 have; mirror all false; no list or item created during the run; plan be6abf2f still confirmed (updated_at moved by the mirror writes, as above). Restoring hid no Finding: the offline ticks were never in the database.
- Edge logs (edge-requests.txt, edge-function-logs.txt): six update_shopping_item calls, 3 online ticks and 3 restores; no other writes.
- 16:28:42Z log stream stopped (by PID), app terminated. console.log held 19 token-like hits: deleted; console-excerpts.log keeps the lines the Findings cite.
- No account created, no COST spend, no plan touched, nothing written to the decisions page.
- Screens visited: Welcome, Log In (email), Timeline (with What's New and TrainingPeaks sharing sheets), iOS notification prompt, Food > Plan, Food > Shopping (live list and offline copy).
- Look-around: Welcome/Log In/Timeline paths already have Findings from waves 2-12 (02-010, 04-002, 07-007, 12-003, 12-008); for the Shopping tab this run filed 20-004 and 20-005, and 20-006 for real airplane mode.
