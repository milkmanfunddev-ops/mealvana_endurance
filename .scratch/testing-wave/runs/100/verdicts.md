# Verdicts, ticket 100 (wave 39, run w39-20260926T1013Z, build 72d3723e)

| Check | Verdict | Evidence | New Finding |
|---|---|---|---|
| 32-007 (fix 94 item 3) | pass | Verify your email: 564564 typed, no tap, confirmed 10:17:40Z (15-after-sixth-digit.png, db-A-after-signup.txt). Enter Reset Code: 241867 typed, no tap, moved to Set New Password (25-after-reset-sixth-digit.png). | |
| 02-005 (fix 95 item 1) | pass | A deleted in app 10:22:00Z; RC GET customer 200 before (revenuecat-A-before-delete.json), 404 after and again ~2 min later (revenuecat-A-after-delete.json); DB rows 0 (db-A-after-delete.txt). | |
| 11-002 (fix 95 item 2) | pass | DEVCOACH30 then DEVCOACH18 (same coach): "You've already asked this coach to pair."; 1 code_redemptions row; coach_code stays DEVCOACH30 (db-A-after-devcoach18.txt, revenuecat-A-after-devcoach18.json, 20-after-devcoach18.png). Used the dev DEVCOACH pair, since `own` makes one code per account. | 100-008 (follow-up) |
| 19-002 (fix 96, 101) | pass | Plan list Delete: "Delete your plan's list?" + rebuild text (43-delete-plan-list-dialog.png); hand-made list keeps "Delete this list?" (47-handmade-delete-dialog.png); Keep it both times. Plan ⋮ Rebuild shopping list: same list 8719653f, 5 items, one list (db-plan-list-after-rebuild.txt). | 100-001 |
| 16-006 (fix 97.1) | pass | Meal plans rows "Sep 20 week · Confirmed/Archived", "No plan yet" (59-conversations-mealplans.png). | |
| 18-007 (fix 97.1) | pass | Older conversation f6a0f7fa opened headed "Sep 20 week · Archived" (60-old-conversation.png); no model call. | |
| 17-004 (fix 97.2) | pass | Sheet: never-confirmed drafts gone, earlier weeks' confirmed plans tagged "Confirmed", this week's rows newest first (48-previous-plans.png, db-test-plans-start.txt). No week held a confirmed plan plus others, so "confirmed first" was read from the code only. | 100-005 (idea) |
| 17-007 (fix 97.3) | pass | Back from Sep 6 – Sep 12 returns to the sheet (52-after-back-from-earlier.png). Scroll position not exercisable (5 rows fit). | 100-010 (follow-up) |
| 24-007 (fix 97.4) | pass | Review & Log shows the analyzed photo (71-review-and-log.png); logged c39bdef9 source photo (db-meal-log-24-007.txt). | 100-007 |
| 28-004 (fix 98) | pass | Search "00720579120045" → TEXAS RICE (62-search-cached-barcode.png); no-camera app message + "Search for the food instead" + Enter (64-scanner-no-camera.png); Enter barcode → Log Food TEXAS RICE (66-barcode-lookup-result.png). | 100-009 (follow-up) |
| 29-002 (fix 99, 101) | not run | Today's FinalSurge fetch: 21 workouts, all WorkoutCompleted false (console-redacted.log). Supporting only: Sep 25 swim stored completed/provider with actuals, card "verified · Final Surge · 1.0 mi · 34 min", no Undo, planned 2000 m kept (db-fs-completed-activities.txt, 33-sep25-workouts.png, 35-swim-detail.png). | 100-002, 100-003, 100-006, 100-011 |
| 94 item 1: Swap list length | pass | Swap from "Sweet rice cake with jam": 20 rows (swap-rows.txt, 55-swap-bottom.png). | |
| 94 item 2: plan reveal nudge | pass | After "I don't use training plan apps." the plan reveal has no Connect nudge (10-plan-reveal-bottom.png). | |
| 94 item 4: RevenueCat configure/logIn (console) | pass | "configured {store: test_store}" once at launch, "logged in" after each sign-in, no "configure failed", no skipped logIn (console-redacted.log). The failed-first-configure path cannot be forced on a simulator. | |
| 94 item 5: Settings tile text | pass | "Profile & Preferences / Edit your profile, units, and preferences" (73-settings.png); code reads both from content keys. | |
