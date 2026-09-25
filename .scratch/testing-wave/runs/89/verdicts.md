# Ticket 89 verdicts (run w29-20260925T1950Z, build e3367d2c)

| Finding | Verdict | Evidence (under runs/89/) | New Finding |
|---|---|---|---|
| 17-001 | pass | 36-prev-plans-1s.png, db-03-prev-plans-vs-sql.txt (sheet rows = every plan list_plans must list, minus the Plan tab's; the Aug 23 plans are never-confirmed, left out by mp-677, known) | |
| 17-002 | pass | db-03-prev-plans-vs-sql.txt (drafts fc9687ff, 968c5a59, 173cebb2 not listed), 36-prev-plans-1s.png | |
| 17-003 | pass | 35-prev-plans-immediate.png, 36-prev-plans-1s.png, edge-function_logs.txt (list_plans 133 ms, was 8062 ms); Back returns to the loaded sheet and a row tapped ~9 s later opened (39-) | 89-005 (a separate hang on the earlier plan view's own read) |
| 18-004 | pass | 50-18-004-meals-tab-search-salmon.png, 59-18-004-browse-search-salmon.png ("Nothing found"), 51-18-004-meals-tab-search-spinach.png, 61-18-004-browse-filter-dinner.png (ingredient subtitles), db-05-salmon-library.txt | 89-003 (Swap screen still shows research notes), 89-008 |
| 19-003 | pass | 93-19-003-14-lists-top.png, 94-19-003-14-lists-scrolled.png, 95-19-003-last-list-opened.png (14 lists on the throwaway, scrolls to the last, no overflow) | |
| 73-001 | pass | db-04-after-use-again.txt (first copy 9598807a archived when 1192963b was made; one live conversation-less draft), 43-, 44-, 46- | 89-006 (the copy itself cannot be reached after Back) |
| 17-005 (follow-up) | pass | 41-17-005-tap-meal-row.png (step 1: meal detail), 40-earlier-plan-sep13-retry.png (step 5: names wrap), 98-17-005-deleted-plan-opened.png (step 3: "This plan is no longer here."); step 2 inconclusive (servings = servings_left on every row); step 4 not runnable (plans with days are never-confirmed, not listed) | 89-013, 89-016 |
| 17-006 (follow-up) | fail | 96-17-006-empty-sheet.png (step 1 pass), 81-/83-/86-/87- (step 2: 35-40 s spinner offline, pull-down does nothing), 88-17-006-dismiss-during-load-reopen.png (step 3 pass), 91-throwaway-plan-tab.png (step 4: no menu without a plan) | 89-011, 89-012 |
| 19-009 (follow-up) | pass | 12-19-009-shopping-after-swap.png, db-01-after-swap.txt (the first edit made list 10579cbf for be6abf2f, 15 rows, mirror 15; the tab opened it); step 3: 03-/19-009-share-text-no-plan-list.txt; step 4: 07-, 08-; step 2 (Vana Add back) not run, list already rebuilt | 89-001, 89-002, 89-004 |
| 18-010 (follow-up) | fail | 63-/66-/67- (heart), 68- (thumbs), 71-/73- (Team review), 74- (Start cooking), 75- (Add photo), 76-78- (original recipe), 79- (Swaps), 80- (Back keeps the filter, nothing ticked; draft 173cebb2 unchanged) | 89-009, 89-010, 89-014 |
| 19-007 (follow-up) | pass | 16-/17- (empty name), 18-/19- (long name), 20- (duplicate name), 21-/22- (Back to current list), 23- (Keep it), 24-26- (delete from the sheet), 28- + edge-function_logs.txt (double Delete: one call), 27- (Open now row), 30-/31- (delete the confirmed plan's list from the sheet); offline delete not run (20-004) | 89-015, 89-017 |

Counts: 11 rows; 9 pass, 2 fail, 0 not run.
