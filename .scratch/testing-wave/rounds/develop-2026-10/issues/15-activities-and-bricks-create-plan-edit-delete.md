# 15: Activities and bricks: create, plan, edit, log fuel, delete

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:activities
**Branch:** `develop-next`
**Source:** new
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 15`
**Model:** opus

**What to test:** The athlete creates a run and gets a fuelling plan, edits it, swaps a food, logs fuel
after the session, skips and unskips one, builds a brick from a run and a ride on the same day, undoes
and ungroups it, then deletes the brick and an activity. Every step matches the database.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/15/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** one new `lee+e2e-15-<UTC time>@rightpathprogramming.com` (onboarding with run + bike,
a real weight). **App data:** cleared by the wave lead. **Cost:** no AI call.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Timeline "+ Add Activity", "Brick" pill (shown when a day holds 2+ swim/bike/run workouts across 2+ sports) | `/main` | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart`, `lib/features/activities/presentation/providers/brick_creation_available_provider.dart` |
| New activity (run / bike / swim; "Use Routine"; "Generate Plan") | `/distancepacegut` → `NewActivityScreen` | `lib/features/nutrition_plan/presentation/screens/new_activity_screen.dart` |
| Routine picker, My Routines | "Use Routine" → `/settings/templates` | `lib/features/personal_templates/presentation/` |
| Weather detail | the run tab's forecast (upcoming, with location) | `lib/features/weather/presentation/screens/weather_detail_screen.dart` |
| Adjust Your Macros ("Edit Macros") | `adjust-macros` | `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart` |
| Activity detail (app bar: Edit Activity, Edit Fuel Log, Delete Activity) | `/plan?activityId=…` | `activity_detail_screen.dart`, `widgets/activity_detail/activity_detail_app_bar.dart` |
| Swap food, food detail | `/swap-food`, `food-detail` | `swap_food_screen.dart`, `lib/shared/screens/food_detail_screen.dart` |
| Fuel log ("How did it go?") | `fuel-log` | `fuel_log_screen.dart` |
| Workout card Skip / Unskip; brick tile menu (ungroup, "Delete brick") | Timeline | `lib/features/macro_dashboard/presentation/widgets/workout_card.dart`, `lib/features/fuel_timeline/presentation/widgets/timeline_brick_tile.dart` |

Standing rule: Activity detail keeps its look and copy. Only wrong numbers and broken navigation are
bugs there.

## Expected records (`RUNS/expected.md`)

Read the columns of `activities` from `information_schema`; read the brick repository and the delete
path in `activities_controller.dart` / `brick_actions_controller.dart` first, then write:
- after create: one row (sport, scheduled time, duration, distance) with a plan;
- after edit: same id, new values, and the plan refreshed or flagged for refresh (name the flag);
- after the fuel log: the consumed amounts where the code stores them;
- after skip / unskip: the status column both ways;
- after brick create: the link between the two legs (parent row or group id, per the code); after
  undo and ungroup: no link, both legs intact; after delete brick: the brick and its plan gone, the
  legs restored ("Brick deleted · legs restored");
- after Delete Activity: the row gone or soft-deleted, per the code.

## Steps

1. Sign up. Timeline → "+ Add Activity". Run tab: tomorrow, 10 km, 60 min. Allow location; open the
   weather detail. "Generate Plan" → Adjust Your Macros → continue → the plan. Back once: where does it
   land? (The earlier round's 116-011: it walked back through the form.)
2. Edit Activity: change the duration to 75 min. The plan's numbers change; SQL.
3. Swap one food in the plan; open its food detail. SQL the plan's foods.
4. Make a run whose time has passed (earlier today, or yesterday if the form allows a past date; write
   which). Edit Fuel Log: mark one item Partial, one Skipped, answer "How did it go?". SQL.
5. Skip tomorrow's run on its card, then Unskip. SQL both.
6. Add a ride for tomorrow (60 min). The Brick pill appears. Brick → pick both → create. Snackbar
   "Brick created · …" with Undo: Undo ("Brick undone — legs restored"). Create again. Ungroup from
   the tile menu. Create again. "Delete brick" → confirm. SQL after each.
7. "Use Routine": save a routine if the flow offers it, apply it to a new activity, then delete that
   routine in My Routines.
8. Delete Activity on the remaining run. SQL. Delete the account in the app.

## What counts as a Finding

- Any row that disagrees with what the screen said happened; a plan that never refreshes after an edit.
- A brick action that loses a leg, leaves a half-linked pair, or shows success and does nothing.
- Back that walks through finished forms; a location prompt for a past workout (the earlier round's
  100-004).
- Console errors; look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 15 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-15-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-15`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/15-*.md` and `runs/15/` committed on the ticket branch, explicit paths only.
