# 68: Retest: meal logging after wave 6

**Status:** in-progress (wave 7, 2026-10-08)
**Labels:** retest, round:develop-2026-10, area:meal-logging, ai-call
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 6 lands)
**Source:** TRIAGE.md rulings of 2026-10-08 (wave 5 triage): followups 49-004, 49-007, 49-008, 49-009, 50-013; fix retests for tickets 58 (49-010, and ticket 39's UTC retest that rides on it), 55 (49-005), 60 (49-006), 66 (49-002, 49-003)
**Blocked by:** fix wave 6 (55, 58, 60, 66) and its rebuild; runs in wave 7
**Next:** `/testing-wave develop-2026-10 --only 68`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/68/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Accounts:** the dev test account (`CRED type test@test.com --udid UDID`); ticket 69 may be on it in the same wave and writes Connected Apps and events (an integration that changes state is theirs). Check only rows this run writes. **App data:** cleared by the lead; the simulator has no camera. **Cost:** at most three AI logging spends (`COST spend 7 logging 68` before each send); exit 3 skips that spend's checks with one followup-test Finding.

## Checks (12)

1. **58 / 49-010, load.** Before any save, read `food_preferences` for the account (SQL, named columns: the food key, level, `updated_at`). Sign in on the cleared app, Settings → Diet, Allergies & Formulas → Food Likes & Dislikes. Passes when the screen shows the server levels (run 49 saw `sports_drink` at 4 on the server and 2 on screen).
2. **58 / 49-010, save.** Move one food one level, Save Changes. Passes when that server row's level changes within seconds and its `updated_at` carries `+00` and equals the UTC wall clock of the save (ticket 39), and a read-only copy of the Drift file holds the same snake_case key the server does (no display-name rows like "Energy Chews").
3. **58, round trip.** Sign out and sign in again (ask the lead to clear app data first if sign-out keeps the local rows). Passes when the screen shows the level saved in check 2, read from the server. Put the level back and Save at the end of the run; read the row again.
4. **66 / 49-002, short line.** Describe tab, type "egg", Analyze (no call, no spend). Passes when the whole line "Add a bit more: at least 5 characters, like what you ate and how much." shows on screen, wrapped, no ellipsis.
5. **Spend 1, not-food: 55 / 49-005 + 66 / 49-002.** Describe "my bike ride", Analyze. Passes when the not-food line shows in full (wrapped), the ledger has no debit, and the console shows `expected_failure` with a not-food reason and no `error_reported`; the dev Sentry project (read-only) has no FunctionException for that minute.
6. **Spend 2, long text: 49-007 step 1.** Paste more than 2,000 characters (`simctl pbcopy`), Analyze. Passes when the message says the text is too long (the server's 400) and the ledger has no debit; "The AI service returned an error" is a fail. Then **49-007 step 3** (no spend): `xcrun simctl privacy UDID revoke camera com.milkman.mealvanaendurance.dev`, tap Camera: record the message; it explains itself or it is a Finding.
7. **60 / 49-006.** Tap Camera (no camera on the simulator: the plugin's "Camera not available" alert, OK), then Gallery and close the picker with X. Passes when neither tap sends `meal_ai_photo_attached`. The real pick in check 8 must send exactly one.
8. **Spend 3, double-tap with a photo: 49-007 steps 2 and 4.** Put a photo with GPS EXIF in the library (SCRATCH copy of `benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg` with a GPS tag written by exiftool or PIL; `simctl addmedia`). Gallery → pick it (one `meal_ai_photo_attached`), type what it shows, double-tap Analyze inside 0.3 s. Passes with one `analyze-meal-photo` request line and one ledger debit, and the uploaded `meal-photos` object (downloaded read-only to SCRATCH) carries no GPS tags. If `log_meal_screen.dart` shows the photo path skips the in-flight join, double-tap text only instead and mark the location half "not run: cap".
9. **66 / 49-003.** On the Review from check 8, swipe an item away. Passes when a snackbar with Undo shows and Undo restores the item and the total. Then rename the meal (and swap an item if there are two), tap Back: passes when a Discard dialog asks before the edits drop. Keep editing, then Log this meal.
10. **49-009, swap picker.** From Edit Meal on the logged meal, swipe an item right to left. Search a food and pick it; Create Custom Food and come back (name it `tw68 …`; delete it if the app offers a way, else a leftover); Scan barcode (no camera: record the state); pick a food with a serving unit (a cup or a slice) at quantity 2, then Edit Item to 3. Passes when the row reads "2 × 1 cup" (then "3 × 1 cup") and kcal and the stored `quantity` follow. One Finding for the screen.
11. **49-008, Edit Meal.** Time eaten → 11:59 PM today, and a time across midnight: record whether a future time is allowed and where the card sorts. Edit the notes, Back → Discard: `meal_logs.updated_at` unchanged. Edit again, Back → Keep editing: the edit stays. Toggle only Hide details, Back: no dialog. Re-scan photo: "not run: cap" (three spends used). One Finding for the screen.
12. **50-013 + 49-004.** Log a Meal: header Search with an empty field gives feedback (record what); Scan barcode → Enter a known barcode and an unknown one; Recent and Common: if the account has entries, write "not empty on this account" and read the empty-state copy from code for raw keys; Describe offline needs a spend: "not run: cap". Reconnect notice (49-004): `netcut.sh` gives a network failure, not `invalid_grant`, so it cannot move a provider to `requires_reauth`, and a dead token is a write on `integrations` this ticket does not name: write "needs a dead token; not forceable without a write". Observe only: read `integrations` at sign-in and at the end; if a provider is active and `requires_reauth` (ticket 69's TrainingPeaks work may cause it), check the notice's words, Reconnect, X and a relaunch.

Delete every meal this run logged; put the preference back (check 3).

## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 68 … --round develop-2026-10`; index exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>`, the new Finding's id, or "not run" with its reason; each spend and what it bought.
- [ ] Meals deleted; preference restored (row read); custom food deleted or named as a leftover with its id; camera permission reset with `simctl privacy UDID reset camera …`. `netcut.sh off SCRATCH`; helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-68`; simulator released.
- [ ] Console redacted. `findings/68-*.md` and `runs/68/` committed on the ticket branch, explicit paths.

Next: /testing-wave develop-2026-10 (wave 7)
