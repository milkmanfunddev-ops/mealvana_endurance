# 125: Account lifecycle: delete, sign out, log in and the first-login sheets

**Status:** ready-for-agent
**Blocked by:** none.
**Pair with:** 124 (same auth email budget): this run keeps to 10 auth emails an hour.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 109 (Lee, 2026-09-25: about ten checks per run).

**What to build:** Part of the run through every untried account path, from the 2026-09-25 follow-up sort. It also retests ticket 108. The wave lead rebuilds the testing app first if app code changed since `app-build.json` (RUNBOOK, wave lead step 2). Nothing is fixed during the run.

**Findings to retest:** none (ticket 108's two retests are in tickets 124 and 111).

**Follow-up tests to run:** 02-008 (A failed delete-user call is reported to the athlete, not hidden behind a normal sign-out), 02-009 (Delete account → Cancel on both confirm dialogs keeps the account and its session), 02-010 (Signing in with a deleted account's old password gives a clear error), 02-015 (Delete account while offline), 02-016 (Delete account for a Lapsed account from the paywall menu), 06-007 (A paid account signs out offline, and cancels the Sign Out dialog once first), 06-008 (A paid account's email Log In with a wrong password first, then the right one), 07-007 (Log In after a reinstall: offline, wrong password, Apple and Google sign-in for a paid account, and a Lapsed account), 31-012 (After sign-out: log back in as the same account and as a different account on the same phone), 12-008 (First login stacks the What's New sheet and the TrainingPeaks sharing sheet over the timeline), 07-009 (The What's New sheet shows again after a reinstall for an account that already dismissed it), 31-010 (Notification permission prompt: first shown on the second launch; test Allow and what it writes). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md`.

**Setup:** make two or three fresh `lee+e2e-125-…` accounts and reuse them across the paths (one to delete, one paid through the Test Store for 06-007, 06-008 and 07-007, one left to lapse for 02-016 and 07-007). Plan the order so one account covers several paths before its delete; 02-010 signs in with the deleted account's old password. The emailed code comes through the Gmail tool (RUNBOOK step 5); count auth emails in `notes.md`, at most 10 an hour for this run. 31-012 signs test@test.com out and back in on this run's simulator. 12-008, 07-009 and 31-010 are about the first-login sheets and the notification prompt: note what shows on each fresh sign-in.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] Every account made is deleted through the app at the end (or marked `delete-failed` with a Finding), and `CRED` rows updated.
- [ ] Each retest and follow-up has a verdict in `RUNS/verdicts.md`, evidence under `runs/125/`.

Next: /implement-lee testing-wave
