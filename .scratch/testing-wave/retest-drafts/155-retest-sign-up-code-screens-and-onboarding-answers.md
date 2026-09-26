# 155: Retest: sign-up, the code screens, and onboarding answers

**Status:** ready-for-agent
**Blocked by:** 139.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 139 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 139's fixes and runs the folded sign-up and onboarding follow-ups. Onboarding body copy is Xuan's and is not judged. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** app data cleared, simulator clock zone as the dev simulator (US Central; write it in notes). New addresses, each made with `CRED new` before sign-up. G is confirmed and kept to the end for check 3. H is abandoned in check 4. I and J are ordinary sign-ups. Codes are read from Gmail (`to:<address> from:support@mealvana.io`). Dev's `smtp_max_frequency` is 60 s: space the mails.

**Shared account:** none.

**COST:** none.

## Checks

1. **Resend waits as long as the server does (121-001).** Sign up I, reach Verify your email. *Pass:* "Resend code in Ns" counts down from 60. A tap at zero sends a mail (Gmail shows a second one) with no 429. If a 429 does come, the screen says "after N seconds" and counts N, never a bare "Failed to resend code". *Verify:* screenshots at 0/30/60 s, Gmail, console status.
2. **An old code points to the newest email (121-002).** After check 1's resend, type the first mail's code. *Pass:* the message says only the newest email's code works and does not tell you to tap Resend. The newest code then verifies. *Verify:* screenshot.
3. **An existing account's address (124-002, 124-007).** G signs up, verifies, signs out. Build My Plan > onboarding > Sign up with Email with G's address (a) and its password, (b) and a different password (typed by hand, not stored). *Pass:* the code screen shows "No code? This address may already have an account" with Log in, which opens Log in with email with the address filled. It never says whether the account exists. After (b) G's old password still signs in and `auth.users` is unchanged (updated_at). *Verify:* screen, SELECT (id, updated_at, email_confirmed_at).
4. **Use a different email (121-003, 121-014).** Sign up H, reach Verify your email, tap Use a different email. *Pass:* H's auth user is gone within seconds (`discard-signup` answered 200), and the form still holds H's address and both password fields. Change only the address to J > Create Account > verify J. Also on that form: a mismatched Confirm Password is refused before any request. *Verify:* SELECT `auth.users` for H before and after, `discard-signup` edge log, screen.
5. **A verified signup goes straight to the paywall (121-011).** Record at 10 fps while entering J's right code. *Pass:* no frame of Create Your Account's sign-up buttons between the code and the paywall; its busy state shows instead. *Verify:* recording frames.
6. **`public.users.created_at` is the real instant (120-003, 121-004).** For J: SELECT `auth.users.created_at` and `public.users.created_at`. *Pass:* they are within a minute of each other (not 5 h or 10 h early). Existing dev rows are known to be off (139 notes). Only J's is judged. *Verify:* SELECT.
7. **Verify your email survives a kill; an old code (121-015).** Sign up I again if it was deleted, or a new address. Reach the code screen, kill the app, relaunch. *Pass or record:* where it lands. If it lands on Welcome, Log In reaches the code (see 154 check 4). The "code older than an hour" leg: keep the first code mail and try it at the end of the run if an hour has passed, else "not seen live". *Verify:* screen, times in notes.
8. **Onboarding keeps its answers (118-009, 121-013).** Walk onboarding with non-default answers (sports, goals, body). Go back to the first step and forward again. Kill the app on the plan reveal step and relaunch. Tap Connect now on the Connect with Garmin card before any account exists. Back from Sign Up with Email and from Verify your email (Use a different email), then forward. *Pass:* the answers are kept each time, or the loss is filed with the step. Garmin before an account says what it needs, or waits, and does not crash. *Verify:* screenshots, and the profile row after the account is made.
9. **A weak password of 8+ characters (124-006, rewritten).** As written it was skipped, because a server-accepted weak password would make an account whose password is not in the credentials file. Rewritten: sign up a fresh address with an 8-letter all-lowercase common word (not a secret; it may appear in notes), matching confirm. *Pass or record:* the app refuses it with a clear rule, or the server accepts it. If accepted, verify with the code and delete the account from the paywall ⋯ in the same minute. This address gets no `CRED` row. Name the address in notes as "weak-password test, deleted". *Verify:* screen, SELECT `auth.users` afterwards (gone).

**Findings:** 121-001, 121-002, 124-002, 121-003, 121-011, 120-003, 121-004; follow-ups 124-007, 121-014, 121-015, 118-009, 121-013, 124-006 (rewritten).

**Decisions:** Lee's rulings in `triage-20260926.md` (124-002, 121-003). Onboarding copy is Xuan's.

**Touches:** accounts G, H, I, J and the weak-password address, all made and deleted in the run (H by `discard-signup`). No shared account.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/155/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Every account made is deleted. An unconfirmed leftover is named under "Leftover accounts" for the lead's sweep.

Next: /implement-lee testing-wave
