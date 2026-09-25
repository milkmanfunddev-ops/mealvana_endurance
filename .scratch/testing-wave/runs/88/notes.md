# Ticket 88 notes (retest, wave 29)

- RUN: w29-20260925T1949Z. Slot claimed 19:49:48Z.
- App build: e3367d2c914d59f0fcde4b854ff4805416a6dc20 (installed on wave-pool-1, 2423A058-FAD7-4CA8-9C3C-D282BF6CDF84, data cleared).
- Worktree HEAD db48b247 (checked, mealplanning has no lib/ change past it).
- Run started 19:49Z; 89's flag deadline 21:49Z.

## Timeline
- 19:53:20Z tap Ask Vana (15-004 retest; today's general conversation d17ba332 context_day 2026-09-25 exists)
- 19:53:25Z Ask Vana created a NEW general conversation 0aeabaa0 (context_day 2026-09-25) with a paid Haiku opener, though d17ba332 (13:36Z, same day) exists: 15-004 fails -> Finding. The chat spend bought a real opener (vana_calls row 19:53:25Z).
- 19:53:40Z sheet chips: "Pick tonight's dinner", "Fuel tomorrow's long run" (07-ask-vana-sheet-8s.png).
- 19:54Z 15-008: full screen shows 3 chips (Finish the week's plan extra); stored askChoice has 3 options; sheet draws max 2 by design (vana_sheet_conversation.dart VanaSheetQuickReplies.max=2; docs/ssot/spec/design/components/vana-sheet.md line 63 'at most two chips'). Deliberate and documented -> pass.
- 19:54:45Z Conversations > Meal plans: EVERY row reads 'No plan yet' (f6a0f7fa holds confirmed be6abf2f, ebac747d archived 15b6b4f4...). Cause read: fetchConversations selects 'id, kind, title, summary, last_message_at, created_at' only, so VanaConversationSummary.plan is always null (ticket 97, 0f7890b4) -> Finding.
- 19:57:00Z 15-005 step 5: tap the ticked checkbox on 'Rice, black beans, guac' card in ebac747d (archived 15b6b4f4)
- 19:57:17Z 15-005 step 2: tap old-turn chip 'Different protein' in ebac747d (chat spend 2/5)
- 19:57:17Z the chip tap sent nothing (no vana_messages/vana_calls rows); the transcript jumped to the bottom. chat spend 2 bought nothing so far.
- known noise: TrainingPeaks token refresh 400 / V.O2 reconnect (dev test account's integrations expired; seen in every wave).
- 19:58:04Z 15-005 step 3: Edit on old 'That's my week' turn in ebac747d shows 'Editing — sending will rewind the conversation'; sending it unchanged
- 19:58:12Z Edit-send rewound ebac747d: old 'That's my week' + reply replaced by new pair (vana.chat.meal_planning $0.032); no plan row changed (db-04). chat spend 2 used here.
- 19:59:46Z 15-005 step 4: + on 'Rice, seitan & roasted broccoli' in 1a24f2bf (confirmed f2c0bc78, week of Sep 13)
- 20:01:14Z restored seitan bowl to 4 servings with − (f2c0bc78). Stepper edits go through RPC plan_set_servings, list 77fd387c NOT rebuilt -> Finding (mp-244).
- 20:01:58Z 18-009 step 1: Browse from d8efbdb3 (archived 54a02440): '+' on Injera
- 20:01:59Z the tap meant for Injera's + landed on 'Rice, black beans & roasted plantain': Recents re-ordered between 20:01:50 (Injera first) and the tap (plantain first). Browse's Add wrote it into ARCHIVED 54a02440 (now 2 meals, updated 20:02:00) and the card shows "In your plan" -> 18-009 fail (open question mp-683). Finding.
- be6abf2f changed at 19:57:12Z (Wholewheat pasta -> Quinoa, mixed veg & walnuts): ticket 89's 19-009, expected. rename_shopping_list/list_shopping_lists calls 19:59-20:00Z in edge logs are 89's 19-007.
- 15b6b4f4 (archived) updated_at moved to 19:58:11Z by my Edit-send turn in ebac747d; meals unchanged.
- 20:03:25Z 18-001: tap the ticked 'In your plan' on Sweet rice cake (173cebb2 has it x8)
- 20:03:58Z 18-001: tap on the ticked 'In your plan' did nothing (pass); the card body opened the detail, which still offers a plain '+ Add to plan'; tapping it showed "Added to your plan" but servings stayed 8 (db-07). Servings no longer double; the toast claims an add that did not happen -> Finding.
- 20:04Z flag watcher started (PID in SCRATCH/flagwatch.pid), polls every 60 s for testing-wave-w29-shared/89-be6abf2f-done.
- 20:04:33Z 18-008 step 3: fast double tap + on Toast with peanut butter & honey (draft 173cebb2, conv 0401b3d8)
- 20:05:32Z 09-006 step 1 (part): Review sheet of 173cebb2, Remove on Toast with peanut butter & honey
- 20:05:33Z Review Remove: server row gone (db-09) but the Review sheet kept showing Toast and "3 meals · 16 servings" 10 s later (48-...png) -> Finding. List 813df86f NOT rebuilt: Peanut butter / Honey still there, updated_at 20:04:35 (the pick). Remove goes local-first (plan_remove_meal RPC), no vana-action remove -> same mp-244 Finding as the stepper.
- delete_shopping_list 15:04:54 / 15:05:44 local in edge logs: ticket 89's 19-007.
- 20:08:12Z 14-001/14-002: Food > Plan > New meal plan (COST plan 1/3)
  (mis-tap: hit the Learn tab, New meal plan not yet tapped; no model call)
- 20:08:45Z Plan tab scrolled to the end: Add meal / New meal plan still half under the floating tab bar (57-food-plan-scrolled.png); unscrolled they are fully covered (53-...png) -> Finding.
- 20:08:56Z tap New meal plan (14-001/14-002)
- 20:08:58Z new conversation 449da56d (meal_planning); bar "Your plan · 0 meals" from the first frame (58-new-plan-1s.png); no meal_plans row changed, be6abf2f untouched (db-11 vs db-10) -> 14-001, 14-002 pass. Opener chips: Same as last time / Something new / Use what I have.
- 20:09:26Z 09-008: tap 'Something new' then Back at once
- 20:10:09Z 09-008: reopened 449da56d from Conversations: same conversation, the 'Something new' turn finished (20:09:31Z) with its cards, bar at 0 meals, no draft row, no stuck spinner -> pass. Header now reads 'No plan yet'.
- 20:10:22Z pick Egg & Veggie Scramble card checkbox in 449da56d (first pick -> new draft)
- 20:11:22Z picked Wholewheat pasta and Quinoa, mixed veg & walnuts into 8ebeb6da (conv 449da56d)
- 20:11:50Z chat meal sheet > Swap (swap_picker, 8 candidates) for Quinoa, mixed veg & walnuts in 8ebeb6da: every candidate carries kcal (61-001 ok here). The list offers the meal itself (Quinoa, mixed veg & walnuts) and the two other meals already in the draft as swaps -> Finding (bug, minor).
- 20:12:34Z Plan tab > More > Swap (swap_meal_screen, be6abf2f, read only, nothing picked): every candidate shows kcal (61-001). Two 'why' lines read 'his dinner base is…' (first letter lost): 6 active library meals' why starts 'his ' (db-14) -> Finding (data).
- 20:13Z 89's flag 89-be6abf2f-done present (watcher saw it at 20:07:24Z; watcher exited). Waited: no confirm/delete/be6abf2f write by me before this.
- 20:14:16Z 18-009 step 2: Browse from f6a0f7fa (confirmed be6abf2f), + on Wholewheat pasta (be6abf2f write, after 89's flag)
- 20:14:39Z relaunch with netcut (for 09-006 offline confirm, 14-009, 18-008 offline Add, 15-006 offline open)
- 20:15:10Z 14-009: netcut ON, tap New meal plan
- 20:15:16Z 14-009: offline New meal plan: console logs '[VANA_CHAT_CONTROLLER] Vana turn failed {kind: meal_planning, opener: true}' but the screen stays an empty chat with the bar at 0 meals and no error or retry for 25 s+ (77-...png). No conversation row written (db-17). -> fail, Finding.
- 20:16:25Z offline, in that dead new-plan chat: + > Browse meals does nothing (no screen, no message) (80/81-...png). Part of the 14-009 Finding.
- 20:16:43Z-20:17:13Z 15-006: Conversations > Meal plans offline: spinner for 35 s+, no rows, no error or retry; console repeats '[VANA_CHAT_REPOSITORY] fetchConversations(meal_planning) failed' (82-84-...png) -> Finding.
- 20:17:43Z 15-006: netcut ON, open Sep 22 6:59 AM (0b7df6f0, never opened on this install)
- 20:17:48Z offline open of 0b7df6f0 (11 messages, archived 6f365c30 with 2 meals): shows header 'New meal plan', no history, bar 'Your plan · 0 meals' — the empty new-chat state (85/86-...png) -> 15-006/16-008 fail, Finding.
- 20:18:22Z offline open of ebac747d (opened online earlier in this app session, before the netcut relaunch): same empty new-chat state (87-...png).
- 20:18:41Z back online 12 s: the empty chat does not recover (no retry); needs leaving and reopening.
- 20:19:15Z 18-008 step 1: netcut ON in Browse (0401b3d8), + on Oats, bread, orange & black coffee
- 20:19:21Z offline + in Browse: pink toast 'Something went wrong. Try again.', no tick, no row (db-18). Not the 'needs connection' warning 18-008 expected (netcut limit: connectivity check reads online, 20-006) -> Finding (minor).
- 20:19:44Z 18-008 step 7: Done with nothing added -> chat bar unchanged at 2 meals, no write
- 20:20:05Z 18-008 step 4: 'Browse meals' chip under the picker in 449da56d
- 20:20:22Z 18-008 step 6: content size accessibility-large: every Browse card shows the Flutter 'BOTTOM OVERFLOWED BY 7.0 / 37 PIXELS' stripe (93-...png); Done still reachable. Restored to 'large' 20:20:40Z -> Finding. Step 4 (Browse from the picker's chip) opened Browse with planned meals ticked, no chat turn (pass).
- 20:20:58Z 09-006 step 1: Review of 8ebeb6da, Remove Egg & Veggie Scramble
- 20:21:12Z 09-006 step 3a: netcut ON, tap Confirm plan (8ebeb6da)
- 20:21:13Z offline Confirm: vana-action network error in console, the sheet stays as it was with no message at 1 s and 5 s (96/97-...png); draft untouched (db-21) -> fail on 'says so', Finding.
- 20:21:41Z CONFIRM (be6abf2f/other plans archived by this): online double tap on Confirm plan for 8ebeb6da in conv 449da56d (16-011, 16-001, 16-002, 09-006 step 3b, 09-007)
- 20:21:43Z confirm_plan (one call for the double tap) confirmed 8ebeb6da (2 meals after the Review remove); archived be6abf2f, 173cebb2 and 89's 1192963b/9598807a; 173cebb2's list 813df86f deleted (ticket 101); list 2aeb8156 confirmed 20:21:43, 5 rows = the 2 meals' ingredients (cooked->dry for pasta/quinoa) (db-22). Router: /main?tab=food&food=shopping; Food opened on Shopping (101-confirm-10s.png). No "you're set" card, share or reminder chip at any point (98-101) -> ssot-conflict Finding (mp-235). The tab bar is shown collapsed to a Food bubble.
- 20:22:53Z 03-006: tapping a Plan tab row opens the meal's detail page (recipe, review, ingredients, Start cooking); its ⋮ has only Swap and Remove; no sheet with servings stepper or 'Ate it'. Timeline + Add Food has no plan tab either. logFromPlan has no caller in lib/ presentation. -> 03-006 fail, ssot-conflict Finding (mp-239 details 2 and 4).
- 20:25:05Z 14-007 step 2: Plan options > Start a new plan (chat spend 3/5)
- 20:25:08Z Start a new plan opened the same new-plan chat (header 'New meal plan', bar 0 meals, opener chips) -> 14-007 step 2 pass. (Wave chat counter jumped 2->4: ticket 89 spent one.)
- 20:25:41Z 18-008 step 8: + Wholewheat pasta in Browse of the brand-new conversation
- 20:26Z 14-008: with draft 666be167 (conv 9db7c080, 1 meal) in progress, the Plan tab shows only confirmed 8ebeb6da (109-...png); Previous plans lists one Sep 20 row '5 meals' with no state tag (be6abf2f, archived) and not the draft (110-...png); Conversations rows all read 'No plan yet'. No way from the Plan tab to the half-built draft -> fail, Finding (product question).
- 20:26:41Z DELETE plan (Plan tab menu) on confirmed 8ebeb6da, draft 666be167 half built (14-007 step 3)
- 20:26:43Z Delete: 8ebeb6da is_deleted=true (status stays 'confirmed'), draft 666be167 untouched; the deleted plan's list 2aeb8156 still exists with confirmed_at though the dialog says 'The meals and shopping list for this week go with it' (db-25). Plan tab then shows the draft (1 meal x4) with a 'Confirm plan · build shopping list' button (113-...png).
- 20:27:48Z Previous lists still shows the deleted plan's list (Week of Sep 20 · 5 items, 2aeb8156) (115-...png) -> Finding with the delete one. Shopping opened on the 9-19 hand list.
- 20:28:06Z CONFIRM #2: Plan tab 'Confirm plan · build shopping list' on draft 666be167 (conv 9db7c080) after the delete (14-007 step 3)
- 20:28:08Z confirm #2 confirmed 666be167 (list c667902d confirmed, 3 rows); deleted 8ebeb6da stays is_deleted, nothing else archived -> 14-007 step 3 pass. The Plan tab confirm stayed on Plan (no Shopping landing, no you're-set card) (117-...png).
- 20:28:39Z 14-006: New meal plan, wait for opener, Back with nothing picked (chat 5/5)
- 20:28:41Z 14-006: New meal plan + Back with nothing picked left conversation 7cc15497 ('This week's plan', 1 opener message, no plan) and a paid opener ($0.0025); no draft row; Plan tab unchanged (db-27). Across this run 3 such 'This week's plan' rows were added. -> Finding (product question: keep abandoned new-plan conversations?).
- 20:30:17Z 15-007: Meal plans list ends at 'Sep 8, 8:23 AM' = row 50 (fetchConversations limit 50, no paging); 80 meal_planning conversations exist back to 2026-06-12, 30 unreachable (db-28, 122-...png) -> Finding.
- 20:30:31Z 15-007 step 3: long-press on a row just opens it (Sep 8 conversation, header 'Sep 6 week · Confirmed'); no rename/delete on long-press or swipe.
- 20:31:27Z 15-006 step 4: open 9db7c080 (Sep 25 3:25), Back at 1 s, open ebac747d (2:58) at once
- 20:31:34Z quick switch showed ebac747d's own header, bar and note, nothing from 9db7c080 -> step 4 pass. 20:31:43Z step 2: kill the app with ebac747d open, relaunch
- 20:32:07Z after relaunch, Ask Vana (15-004 repeat on the same install after a kill; chat cap is 5/5, so any new opener here is over cap)
- 20:32:13Z Ask Vana after the kill reopened 0aeabaa0 (no new opener; same install keeps today's conversation). 29897d1c (general, 20:13:14Z) is ticket 89's: my console pushed /vana?c=0aeabaa0 at that time.
- 20:32:46Z 15-006 step 2: after kill+relaunch ebac747d opened with its history (Today divider, rewound turn) and the archived bar -> pass. Step 3 (count 15 turns of f6a0f7fa) not run.
- 20:33:08Z 12-009: relaunch with netcut to send offline from the Ask Vana sheet
- 20:33:44Z 12-009: sheet closed and reopened (same conversation, chips), then netcut ON and sent 'is rice ok tonight'
- 20:33:45Z 12-009 offline send from the sheet: shows 'You're offline — Vana will reply when you're back.' + Retry, but the athlete's sent text 'is rice ok tonight' is not shown anywhere (no bubble, composer empty) and the chips are gone (130/131-...png) -> Finding (the sent message is invisible; 'never loses a sent message'). Retry not tapped (chat cap 5/5 used). App terminated while still offline so the queued turn does not spend over the cap.

## Writes to the shared account (conversation -> plan)
- ebac747d (archived 15b6b4f4): Edit-send rewound one turn 19:58:12Z; no plan change.
- 1a24f2bf (confirmed f2c0bc78, week of Sep 13): servings 4->5->4 on the seitan bowl 19:59:45Z / 20:01:11Z.
- d8efbdb3 (archived 54a02440): Browse + added Rice, black beans & roasted plantain x4 at 20:02:00Z.
- 0401b3d8 (draft 173cebb2, list 813df86f): Browse + Toast x4 20:04:34Z, Review Remove 20:05:33Z; detail Add (no change) 20:03:58Z.
- 449da56d (NEW, COST plan 1): draft 8ebeb6da, picks 20:10:24Z–20:11:18Z, Review Remove Egg 20:20:59Z, CONFIRM 20:21:43Z (list 2aeb8156).
- f6a0f7fa (be6abf2f, after 89's flag): Browse + Wholewheat pasta x4 at 20:14:18Z (be6abf2f write, list 2a4cbd64 rebuilt).
- 9db7c080 (NEW via Start a new plan): draft 666be167, Browse + 20:25:43Z; DELETE of 8ebeb6da 20:26:43Z; CONFIRM #2 of 666be167 20:28:08Z (list c667902d).
- 7cc15497 (NEW, abandoned): opener only, 20:28:40Z.
- 0aeabaa0 (general, new): opener 19:53:25Z.

## be6abf2f / confirm / delete times (UTC)
- 89's flag seen 20:07:24Z (watcher); all of these came after it:
- 20:14:18Z Browse + into be6abf2f (f6a0f7fa).
- 20:21:43Z CONFIRM 8ebeb6da (archived be6abf2f, 173cebb2, 1192963b; 813df86f deleted).
- 20:26:43Z DELETE 8ebeb6da (Plan tab menu).
- 20:28:08Z CONFIRM 666be167 (Plan tab button).

## Cost
- plan 1/3 (mine); chat 5/5 (4 mine: 19:53 Ask Vana opener [bought a real opener], 19:57 old-chip/Edit turn [the chip bought nothing, the Edit-send used it], 20:25 Start a new plan opener, 20:28 14-006 opener; 1 by ticket 89). No logging spend.
- The 20:08:58Z New meal plan opener and the 20:09:27Z "Something new" turn ran under the plan spend.

## End
- 20:34:20Z netcut off; app terminated; log stream stopped; flag watcher had exited on its own at 20:07:24Z.
- 20:38:55Z slot released. No account created, so nothing to delete (step 9.1 n/a). Simulator left running for the lead.
