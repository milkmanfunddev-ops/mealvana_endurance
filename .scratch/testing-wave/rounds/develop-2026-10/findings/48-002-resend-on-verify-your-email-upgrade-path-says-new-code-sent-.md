# 48-002 · Resend on Verify your email (upgrade path) says New code sent but GoTrue sends nothing

- kind: bug
- status: open
- ticket: 48
- run: w5-20261008T1718Z
- screen: Verify your email
- decision: 

**Steps.**
1. Welcome → Build My Plan (anonymous session 1c31d98e-1413-4233-92ad-1991d1737355) → onboarding → Sign up with Email →
   Create Account (upgrade path, OTP type emailChange). Code 844982 mailed 17:28:44Z.
2. Wait out the countdown; tap Resend code (17:29:51Z).

**Expected.**
A new code arrives in the mailbox within a minute or two, and `auth.users.email_change_sent_at` moves to the resend time. A refusal
shows on screen; "sent" with no email is a fail (ticket 30's expected records, 01-003).

**Actual.**
- Screen: snackbar "New code sent to lee+e2e-48-20261008T1726Z@rightpathprogramming.com", Resend counts down from 59 s again.
- Auth log: `POST /resend` 200 at 17:29:52Z.
- No email arrived (mailbox read at 17:30:3xZ and 17:31Z: only the 17:27:20 and 17:28:44 codes).
- `auth.users.email_change_sent_at` stayed 17:28:44.18934 (db-48-anon-after-resend.txt, read 17:30:35Z).
- The code from before the Resend (844982) was still the live one and was accepted at 17:31:19Z.
From the log alone: GoTrue answers 200 to a resend it did not act on. A likely cause, unverified: the app resends with the new
address, but on the upgrade path the user's `email` is null and the address sits in `email_change`, so GoTrue finds no user for
it and answers 200 without sending (it does not reveal unknown addresses). The athlete is told a code is on its way and waits for
an email that never comes; the pending-signup record's send time also moves, so a relaunch counts down from the Resend, not from
the code that is really live.
Ticket 30's run said Resend sent a second code on the plain signup path (OTP type signup); this is the emailChange path only.

**Evidence.**
- runs/48/48-31-after-resend.png (snackbar)
- runs/48/auth-logs-1727-1731.txt (17:29:52Z /resend 200)
- runs/48/db-48-anon-after-resend.txt (email_change_sent_at unchanged)
- runs/48/prefs-pending-signup-before-relaunch.txt (code_sent_at moved to 17:29:52Z)

**Decision quote.**
> 

**Triage.**
