# 146: Retest: Previous plans, deleting a replaced plan, and a plan's list on an account of its own

**Status:** ready-for-agent
**Blocked by:** 133, 134.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** Lee's 100-005 ruling ("the next retest checks that deleting an older, replaced plan from Previous plans works"), ticket 133's draft-list rule, and the 2026-09-26 triage.

**What to build:** A retest run on the testing build (`app-build.json`). It builds two plans for one week on a fresh account without generating any plan (Browse picks only), confirms one, then replaces it. It then checks Previous plans, Lee's delete check and the shopping legs of 110-013 that could not run on the shared account. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** account B, new, `lee+e2e-146-<UTC>` (`CRED new`). Buy Annual on the onboarding paywall (Test Store). App data cleared. Plan P1 comes from Browse picks: two meals that share an ingredient (SELECT the library first, e.g. two meals with avocado or rice, and name them in `RUNS/expected.md`). Build it from the Plan tab's Browse if 134 offers it there, or from a general Ask Vana conversation (134 puts those picks in the Plan tab's plan).

**Shared account:** none. Lee's check is kept off test@test.com so the shared account's history is not deleted.

**COST:** `chat` ×1 only if Browse is reached through Ask Vana (spend before the tap). No `plan` spend. Each confirm runs `vana-day-notes` (not a capped kind; note the `vana_calls` rows).

## Checks

1. **A draft has no shopping list (110-012).** With P1 still a draft: Food > Shopping. SELECT `shopping_lists` for B. *Pass:* no list row for the draft, and the Shopping tab does not show a list for it. Plan ⋮ offers no working Rebuild shopping list (hidden, or a tap writes nothing). *Verify:* screen, DB SELECT.
2. **Confirm builds the list (mp-244, 110-012).** Confirm P1 from its Review sheet. *Pass:* one list for P1 with `confirmed_at` set, whose items match the two meals. Shopping opens it with the confirmed label. *Verify:* SELECT `shopping_lists` / `shopping_items`, screen.
3. **A line used by two meals (110-013 step 1).** On the shared ingredient's row, tap its meal count. *Pass:* it lists both meals, and each opens its recipe. *Verify:* screen.
4. **Units switch (110-013 step 2).** Settings > units metric, back to Shopping and Share. Then back to imperial. *Pass:* the list and the share text switch units both ways. *Verify:* screenshots, share text in notes.
5. **Editing the confirmed plan keeps ticks (110-013 step 3).** Tick two rows. Remove one meal from P1 and change the other's servings. *Pass:* the list rebuilds, the ticked lines still present stay ticked, and the removed meal's lines go. *Verify:* screen, `shopping_items` SELECT before and after.
6. **Replace P1 with P2 (mp-241).** Start a new draft P2 for the same week with one Browse pick, and confirm it. *Pass:* P1 is archived, P2 confirmed, and the Shopping tab shows P2's list. *Verify:* SELECT `meal_plans` (id, status, confirmed_at), screen.
7. **Previous plans rows for this week (120-008).** Plan ⋮ > Previous plans. Note each row for the week and match it to P1 or P2 by SELECT. Open each. *Pass:* opening a row shows that plan and does not change the Plan tab's plan (SELECT after). An unlabelled look-alike row is expected (100-005 is won't-fix). *Verify:* screen, SELECT.
8. **Lee's check: delete the older, replaced plan (100-005 ruling).** In Previous plans open P1 (replaced) > Delete plan, and confirm. *Pass:* P1's row leaves Previous plans at once and stays gone after a cold restart. `meal_plans` P1 is deleted (is_deleted true or row gone), and P1's list no longer shows in Previous lists. P2, its list and the Plan tab are untouched. *Verify:* screen, SELECT `meal_plans` and `shopping_lists` for B before and after, console free of errors.
9. **Back from an earlier plan keeps the sheet's scroll (100-010, rewritten).** As written it needed more plans than the sheet shows, and test@test.com's five rows fit (proved in wave 39). Rewritten: set the text size to the cap with the dev testing tools (the top-edge dev pill, ticket 141), so B's rows overflow the sheet. Scroll the sheet, open the lowest row, tap Back. *Pass:* the sheet returns at the same scroll position. If the rows still fit at the cap, record "not reproducible" and close it as such. *Verify:* screenshots before and after.

**Findings:** 110-012, 120-008; follow-ups 110-013 (steps 1-3), 100-010 (rewritten); Lee's 100-005 check (no Finding file; the verdict row says `100-005 check`).

**Decisions:** mp-241, mp-244 (as clarified by 110-012), 100-005 won't-fix ruling.

**Touches:** account B only: two plans, their lists, ticks, one plan deleted, units changed and restored. B is deleted at the end.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/146/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding. Lee's delete check has its own row.
- [ ] Account B is deleted through the app at the end.

Next: /implement-lee testing-wave
