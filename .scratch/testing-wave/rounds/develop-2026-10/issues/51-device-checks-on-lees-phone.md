# 51: Device checks on Lee's phone: real notification taps, Apple relay email, TrainingPeaks sharing sheet

**Status:** ready (round develop-2026-10, retest, wave 5)
**Labels:** retest, round:develop-2026-10, area:device, lee
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 4 lands)
**Source:** TRIAGE.md rulings of 2026-10-08 (wave 3 triage): followups 32-009, 31-008; fix retests for tickets 34 (22-001 on a real push) and 36 (Apple hidden-address contact email)
**Blocked by:** fix wave 4 (34, 36) and its rebuild; runs in wave 5
**Next:** `/testing-wave develop-2026-10 --only 51`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/51/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Who runs it:** Lee, on his phone, with the dev build (TestFlight dev or a local install); the lead writes the steps and reads the evidence. Not a simulator ticket: no slot, no wave simulator.

## Checks (4)

1. **34 / 22-001 / 32-009.** A real push (OneSignal test send to Lee's device, or a Garmin completion push) tapped (a) from killed: the app opens on the activity, exactly one launch-trail dialog (dev); (b) from background: the app resumes onto the activity, the two payload keys cleared.
2. **36.** Sign in with Apple choosing Hide My Email on a fresh account: Profile & Preferences shows an editable Contact email, empty; typing an address and saving writes `public.users.email`; a sign-out and Apple sign-in again keeps it. Delete the account afterwards.
3. **31-008.** On an account with a healthy TrainingPeaks connection: the sharing sheet on the first shell launch after sign-in; Keep Sharing, Turn Off Sharing and the scrim; the prefs keys after each.
4. **The Drift gap (TRIAGE, wave 2 question d).** Before any of the above, wipe the app on the phone if it ever ran a mealplanning build (ruling: reinstall on internal devices).

## Exit
- [ ] Evidence (screenshots, the plist key reads, SQL rows) in `runs/51/`; `PASS <id>` or new Findings (`findings.mjs new 51 …`) in `runs/51/notes.md`.
- [ ] The Apple test account deleted; the OneSignal test send recorded.

Next: /testing-wave develop-2026-10 (wave 5)
