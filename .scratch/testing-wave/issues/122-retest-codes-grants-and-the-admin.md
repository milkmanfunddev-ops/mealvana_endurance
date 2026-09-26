# 122: Retest: codes, Grants and the admin with no Pro

**Status:** in-progress (wave 38, 2026-09-26)
**Blocked by:** none.
**Pair with:** 118 (its 11-005 redeems DEVCOACH30 on a new athlete, a pending pairing to test@test.com). This run accepts and declines pairings as test@test.com (11-009): act only on your own athletes' pairings. Ticket 100 may run in the same wave on test@test.com: treat its rows as expected.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 107 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run on a build that carries tickets 102-106 (the testing app was rebuilt after them; the commit is in `.scratch/testing-wave/app-build.json`). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 87-001. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 87-003 (delete account at 10 fps: any paywall frame?), 87-004 (redeem double tap, close mid-request, spaced code), 87-005 (second giveaway on a Grant, a Grant's last day), 11-010 (Redeem code from the Subscription screen for an account that already has Pro), 11-001 (The coach's-own-code leg cannot run on a fresh account: both dev coach codes belong to test@test.com, which has already redeemed them), 11-007 (Redeem sheet paths: double-tap Redeem, close or swipe it down mid-request, reopen, software keyboard over the field), 11-008 (Influencer, giveaway, expired, not-yet-valid and used-up codes have no dev rows and have never been redeemed in the app), 11-009 (The coach sees, accepts and declines a pairing that came from a code), 12-001 (The dev admin holds three active pro Grants, so mp-416's admin-with-no-Pro case (paywall skipped, Vana refused) cannot be observed on it), 12-006 (Admin with no Pro on a slow network: the admin read is bounded by two seconds and lands on the paywall). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** 12-001 and 12-006 run on the Patrol account (lapsed on dev and `is_admin`, see `CRED list`), not on test@test.com, which holds Pro Grants. 11-001 and 11-008 use `node scripts/testing-wave/seed-codes.mjs seed`, and for the coach's own code `seed-codes.mjs own <user id>` after signing up. 87-001 redeems E2EGIVE365 after `seed-codes.mjs seed`. 87-005 uses `seed-codes.mjs seed` and `own <id> --days 1`. New accounts for the redeem and delete paths. 11-009 makes its own pairing (a new athlete redeems DEVCOACH30 or DEVCOACH18): 118's pairing went when its account was deleted (wave 36).

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and the code redemptions and pairings it makes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and follow-up test above: pass | fail | not run, evidence (paths under `runs/122/`), and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
