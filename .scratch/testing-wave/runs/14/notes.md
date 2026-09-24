# Ticket 14 run notes (w8-20260924T1418Z)

- App on UDID FE0AA9E3-9955-4E3F-AEFD-6530AF39AC48 built by the wave lead from 433514bcfedc0100ce7d76416de44fb53fcf6b01 (app-build.json).
- Slot claimed 14:18:16Z (held with testing-wave-10).
- Account: test@test.com (dev admin, entitled: active_until 2027-09-15).
- The worktree's app-build.json at 433514bc still reads commit null; the prompt names 433514bc as the build commit (the main clone's copy is modified, uncommitted). Known noise: the wave lead's uncommitted edit.
- 14:21:53Z COST spend 8 plan 14 -> plan 1/3. db-before.txt taken 14:21Z.
- Console 09:20:28 local: TrainingPeaks token refresh 400 and V.O2 'Please reconnect' on login. Known noise: the dev admin's integration tokens are expired; unrelated to planning (existing integrations findings, e.g. 03-008).
- 14:19:16Z `simctl launch` started the app (pid 55512) but the simulator stayed on the home screen; tapping the Endurance Dev icon brought it forward. Testing-process note (IMPROVEMENTS), not an app bug.
- The mobile MCP's save_screenshot refuses paths inside the worktree; screenshots were saved with `xcrun simctl io <udid> screenshot`. Its element list once returned the previous screen after a tap (stale); screenshots were used to confirm. Testing-process notes.
- 14:20:20Z logged in by email as test@test.com. Timeline, then Food → Plan tab.
- 14:21:06Z Plan tab showed 5 meals incl. "Brown rice, zucchini & chickpea bowl"; 14:21:53Z 4 meals. Finding 14-003.
- Local Drift DB holds another account's rows (37129f7e). Finding 14-004.
- 14:22:03Z tapped New meal plan. iOS asked for Speech Recognition before the mic was touched; Don't Allow tapped. Already filed as 09-004 (seen again, not refiled).
- 14:22:13Z opener stored (metadata new_plan=true). Opener talks about last week: Finding 14-005.
- 14:22:40Z db-after.txt: only conversation d8efbdb3 new; no plan archived or created. Finding 14-001 (mp-241), 14-002 (mp-234, no plan bar at 0 meals).
- 14:23:04Z chip "Show me what fits the training" (a model turn, inside the one plan spent). 14:23:36Z picked Egg & Veggie Scramble: draft 54a02440 created (db-after-pick.txt).
- Console after 09:22 local (14:22Z): no Flutter error or exception lines. Earlier lines "No distance data available" / "No intensity distribution hints available": known noise, fuelling-engine defaults for Patrol test activities.
- Account left: old confirmed be6abf2f (week 2026-09-20) still confirmed and on the Plan tab; new draft 54a02440 (week 2026-09-20, 1 meal: Egg & Veggie Scramble) in conversation d8efbdb3. Nothing deleted.
- console.log held 4 token-like hits (runbook 9.4 scan); deleted, console-excerpts.log keeps the error lines these notes cite.
