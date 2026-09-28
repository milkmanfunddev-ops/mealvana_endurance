# 156: Retest: password reset and sign-out

**Status:** ready-for-agent
**Blocked by:** 139.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 139 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 139's fixes and runs the folded reset and sign-out follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** app data cleared.
- Account K, new, bought Annual, for the reset checks (1-5) and the paid sign-out (6). Before a reset changes its password, `CRED file` keeps the old one, and `CRED update K --new-password` records the new one.
- Account L, new, never paid (stays on the onboarding paywall), for checks 7 and 8.
- Account M, signed up and never verified, for check 4.
Reset codes come from Gmail.

**Shared account:** none.

**COST:** none.

## Checks

1. **A recovery session is signed out unless the new password is saved (124-003).** Sign out K. Log In > Forgot Password? > K > Send Reset Code, enter the right code: Set New Password opens. Run 1: Cancel. Run 2: the back arrow, then Back to Log In. Run 3: terminate on Set New Password. After each, relaunch. *Pass:* each relaunch lands on Log In, and `auth.sessions` for K has no live recovery session. RevenueCat was not logged in at the code step (record the console). *Verify:* screen, SELECT `auth.sessions` (id, created_at, not_after) for K, console.
2. **Enter Reset Code counts down (124-004).** Send Reset Code, then within 20 s look for Resend. *Pass:* a 60 s countdown. A tap at zero sends a new mail. A 429 reads "after N seconds" and counts it. *Verify:* screenshots, Gmail.
3. **Submit on the sixth digit sends one verify (124-008).** Type a wrong six-digit code and tap Verify Code at once. Then the right code the same way. *Pass:* one verify call per code (console "Reset code verification" lines, auth log). The right code opens Set New Password once. *Verify:* console counts, auth log.
4. **Forgot Password for an unverified address (124-009).** M signs up and stops on the code screen, leaves. Log In > Forgot Password with M. *Pass or record:* what the screen says and whether a mail comes. It must not reveal whether an account exists beyond what signup already does. M is then removed by the lead's sweep (name it under Leftover accounts). *Verify:* screen, Gmail.
5. **A second phone after a password reset (124-010, rewritten).** As written it needed two simulators signed in to one account (the cap allows one per ticket). Rewritten: K is signed in on this simulator and stays signed in. From the host, reset K's password through the auth API (`POST /auth/v1/recover`, the Gmail code, `PUT /auth/v1/user` with the new password; this write is named here). Then on the simulator, background and resume, and relaunch. *Pass:* at its next refresh the app lands on Log In with no red screen, and the old refresh token is refused (auth log). *Verify:* screen, auth log, console.
6. **Sign-out never passes through the paywall (125-001, 120-004).** K paid (Annual). Record at 10 fps, Settings > Sign Out > Sign out: once online, once after `netcut on --relaunch`. *Pass:* no paywall frame. The console has no `redirecting to /paywall` before Welcome, and Supabase signs out before the Pro status clears. *Verify:* recording frames, console GoRouter lines.
7. **The offline sign-out line clears Welcome's buttons (120-006).** From check 6's offline sign-out: Welcome. *Pass:* the line sits clear of "I already have an account", or dismisses on tap, and the button takes a tap while it shows. Welcome's copy is unchanged. *Verify:* screenshot, `idb ui describe-point` on the button.
8. **A paywall sign-out logs its source; offline too (120-007, 121-017).** L on the paywall: ⋯ > Sign out > Sign out. *Pass:* `settings_sign_out_tapped` carries `source: paywall`, and a Settings sign-out carries `source: settings` (check 6). Repeat L's sign-out from the paywall with `netcut on --relaunch`: it signs out with the offline line. Online again, relaunch and Log In as L: the paywall again. *Verify:* console `[ANALYTICS]`, screen.

**Findings:** 124-003, 124-004, 125-001, 120-006, 120-007; follow-ups 124-008, 124-009, 124-010 (rewritten), 120-004, 121-017.

**Decisions:** Lee's rulings in `triage-20260926.md` (124-003, 120-006, 120-007).

**Touches:** accounts K, L (deleted at the end) and M (unconfirmed, swept by the lead). One host-side password reset on K (check 5).

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/156/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] K and L are deleted through the app. M is listed under Leftover accounts.

Next: /implement-lee testing-wave
