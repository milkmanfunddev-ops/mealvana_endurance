# 144: Retest: Shop with Kroger, a rebuilt list, and Share

**Status:** ready-for-agent
**Blocked by:** 133.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 133 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 133's fixes, then runs the folded Kroger follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com, app data cleared. Kroger certification environment with Lee's shopper login (`CRED type <kroger email> --udid UDID` once the password field of the web sheet is focused; drive the sheet by coordinates, RUNBOOK step 5). Start state: no Kroger connection. Before the run, SELECT the account's Kroger connection row (named columns only, never tokens) and `kroger_oauth_sessions` for the user. If the account is connected, stop and write a Finding: the run does not disconnect a connection it did not make. Location for the Kroger checks: `xcrun simctl privacy UDID revoke location com.milkman.mealvanaendurance.dev` where a check says "location off".

**Shared account:** test@test.com and its confirmed plan's list are also used by 143. Never run them in one wave. If they are paired, wait for `SCRATCH-shared/143-done`.

**COST:** none.

## Checks

1. **Matching before Kroger login (111-002).** Not connected: Shop with Kroger from the confirmed plan's list. Set delivery ZIP 35209. *Pass:* Match all shows and runs, and a line's product search and Choose product work, all before any Kroger sign-in. Add to Kroger cart is shown and asks to connect. *Verify:* screen, `kroger_drafts` SELECT for the plan (store id set), `kroger` edge logs (search 200).
2. **Cancel on the kroger.com alert is quiet (111-001).** Connect Kroger, then Cancel on the iOS "Wants to Use kroger.com to Sign In" alert. *Pass:* no "Something went wrong" and no error snackbar. Connect Kroger is back, and `kroger_oauth_sessions` has no row for that attempt (`cancel_connect`). *Verify:* screenshot, DB SELECT (id, created_at), edge logs.
3. **X on the Kroger web sheet is quiet (111-001).** Connect Kroger > Continue, wait for login-stage.kroger.com, close the sheet with X. *Pass:* same as check 2. *Verify:* same.
4. **Connect from Add to Kroger cart, then add (111-002).** Add to Kroger cart > connect with the shopper login > back on the screen tap Add again (133 notes: no auto-continue). *Pass:* the cart hand-off answers. Never Place Order. *Verify:* screen, `kroger` edge logs. At the end, Disconnect Kroger (it asks first, ticket 82) so the account is back to its start state.
5. **Delivery ZIP edges (111-005).** Not connected, location off. Set delivery ZIP 99701 (no Kroger delivery), then 1234, then ABCDE, then Cancel. *Pass:* each gets a clear message, and no store is saved for a refused ZIP. *Verify:* screen, `kroger_drafts` SELECT.
6. **The typed ZIP after a restart (111-006).** Location off, set ZIP 35209, cold restart, reopen Shop with Kroger. *Pass or record:* write down whether the ZIP must be typed again (the controller keeps the area per session by Kroger's Locations terms). Check that Match all and the cart still work from the stored store. A retype on every visit is an idea Finding, not a bug. *Verify:* screen, `kroger_drafts`.
7. **Skip, Include and Add item reach `kroger_drafts` (111-007).** Not connected: Skip a line, Include a skipped one, Add item. Leave, reopen, SELECT `kroger_drafts` (updated_at and lines) for the plan. Also change the ZIP and see whether `updated_at` moves. *Pass:* each change is in the row after the reopen. *Verify:* DB SELECT before and after.
8. **Jam goes to Pantry (110-008).** On the confirmed plan (SELECT whether it holds a meal with jam, e.g. "Sweet rice cake with jam"), Plan ⋮ > Rebuild shopping list. *Pass:* strawberry jam sits under Pantry. If no confirmed meal has jam, mark it not run and say why. Do not add a meal to test@test.com's plan. *Verify:* screen, `shopping_items` (name, aisle).
9. **Share on an empty list, and share text (110-007, 110-011).** (a) A `W<WAVE>-144` empty hand-made list > Share: a message says there is nothing to share. (b) Share on the rebuilt plan list with one row ticked. *Pass:* the text is titled with the list's name in words ("Week of Sep 20"), not "Mealvana shopping list", and the to-buy count leaves the ticked row out. *Verify:* share sheet screenshot (copy the text into notes).

**Findings:** 111-001, 111-002, 110-008, 110-007, 110-011; follow-ups 111-005, 111-006, 111-007. 110-013's Kroger-with-no-connection leg is covered by check 1. Its other legs are in 146.

**Decisions:** Lee's rulings in `triage-20260926.md` (111-002, 110-011).

**Touches:** test@test.com. `kroger_drafts` for the confirmed plan, one Kroger connection made and removed, `kroger_oauth_sessions` rows, a rebuilt list for the confirmed plan, and one `W<WAVE>-144` list (deleted at the end). No account created.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/144/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Kroger is disconnected again at the end, and no order is placed.

Next: /implement-lee testing-wave
