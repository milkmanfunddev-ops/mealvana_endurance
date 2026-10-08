# 49: Retest: meal logging after wave 4

**Status:** done 2026-10-08 (wave 5 run complete; see runs/49/notes.md)
**Labels:** retest, round:develop-2026-10, area:meal-logging, ai-call
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 4 lands)
**Source:** TRIAGE.md rulings of 2026-10-08 (wave 3 triage): followups 31-006, 31-009, 31-010, 31-011; fix retests for tickets 38 (swap quantity), 45 (31-002, 31-003, 31-004, 31-005, 31-007), 39 (one food_preferences row's updated_at offset)
**Blocked by:** fix wave 4 (38, 39, 41, 45) and its rebuild; runs in wave 5. 41 is here for the `meal_log_deleted` event (ticket 41 item 13).
**Next:** `/testing-wave develop-2026-10 --only 49`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/49/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Accounts:** the dev test account (`CRED type test@test.com --udid UDID`); ticket 50 may be on it in the same wave and writes nothing but its Connected Apps step. Check only rows this run writes. **App data:** cleared by the lead. **Cost:** at most three AI logging spends (`COST spend 5 logging 49` before each send); exit 3 skips that spend's checks with one followup-test Finding.

## Checks (10)

1. **Spend 1, text describe.** "two scrambled eggs, a slice of whole wheat toast with butter, a banana". **45 / 31-004:** Back on Review returns to the sheet with the analysis and text kept; reopening Review costs nothing (ledger unchanged). **45 / 31-002:** clear the meal name: Log this meal is disabled with a hint. Log it.
2. **38.** Swap one item to quantity 2 through the picker: the row reads "2 × 1 <unit>", reopening shows Quantity 2 over the base. **45 / 31-005:** the picker's kcal and the row's kcal agree.
3. **Spend 2, non-food.** "my bike ride": **45 / 31-003:** a "not food" message, no Review; the ledger shows what the ticket's Decision says about the charge (record it either way).
4. **45 / 31-007.** Describe with 3 characters: the message says the minimum and comes from the content system (no raw key, not the old text).
5. **Spend 3, photo + text.** One ledger debit; `source`, `photo_path`, `notes` on the row. **41 / 31-013:** the function_edge_logs now carries the analyze-meal-photo request line (or ticket 41's documented reason why not).
6. **40 / 31-001.** The Timeline reconnect notice and the meal card's Save as favorite read as words.
7. **39.** SQL: this account's newest `food_preferences.updated_at` (after one preference toggle in Settings, a write this ticket names) has a `+00` offset and equals the wall clock in UTC.
8. **31-006.** Remove an item and remove a meal: is there a confirm or undo (as ticket 45 left it); accidental swipe recovery.
9. **31-009.** The Timeline reconnect notice: Reconnect and X behaviour, and whether it survives a relaunch.
10. **31-010 + 31-011.** Edit Meal paths (Scan a photo, Time eaten Change, Notes edit, Hide details, Back with unsaved edits); Describe and the swap picker paths (Camera on the simulator, Gallery cancel, very long text). One Finding per screen.

Delete every meal this run logged (step 7 of ticket 31's exit); put the toggled preference back.

## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 49 … --round develop-2026-10`; index exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>`, the new Finding's id, or "skipped: cap"; spends that bought nothing named.
- [ ] Meals deleted; preference restored; hardware keyboard back on. `netcut.sh off SCRATCH`; helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-49`; simulator released.
- [ ] Console redacted. `findings/49-*.md` and `runs/49/` committed on the ticket branch, explicit paths.

Next: /testing-wave develop-2026-10 (wave 5)
