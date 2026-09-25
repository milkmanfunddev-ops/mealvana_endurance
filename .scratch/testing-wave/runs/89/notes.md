# Ticket 89 notes, run w29-20260925T1950Z

- Build commit for every Finding: e3367d2c914d59f0fcde4b854ff4805416a6dc20 (installed on wave-pool-2 DD62798C…, app data cleared).
- Worktree HEAD db48b2474566e6d36917b2c0a727c8671927e08d; main mealplanning at the same commit.
- 19:50Z slot claimed; console stream started; first `simctl launch` left SpringBoard in front (IMPROVEMENTS #50), second launch fine.
- 19:52Z signed in as test@test.com; "New in Mealvana" What's New sheet shown once, dismissed. Baseline db-00-baseline.txt matches the prompt.

## 19-009 (run first, per the wave lead's ordering rule)
- 19:53Z Shopping tab with be6abf2f confirmed and no plan list: opens hand-made 90c2fefc "List 2026-09-19" (the default rule: newest hand-made list). Not the archived draft's list (19-001 holds). 02-shopping-before-19-009.png.
- 19:54Z Share (step 3): shares 90c2fefc as plain text (19-009-share-text-no-plan-list.txt). Header says "9 items to buy" while 6 of the 9 are ticked: see Finding (share count).
- Shop with Kroger (step 3): not offered on a hand-made list (shopping_tab.dart shows it only when the list has a planId): by design, no Finding. List ⋮ = New list, Previous lists, Delete list (05-list-options-menu.png).
- 19:55:00Z cold relaunch with netcut on (step 4). Notification permission prompt on cold start (06-cold-start-notification-prompt.png): Allowed. Known noise: first launch after sign-in, which ticket 79 made the prompt's moment (after sign-in, never before Welcome); ticket 93 retests 79.
- 19:55Z offline Shopping: "No shopping list / Confirm a meal plan and the shopping list builds itself." + New list, no offline notice; Share tap does nothing (07-, 08-). Console "shopping list read failed; showing the plan mirror". New bug Finding.
- 19:56:02Z netcut off; within 25 s the tab showed 90c2fefc again with no action (retry timer). Recovery OK.
- 19:57:10Z EDIT: swapped be6abf2f's "Wholewheat pasta, mixed veg & avocado" for "Quinoa, mixed veg & walnuts" (Plan tab > More > Swap). The Swap screen's cards carry research-note subtitles ("his dinner base is ...") -- 18-004's fix covered Browse only: new Finding.
- 19:57:11Z server made list 10579cbf (plan_id be6abf2f, "Week of Sep 20", 15 plan rows) and filled the mirror (15). Shopping tab opened it at once with Shop with Kroger, oz units, Farro count 2 (12-, db-01-after-swap.txt). mp-244 holds -> 19-009 pass.
- The rebuilt list's `confirmed_at` is NULL (the edit path, refreshShopping, does not stamp it; the Plan tab's Rebuild path does, markListConfirmedIfUnset). Tab still opens it (default = the confirmed plan's list by plan_id). Filed as a low bug so the two paths agree.
- 19-009 step 2 (Vana Add back without a list) not run: the list already existed after step 1 and it needs a chat spend; nothing to test in that order.

## 19-007 and 19-003 (on test@test.com, lists other than 813df86f)
- 19:58Z Previous lists: 9 lists, all visible, no overflow stripe (13-previous-lists.png). The account no longer has 14 lists, so 19-003's overflow case is retested on the throwaway account with 14 lists (below).
- Row ⋮ = Rename, Delete. Rename opens a sheet over the tab and closes Previous lists.
- 19:58:47Z Rename 23a6ab6c to "" + Save: nothing happens, no message, no call, sheet stays (17-). Acceptable; noted.
- 19:59:17Z Rename 23a6ab6c to a 123-char name: saved whole (DB length 123), sheet ellipsizes it on one line (19-). Lists have no length cap (plans cap at 60, PLAN_NAME_MAX). Noted, not filed (no rule).
  The first Save tap at 19:59:06 landed on the keyboard (the sheet had moved up with it) and typed a space; the server trimmed it.
- 20:00:20Z Rename 23a6ab6c to "List 2026-09-19" (same as 90c2fefc): allowed; the sheet then shows two "List 2026-09-19" rows told apart only by date (20-).
- 20:00Z Open 90c2fefc from the sheet: header "Made Sep 19, 2026 · An earlier list"; ⋮ adds Back to current list; it returns to "Week of Sep 20" with Shop with Kroger (21-, 22-). Pass.
- 20:01:02Z Delete list > Keep it on the plan's list 10579cbf: dialog "Delete your plan's list? ... You can rebuild it any time from the Plan tab." Keep it wrote nothing (updated_at unchanged, 15 rows). Pass.
- 20:01:39Z DELETE 23a6ab6c from the sheet's row menu (a list not on screen): generic "Delete this list? Everything on it goes with it." (does not name the list, and two lists shared its name). Row gone from DB and from the sheet on reopen (26-). The sheet closes after the delete.
- 20:04:53Z DELETE f7eb5cc7: opened it, ⋮ > Delete list > Delete tapped twice 0.15 s apart. ONE delete_shopping_list call (edge log 15:04:54 local), the second tap landed on the list screen and ticked nothing (no checked rows on 10579cbf). Pass.
- Tapping the "Open now" row: closes the sheet, stays on the list (27-). Pass.
- 20:05:43Z DELETE 10579cbf (be6abf2f's list, built by the 19:57 edit) from the sheet's row menu: plan-list dialog shown; list and its rows gone, mirror emptied to 0; the tab fell back to hand-made 90c2fefc, not to draft 173cebb2's list 813df86f (31-). Pass.
- 20:06:06Z Plan tab ⋮ > Rebuild shopping list: list 2a4cbd64 (15 rows, confirmed_at 20:06:09) and mirror 15. The Shopping tab showed the OLD list 90c2fefc for ~5 s before switching to "Week of Sep 20 · Confirmed Sep 25, 2026" (33-, 34-). Ticket 96 is ticket 100's retest; noted here only.
  Header reads "Confirmed Sep 25" for the Rebuild-made list but "Made Sep 25" for the edit-made one: same plan, same list, two words (see the confirmed_at Finding).
- Ticket 88 activity seen in edge logs on the same user (pick_meals, rewind, recent_meals, get_meal at 14:57-15:04 local); 813df86f grew to 14 items and archived plans 54a02440/15b6b4f4 changed: theirs, expected.

## FLAG written 2026-09-25T20:06:36Z (testing-wave-w29-shared/89-be6abf2f-done)
be6abf2f CONFIRMED, 4 meals, list 2a4cbd64 (15 rows, confirmed_at set), mirror 15. db-02-at-flag.txt. From here ticket 88 may confirm/archive.

## 17-001, 17-002, 17-003, 17-005, 73-001 (test@test.com, after the flag)
- 20:07:03.7Z Plan ⋮ > Previous plans: spinner at once (35-), rows by ~1 s (36-); edge `list_plans` 133 ms. Rows: Sep 13 (6), Sep 6 (4), Aug 30 (3), all "Confirmed". SQL (db-03-prev-plans-vs-sql.txt): the plans list_plans must list are be6abf2f (on the Plan tab, so dropped), f2c0bc78, a5b4c73c, a89fbf86: exact match. Never-confirmed drafts 968c5a59, fc9687ff, 173cebb2 absent (17-002 pass). The Aug 23 plans are never-confirmed archived plans: not listed by mp-677's rule; the prompt says known, not a Finding.
- 20:07:31Z tapped Sep 13 (f2c0bc78): the earlier plan screen sat on a spinner for 76 s; NO get_plan request reached vana-action (edge logs: nothing between list_plans 15:07:04 and get_plan 15:08:58 local), no Flutter log line, no error on screen (37-, 38-). Back returned to the sheet; Sep 6 then opened in ~1 s, and Sep 13 on the retry in ~1 s. New bug Finding (hang with no request and no timeout). netcut was off since 19:56:02Z (netcut.log has no block after that).
- 17-003 retest: Back returns to the sheet (rows shown at once); tapped a row ~9 s later, it opened. list_plans 133 ms vs 8062 ms before. Pass (the one hang above is the earlier plan screen's own read, filed separately).
- 17-005 step 1: tapping a meal row on an earlier plan opens the meal detail (Save to mine, Add photo, See the original recipe, Swaps, Start cooking; no Log/Swap-in-plan) (41-). The earlier plan view is now editable by design (mp-675): servings steppers and a row ⋮ are shown. Step 2: servings = servings_left on every f2c0bc78 row (4,4,4,4,3,3), so ×N still cannot tell them apart. Step 4 (days): d5b89888/83eb5608 are never-confirmed and no longer listed (mp-677): cannot run. Step 5: long names wrap on two lines with no clipping (40-). Step 3 on the throwaway account below.
- 20:09:56Z EDIT: Sep 13 plan ⋮ > Use this plan again: copy 9598807a (draft, no conversation, 6 meals) made; the screen switched to "Sep 20 – Sep 26 · 6 meals" about 8 s later (43-, 44-).
- 20:10:36Z EDIT: Back > Sep 6 plan ⋮ > Use this plan again: copy 1192963b (4 meals); 9598807a archived at 20:10:37 and its list dropped. One live conversation-less draft for the week: 73-001 pass (db-04-after-use-again.txt). 8ebeb6da (conversation 449da56d, 20:10:24) is ticket 88's new-plan draft, untouched.
- After Back from the copy: the Plan tab still shows be6abf2f (confirmed wins in getPlan) and Previous plans omits the copy (never confirmed, mp-677), so the copy 1192963b can no longer be reached anywhere (47-). New bug Finding with a product question. Left live for ticket 88's confirm to archive.

## 18-004 and 18-010 (test@test.com)
- 20:11Z Food > Meals (same MealCatalogBrowser): search "salmon" -> "Nothing found — try another search" (50-). "spinach" -> 7 meals, every one with spinach in its ingredients; subtitles are ingredient lines, not research notes (51-). Library has 8 active salmon meals and 51 meals whose `why` mentions salmon but not their name/ingredients (db-05-salmon-library.txt); none shown.
- 20:13:07Z COST spend 29 chat 89 (3/5). Ask Vana opener: vana_calls 20:13:14 vana.opener.general conv 29897d1c (bought). Conversations > Meal plans: every row reads "No plan yet", incl. f6a0f7fa (owns confirmed be6abf2f) and 0401b3d8 (owns draft 173cebb2), while opening 0401b3d8 heads it "Sep 20 week · Draft" (55-, 56-). New bug Finding (ticket 97's area; ticket 100 retests 97).
- 20:14:20Z 0401b3d8 > Add > Browse meals: Browse opened already showing the Meals tab's "spinach" results with the search box closed and, once opened, empty (57-, 58-). New bug Finding (search carried across screens, invisible).
- Browse "salmon" -> Nothing found (59-). Filters > Dinner: subtitles are ingredients (61-). 18-004 pass. The saved "Egg & Veggie Scramble" repeats its own name as its subtitle (no ingredients): noted with the subtitle Finding.
- 18-010 detail from Browse (Quinoa, mixed veg & walnuts, AD-015):
  - 20:15:38Z heart (Save to mine): saved_meals 09f59fb0 at 20:15:40, "Saved to My Foods" toast, heart filled (63-). vana.embed call at 20:15:40 = the save's embedding.
  - 20:15:54Z second tap on the filled heart: nothing (no unsave; button disabled once saved, by code).
  - Back, reopen: heart EMPTY again although saved (66-); tapping it at 20:16:28Z "saves" again, server dedups (still one row). New bug Finding.
  - 20:16:48Z thumbs up: meal_feedback row vote=1 (athlete vote; not the team review). Thumb buttons have no accessibility label (idb shows empty StaticText): ticket 51's area, noted.
  - Team review box was ABSENT although users.is_admin = true: console 14:55:04 local "[IS_ADMIN] is_admin read failed; treating as not admin" (Network unreachable) from the 19:55 offline cold start; isAdmin is keepAlive and never re-read once online. New bug Finding.
  - 20:17:40Z relaunched (netcut launch, network on); deep link com.milkman.mealvanaendurance:///vana/browse?c=0401b3d8… (iOS "Open in Endurance Dev?" prompt) -> Browse. Team review box shown now (71-).
  - 20:19:18Z Good recipe + why "testing-wave 89 check, ignore" + Send review: meal_reviews 8861acf0 is_good=true; app_version NULL; box cleared (73-).
  - Start cooking: "Step 1 of 3" cooking mode, Close returns to the detail (74-). Add photo: admin "Meal photos" screen, nothing uploaded, Back returns (75-). See the original recipe: opens Safari on sundried.com (the stored source_url), with Safari's first-run tip (76-78). Swaps icon: shows "quinoa→rice or wholewheat pasta", "walnuts→avocado or seeds" read-only (79-).
  - Back to Browse: Dinner filter kept, no card ticked; the new saved copy shows as "Yours" (80-). Draft 173cebb2's plan_meals unchanged (2, last 09-24 21:11). 18-010 pass apart from the Findings above.
- vana_calls 20:15:17 vana.daynotes: day notes refresh after my plan edits (day_notes_stale). Expected.

## 17-006 steps 2-3 (test@test.com)
- 20:21:43Z (seen at 20:22) ticket 88 confirmed 8ebeb6da (conversation 449da56d): be6abf2f, 173cebb2 and my copy 1192963b archived (db-06-week-after-88-confirm.txt). Plan tab shows "Sep 20 – Sep 26 · 2 meals". Expected (88's run).
- 20:22:03Z netcut on; Plan ⋮ > Previous plans at 20:22:04: spinner for ~35-40 s (81-, 82-) while the console logged "Network error calling vana-action" every ~6 s (Riverpod retrying list_plans; connects fail at once, netcut.log); the failed text "Couldn't load earlier plans. Pull down to try again." showed by 20:22:45 (83-). New bug Finding.
- 20:22:46Z netcut off: the sheet stays on the failed text (84-). "Pull down to try again": two slow pulls on the sheet did nothing (85-, 86-); the sheet has no RefreshIndicator (previous_plans_sheet.dart). A fast swipe-down dismisses it. Reopen at 20:23:54 loaded at once (87-): recovery works by reopening only. Same Finding.
- Step 3: swipe-dismiss during load and reopen at once: loads normally, list matches SQL (88-). Pass.
- The sheet now lists be6abf2f (replaced, confirmed_at kept) as "Sep 20 – Sep 26 · 5 meals" with no badge, above the Confirmed ones: matches mp-677 (listed because once confirmed). How it is labelled is 17-004's (ticket 100).
- 20:24:43Z signed out test@test.com (Settings > Sign Out > Sign out). Throwaway: lee+e2e-89-20260925T2024Z@rightpathprogramming.com (CRED new).

## Throwaway account lee+e2e-89-20260925T2024Z@rightpathprogramming.com (user 3f5d28fe-25b3-487e-94c4-632ad6e42142)
- 20:24:43Z signed out test@test.com. Onboarding (Running; Eat healthier; No time to plan meals; no connections; Male; defaults) > Sign up with Email; code 397633 from Gmail at 20:27:15; verified. Paywall > Monthly > Test Store "Test valid purchase" at 20:28:03 (CRED state paid, monthly).
- 20:28Z Food > Plan with no plan: "No plan yet ..." + Add meal + New meal plan, NO ⋮ menu, so Previous plans (and Use this plan again) cannot be opened at all when this week has no plan with meals (plan_tab.dart shows PlanOverflowMenu only when plan has meals) (91-). 17-006 step 4 cannot run; new bug Finding with a product question (every new week starts like this).
- 19-003 retest: 20:28:48-20:29:48Z Shopping > New list x14 (14 empty hand-made lists, DB count 14). Previous lists: rows in a ScrollArea, slow swipe scrolled to the 14th, no overflow stripe, no OVERFLOW line in the console; tapped the last (oldest, 89eced2f) row: opened "Made Sep 25, 2026 · An earlier list" with Back to current list (93-, 94-, 95-). Pass. The last row's ⋮ sits under the dev wrench button (ticket 68/93's area).
- Meals tab detail has no Add to plan (Start cooking only), so plans for the throwaway were made "on another device": vana-action as the throwaway user (SCRATCH/act.mjs, password via CRED file):
  - 20:31:30Z pick_meals AD-015 + confirm_plan -> plan A 7fec0368 confirmed.
  - 20:31Z 17-006 step 1: Plan ⋮ > Previous plans with only the current plan: "No earlier plans yet" (96-). Pass.
  - 20:32:10Z new_plan + pick_meals + confirm_plan -> plan B e9e5e1f0 confirmed, A archived (confirmed_at kept).
  - Opened Previous plans in the app: A listed "Sep 20 – Sep 26 · 1 meal" (97-).
  - 20:32:40Z delete_plan A via API (is_deleted true). 20:32:42Z tapped A's row: "This plan is no longer here." (98-). 17-005 step 3 pass.
  - Back: the sheet still lists the deleted plan A (99-): stale row until reopened. New small bug Finding.
- 20:33:03Z the Test Store monthly lapsed (console: customer info active:false, expires_at 20:33:03 = purchase + 5 min) and the full-screen paywall replaced the app when I reopened the sheet (100-). Known: Test Store monthly is 5-minute periods and renewals land late (05-003, 07-003). Not re-filed. 20:33:44Z bought Annual (Test Store) to continue; CRED updated.
- 20:34:27Z Settings > Delete account > Delete (dialog says the store subscription keeps renewing): back on Welcome; auth.users, meal_plans, shopping_lists rows for 3f5d28fe = 0 (102-). CRED state deleted. SCRATCH/pw.txt removed.

## Console and edge logs (runbook step 7)
- console-redacted.log: 23 "[VANA_TRANSPORT] Network error calling vana-action" + SocketException lines = my netcut offline windows (19:55-19:56Z, 20:22-20:22:46Z). Known noise: caused on purpose.
- "[IS_ADMIN] is_admin read failed" at the offline start: Finding 89-010. "[SHOPPING_LIST] shopping list read failed": Finding 89-001.
- TrainingPeaks "Token expired. Please reconnect." and V.O2 "Please reconnect your V.O2 account" / INTEGRATION_SYNC failures on test@test.com: known noise, the dev account's stale connections (tickets 64, 76 cover the reconnect wording). "No intensity distribution hints", "No distance data ... using default": known noise, workout estimate defaults.
- edge-function_logs.txt: garmin-push "record failed ... reason=no_user_mapping" at 15:03-15:04 local: server pushes for unmapped Garmin users, not this app; known (18-012). No vana-action or kroger error lines; kroger calls 200.
- vana_calls in the run: 19:53:25 vana.opener.general conv 0aeabaa0 and 19:58:12 / 20:08:58 / 20:09:27 planning calls were ticket 88's (I made no chat before 20:13); 20:13:14 opener.general 29897d1c is my one chat spend; 20:15:17 vana.daynotes follows my plan edits; 20:15:40 vana.embed is the Save to mine.
- Test Store monthly lapsed 5 min after purchase: known (05-003, 07-003), not re-filed.

## Release
- 20:35:35Z log stream stopped (its PID only), app terminated, slot released. Console scanned: 18 token-bearing lines cut into console-redacted.log; rescan 0. Simulator left running for the lead.
