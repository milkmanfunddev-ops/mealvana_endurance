# 06: Editing and deleting a logged meal changes the day's totals

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:meal-logging
**Branch:** `develop-next`
**Source:** testing-wave 27 (`origin/mealplanning`); made self-contained, so it no longer waits on 26
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 06`
**Model:** opus

**What to test:** The athlete logs two meals by hand, edits one and deletes the other, and the day's
totals on screen equal the sums in the database at each step.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/06/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account. Log on a day no other ticket in the wave uses: tomorrow's date
(pick it in the sheet's day if it offers one; otherwise today, and filter SQL to your own rows).

**App data:** cleared by the wave lead. **Cost:** no AI call. Do not use "re-scan photo" or any AI
button on the edit screen.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Timeline meal card → "Edit food" | Timeline | `lib/features/macro_dashboard/presentation/widgets/meal_card.dart` |
| Edit meal | `/meal-log/edit` | `lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart` |
| Energy card / breakdown | Timeline header card; tap opens the breakdown pager | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |

## Expected records (`RUNS/expected.md`)

- Three snapshots of the day: after the two logs, after the edit, after the delete. Each: the day's
  `meal_logs` sums (by SQL) and the on-screen intake (energy card and breakdown). They must agree.
- The edited row keeps its id; the deleted row is gone or carries the delete marker the repository
  writes (read the delete path first and write which).

## Steps

1. Sign in. Log meal A (400 kcal, 50 C, 20 P, 10 F) and meal B (300 kcal, 40 C, 10 P, 10 F) by Manual.
   Snapshot 1.
2. Meal A → Edit food. Change its carbs (or a quantity) by a round amount. Save. Snapshot 2.
3. Meal B → Edit food → delete. Snapshot 3.
4. Relaunch. Snapshot 3 holds.
5. Look around: Back from Edit with unsaved changes (does it ask?), delete Cancel, editing a meal on a
   past day.

## What counts as a Finding

- Any snapshot where screen and SQL disagree, or a total that lags until a relaunch.
- An edit that makes a new row instead of changing the old one.
- Leaving edit with changes and no question (record it; the earlier round's 119-010 asked for one).
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/27-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 06 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-06-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-06`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/06-*.md` and `runs/06/` committed on the ticket branch, explicit paths only.
