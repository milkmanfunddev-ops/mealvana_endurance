# 157: Retest: Delete account from every door, online, offline and slow

**Status:** ready-for-agent
**Blocked by:** 139.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 139 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 139's delete fixes and runs the folded delete follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`. A delete that fails (the account is still on dev after an online delete) stops the run: write the Finding, `RUNS/STOPPED.md`, go to step 9.

**Accounts and start state:** app data cleared. Every account is new (`CRED new`) and ends deleted:
- N: bought Annual. Makes the unsynced rows for checks 5 and 6.
- O: never paid, on the onboarding paywall (checks 1, 2, 5).
- P: bought nothing. `node scripts/testing-wave/seed-states.mjs grant P --minutes 2` after sign-up, and it lapses to the full-screen paywall (checks 3 and 4). One grant per account (RUNBOOK step 5).
- Q: bought Annual, with one activity and its stored plan (checks 7 and 8).
- R: holds Pro from its own coach code: `seed-codes.mjs own <R's user id>`, then redeem it from the paywall ⋯ (check 9). Do not run `seed-codes.mjs seed`; ticket 159 owns the shared `E2E*` codes.

**Shared account:** none. test@test.com is not used.

**COST:** none.

## Checks

1. **Delete account offline stops and says so (121-007).** O on the paywall, `netcut on --relaunch`, ⋯ > Delete account > Delete. *Pass:* O stays signed in on the paywall with a needs-a-connection message. No local wipe, no RevenueCat logout. After `off`, `auth.users` and `public.users` still hold O. *Verify:* screen, SELECT, RevenueCat customer read.
2. **An online delete completes; the post-delete 403 (121-009).** O online: ⋯ > Delete account > Delete. *Pass:* Welcome. O is gone from `auth.users`, `public.users` and RevenueCat. 139 closed the `/auth/v1/logout` 403 as expected after a delete, so record whether it still shows and pass either way. *Verify:* SELECT, RevenueCat read, auth request log for the minute.
3. **The Lapsed paywall's delete analytics (115-004).** P lapsed on the full-screen paywall: ⋯ > Delete account. Read the confirm (for check 4), then Delete. *Pass or record:* the analytics line fired, and whether it tells the Lapsed paywall apart from the onboarding one. If it cannot, file an idea Finding naming the event. *Verify:* console `[ANALYTICS]`.
4. **The confirm's words for a plan that ended (123-007 leg 1).** From check 3's confirm, before Delete. *Pass:* it does not say a subscription keeps renewing when P's Pro was a Grant that ended. *Verify:* screenshot. Leg 2 (a store plan still renewing) is covered by check 8.
5. **Another account's unsynced rows survive an in-app delete (120-012).** N signed in, `on`, Manual log `W<WAVE>-157 N-unsent`, sign out offline (the row stays local). `off`. Sign up O's replacement O2 and delete O2 from its paywall. Read the local sqlite: N's dirty row is still there. Log In as N. *Pass:* the row uploads to dev under N. *Verify:* local sqlite read, SELECT `meal_logs` for N.
6. **Offline edit, then delete, of an unsynced log before sign-out (120-013).** N, `on`: Manual log `W<WAVE>-157 edit`, edit it, sign out offline, `off`, Log In: dev gets the edited version. Again with a log that is deleted before sign-out: dev never gets it (or gets it already deleted). *Pass:* both. *Verify:* SELECT after each sign-in.
7. **No lookup of the deleted account's activity (116-015).** Q: open its activity, back to the Timeline, Settings > Delete account > Delete. *Pass:* in the 5 s after the delete the console has no `[ACTIVITIES_SERVICE] Activity not found` or other query for Q's user id. *Verify:* console-redacted.log around the delete.
8. **Delete a Pro account: the confirm and RevenueCat (121-019, 123-007 leg 2).** Before check 7's Delete tap, read Q's confirm (Annual, renewing) and tap Manage subscription once, then come back and Delete. *Pass:* the confirm says the store subscription keeps renewing and how to cancel it (ticket 78). Manage opens and returns. After the delete, RevenueCat's customer is removed (ticket 95), and the record says what happened to its subscription. *Verify:* screenshots, RevenueCat read before and after.
9. **Delete on a slow network builds no paywall (122-012, rewritten).** As written it asked for a device and a slow network. The device half stays out of the count. The slow half now runs on the simulator: R with Pro from its code, `netcut.sh slow 1500 --relaunch UDID`, record at 10 fps, Settings > Delete account > Delete. *Pass:* no paywall frame, and the console shows no `/paywall` redirect or `offerings fetched` between the tap and Welcome. *Verify:* recording, console.

**Not counted:** 122-012's device leg ("device: not run on simulator"). The Garmin deregistration on account delete (121-010 item 2) needs an account connected to a Garmin test user (see 153).

**Findings:** 121-007, 121-009; follow-ups 115-004, 123-007, 120-012, 120-013, 116-015, 121-019, 122-012 (rewritten).

**Decisions:** Lee's rulings in `triage-20260926.md` (121-007, 121-009 via 139). Ticket 95: account deletion also deletes the RevenueCat customer.

**Touches:** accounts N, O, O2, P, Q and R, all deleted. One seeded grant (P), one owned coach code (R, deleted with the account). No shared account.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/157/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Every account made is deleted, with its `CRED` state set to deleted (or delete-failed, with a stop).

Next: /implement-lee testing-wave
