# Ticket 88 verdicts (retest, wave 29, RUN w29-20260925T1949Z, app build e3367d2c)

Account test@test.com on dev. Ticket 89 ran on the same account; its rows are treated as expected.

## Retests

| id | verdict | evidence | new Finding |
|---|---|---|---|
| 14-001 | pass | runs/88/db-10-before-new-plan.txt, runs/88/db-11-after-new-plan-tap.txt (New meal plan wrote only conversation 449da56d; be6abf2f untouched), runs/88/58-new-plan-1s.png | none |
| 14-002 | pass | runs/88/58-new-plan-1s.png ("Your plan · 0 meals" from the first frame, before the opener) | none |
| 15-001 | pass | runs/88/12-ebac747d-5s.png, runs/88/13-ebac747d-plan-bar-expanded.png (note, Use this plan instead, no -/+, ×, Review or Confirm) | none (a pick there still writes the archived plan: 88-005) |
| 15-002 | pass | runs/88/15-ebac747d-top-15-002.png (question once, as the chip prompt) | none |
| 15-003 | pass | runs/88/16-ebac747d-injera-card.png, runs/88/17-ebac747d-rice-guac-card.png (archived plan), runs/88/26-1a24f2bf-open.png (confirmed plan), runs/88/29-d8efbdb3-open.png | none |
| 16-001 | pass | runs/88/db-19-before-confirm.txt, runs/88/db-22-after-confirm.txt (8ebeb6da confirmed from its own conversation while be6abf2f was confirmed; be6abf2f, 173cebb2 and 89's drafts archived) | none |
| 16-002 | pass | runs/88/101-confirm-10s.png, runs/88/console-redacted.log (`/main?tab=food&food=shopping`, Food opened on Shopping) | 88-016 (no "you're set" card; Plan-tab confirm stays on Plan) |
| 16-004 | pass | runs/88/65-16-004-review-1-meal.png ("1 meal · 1 serving") | none |
| 16-005 | pass | runs/88/25-f6a0f7fa-open.png ("Sep 20 week · Confirmed"), runs/88/12-ebac747d-5s.png ("Sep 20 week · Archived") | none (the list rows are wrong: 88-002) |
| 18-001 | pass | runs/88/38-18-001-tap-on-ticked.png, runs/88/db-07-18-001-173cebb2.txt (tick tap does nothing; detail Add leaves servings at 8) | 88-007 (detail still says "Added to your plan") |
| 18-003 | pass | runs/88/37-18-003-browse-recipes.png (both planned meals "In your plan" on reopen) | none |
| 29-001 | pass | runs/88/03-food-plan.png, runs/88/db-01-29-001-plan-meals.txt (all four meals with kcal/macros; 0 blank active library meals) | none |
| 61-001 | pass | runs/88/70-61-001-swap-list.png, runs/88/72-61-001-swap-meal-screen.png, runs/88/db-01-29-001-plan-meals.txt (every candidate and placed meal has numbers; dev has no blank meal, so the refusal path itself was not reachable) | none (88-009, 88-010 seen on the same screens) |

## Follow-up tests

| id | verdict | evidence | new Finding |
|---|---|---|---|
| 16-011 | pass | runs/88/db-22-after-confirm.txt (only 8ebeb6da confirmed for 2026-09-20; old confirmed be6abf2f and draft 173cebb2 archived; list 2aeb8156 confirmed, 5 rows = its 2 meals' ingredients; 813df86f deleted), runs/88/101-confirm-10s.png | 88-016 |
| 09-006 | fail | runs/88/47-09-006-review-after-remove.png, runs/88/db-09-09-006-after-remove.txt, runs/88/49-09-006-keep-planning.png, runs/88/96-09-006-offline-confirm-1s.png, runs/88/edge-04-confirm.txt (double tap = one confirm_plan) | 88-004 (removed meal stays shown), 88-003 (list not rebuilt on remove), 88-015 (offline Confirm silent) |
| 18-008 | fail | runs/88/43-18-008-double-tap.png + runs/88/edge-02-18-008-double-tap.txt (one pick_meals), runs/88/44-18-008-search-zzzz.png, runs/88/92-18-008-browse-from-chip.png, runs/88/91-18-008-done-nothing-added.png, runs/88/db-23-18-008-new-conv-add.txt, runs/88/89-18-008-offline-add-1s.png, runs/88/93-18-008-browse-large-text.png | 88-013 (offline Add wording), 88-014 (large-text overflow); step 2 not run (88-024) |
| 18-009 | fail | runs/88/db-06-18-009-after-browse-add-d8efbdb3.txt (step 1 wrote archived 54a02440), runs/88/db-16-18-009-be6abf2f.txt (step 2: confirmed plan edited, list rebuilt 15->17, right) | 88-005 |
| 03-006 | fail | runs/88/103-03-006-tile-sheet.png, runs/88/71-plan-meal-more-menu.png, runs/88/104-03-006-add-food.png | 88-017 |
| 09-007 | pass | runs/88/101-confirm-10s.png, runs/88/console-redacted.log (router `food=shopping` and the Shopping sub-tab agree) | none |
| 14-006 | fail | runs/88/db-27-14-006.txt, runs/88/119-14-006-after-back.png (one repeat, chat cap) | 88-020 |
| 14-007 | pass | runs/88/106-14-007-start-new-plan-2s.png, runs/88/107-14-007-start-new-plan-9s.png (Start a new plan = New meal plan), runs/88/db-25-after-delete.txt, runs/88/db-26-after-confirm-2.txt (delete left the draft alone; confirming it archived nothing unexpected) | 88-019 (deleted plan's list kept) |
| 14-008 | fail | runs/88/109-14-008-plan-tab-with-draft.png, runs/88/110-14-008-previous-plans.png | 88-018 |
| 14-009 | fail | runs/88/77-14-009-offline-25s.png, runs/88/db-17-14-009-offline.txt | 88-011 |
| 09-008 | pass | runs/88/db-12-09-008.txt, runs/88/63-09-008-reopened.png (turn finished on the server; reopening showed the same conversation, no second draft, no spinner; one plan spend) | none |
| 16-010 | pass | runs/88/29-d8efbdb3-open.png (reads as replaced, no Review/Confirm, planned card ticked) | none for the display; a pick there writes the archived plan: 88-005 |
| 15-005 | pass | runs/88/db-04-15-005-after-edit.txt (old chip sent nothing; Edit rewound the turn and changed no plan), runs/88/13-ebac747d-plan-bar-expanded.png (no -/+ on archived), runs/88/db-05-15-005-f2c0bc78.txt (confirmed old-week plan editable) | 88-003 (that stepper edit did not rebuild the list) |
| 15-006 | fail | runs/88/84-15-006-conversations-offline-35s.png, runs/88/86-15-006-offline-open-unopened-15s.png (step 1); runs/88/128-15-006-after-kill-ebac747d.png (step 2 pass); runs/88/126-15-006-quick-switch-5s.png (step 4 pass) | 88-012; step 3 not run (88-024) |
| 16-008 | fail | runs/88/86-15-006-offline-open-unopened-15s.png, runs/88/88-ebac747d-after-back-online-12s.png (failed fetch shows the empty new-chat state, no retry) | 88-012; slow-network leg not run (88-024) |
| 15-007 | fail | runs/88/122-15-007-list-very-bottom.png, runs/88/db-28-15-007-counts.txt, runs/88/123-15-007-long-press-row.png | 88-021 (50-row cap), 88-002 (rows all "No plan yet"); empty-account step not run (88-024) |
| 18-011 | pass | runs/88/08-general-chat-full.png (general chat has no plus), runs/88/46-review-sheet-173cebb2.png (Confirm offered on a draft while be6abf2f was confirmed; confirming a draft is scoped since 16-001), Ask Vana FAB tapped at 362,816 every time | steps 1 (meal question), 3, 4 not run: 88-024 |
| 12-009 | fail | runs/88/08-general-chat-full.png (expand), runs/88/129-12-009-sheet-reopened.png (close/reopen keeps the conversation), runs/88/131-12-009-offline-send-13s.png | 88-022; streaming, chip, Retry and pro_required legs not run (88-024) |
| 15-004 | fail | runs/88/db-02-15-004-general.txt, runs/88/07-ask-vana-sheet-8s.png, runs/88/db-29-15-004-after-relaunch.txt | 88-001 |
| 15-008 | pass | runs/88/07-ask-vana-sheet-8s.png, runs/88/08-general-chat-full.png, runs/88/db-03-15-008-opener-0aeabaa0.txt (the sheet draws at most two quick replies by design: VanaSheetQuickReplies.max = 2, docs/ssot/spec/design/components/vana-sheet.md "at most two chips") | none |

Counts: retests 13 pass, 0 fail, 0 not run. Follow-ups 9 pass, 11 fail, 0 not run (partly-run legs listed in 88-024).
