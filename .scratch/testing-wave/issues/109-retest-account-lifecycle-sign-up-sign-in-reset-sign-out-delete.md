# 109: Account lifecycle run: sign up, sign in, reset, sign out, delete

**Status:** ready-for-agent
**Blocked by:** 108.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** One run through every untried account path, from the 2026-09-25 follow-up sort (Lee: fold every open follow-up test into as few runs as possible, cap of ten lifted for this pass). It also retests ticket 108. The wave lead rebuilds the testing app first if app code changed since `app-build.json` (RUNBOOK, wave lead step 2). Nothing is fixed during the run.

**Findings to retest:** 32-003 (after a reset, `auth.sessions` holds only the new sign-in), 22-005 (a leftover Kroger connection from the other environment shows and can be removed; test@test.com's production row, if it is still there).

**Follow-up tests to run:** 02-008 (A failed delete-user call is reported to the athlete, not hidden behind a normal sign-out), 02-009 (Delete account → Cancel on both confirm dialogs keeps the account and its session), 02-010 (Signing in with a deleted account's old password gives a clear error), 02-011 (Forgot password for an address with no account), 02-012 (Enter Reset Code: wrong code, expired code and Resend), 02-013 (Signing up with an address that already has an account), 02-014 (Sign up with a verify-email code on dev (confirmation turned on)), 02-015 (Delete account while offline), 02-016 (Delete account for a Lapsed account from the paywall menu), 02-017 (The account screen's price line with trial-bearing products), 04-007 (Sign Up with Email rejects a mismatched confirm password and a weak password), 06-007 (A paid account signs out offline, and cancels the Sign Out dialog once first), 06-008 (A paid account's email Log In with a wrong password first, then the right one), 07-007 (Log In after a reinstall: offline, wrong password, Apple and Google sign-in for a paid account, and a Lapsed account), 31-012 (After sign-out: log back in as the same account and as a different account on the same phone), 32-004 (Verify your email: Use a different email), 32-005 (Verify your email: quit the app on the code screen and come back), 32-006 (Set New Password: Cancel or back after the reset code is accepted), 32-008 (No success message seen after Reset Password returns to Log In), 12-008 (First login stacks the What's New sheet and the TrainingPeaks sharing sheet over the timeline), 07-009 (The What's New sheet shows again after a reinstall for an account that already dismissed it), 31-010 (Notification permission prompt: first shown on the second launch; test Allow and what it writes). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md`.

**Setup:** make two or three fresh `lee+e2e-109-…` accounts and reuse them across the paths (one for sign-up and reset, one to delete, one to switch to on the same phone). Plan the order so one account covers several paths before its delete. The emailed code comes through the Gmail tool (RUNBOOK step 5). Dev allows 30 auth emails an hour: count them in `notes.md`. 02-014 is the same code screen ticket 32 used. 12-008, 07-009 and 31-010 are about the first-login sheets and the notification prompt: note what shows on each fresh sign-in.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and test@test.com's Kroger connection (22-005).

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] Every account made is deleted through the app at the end (or marked `delete-failed` with a Finding), and `CRED` rows updated.
- [ ] Each retest and follow-up has a verdict in `RUNS/verdicts.md`.

Next: /implement-lee testing-wave
