# 07: Barcode logging on a simulator

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:meal-logging
**Branch:** `develop-next`
**Source:** testing-wave 28 (`origin/mealplanning`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 07`
**Model:** opus

**What to test:** The athlete opens barcode logging from each place that offers it. The run finds out
whether a simulator can scan anything and either logs a product or records that the path needs a
real phone.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/07/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account. **App data:** cleared by the wave lead. **Cost:** no AI call.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Barcode scanner | named route `barcode-scanner` (`/barcode-scanner`) from the Log a meal sheet's search row, from Build a meal, from Food Preferences' add food, and from the coach's carb food picker | `lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart` |
| Log scanned food | after a scan | `lib/features/meal_logging/presentation/screens/log_scanned_food_screen.dart` |

## Expected records (`RUNS/expected.md`)

- If a product logs: one `meal_logs` row with the product's numbers and the log method the code
  writes for a barcode (read `_onBarcodeScan` in `log_meal_screen.dart`).
- If nothing can scan: no rows.

## Steps

1. Sign in. Sheet → the barcode control. Answer the camera permission prompt. Record what the
   simulator shows (no camera: an error, a blank view, a manual-entry field?).
2. If the screen offers manual barcode entry, enter a common product's EAN (e.g. a cereal box you
   can name) and log it. SQL the row.
3. Open the scanner from Build a meal and from Settings → Diet, Allergies & Formulas → Food
   Preferences' add food. Same checks, no logging needed.
4. Back out of each: the screen you came from is intact.

## What counts as a Finding

- If scanning cannot work on a simulator: exactly one followup-test Finding that marks it for Lee's
  phone (the round's spec allows a device check owed to Lee for the barcode camera).
- A scanner that hangs, a permission denial with no way forward, a crash.
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/28-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 07 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-07-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-07`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/07-*.md` and `runs/07/` committed on the ticket branch, explicit paths only.
