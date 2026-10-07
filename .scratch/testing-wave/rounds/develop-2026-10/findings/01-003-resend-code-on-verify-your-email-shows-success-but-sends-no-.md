# 01-003 · Resend code on Verify your email shows success but sends no new email

- kind: bug
- status: open
- ticket: 01
- run: w1-20261007T1103Z
- screen: Verify your email
- decision: 

**Steps.**
1. Welcome → Build My Plan (the app signs in anonymously), finish onboarding, Sign up with email, Create Account. The first code email arrives within a second.
2. Wait for the "Resend code in Ns" countdown to finish, tap "Resend code".
3. Watch the mailbox (`to:<address> from:support@mealvana.io`) and `auth.users.email_change_sent_at` for the user.

**Expected.**
A new code email arrives (well inside 2 minutes) and `email_change_sent_at` moves to the resend time. If the server refuses (rate limit), the screen says so ("Too many requests. Wait a minute and try again.", which the code has for that case).

**Actual.**
Done twice, both times nothing was sent while the app showed success (the countdown restarts, no error, console logs `email_verification_resent {}`):
- Pass B: first email 11:15:43Z, Resend tapped 11:16:24Z (41 s later). No email by 11:17:20Z; `email_change_sent_at` stayed 11:15:43.139Z.
- Pass C: first email 11:22:21Z, Resend tapped 11:23:33Z (72 s later, past any 60 s mail throttle). No email by 11:24Z; `email_change_sent_at` stayed 11:22:20.673Z.
The first code kept working, so the athlete is not stuck unless that first email is lost, in which case Resend never rescues them.
From code, unverified: signup here is an anonymous upgrade, so the screen resends with `OtpType.emailChange` for an address that is only in `auth.users.email_change` (the `email` column is still null). GoTrue may answer 200 without sending when no user has that address as `email`. That would also make it look like success.

**Evidence.**
- runs/01/gmail-codes.txt
- runs/01/33-B-after-resend.png
- runs/01/46-C-after-resend.png
- runs/01/db-B-before-code.txt
- runs/01/db-C-before-code.txt
- runs/01/console-redacted.log (06:16:24 and 06:23:33 local, email_verification_resent)

**Decision quote.**
> 

**Triage.**

