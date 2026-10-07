# 09: The timeline and the fuelling plan show the week

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:timeline, read-only
**Branch:** `develop-next`
**Source:** testing-wave 30 (`origin/mealplanning`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 09`
**Model:** opus

**What to test:** The athlete walks this week on the Timeline and opens one session's fuelling plan.
What shows equals what the dev database holds.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/09/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account. Ticket 10 changes one of its settings in a later wave; meal
tickets may add meals today: count only activities, and today's meals as "expected to move".

**App data:** cleared by the wave lead. **Read only:** no saves on the plan, no skip, no swap.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Timeline: header day arrows, energy card, workout cards, meal cards | `/main` | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart` |
| Month picker | tap the header date | `lib/features/calendar/presentation/widgets/calendar_month_view_kyle.dart` |
| Energy breakdown pager | tap the energy card | `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart` |
| Activity detail (fuelling plan, by-hour view) | tap a workout card → `/plan?activityId=…` | `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` |

Standing rule: the Activity detail screen's look and copy are frozen. File only wrong numbers and
broken navigation there.

## Expected records (`RUNS/expected.md`)

- This week's `activities` for the account, Monday to Sunday, columns named (read them from
  `information_schema`; at least id, title/type, scheduled time, status, provider).
- For one session with a plan: its stored plan (read `activity_detail_controller.dart` to find where
  the plan lives) with carbs per hour, fluid and sodium.

## Steps

1. Sign in. Walk Monday to Sunday with the day arrows (read the arrow's position from the element
   list each time; it moves with the title width). Each day: workout cards equal that day's rows.
2. Open the month picker; pick a day; use Today.
3. Open the energy breakdown on a past day and on today.
4. Open one planned session's detail. Record the plan's per-hour numbers and the by-hour view.
   Compare with the stored plan.
5. Back lands on the Timeline on the same day.

## What counts as a Finding

- A session on screen that is not in the database, or the reverse; a session on the wrong day (time
  zones: `scheduled_date_time` is local-naive).
- Plan numbers on screen that differ from the stored plan.
- Console errors (the dev test account's TrainingPeaks/V.O2 Degradeds are known noise, Sentry ticket
  22); look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/30-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 09 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-09-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-09`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/09-*.md` and `runs/09/` committed on the ticket branch, explicit paths only.
