# 115 verdicts (run w32-20260925T2219Z, app e3367d2c)

| Finding | Verdict | Evidence | New Finding |
|---|---|---|---|
| 26-001 | pass | runs/115/04-recent-first-open-0s.png, runs/115/05-recent-first-open-4s.png, runs/115/notes.md (meal_logs_last_sync at sign-in 22:21:43Z) | |
| 19-004 | pass | runs/115/06-food-plan-0s.png (loading card, no "No plan yet"), runs/115/07-food-plan-1s.png, runs/115/09-food-plan-6s.png | |
| 20-003 | pass | runs/115/16-cold-shopping-1s.png (spinner), runs/115/17-cold-shopping-4s.png, runs/115/18-cold-shopping-10s.png (rows at the same y), runs/115/19-unticked.png | 115-001 (separate: "An earlier list" after a tick) |
| 10-001 | pass | runs/115/36-B-login-lapsed-paywall.png, runs/115/38-B-after-resub-4s.png, runs/115/40-B-timeline-meal-no-food.png, runs/115/41-B-timeline-after-pull.png, runs/115/42-B-meals-filter.png, runs/115/db-B-meal-log.txt, runs/115/revenuecat-B-lapsed.json | |
| 04-001 | pass | runs/115/console-redacted.log (`paywall_delete_account_tapped {}` 17:27:46 local), runs/115/21-paywall-menu.png, runs/115/db-A-after-delete.txt | |
| 16-003 | pass | runs/115/32-confirm-3.png (spinner), runs/115/32-confirm-5.png (list), runs/115/34-shopping-retap-0s.png, runs/115/db-after-confirm.txt | |

Why, one line each:
- 26-001: on the cleared app's first sign-in, Recent listed saved meals and recent logs before Food was ever opened.
- 19-004: tapping Food at once showed a loading card, then the confirmed plan within 1 s; "No plan yet" never showed.
- 20-003: after a cold restart the tab showed a spinner, then the full list with the Kroger button; the rows did not move between 4 s and 10 s.
- 10-001: a Lapsed account on a cleared install saw its pre-lapse meal on today's timeline 4 s after resubscribing, before Food was opened; pull-down and the Meals filter kept it.
- 04-001: the paywall delete tracks `paywall_delete_account_tapped`; the Settings delete still tracks `settings_delete_account_tapped`.
- 16-003: confirming draft 9be88811 from the Review sheet (22:33:48Z) landed on Shopping with a spinner, then the 5-item list; "No shopping list" never showed. Path: deep link to conversation 7cc15497 > plan bar Review plan > Confirm plan.
