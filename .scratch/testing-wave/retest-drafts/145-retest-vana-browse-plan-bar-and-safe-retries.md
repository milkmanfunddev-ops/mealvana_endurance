# 145: Retest: Vana's Browse picks, the plan bar, safe retries and the Plan tab after sign-in

**Status:** ready-for-agent
**Blocked by:** 134.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 134 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 134's fixes, checks IMPROVEMENTS #82 (the server ignores a repeated Vana write) on the device, and runs the folded follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`. Ticket 134 was still building when this was written, so the lead checks its final notes (table name, what the Plan tab offers) before the prompt.

**Accounts and start state:**
- Part 1 (checks 1-2): **app data NOT cleared.** The lead skips `clear-app.sh` for this ticket (it tests leftover data, like 120's run) and says so in the prompt. The dev simulator copy holds test@test.com's older local rows. Log In as test@test.com.
- Part 2 (checks 3-11): account A, new, `lee+e2e-145-<UTC>` (`CRED new`). Buy Annual on the onboarding paywall (Test Store, 1-hour periods), so no lapse interrupts the run. Before check 3, Log a Meal > Manual three meals (no AI) so check 11's opener has logged carbs to compare.
- Supabase host for the slow proxy: `vlmtsdzpnjnavdgytcmi.supabase.co`.

**Shared account:** Part 1 reads test@test.com's plans and makes no writes to them. Other runs in the wave may write ticks or logs on test@test.com. Those rows are expected.

**COST:** `chat` ×2 (the general Ask Vana opener in check 3; a new planning conversation's opener in check 4, if it makes a call). No `plan` spend: picks come from Browse, which makes no model call. Confirm (check 9) runs `vana-day-notes`, which is not a capped kind. Note its `vana_calls` row. Spend before any tap that can open Vana (RUNBOOK step 5).

## Checks

1. **After Log In the Plan tab waits for the first pull (120-001).** Before launch, read the local `meal_plans` / `plan_meals` for test@test.com's current week from the app's sqlite, and SELECT the same on dev. Note any plan whose local meals differ from dev. Record at 10 fps, Log In, open Food > Plan at once. *Pass:* the first frames show loading, then dev's plan. The stale local plan never shows. If local and dev already agree, the check is not run ("no stale state on this copy"), not passed. *Verify:* recording, both reads.
2. **A pull never archives a newer draft (120-002).** After the first sync, compare the week's local statuses with dev. *Pass:* every plan has dev's status, and a draft newer than the confirm stays a draft locally. If dev has no newer draft that week, re-run this in Part 2 after check 9: confirm plan P1, make draft P2 by a Browse pick, sign out, Log In, compare. *Verify:* local sqlite vs dev SELECT (id, status, updated_at).
3. **A Browse pick from a general chat goes into the Plan tab's plan (118-004).** Account A: `COST spend WAVE chat 145`, Ask Vana (general). Open Browse for it (`xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///vana/browse?c=<general id>"`). Tap + on one meal, then + on a second, then tap the second again. Tap Done. *Pass:* the Plan tab's plan holds the first meal only, and there is no conversation-scoped draft (SELECT `meal_plans` for A: conversation id, status). The chat's plan bar shows the pick with Remove, and Remove takes it out of the plan. *Verify:* screen, DB SELECT on `meal_plans` / `plan_meals`.
4. **A planning chat keeps its picks in its own draft, and the plan bar shows them after Done (110-009).** `COST spend WAVE chat 145` if the new plan's opener calls the model (note in notes if it bought nothing). Food > Plan > New meal plan, then Browse for that conversation, + one meal, Done. *Pass:* the conversation's plan bar reads 1 meal, not "No plan yet" / "0 meals", and the draft row holds the pick. *Verify:* screen, SELECT.
5. **A general conversation by link opens as general; odd ids (115-006).** `openurl …/vana?c=<general id>` with no mode: the header is not "New meal plan". Then `?c=` with (a) a deleted conversation, (b) an archived plan's conversation, (c) another account's conversation id (test@test.com's, SELECT one), (d) a random uuid. *Pass:* (a), (c) and (d) show a clear not-found state with no model call. (b) opens read-only or says archived. Nothing is written. *Verify:* screen, `vana_calls` and `vana_messages` SELECT for A in the run's minutes.
6. **Browse filters, empty result, Back vs Done (118-014).** In the planning conversation's Browse, search a word, add the Dinner and Recipes filters, pick a combination with no results, then pick a meal and leave with Back. Reopen Browse. *Pass:* the empty state says so. Back keeps the pick the same way Done does, and the draft agrees with the screen. *Verify:* screen, SELECT.
7. **A repeated `pick_meals` writes once (#82).** `netcut.sh slow 25000 --only vlmtsdzpnjnavdgytcmi.supabase.co --relaunch UDID` (longer than the 20 s transport timeout). In Browse tap + on a new meal. The screen should report the network. Tap it again (the retry). `netcut.sh off`. *Pass:* one `plan_meals` row for that meal. The request-id table 134 added (name from its migration) holds one row for the first tap's id. The second request was answered from it or refused as in progress. *Verify:* DB SELECT, `vana-action` edge logs, `SCRATCH/slowproxy.log`.
8. **A repeated `log_from_plan` and `save_meal` write once (#82).** Same slow proxy. (a) Plan tab > a row > Ate it, then retry after the timeout: one `meal_logs` row. (b) A meal detail's heart (save), then retry: one saved-meal row, and the heart shows saved. *Pass:* one row each. *Verify:* SELECT `meal_logs` (id, name, created_at) and the saved-meal table for A, edge logs.
9. **Confirm, and the day note's wording (116-012, 115-005).** Confirm the planning draft from its Review sheet. Time the Plan tab's Vana card from the confirm to the day note (115-005: it read "Looking at your day…" 20 s or more). *Pass:* the note writes carbs as "835 g of carbs" and has no `NNNC` or `NNNg carbs` shorthand. A wait over 20 s is written down as a new Finding with the time. Also SELECT the day notes of test@test.com's plans 666be167 and 8ebeb6da (read only) and note whether they still say "835C" (they keep it until regenerated). *Verify:* screen, `meal_plans` day-note column SELECT, `vana_calls`.
10. **The Food tab offline does not hammer vana-action (117-009).** `netcut.sh on --relaunch`, open Food > Plan, stay 40 s, then visit Events and Learn. *Pass or record:* count `[VANA_TRANSPORT] Network error` lines. If the reads still retry about eleven times and keep going after leaving Food, file a new bug Finding with the count. *Verify:* console-redacted.log.
11. **Ask Vana reads the day's numbers right (118-008).** Read check 3's opener (the spend already bought it). *Pass:* it states logged carbs against today's target correctly, over or under, with "g of carbs", and never says "tracking well toward 419" after more was logged. *Verify:* screenshot, `vana_messages` text, `daily_macro_targets` and the day's `meal_logs` sums by SELECT.

**Findings:** 120-001, 120-002, 118-004, 110-009, 116-012, 118-008; IMPROVEMENTS #82 (no Finding file; the verdict row says `#82`); follow-ups 115-005, 115-006, 117-009, 118-014.

**Decisions:** Lee's rulings in `triage-20260926.md` (#82, 118-004, 116-012).

**Touches:** test@test.com (read only, reads only its own leftover rows). Account A: conversations, plans, picks, one confirm (with its list and day note), 1-2 meal logs, one saved meal, the request-id rows. A is deleted at the end.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id (plus `#82`), with evidence under `runs/145/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Account A is deleted through the app (runbook step 9), and the slow proxy is stopped by its PID.

Next: /implement-lee testing-wave
