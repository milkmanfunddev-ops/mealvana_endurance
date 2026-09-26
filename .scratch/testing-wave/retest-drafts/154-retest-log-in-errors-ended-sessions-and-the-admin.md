# 154: Retest: Log In errors, sessions the server ended, and the admin offline and without Pro

**Status:** ready-for-agent
**Blocked by:** 139.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 139 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 139's fixes and runs the folded Log In follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:**
- test@test.com (dev admin) for checks 1-3 and 7.
- The Patrol account (Admin, lapsed, no Pro; `CRED type <patrol email> --section patrol`) for check 8.
- Account F, new, `lee+e2e-154-<UTC>`, bought Annual, for checks 4, 6, 9 and 10. Check 4 needs a second address F2 that signs up and stops before the code.
- App data cleared. Offline via `netcut.sh`, slow via `netcut.sh slow`.

**Shared account:** test@test.com (sign-ins only; no data written). The Patrol account is shared with no other retest here. If a wave pairs this with another Patrol user, say so in both prompts.

**COST:** `chat` ×1 (check 8's Ask Vana on the Admin).

## Checks

1. **Log In errors sit under the form (125-002, 125-007, 112-015 step 1).** Log in with email: (a) a wrong password, (b) the right password with `netcut on --relaunch`, (c) an address with no account. *Pass:* each shows a line under the form that stays until the next edit. (a) says wrong email or password, (b) says no connection, (c) reads like (a). No 2-second snackbar. *Verify:* screenshots at 0 s and 5 s, then after one keystroke.
2. **Double tap Log In, Forgot Password, What's New once (112-015 steps 2-4).** Double tap Log In with the right password. *Pass:* one sign-in (one `/token` call in the auth log). Forgot Password opens. What's New shows after this sign-in and not on the next relaunch. The notification prompt shows once (see 152). *Verify:* screen, console.
3. **Several wrong passwords in a row (120-011).** Five or more wrong passwords fast on test@test.com. *Pass or record:* what the app says when Supabase rate-limits (429). A bare "check your credentials" on a 429 is a bug Finding. Wait out the limit before the next check. *Verify:* screenshot, console status codes.
4. **Log In with an unconfirmed email reaches the code (124-001).** F2 signs up by email and stops on Verify your email. Terminate, relaunch, Log In with F2. *Pass:* the app resends the signup code and opens Verify your email for F2. The code from Gmail then continues as signup does. Record whether the onboarding answers survived. F2 is then deleted from its paywall. *Verify:* screen, Gmail, SELECT `auth.users.email_confirmed_at`.
5. **Cancelled Google and Apple sign-in stay quiet (125-003, 125-009).** Welcome > I already have an account > Continue with Google > Continue > close with X. Then on the post-onboarding Create Your Account, the same for Apple and Google. *Pass:* no "Sign in failed" and no error log for the cancel. The simulator's Apple `unknown` (no Apple Account) may still show a failure: record which. *Verify:* screenshots, console.
6. **A session the server ended goes to Log In (117-011, 117-012).** F signed in, app terminated. Password grant for F, then `POST /auth/v1/logout?scope=global` (this write is named here). Cold start, visit Timeline and Food. *Pass:* one refresh attempt, then Log In, with no red screen and no run of 401s from Vana (at most one). 117-012's leg: note F's last sign-in time. If the run lasts past one hour from it, repeat with the access token expired and the refresh token revoked. Otherwise write "not seen live: under an hour". *Verify:* console, auth log, screenshots.
7. **The admin read does not loop offline (118-003, 119-004, 120-009).** test@test.com signed in, `netcut on --relaunch`, 2 minutes across Timeline, Log a Meal and Settings, then `off`. *Pass:* `[IS_ADMIN] is_admin read failed` appears a handful of times at most (one read, one retry on online or resume), not hundreds. *Verify:* `grep -c` on console-redacted.log.
8. **An Admin with no Pro gets every feature; a slow admin read (122-004, 122-009 rewritten).** Patrol account: Log In, then `COST spend WAVE chat 154`, Ask Vana. *Pass:* the opener answers (no 403 `pro_required`, and no Retry link if a refusal ever shows). Settings > Subscription shows what an admin has. 122-009 was not run in wave 38 because the old shim failed TLS. Rewritten with the proven proxy: `netcut.sh slow 3000 --relaunch UDID`, cold launch and time the first screen and the `[IS_ADMIN]` / `GoRouter` lines. *Pass:* the admin lands in the app, not on the paywall, within the entitlement wait plus the admin read. *Verify:* screen, `vana_calls` row, edge logs (200), console timings.
9. **Sign out offline, log back in offline (120-015).** F online, a Manual log `W<WAVE>-154`, `on`, Sign Out, then Log In as F still offline. *Pass:* a clear no-connection line (check 1). The unsynced log stays on the phone and reaches dev after the next online sign-in. *Verify:* screen, SELECT after going online.
10. **Welcome: log in offline; after a refused offline delete (121-012, rewritten leg 2).** Cut the network on Welcome > I already have an account > Log in with email as F: the no-connection line. Leg 2 as written followed an offline delete that signed out. Since 139 an offline delete stays signed in, so it is rewritten: F online, `on`, Settings > Delete account > Delete. *Pass:* the app stays signed in and says it needs a connection. `off`, and F still exists on dev. *Verify:* screen, SELECT `auth.users` for F.

**Findings:** 125-002, 125-007, 124-001, 125-003, 117-011, 118-003, 119-004, 120-009, 122-004; follow-ups 112-015, 120-011, 125-009, 117-012, 122-009 (rewritten), 120-015, 121-012 (leg 2 rewritten).

**Not counted (device: not run on simulator):** 125-009's "Don't share / Hide My Email" with a real Apple ID.

**Decisions:** Lee's rulings in `triage-20260926.md` (122-004 supersedes mp-416's server check for admins; 125-007/125-002).

**Touches:** test@test.com (sign-ins only). Patrol account (one chat). Accounts F and F2 (made and deleted). One global logout on F (named in check 6).

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/154/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] F and F2 are deleted through the app. The slow proxy is stopped by its PID.

Next: /implement-lee testing-wave
