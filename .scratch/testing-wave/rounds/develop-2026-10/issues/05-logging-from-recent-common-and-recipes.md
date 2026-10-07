# 05: Logging from Recent, Common and Recipes

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:meal-logging
**Branch:** `develop-next`
**Source:** testing-wave 26 (`origin/mealplanning`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 05`
**Model:** opus

**What to test:** The athlete logs one meal from each of the sheet's Recent (and Saved meals), Common
and Recipes tabs. Each saves as its source had it.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/05/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account (it has recent meals from earlier use). Other meal tickets may
write on it: check only your rows.

**App data:** cleared by the wave lead. **Cost:** no AI call.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Log a meal sheet: Recent tab (Saved meals + Recent sections), Common tab, Recipes tab (filter chips "All" + types) | Timeline "+ Add Food" | `lib/features/meal_logging/presentation/screens/log_meal_screen.dart` (`_RecentAndSavedTab`, `_RecipesTab`) |
| Search results | the sheet's "Search anything to add..." field | `lib/features/meal_logging/presentation/widgets/unified_meal_search_results.dart` |

`/meal-log/recent-saved` and `/meal-log/recipe` have no in-app entry on develop-next (ticket 08 opens
them by deep link). `RecipesScreen` (`lib/features/recipes/presentation/screens/recipes_screen.dart`) is
built nowhere; it is not part of this ticket.

## Expected records (`RUNS/expected.md`)

For each of the three logs: the source row (the recent `meal_logs` row, the `saved_meals` row, the
Common item, the recipe: read each tab's code to find its table before the run) and the new
`meal_logs` row. Name, macros and items equal, scaled only if you changed the serving.

## Steps

1. Sign in. Sheet → Recent. Log one Saved meal (if any) and one Recent meal. Write source ids.
2. Common: log one item at its default serving.
3. Recipes: filter by one type, log one recipe.
4. SQL: each new row against its source.
5. Search once from the sheet's search field and log a result; record which source it came from.
6. Look around: an empty Saved section, an empty search, a recipe with no macros.

## What counts as a Finding

- A logged row that differs from its source; a serving change that does not scale.
- A tab that shows nothing on an account that has data (by SQL).
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/26-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 05 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-05-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-05`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/05-*.md` and `runs/05/` committed on the ticket branch, explicit paths only.
