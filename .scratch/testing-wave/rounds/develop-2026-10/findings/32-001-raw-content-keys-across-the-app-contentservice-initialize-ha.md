# 32-001 · Raw content keys across the app: ContentService.initialize() has no caller, so every getValue without a default shows its key

- kind: bug
- status: open
- ticket: 32
- run: w3-20261008T1256Z
- screen: many: Log In, Timeline, Learn, Settings, Sign Out dialog, Connected Apps
- decision: 

**Steps.**
1. Fresh install (cleared app data), dev build a89ace2a, online or offline.
2. Log in with email offline (Log In); sign in online and look at the Timeline's reconnect notice; open
   Learn; open Settings; tap Sign Out; open Settings → Connected Apps.

**Expected.**
Every string read through `contentService.getValue(key)` shows its text from the content system or
from the bundled defaults (`assets/config/content_defaults.json`, which holds every key below).

**Actual.**
The raw key is shown instead, on every surface that reads a key without a `defaultValue`:
- Log In offline: `auth.login.error_no_connection` (default "No connection. Check your network and try again.").
- Timeline, first launch after sign-in: the reconnect notice reads `connections.reconnect_notice` and
  `connections.reconnect_notice_action`, wrapped one syllable per line.
- Learn: both Notify Me buttons read `learn.notify_me`; after a tap `learn.notify_me_noted`, toast `learn.notify_me_confirm`.
- Settings: `settings.delete_account_button`, `settings.profile_preferences_title`, `settings.profile_preferences_subtitle`.
- Sign Out dialog: title `settings.sign_out_confirm_title`, body `settings.sign_out_confirm_body`, buttons
  `settings.confirm_cancel` and `settings.sign_out_confirm_action` (defaults: "Sign out?" / "You'll need to
  sign in again to use Mealvana. Your data stays with your account." / "Cancel" / "Sign out"). This is
  what blocks retest 08-021: the behaviour matches the intended text, but the athlete reads four keys.
- Connected Apps: `settings.connection_reconnect_button`, `settings.connection_needs_reconnect`, `connections.garmin_sync_note`.
Cause from code: `ContentService.initialize()` (`lib/features/content/application/content_service.dart:20`)
fills `_cachedContent`; nothing in `lib/` calls it (the last caller, `contentService.initialize()` in the
startup service, went in `ab6c04ce`, 2025-08-22). With `_cachedContent` null, `getValue` returns
`defaultValue ?? key` (`:71-75`). The dev `app_content` table is empty (db-app-content.txt), so remote
content is not the cause. The keys became visible as wave 2's review fixes and ticket 29 moved literals
into content keys read without a default. Ticket 23's Out-of-credits dialog strings go the same way
(not seen in this run: no AI spend).

**Evidence.**
- runs/32/b05-offline-login-14s.png `auth.login.error_no_connection`
- runs/32/c02-timeline-after-dont-allow.png reconnect notice keys
- runs/32/f01-learn-tab.png Learn
- runs/32/f12-notify-me-courses.png noted + confirm keys
- runs/32/g01-settings.png Settings keys
- runs/32/l01-sign-out-dialog.png Sign Out dialog keys
- runs/32/m01-connected-apps.png Connected Apps keys
- runs/32/db-app-content.txt dev `app_content` has no active row
- runs/32/notes.md steps 2, 4, 8, 9, 12 and the Connected Apps section

**Decision quote.**
> 

**Triage.**
