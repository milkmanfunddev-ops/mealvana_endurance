# 03: Logging a meal from a photo in the library

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:meal-logging, ai-call
**Branch:** `develop-next`
**Source:** testing-wave 24 (`origin/mealplanning`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 03`
**Model:** opus

**What to test:** The athlete picks a meal photo from the simulator's library, the app reads it, and
the meal saves with the numbers the Review screen showed.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/03/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account. Ticket 02 may log on it in the same wave: check only your rows.

**App data:** cleared by the wave lead.

**Cost:** one AI logging call (`COST spend WAVE logging 03` before the tap that sends the photo).

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Log a meal sheet, Describe tab → "Gallery" / "Choose Photo" | Timeline "+ Add Food" | `lib/features/meal_logging/presentation/screens/log_meal_screen.dart` (`_pickPhoto`) |
| iOS photo picker | system | — |
| Review | `/meal-log/review` | `lib/features/meal_logging/presentation/screens/meal_review_screen.dart` |

`/meal-log/photo` (`photo_capture_screen.dart`) has no in-app entry on develop-next; ticket 08 opens it
by deep link.

## Expected records (`RUNS/expected.md`)

- New `meal_logs` row(s) equal to Review's totals (columns named, read from `information_schema`).
- Credits: same rule as ticket 02, with `ref = analyze-meal-photo`.
- Any AI usage row the edge function writes (read `supabase/functions/analyze-meal-photo/index.ts`
  first). The earlier round found one photo writing two usage rows (24-001); check it here.

## Steps

1. Put a food photo in the library first: fetch one plain meal photo (CC0 or your own) into SCRATCH
   and `xcrun simctl addmedia UDID SCRATCH/<file>.jpg`. Write its source and whether it carries GPS
   data in `RUNS/notes.md`.
2. Sign in. Timeline → "+ Add Food" → Describe → Gallery. Answer the Photos permission prompt (Allow).
3. Spend, then pick the photo. Wait for the read. Record items and totals on Review.
4. Log it. The Timeline card matches; relaunch, still there.
5. SQL: meal rows, ledger, balance, usage rows. Edge log for `analyze-meal-photo` in the window.
6. Look around without spending: Camera on a simulator (no camera; record what the app says), Back
   from Review without logging (nothing saved, by SQL).

## What counts as a Finding

- A photo that never comes back, or comes back with no items and no message.
- Review totals that differ from the stored row; a picture missing where the design shows one.
- Two usage rows for one photo; a debit for a failed read.
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/24-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 03 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-03-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-03`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/03-*.md` and `runs/03/` committed on the ticket branch, explicit paths only.
