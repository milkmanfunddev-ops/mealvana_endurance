# Signup email verification — setup and prod runbook

Status as of 2026-07-28:

| | Dev (`vlmtsdzpnjnavdgytcmi`) | Prod (`wvmvsodrvbkxfydabqed`) |
|---|---|---|
| `mailer_autoconfirm` | **false** (verification required) | `true` (still auto-confirms) |
| Confirmation template | 6-digit `{{ .Token }}` | still `{{ .ConfirmationURL }}` link |
| Custom SMTP | **Resend** (`smtp.resend.com:465`) | **Resend** (`smtp.resend.com:465`) |
| Sender | `support@mealvana.io` | `support@mealvana.io` |
| Client flow | shipped | shipped (inert until prod flips) |

## Resend was already here — but not where it counted

The `RESEND_API_KEY` secret and `secrets/resend.env` predate this work, and
`send-nutrition-plan-email` has been calling `api.resend.com` directly since
2026-07-01. That is the **Resend HTTP API**, a completely separate path from
Supabase Auth.

Supabase Auth had `smtp_host = null` and `hook_send_email_enabled = false`, so
every auth email — signup confirmation *and password reset* — was going through
Supabase's built-in mailer, which only delivers to project team members. Which
means **password-reset emails have not been reaching real users**. Wiring the
existing Resend key into Auth SMTP (done 2026-07-28, both projects) fixes
signup verification and password reset in one move.

`smtp_port` must be sent as a **string** — the API rejects a JSON number with
`smtp_port: Invalid input: expected string, received number`.

The client code is environment-agnostic: it branches on whether Supabase
returns a session, so it does the right thing on both projects without a flag.

---

## Why prod is not flipped yet

**Supabase's built-in mailer cannot email your users.** It is not merely rate
limited — per Supabase's own SMTP guide it "will only send messages to
pre-authorized addresses" (your project's team members); everything else fails
with `Email address not authorized`. It also carries "no SLA guarantee on
message delivery or uptime" and is "provided as best-effort only", with a
default of 2 messages per hour.

So flipping prod without custom SMTP would create accounts that can never be
verified. Custom SMTP raises the initial limit to 30 messages/hour (adjustable).

---

## Prod runbook

### 1. Resend account + verified domain

Resend is one of Supabase's supported providers. Free tier is 3,000
emails/month and 100/day — comfortably above signup volume.

You must **verify a sending domain** (a mealvana domain) via DNS. Without it
you can only send to your own account address, which reproduces exactly the
limitation we're trying to escape.

### 2. Put the SMTP credentials in Supabase

Supabase Dashboard → the **prod** project → Authentication → Emails → SMTP
Settings:

| Field | Value |
|---|---|
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | your Resend API key |
| Sender email | e.g. `noreply@<your-verified-domain>` |
| Sender name | `Mealvana Endurance` |

**Do this step yourself in the dashboard.** The API key is a credential; it
should not be pasted into a chat, a repo file, or a shell command where it
lands in history.

Send the built-in test email before continuing.

### 3. Flip the auth config

Once SMTP is live, apply the same three changes dev already has. The
Management API works, but note two traps found while doing dev:

- Cloudflare rejects Python `urllib` with `error code: 1010`. Use `curl`.
- Send the payload as `--data-binary @file`, not inline, so the template's
  quotes and newlines survive.

```bash
TOKEN=$(security find-generic-password -s "Supabase CLI" -w \
        | sed 's/^go-keyring-base64://' | base64 -d)

curl -s -X PATCH \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data-binary @prod_auth_payload.json \
  "https://api.supabase.com/v1/projects/wvmvsodrvbkxfydabqed/config/auth"
```

`prod_auth_payload.json` sets:

- `mailer_autoconfirm: false`
- `mailer_subjects_confirmation: "Your Mealvana Endurance verification code"`
- `mailer_templates_confirmation_content`: the `{{ .Token }}` template (copy
  the live value from dev so the two stay identical)

Also consider raising `rate_limit_email_sent` once SMTP is in place.

### 4. Verify

```bash
curl -s -X POST "https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/signup" \
  -H "apikey: <prod anon key>" -H "Content-Type: application/json" \
  -d '{"email":"<a real inbox you control>","password":"..."}'
```

Correct behaviour: a user id comes back, `confirmed_at` is null, and there is
**no** `access_token`. Then confirm the code actually arrives, and complete the
signup in the app.

Delete the test user afterwards.

---

## What was checked before flipping dev

- **Nobody gets locked out.** Every existing user on both projects is already
  confirmed: prod 1024 users / 133 with an email / **0 unconfirmed**; dev 568 /
  70 / **0 unconfirmed**. `mailer_autoconfirm` only governs new signups, so
  there is no retroactive lockout.
- **Anonymous auth is unaffected.** 891 of prod's users are anonymous
  (`is_anonymous`), and anonymous sessions don't go through email confirmation.
- **Verified live on dev**: a real signup against the dev API returned a user
  with `email_confirmed_at = null` and **no access token**, and the auth log
  shows `mail.send` with `mail_type: confirmation`. Test user deleted.

---

## The client flow

`signUp` returning a null session is the signal. `EmailAuthService` throws
`EmailVerificationRequiredException` at that point and stops — deliberately
*before* the post-signup work, because everything after it (the onboarding-data
migration, every RLS-protected write) needs an authenticated session that does
not exist yet.

`VerifyEmailScreen` collects the 6-digit code and calls
`verifyEmailOtp(type: OtpType.signup)`. On success Supabase issues the session,
`userIdProvider` is invalidated, and the signup screen resumes exactly where an
auto-confirmed signup would have.

Details worth keeping:

- The screen sets `canPop: false`. Backing out would strand a created-but-
  unverified account with no route back to the code entry. "Use a different
  email" is the deliberate escape hatch.
- The code field uses `AutofillHints.oneTimeCode`, so iOS offers the emailed
  code above the keyboard.
- Resend starts on a 30s cooldown, because signup has already sent one code.
- Expired vs. wrong codes produce different messages; a rate-limited resend
  reads as "wait a moment", not "something is broken".

## ⚠️ The Resend key in use was leaked to git and never rotated

`docs/test/BUGS_FOUND.md` recorded that a live Resend key was committed to
`send-nutrition-plan-email/index.ts` as a hardcoded fallback. The source
fallback is gone, but the key itself was never changed: the value in
`secrets/resend.env` today has the same `re_DHjg7ayY_` prefix as the one in
the commit history (`077ac41e`, `f65090b6`). It is permanently in the git
history, and the repo has since been transferred to the
`milkmanfunddev-ops` org — anyone who ever had clone access still has it.

It is a **send-only restricted** key (it cannot read domains or logs, confirmed
by API), so the blast radius is bounded — but that radius is "can send mail as
`support@mealvana.io`", i.e. phish your users from your own verified domain.

Wiring it into Auth SMTP raises the stakes, because it now also carries signup
and password-reset mail. **Rotate it:**

1. Create a fresh send-only key in Resend, revoke the old one.
2. Update `secrets/resend.env`.
3. `supabase secrets set RESEND_API_KEY=… ` on **both** projects (for the
   edge function).
4. Re-PATCH `smtp_pass` on both projects (for Auth).

## Follow-up not required for this to work

`site_url` and `uri_allow_list` on **both** projects still point at a stale
Vercel preview URL (`mealvanaendurancecoachmode-abrgl2ueg-…`). OTP codes don't
use redirects so this doesn't affect signup, but it does affect password-reset
and any future magic-link flow, and it should be corrected.
