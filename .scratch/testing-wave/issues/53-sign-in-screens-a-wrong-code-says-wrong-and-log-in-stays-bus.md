# 53: Sign-in screens: a wrong code says wrong, and Log In stays busy

**Status:** in-progress (wave 19, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A mistyped signup code says the code is not right; only an actually expired code says expired (GoTrue answers both with "Token has expired or is invalid", so the app tells them apart another way or says "wrong or expired"). After Log In, the screen stays in its busy state until the tabs shell replaces it, so it never comes back enabled for a second.

**Findings:** 32-001, 12-003 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** none; the fix restores behaviour no decision disputes.

**Touches:** lib/features/auth/application/email_auth_service.dart, lib/features/auth/domain/auth_exceptions.dart, lib/features/auth/presentation/screens/email_login_screen.dart

- [x] Unit test on the code-error mapping.
- [x] Widget test: Log In stays disabled from tap to navigation.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
