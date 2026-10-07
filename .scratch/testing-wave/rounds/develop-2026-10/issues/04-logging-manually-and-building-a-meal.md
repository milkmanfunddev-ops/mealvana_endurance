# 04: Logging manually and building a meal

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:meal-logging
**Branch:** `develop-next`
**Source:** testing-wave 25 (`origin/mealplanning`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 04`
**Model:** opus

**What to test:** The athlete logs one meal by hand and builds another from searched foods. Both save
with exactly the numbers entered.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/04/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account. Other meal tickets may write on it in the same wave: check only
your rows.

**App data:** cleared by the wave lead. **Cost:** no AI call.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Log a meal sheet, Manual tab | Timeline "+ Add Food" | `lib/features/meal_logging/presentation/screens/log_meal_screen.dart` |
| Build a meal | "Build a meal" button on the sheet | `lib/features/meal_logging/presentation/screens/build_meal_screen.dart` (`openBuildMealScreen`) |
| Add food (inside Build a meal) | "+" in Build a meal | `build_meal_screen.dart` (`_AddFoodScreen`) |
| Meal slot picker | on save | `lib/features/meal_logging/presentation/widgets/log_sheet_helpers.dart` |

`/meal-log/manual` (`manual_log_screen.dart`) has no in-app entry on develop-next; ticket 08 opens it
by deep link.

## Expected records (`RUNS/expected.md`)

- Manual: one `meal_logs` row whose name, calories, carbs, protein, fat (and whatever else the form
  takes) equal what you typed, to the unit the form shows.
- Built meal: a `meal_logs` row (or rows: read the save first) whose totals equal the sum of the
  chosen foods at the chosen quantities. Write the per-food numbers the screen showed before saving.
- If the build offers "save as a meal", a `saved_meals` row: record whether you took it.

## Steps

1. Sign in. Timeline → "+ Add Food" → Manual. Enter a meal with round numbers (e.g. 500 kcal,
   60 g C, 30 g P, 15 g F). Save into a slot. Timeline card and day intake move by exactly that.
2. Sheet → Build a meal. Search and add three foods; change one quantity. Record each food's numbers
   and the total. Save.
3. SQL both rows. Relaunch; both still on the Timeline.
4. Look around: an empty Manual save, a negative or huge number, Back from Build a meal with foods
   added (is anything kept or lost without asking?).

## What counts as a Finding

- Any stored number that differs from what was entered or shown.
- A save that accepts an empty or impossible value without a message.
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/25-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 04 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-04-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-04`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/04-*.md` and `runs/04/` committed on the ticket branch, explicit paths only.
