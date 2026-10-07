# 02: Logging a meal by describing it

**Status:** in-progress (wave 1, 2026-10-07)
**Labels:** test, round:develop-2026-10, area:meal-logging, ai-call
**Branch:** `develop-next`
**Source:** testing-wave 23 (`origin/mealplanning`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 02`
**Model:** opus

**What to test:** The athlete describes a meal in words, reviews what the AI made of it and logs it.
The meal and its numbers show on the day and in the dev database, and the credit balance moves the
way the server says it should.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/02/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account (`CRED type test@test.com --udid UDID`). Other tickets in the same
wave may log meals on it: check only the rows this run writes (by `created_at` inside your run's
minutes and the text you typed).

**App data:** cleared by the wave lead.

**Cost:** one AI logging call. `COST spend WAVE logging 02` before the tap that sends the
description, never after. Exit 3: skip the send and write a followup-test Finding.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Timeline | `/main`, "+ Add Food" | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart` |
| Log a meal sheet, Describe tab (token pill in its header) | `openLogMealScreen` | `lib/features/meal_logging/presentation/screens/log_meal_screen.dart` |
| Review | `/meal-log/review` | `lib/features/meal_logging/presentation/screens/meal_review_screen.dart` |
| Meal slot picker | sheet from Review | `lib/features/meal_logging/presentation/widgets/log_sheet_helpers.dart` |

The standalone `/meal-log/describe` route has no in-app entry on develop-next (nothing navigates to
it). Ticket 08 opens it by deep link; this ticket uses the sheet, which is how an athlete gets there.

## Expected records (`RUNS/expected.md`)

- Before: the day's `meal_logs` rows for the account (read the columns from
  `information_schema.columns` first, then name them; never `SELECT *`).
- After: one new `meal_logs` row (or one per item, whichever the save writes: read the save path in
  `meal_review_screen.dart` first) whose macros equal the Review screen's totals.
- Credits: `token_wallets.balance` and the newest `token_ledger` rows before and after. If dev
  enforces credits, one `debit_usage` row with `ref = describe-meal` and the balance down by the
  cost; if dev does not enforce, no ledger row and no balance change. Write which one you saw; the
  server decides (`supabase/functions/_shared/ai/credits.ts`), the app must agree with it.

## Steps

1. Sign in. Note the token pill's number and the SQL balance; they must match.
2. Timeline → "+ Add Food" → Describe. Type a plain meal ("two scrambled eggs, a slice of whole wheat
   toast with butter, a banana"). Spend, then send.
3. On Review, record every item and the totals. Change one quantity, check the totals move, put it back.
4. Log it into a slot. Back on the Timeline, the meal card shows at the logged time with the same
   numbers; the day's intake moves by the meal's total.
5. SQL: the new row(s), the ledger and the balance. Pull the `describe-meal` edge-function log for
   the minutes of the call (the Supabase MCP `query_logs`, per RUNBOOK step 6: console lines).
6. Relaunch the app: the meal is still there.

## What counts as a Finding

- Numbers on Review, the Timeline card and the stored row that disagree.
- A pill balance that disagrees with `token_wallets`, or a debit on a failed call.
- Any edge-function error line in the window, even one your run did not cause (screen none).
- Console errors on any visited screen; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/23-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 02 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-02-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-02`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/02-*.md` and `runs/02/` committed on the ticket branch, explicit paths only.
