# 108: A password reset signs out everywhere else, and a leftover Kroger connection can be removed

**Status:** in-progress (wave 28, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Two small fixes from the 2026-09-25 follow-up sort.
1. **A reset signs out every other session (32-003, Lee 2026-09-25).** After Set New Password succeeds, every other session of that account ends: the recovery session the reset code opened and any other device (Supabase global sign-out, or the admin API on the server if the client can't end the recovery session itself). The athlete then signs in once with the new password, as today. Ordinary sign-out from Settings stays local (`SignOutScope.local`); only the reset changes.
2. **A leftover connection from the other Kroger environment (22-005).** Today the Kroger screen shows only "Connect Kroger" when the stored `kroger_connections` row belongs to the environment dev is not on (a production token while dev runs certification), and nothing shows or removes it. The screen shows that a connection exists and offers Disconnect. Connect still replaces it. Read the `kroger` function's `status` action and the screen before choosing how.

**Findings:** 32-003, 22-005. Retest ticket 109 covers both.

**Decisions:** none on the page; Lee's ruling in the terminal (32-003).

**Touches:** lib/features/auth/application/supabase_auth_service.dart, lib/features/auth/presentation/providers/password_recovery_controller.dart, lib/features/auth/application/email_auth_service.dart (only if the reset path runs there), lib/features/kroger/, supabase/functions/kroger/index.ts, supabase/functions/_shared/kroger/, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [x] Controller test through the real notifier: a successful password update then signs out globally; a failed one signs nothing out.
- [x] Kroger: a test (deno for `status`, widget for the screen) where the stored connection is the other environment's: the screen shows it and Disconnect removes the row; Connect replaces it.
- [x] No hardcoded strings: any new text goes through the content system.
- [x] `flutter analyze` clean on touched files, deno tests for touched functions. Deploy: wave lead.

Next: /implement-lee testing-wave
