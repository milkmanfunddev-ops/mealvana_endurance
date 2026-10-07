# 11: Signup with the emailed code, and forgot password

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:account
**Branch:** `develop-next`
**Source:** testing-wave 32 (`origin/mealplanning`); lands on the Timeline, not the paywall
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 11`
**Model:** opus

**What to test:** A new athlete signs up with email; dev asks for the 6-digit code we email (on since
2026-09-24). The run reads it with the Gmail tool and lands on the Timeline. Then the same account
signs out, uses Forgot password, sets a new password with the emailed code and signs in with it.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/11/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** one new `lee+e2e-11-<UTC time>@rightpathprogramming.com`, logged with `CRED new` before
signup. **App data:** cleared by the wave lead.

## Screens (from code, unverified)

| Screen | Route | Code |
|---|---|---|
| Welcome, onboarding | `/welcome`, `/onboarding` | see ticket 01 |
| Create account → email | `/auth/post-onboarding` → `/auth/email-signup` | `lib/features/auth/presentation/screens/` |
| Verify your email ("Verify", "Resend code in Ns", "Use a different email") | pushed by signup | `verify_email_screen.dart` |
| Log in | `/auth/email-login` (also Welcome → "I already have an account" → `/auth/post-onboarding?mode=login`) | `email_login_screen.dart` |
| Forgot password → code → new password | `/auth/forgot-password` → `/auth/verify-reset-code` → `/auth/set-new-password` | `forgot_password_screen.dart`, `verify_reset_code_screen.dart`, `set_new_password_screen.dart` |

## Expected records (`RUNS/expected.md`)

- Before the code: `auth.users.email_confirmed_at` empty. After: set.
- After the reset: the new password signs in; the old one is refused. `CRED update <address>
  --new-password` after `CRED file` keeps the old one for the refusal check.

## Steps

1. Signup to the code screen. The code email arrives (`from:support@mealvana.io`); record arrival
   time, subject, sender. Over 2 minutes is a Finding.
2. Try a wrong code once, then Resend code once (record whether the first code still works), then
   the right code. Land on the Timeline. SQL `email_confirmed_at`.
3. Settings → sign out. Log in → Forgot password. The reset email arrives; type its code; set a new
   password (`CRED type` after `--new-password`). Sign in with it. Sign out; the old password is
   refused with a clear message.
4. Delete the account in the app at the end; `CRED update --state deleted`.

## What counts as a Finding

- Missing or late email; a wrong code accepted; a resend that does nothing or keeps no cooldown.
- A reset that signs in with the old password, or leaves other sessions alive (the earlier round's
  108).
- Any paywall, Pro or entitlement screen on the way.
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/32-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 11 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-11-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-11`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/11-*.md` and `runs/11/` committed on the ticket branch, explicit paths only.
