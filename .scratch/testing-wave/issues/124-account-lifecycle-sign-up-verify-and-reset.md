# 124: Account lifecycle: sign up, verify email and reset password

**Status:** ready-for-agent
**Blocked by:** none.
**Pair with:** 125 (same auth email budget). Dev allows 30 auth emails an hour across the wave: this run keeps to 20, 125 to 10.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 109 (Lee, 2026-09-25: about ten checks per run).

**What to build:** Part of the run through every untried account path, from the 2026-09-25 follow-up sort. It also retests ticket 108. The wave lead rebuilds the testing app first if app code changed since `app-build.json` (RUNBOOK, wave lead step 2). Nothing is fixed during the run.

**Findings to retest:** 32-003 (after a reset, `auth.sessions` holds only the new sign-in). A global sign-out revokes refresh tokens only, so the other device's current access token still reads PostgREST for up to an hour; judge 32-003 by `auth.sessions` and by the other device failing its next token refresh, not by a PostgREST read in that hour (wave 28 review).

**Follow-up tests to run:** 02-011 (Forgot password for an address with no account), 02-012 (Enter Reset Code: wrong code, expired code and Resend), 02-013 (Signing up with an address that already has an account), 02-014 (Sign up with a verify-email code on dev (confirmation turned on)), 02-017 (The account screen's price line with trial-bearing products), 04-007 (Sign Up with Email rejects a mismatched confirm password and a weak password), 32-004 (Verify your email: Use a different email), 32-005 (Verify your email: quit the app on the code screen and come back), 32-006 (Set New Password: Cancel or back after the reset code is accepted), 32-008 (No success message seen after Reset Password returns to Log In). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md`.

**Setup:** make two fresh `lee+e2e-124-…` accounts and reuse them across the paths (one for sign-up and verify, one for reset). Plan the order so one account covers several paths before its delete. The emailed code comes through the Gmail tool (RUNBOOK step 5). Count auth emails in `notes.md`: at most 20 an hour for this run. 02-014 is the same code screen ticket 32 used. 02-011 uses an address with no account: one this run deleted, or a never-used `lee+e2e` address.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] Every account made is deleted through the app at the end (or marked `delete-failed` with a Finding), and `CRED` rows updated.
- [ ] Each retest and follow-up has a verdict in `RUNS/verdicts.md`, evidence under `runs/124/`.

Next: /implement-lee testing-wave
