# 112 verdicts (run w34-20260925T2320Z, app e3367d2c)

| Finding | Verdict | Evidence | New Finding |
|---|---|---|---|
| 26-002 | pass | runs/112/09-recent-builtbowl-sheet.png, runs/112/db-run-rows.txt (c1dd9305 vs source ae7dba02) | |
| 26-003 | pass | runs/112/13-common-oatmeal-sheet.png, runs/112/15-recent-after-common.png, runs/112/db-run-rows.txt (70bb791d) | |
| 26-004 | pass | runs/112/db-run-rows.txt (70bb791d, 5543d340, 6ff23915, 3d90eedf: sodium_mg null; items carry no sodium key) | 112-014 (idea) |
| 26-005 | pass | runs/112/10-builtbowl-after-log-0s.png, runs/112/34-recent-after-recipe.png | |
| 26-006 | fail | runs/112/76-after-trash-tap.png, runs/112/22-double-tap-after.png, runs/112/16-recent-oatmeal-2x-sheet.png, runs/112/db-run-rows.txt (58ea9022, 5543d340, 5c0c96f4, d26a7902, 85c22213) | 112-005, 112-006, 112-003, 112-004 |
| 26-007 | fail | runs/112/26-common-egg-1.5-sheet.png, runs/112/29-search-egg.png, runs/112/db-run-rows.txt (83f837b4, f29ae721, 6ff23915, 2944415f, efdbe6cf) | 112-002 |
| 26-008 | pass | runs/112/32-recipe-chews-0.5-sheet.png, runs/112/35-recipes-chip-recovery.png, runs/112/77-search-lentil.png, runs/112/db-run-rows.txt (0ebf3fed) | 112-019 (step 4 not run) |
| 26-009 | fail | runs/112/38-recipe-soup-sheet-after-2min.png, runs/112/44-sheet-time-2-15.png, runs/112/49-yesterday-after-log.png, runs/112/57-offline-recent-relog-1s.png, runs/112/console-meal-uploads.txt | 112-001 |
| 09-005 | fail | runs/112/28-eggs-toast-second.png, runs/112/50-timeline-yesterday-bottom.png, runs/112/54-offline-apple-after-log-1s.png, runs/112/60-offline-balance-details.png, runs/112/db-run-rows.txt | 112-001 |

Why, one line each:
- 26-002: re-logging the two-item manual "W14-25 Built bowl" from Recent saved both items, the same totals, source manual and no saved_meal_id.
- 26-003: Common "Oatmeal + raisins" saved under the tile's name, and Recent then listed it by that name.
- 26-004: quick adds whose items have no sodium saved sodium_mg null, from Common and from a Recent re-log of a null-sodium log. A re-log of an old row that already stores 0.0 (from before fix 41) copies 0.0, which is faithful to the source.
- 26-005: a Recent re-log and a recipe log were both first in Recent at once, without leaving Log a Meal.
- 26-006: saved-meal log (source saved, saved_meal_id, last_used_at bumped), 2x/1.5x totals and the Describe re-log (no AI call, totals equal) pass; the trash deletes with no confirm or undo (112-005); a double tap logs once but opens the next tile's sheet (112-006); scaled portions read "2/2 cup dry" (112-003).
- 26-007: totals and sodium scale (71 → 106.5), but the saved portion loses its unit ("1.5 servings", not "1.5 large").
- 26-008: 0.5x and 2x recipe logs equal the tile's per-serving figure × servings, each chip lists exactly that type's recipes (matches `recipes.type`), search finds a recipe by name; the offline fresh-install step was not run (the app already held recipes).
- 26-009: eaten_at is the minute the sheet opened (6:24 PM sheet, Log it 23:25:06Z → eaten_at 23:24Z); a changed time (2:15 PM → 19:15Z) and yesterday 8:30 PM (log_date 09-24) land right; scrim tap and handle drag write nothing; offline logs show at once but never upload (112-001).
- 09-005: the same combo twice gives two rows; yesterday's time lands on yesterday; the offline log shows at once and the totals follow, but it does not upload when the network returns (112-001).
