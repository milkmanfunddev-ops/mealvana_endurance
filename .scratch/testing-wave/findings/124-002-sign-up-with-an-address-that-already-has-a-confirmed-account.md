# 124-002 · Sign up with an address that already has a confirmed account opens Verify your email for a code that is never sent

- kind: bug
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Sign Up with Email; Verify your email
- decision: 

**Steps.**
1. Account B signed up and verified (02:30:41Z), then signed out.
2. Build My Plan, run onboarding again, Create Your Account > Sign up with Email with B's address and its own password > Create Account (02:32:45Z).
3. On the screen that opens, wait for Resend and tap it (02:33:29Z); then enter a code (123456).

**Expected.**
The "Account Already Exists" dialog with Sign In (code map item 1, 02-013). No second account, the first profile unchanged.

**Actual.**
No dialog. "Verify your email ... We sent a 6-digit code to <B>" opened. No email was sent:
auth.users confirmation_sent_at stayed 02:30:15Z and Gmail got nothing for B after 02:30:16Z. The
console logged `email_verification_required {user_id: 350cd5c1-...}`, an id that is not in
auth.users (GoTrue's decoy user for an existing confirmed address when confirmation is on, so the
app's "already exists" check never fires). Resend said "New code sent to <B>" and again nothing
was sent; a code was refused with "That code is wrong or has expired". The athlete is stuck on a
code screen that can never succeed. What held: one auth.users row for B, and its profile was not
overwritten (first_name "Rerun", gender female before and after).

**Evidence.**
- runs/124/22-signup-existing-confirmed-B.png
- runs/124/23-resend-on-fake-verify-B.png
- runs/124/24-code-on-fake-verify-B.png
- runs/124/db-after-signup-existing-B.txt
- runs/124/db-B-profile-before-delete.txt
- runs/124/console-redacted.log (email_verification_required 350cd5c1)

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: the code screen says "No code? This address may already have an account" and offers Log in. It never says whether the account exists (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
