# 32: Signup with the emailed code, and forgot password

**Status:** done (wave 9, 2026-09-24)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A new athlete signs up with email on dev, which now asks for the 6-digit code we email (Lee turned confirm-by-email on for dev on 2026-09-24). The agent reads the code from the rightpathprogramming mailbox with the Gmail tool, types it in, and lands on the paywall. Then the same account signs out and uses Forgot password: the reset email arrives, the agent follows it, sets a new password and signs in with it.

**Decisions:** none. Whether prod asks for the code is open question mp-667.

**Touches:** one new `lee+e2e-32-…` account on dev

- [x] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [x] Signs up at `lee+e2e-32-<UTC time>@rightpathprogramming.com`, logged in the credentials file at once.
- [x] The code email arrives (the Gmail tool, `from:support@mealvana.io`); its arrival time, subject and sender are in the run notes, and Resend's log agrees if the agent can reach it. A missing or late email (over 2 minutes) is a Finding.
- [x] A wrong code, an expired or reused code, and Resend code are each tried once and their result recorded; the right code opens the paywall.
- [x] Before the code is entered, `auth.users.email_confirmed_at` is empty by SQL; after, it is set.
- [x] Forgot password from the login screen: the email arrives, its link or code works on the simulator (Safari counts), the new password signs in and the old one is refused.
- [x] The account is deleted in the app at the end and marked deleted in the credentials file.

Next: /implement-lee testing-wave
