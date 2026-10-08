# 30-001 · Verify your email shows raw content keys (auth.verify_email.*) for the countdown, Resend, hint, Log in, errors and the resent snackbar

- kind: bug
- status: closed
- ticket: 30
- run: w3-20261008T1255Z
- screen: Verify your email
- decision: fix ticket 40 (content service initialises at startup; the lead landed it 2026-10-08 before the develop push), retest 50

**Steps.**
1. Fresh install (app data cleared), build a89ace2a. Welcome → Build My Plan → onboarding → Save My Plan → Sign up with email.
2. Fill the form, tap Create Account. Verify your email opens (12:59:29Z).
3. Type a wrong code, tap Verify. Wait out the countdown, tap Resend.

**Expected.**
The texts ticket 21 moved to `auth.verify_email.*` show their words from `assets/config/content_defaults.json`:
"Resend code in {n}s", "Resend code", "No code? This address may already have an account.", "Log in",
"That code is not right. Check the email and try again.", "New code sent to …".

**Actual.**
Every one of them shows its key: `auth.verify_email.resend_in`, `auth.verify_email.resend`,
`auth.verify_email.maybe_account_hint`, `auth.verify_email.log_in`, `auth.verify_email.error_wrong_code` under the
code field, and a snackbar `auth.verify_email.resent`. The countdown seconds never show, so the athlete cannot
see when Resend opens. "Verify", "Use a different email" and the heading are fine (not content keys).
The bundled defaults do contain the keys (checked in the installed app's
`flutter_assets/assets/config/content_defaults.json`), and dev has no active `app_content` row.
From code, unverified at runtime: `ContentService.getValue(key)` returns
`_cachedContent?.getValue(key) ?? defaultValue ?? key`, and nothing in `lib/` calls `ContentService.initialize()`,
so `_cachedContent` stays null and every call without a `defaultValue` returns the key.
`verify_email_screen.dart` calls `content.getValue(ContentKeys.verifyEmail…)` with no default. Any other screen that
does the same shows keys too (not checked here). The widget test passed because it seeds content itself.
Retest of 01-002 and 01-003: the reason chosen is right (`error_wrong_code`, not `error_expired`), but the athlete
reads a key, not a message.
Same cause on Settings (13:03Z): the Delete Account button reads `settings.delete_account_button`, the Profile row
`settings.profile_preferences_title` / `settings.profile_preferences_subtitle`, and the Delete confirm dialog shows
`settings.delete_confirm_title`, `settings.delete_confirm_body`, and two buttons `settings.confirm_cancel` and
`settings.delete_confirm_action`: an athlete cannot tell which button deletes the account. (Ticket 35's wording change is
not what this is: no words show at all.)
Also seen later in the run: the Sign Out dialog (`settings.sign_out_confirm_title`, `…_body`, `settings.confirm_cancel`,
`settings.sign_out_confirm_action`), the offline-delete snackbar `settings.delete_needs_connection`, the offline verify
line `auth.verify_email.error_generic`, and Log In's `auth.login.error_wrong_credentials`. In each case the app chose the
right message; only its words are missing.

**Evidence.**
- runs/30/30a-14-verify.png (keys on first open)
- runs/30/30a-15-wrong-code.png (`auth.verify_email.error_wrong_code` under the field)
- runs/30/30a-17-after-resend.png (`auth.verify_email.resent` snackbar)
- runs/30/30a-21-settings.png (Settings rows as keys)
- runs/30/30a-22-delete-dialog.png (Delete dialog all keys)
- runs/30/30b6-01-signout-dialog.png
- runs/30/30b6b-01-offline-delete.png
- runs/30/30b6d-01-login-deleted.png
- runs/30/db-app-content-auth-keys.txt (no active app_content row on dev)

**Decision quote.**
> 

**Triage.**
