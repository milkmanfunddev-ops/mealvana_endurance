# Ticket 19 run notes, w11-20260924T1647Z

- App build on wave-pool-1 (UDID 8CBC21E1-FB27-41C3-9205-1C5519057429): commit 52c68764b2cde49951a27220a8dbdb3a463116f7.
- Worktree base dcc4a14e (checked). Slot testing-wave-19 claimed 16:47:54Z.
- App data cleared by the wave lead: opens signed out on Welcome.
- Another agent (ticket 31) is signed in to test@test.com on another simulator (Settings/profile only).

## Timeline
- 16:49:48Z logged in as test@test.com
- 16:50:34Z opened Food > Shopping (04 at tap, 05 at +5s). Before that, Food > Plan showed 'No plan yet' for ~6 s after the first open, then the 4-meal plan (03-food-plan.png).
- 16:51:00Z ⋯ menu: New list / Previous lists / Delete list (06). Opened Previous lists (07).
- 16:51:39Z Previous lists shows 14 rows, not scrollable, bottom overflow stripe (07, 08). Tapped 'List 2026-09-19' to open it (09).
- 16:52:10Z on List 2026-09-19 opened ⋯ (New list / Previous lists / Back to current list / Delete list), tapped New list (10).
- 16:52:44Z new list f3210e86 'List 2026-09-24' made at 16:52:01Z, no name asked (10, db-02). Deleted it via ⋯ > Delete list > Delete (11 dialog; 12 at tap, 13 at +4 s).
- 16:53:26Z deleted 03c4c52b (confirmed plan be6abf2f's list) via ⋯ > Delete list > Delete; same generic dialog, no mention of the plan (14; 15 at tap, 16 at +4 s).
- 16:53:30Z db-04: 03c4c52b and its 15 rows gone (no orphans); meal_plans be6abf2f still `confirmed`, its shopping mirror now 0 lines (updated_at 16:53:19.994Z). The tab fell back to list 9bdc9556 "Week of 2026-09-20" (6 items), the list of ARCHIVED draft 54a02440, headed "Made Sep 24, 2026" with Shop with Kroger (16). Plan tab still shows the confirmed 4-meal plan (18). Previous lists now holds 13 lists, the last rows still under the overflow stripe (17).
- Console: no Flutter error or exception line tied to the shopping actions. The only Flutter error lines are the TrainingPeaks token refresh 400 and VDOT "Please reconnect" integration-sync failures right after login (known noise: the dev admin's integration tokens expired long ago; not this ticket's scope). The overflow stripe in Previous lists printed no line to the log stream.
- Observed in the DB, not caused by this run: week 2026-09-13 has three `confirmed` plans (f2c0bc78, 4e29032c, 6e167344) and one `draft` (fc9687ff). The hand-off said "no drafts"; that holds for week 2026-09-20 only. Filed as a Finding (19-008).

## State left on test@test.com (for later tickets)
- The confirmed plan be6abf2f (week 2026-09-20) is still confirmed with its 4 meals, but has NO shopping list: list 03c4c52b was deleted by this ticket and meal_plans.shopping is []. Per mp-244 the next plan edit should rebuild it (not tried here).
- The shopping tab now opens list 9bdc9556 (archived draft 54a02440's list, 6 items, none checked) as the current list.
- 13 lists remain (db-05-final.txt): 9bdc9556 (current on the tab), adc5b2de, e4d6e247, 90c2fefc, debb5576, 77fd387c, f53e980b, 23a6ab6c, d907ba91, c1961185, f7eb5cc7, 7ed03528, 2c62b069. Only 03c4c52b is gone compared with the start; the new list f3210e86 made by this run was deleted. List 90c2fefc still has 6 of 9 rows checked, as before.
- Nothing was re-created to repair state (per prompt).
- 16:54:51Z log stream stopped, app terminated, slot released.
- Token scan hit 4 lines: 3 are Apple BaseBoard "machport" lines matching `sk_`-like text (harmless), 1 is a CFPrefs debug dump of `flutter.sb-vlmtsdzpnjnavdgytcmi-auth-token` holding the Supabase session's access token. So console.log was deleted and console-excerpts.log keeps only the Flutter lines cited here (integration-sync noise), none of the hits. Known noise for the app (supabase_flutter keeps the session in shared_preferences, and `--level debug` prints the prefs), but it means every debug-level console capture carries a live dev token.
