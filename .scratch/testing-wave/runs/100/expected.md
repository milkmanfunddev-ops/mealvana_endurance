# Expected records, ticket 100 (wave 39, run w39-20260926T1013Z)

Judged against the fix tickets' own words (94-99, 101).

## 32-007 (fix 94 item 3): signup account A
- Verify your email: typing the sixth digit submits by itself (no tap on Verify). Same on Enter Reset Code.
- DB after signup: `auth.users` row for A, confirmed; `public.users` row. No entitlement row before purchase.
- RevenueCat: a customer with id = A's user id once the app logs in.

## 94 item 2: plan reveal after "I don't use training plan apps"
- No "Connect now" nudge on the plan reveal.

## 11-002 (fix 95 item 2): account A (or B), two coach codes of one coach
- First coach code: success "Your coach will see your request to pair"; 1 `code_redemptions` row; 1 pairing pending; RC `coach_code` = first code.
- Second code of the same coach: "You've already asked this coach to pair"; still 1 `code_redemptions` row (no new row); RC `coach_code` still the first code.

## 02-005 (fix 95 item 1): delete the new account(s) in the app
- After delete: no auth user, no public.users row; RevenueCat `GET /customers/<user id>` answers 404 (customer deleted).

## test@test.com
- 19-002 (fix 96): Delete on the confirmed plan's list shows "Delete your plan's list?" / "This is the list for this week's plan. You can rebuild it any time from the Plan tab." A hand-made list keeps "Delete this list?". Plan tab ⋮ offers "Rebuild shopping list" on a confirmed plan; Rebuild leaves exactly one list for the plan (DB: count of shopping_lists where plan_id = confirmed plan = 1). Not confirmed on the dialog (prompt).
- 16-006 / 18-007 (fix 97.1): Conversations > Meal plans rows titled "<Mon d> week · <State>" or "No plan yet"; an older opened conversation headed by that title, not "New meal plan".
- 17-004 (97.2): Previous plans: per week, confirmed plan first with a "Confirmed" tag, then others newest first.
- 17-007 (97.3): Back from an earlier plan returns to the Previous plans sheet at its scroll position.
- 24-007 (97.4): Review & Log shows a thumbnail of the analyzed photo (1 AI logging call, COST spent first).
- 28-004 (98): scanner without camera shows an app-written message with a link to search, and "Enter barcode"; typing a cached barcode (00720579120045) in food search finds the product; Enter barcode reaches the same confirm screen.
- 29-002 (99, 101): a FinalSurge workout with WorkoutCompleted true is stored completed (status completed, completed_at set, actual_* set, completion_type 'provider'); planned fields keep planned values; card shows done with measured values and offers no Undo. Not run when today's FS feed has no completed workout.
- 94 item 1: the Swap screen shows a full list (not a short one after blank-number meals are dropped).
- 94 item 4: console on launch shows no RevenueCat logIn skipped after a failed first configure (read the console).
- 94 item 5: Settings tile reads "Profile & Preferences" from the content system (text unchanged on screen).
