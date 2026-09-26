# 158: Retest: paywall purchases, Restore, and the lapsed paywall offline and back online

**Status:** ready-for-agent
**Blocked by:** 140.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 140 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 140's paywall fixes and runs the folded paywall follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`. Ticket 140 was still building when this was written, so the lead checks its final notes before the prompt.

**Accounts and start state:** app data cleared. New accounts only (`CRED new`):
- S: never paid, on the onboarding paywall (checks 1, 3, 4, 7, 9).
- T: `seed-states.mjs grant T --minutes 2` right after sign-up. Lapses to the full-screen paywall about 2 minutes later (checks 2, 5, 6, 10). Never a Test Store monthly for a lapse (RUNBOOK step 5). One grant per account.
- U: buys Monthly for check 8 only (a renewal check, not a lapse).

**Shared account:** none.

**COST:** none.

## Checks

1. **A failed purchase says so (121-005).** S: Monthly > Continue > Test failed purchase. *Pass:* the purchase-failed snackbar shows, and Continue is live again. Cancel on the sheet (second try) stays quiet. *Verify:* screenshots, console.
2. **The same on the lapsed paywall (123-002).** T lapsed: Monthly > Continue > Test failed purchase. *Pass:* same as check 1. *Verify:* same.
3. **One purchase per intent (121-008).** S: Annual, two Continue taps about 2 ms apart (`idb ui tap` twice). Then Test valid purchase. *Pass:* one Test Store sheet and one purchase. RevenueCat shows one transaction, and the console shows no second `purchase` start. *Verify:* RevenueCat read (subscriptions and transactions), console.
4. **An offline restore says it could not check (121-006).** Before check 3: S on the paywall, `netcut on --relaunch`, ⋯ > Restore purchases. *Pass:* a message that the check needs a connection. Never "No active subscription was found". *Verify:* screenshot.
5. **The lapsed paywall offline (125-008, 123-005).** T lapsed, `on --relaunch`: ⋯ > Restore purchases, ⋯ > Manage subscription, Continue with Monthly, then ⋯ > Sign out. *Pass:* each says it needs a connection, or does its offline behaviour clearly. Nothing claims a verdict on the account. Sign out works with the offline line (120-006). *Verify:* screenshots, console.
6. **Back online, the paywall retries by itself (123-009).** T signed back in, lapsed, `on --relaunch`: "Plans aren't available right now". `off` with no resume and no tap. *Pass:* within about 15 s the plans load (a timer re-read; netcut keeps connectivity "online", so the timer is what you see). *Verify:* screenshots with times, console fetch lines.
7. **Paywall offline: Terms, Privacy, Redeem (121-016).** S (before check 3), `on`: tap Terms of Use and Privacy Policy, then ⋯ > Redeem code with any code. *Pass:* the links say they need a connection or open a cached page. Redeem says it needs a connection. Nothing hangs. *Verify:* screenshots.
8. **The Test Store sheet backgrounded; Monthly's renewals (121-018).** U: Continue, Home on the Test Store sheet, back after 30 s, Test valid purchase. Then stay on the Timeline over two 5-minute renewals. *Pass:* the purchase completes after the resume. The two renewals show no paywall frame, and `user_entitlements.active_until` moves each time. Write clock times before and after each wait. *Verify:* screen, SELECT, RevenueCat read.
9. **The first Timeline after purchase (121-020).** Right after check 3's purchase, watch the first seconds without tapping. *Pass or record:* whether a "New in Mealvana" sheet opens for a brand-new account. If it does, file an idea Finding (What's New for someone with nothing to compare). *Verify:* recording or screenshots.
10. **The lapsed paywall after Pro is given elsewhere (123-006, rewritten).** As written it needed a Grant from outside the app on a lapsed account. The seeded grant is one per account, so a second RevenueCat grant writes nothing. Rewritten: T lapsed sits on the paywall. From the host, redeem T's own coach code (`seed-codes.mjs own <T's id>`) by calling `redeem-code` with T's token (this write is named here). Then Home, wait a minute, resume, and separately wait on the paywall untouched. *Pass:* the paywall lets T in on resume or by its timer. If RevenueCat writes no grant (SELECT `user_entitlements`), the check is "not runnable: one grant per account", and 123-006 goes back to the lead to rewrite for a device. *Verify:* SELECT, RevenueCat read, screen.

**Not counted (device: not run on simulator):** 123-001 (a plan's last period reads "Ends on …": 140 item 6 asks for an App Store sandbox cancel first) and 123-008 (a late EXPIRATION after an Annual purchase keeps `will_renew`. On a simulator it needs a Test Store monthly to end, which it does not do while signed out, 117-015. 140's deno test covers the webhook). Each gets a verdict row "device: not run on simulator".

**Findings:** 121-005, 123-002, 121-008, 121-006, 123-009; 123-001 and 123-008 (not counted); follow-ups 125-008, 123-005, 121-016, 121-018, 121-020, 123-006 (rewritten).

**Decisions:** mp-457 / mp-494 (lapsed paywall and its ⋯ menu), mp-679 (renewal grace).

**Touches:** accounts S, T and U (deleted at the end), one seeded grant (T), one owned coach code redeemed from the host (T).

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/158/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] S, T and U are deleted through the app.

Next: /implement-lee testing-wave
