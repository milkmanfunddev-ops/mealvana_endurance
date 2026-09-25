# 107: Retest the fixes of 102 to 106, and wave 25's follow-up tests

**Status:** ready-for-agent
**Blocked by:** 102, 103, 104, 105, 106.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run on a build that carries tickets 102-106. The wave lead rebuilds the testing app first (RUNBOOK, wave lead step 2). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 86-001, 86-007, 86-012, 86-004, 86-005, 86-006, 87-006, 87-009, 87-001, 87-007, 87-008. For 86-012 (found by code reading) check it by its fix ticket's tests and one sync of a repository holding a row the server refuses, if the run can make one safely; otherwise mark it not run.

**Follow-up tests to run:** 86-002 (local plan status against dev after login), 86-003 (Plan tab within 5-10 s of login), 86-008 (wrong password, double-tap Log In), 86-009 (Use a different email, superseded code), 86-010 (connected app's name suggestion leaves the email alone), 86-011 (paywall Delete account offline), 87-003 (delete account at 10 fps: any paywall frame?), 87-004 (redeem double tap, close mid-request, spaced code), 87-005 (second giveaway on a Grant, a Grant's last day).

**More follow-up tests (Lee, 2026-09-25, cap of ten lifted for this pass):** 04-002 (A signed-in new account relaunched cold lands on the paywall again), 04-003 (Restore purchases on a new account with nothing to restore), 04-004 (Paywall offline or with no offerings shows the pricing-unavailable state and still no way off), 04-005 (Continue then cancel the Test Store sheet leaves the new account on the paywall), 05-008 (Lapsed paywall menu: Manage subscription and Restore purchases for an expired Test Store subscription), 05-010 (Paywall Continue tapped twice, or during the 2.4 s after a purchase, buys once), 09-011 (Lapsed paywall: Sign out from the menu, log back in, and relaunch while offline), 10-003 (Lapsed paywall: resubscribe with Annual, with Test failed purchase then retry, and with Cancel on the Test Store sheet), 10-005 (Resubscribe on the same device the account used before the lapse (local data present) and let the new subscription lapse again), 07-008 (Subscription screen for a paid account: which plan, its price and the renewal time), 08-005 (Subscription screen on return from Manage subscription, and Manage tapped twice or offline), 11-010 (Redeem code from the Subscription screen for an account that already has Pro), 11-001 (The coach's-own-code leg cannot run on a fresh account: both dev coach codes belong to test@test.com, which has already redeemed them), 11-007 (Redeem sheet paths: double-tap Redeem, close or swipe it down mid-request, reopen, software keyboard over the field), 11-008 (Influencer, giveaway, expired, not-yet-valid and used-up codes have no dev rows and have never been redeemed in the app), 11-009 (The coach sees, accepts and declines a pairing that came from a code), 07-011 (Home and resume on the Subscription screen does not refetch the customer after a renewal), 12-001 (The dev admin holds three active pro Grants, so mp-416's admin-with-no-Pro case (paywall skipped, Vana refused) cannot be observed on it), 12-006 (Admin with no Pro on a slow network: the admin read is bounded by two seconds and lands on the paywall), 12-007 (Admin signs out and a Lapsed athlete signs in on the same device: the Gate must close, not inherit the admin's answer), 06-004 (Sign in as a paid account on a device whose RevenueCat SDK last held a different, unpaid account). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup for the added follow-ups:** 12-001 runs on the Patrol account (lapsed on dev and `is_admin`, see `CRED list`), not on test@test.com, which holds Pro Grants. 11-001 and 11-008 use `node scripts/testing-wave/seed-codes.mjs seed`, and for the coach's own code `seed-codes.mjs own <user id>` after signing up.

**Setup:** 86-001 and 86-007 need two accounts on one phone: test@test.com plus a new account, with rows of the first left unsynced (`netcut.sh on`, a Manual meal log) before signing out and in as the other; read the local Drift database read-only before and after each step, as run 86 did. 87-006 and 87-009 need a Test Store monthly (5-minute periods, ends after five): plan around the 25-minute lapse. 87-005 uses `seed-codes.mjs seed` and `own <id> --days 1`. New accounts for signup, delete and redeem paths. Ticket 100 may run in the same wave on test@test.com: treat its rows as expected.

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and follow-up test above: pass | fail | not run, evidence, and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
