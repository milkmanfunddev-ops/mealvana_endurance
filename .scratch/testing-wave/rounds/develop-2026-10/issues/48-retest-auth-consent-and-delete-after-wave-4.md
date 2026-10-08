# 48: Retest: auth, consent and delete after wave 4

**Status:** ready (round develop-2026-10, retest, wave 5)
**Labels:** retest, round:develop-2026-10, area:account
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 4 lands)
**Source:** TRIAGE.md rulings of 2026-10-08 (wave 3 triage): followups 30-013, 30-014, 30-015; fix retests for tickets 35, 36, 40 (30-001 screens), 41 (30-005, 30-011), 42 (30-007, 30-008), 43 (30-002, 30-010)
**Blocked by:** fix wave 4 (35, 36, 40, 41, 42, 43) and its rebuild; runs in wave 5
**Next:** `/testing-wave develop-2026-10 --only 48`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/48/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Accounts:** new ones only, `lee+e2e-48-<UTC time>@rightpathprogramming.com`, via `CRED new`. The Apple-relay half of 36 needs a real Apple hidden-address sign-in: note "device check, Lee's phone" (ticket 51) and test only the email/password read-only case here. **App data:** cleared by the lead. **Cost:** none.

## Checks (10)

1. **40 / 30-001.** Fresh signup to Verify your email: the countdown, Resend, hint, wrong-code and Log In texts are words, not keys. Then Settings and both account dialogs (Sign Out, Delete) read as words. Screenshot each.
2. **35.** Settings → Delete Account: title "Delete Account?", body "This will permanently delete your account and all associated data. This action cannot be undone.", button "Delete Account". Cancel keeps the account.
3. **36.** Profile & Preferences on an email/password account: Email is read-only, labelled "Your login email", and a save leaves `public.users.email` unchanged (SQL, named columns).
4. **42 / 30-007.** On Verify your email, terminate and relaunch: Verify your email reopens with the countdown honoured and the onboarding answers kept; the original code still works.
5. **42 / 30-008.** Create Account twice within 60 s: the second shows a wait/countdown, not a failure; no `error_reported`.
6. **41 / 30-005.** Google cancel, Apple sheet closed, "email already registered", wrong password: each a breadcrumb or info line, no `error_reported`; the dev Sentry project (read-only) shows nothing new for the run's minutes.
7. **41 / 30-011.** Three signed-out launches: no "Notification permission answer not stored" warning; the tape has its info line.
8. **43 / 30-002, 30-010.** Walk onboarding with the console on: no RenderFlex overflow; `idb ui describe-all` shows Build My Plan and the sign-in options as buttons with labels, and the consent switch labelled.
9. **30-013.** Verify your email untried paths: the hint's Log in; paste a code; Verify tapped twice fast; the expired code at 60 min only if the run lasts that long ("not seen live" otherwise).
10. **30-014 + 30-015.** Consent and Create account paths (toggle ON, the Privacy Policy and Terms links, Back from Your plan); Delete Account paths (Cancel on the dialog; delete-user answering 500 via `netcut.sh slow` on the functions host: message and account survives).

## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 48 … --round develop-2026-10`; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-48-index.md"` exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>` or the new Finding's id.
- [ ] Every account created is deleted in the app and `CRED update … --state deleted`; leftovers named with ids.
- [ ] `netcut.sh off SCRATCH`; helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-48`; simulator released.
- [ ] Console redacted (runbook § 9.4). `findings/48-*.md` and `runs/48/` committed on the ticket branch, explicit paths.

Next: /testing-wave develop-2026-10 (wave 5)
